/**
 * ai-university-badges — AI大学 達成バッジ + スコア管理EF
 *
 * `award_ai_university_badge` RPC のラッパー + 条件評価ロジック + クイズスコア書き込み。
 *
 * ── バッジ系 ─────────────────────────────────────────────────────────────
 * POST { action: "list", user_id? }
 *   → 認証ユーザーのバッジ一覧を取得 (user_id 省略時は自分)。
 *   → user_id 指定時は is_public=true のバッジのみ返す (他人のプロフィール表示用)
 *
 * POST { action: "award", badge_id, badge_name, icon_emoji?, condition? }
 *   → 手動でバッジを付与 (social_sharer 等、クライアント側イベント駆動)
 *   返り値: { success, newly_awarded: boolean }
 *
 * POST { action: "check_streaks" }
 *   → ai_university_streaks.current_streak を参照し、3d/7d/30d 条件を満たすバッジを自動付与
 *   返り値: { success, current_streak, awarded: string[] }
 *
 * POST { action: "check_quiz_master" }
 *   → ai_university_scores で quiz_correct=true のユニークプロバイダー数をカウントし、
 *     3社以上で quiz_master_3、全登録プロバイダーで quiz_master_all を付与
 *   返り値: { success, correct_count, total_providers, awarded: string[] }
 *
 * POST { action: "leaderboard", limit? } / GET ?action=leaderboard&limit=20
 *   → 公開バッジ保有数上位の user_id ランキング (service_role 読み出し)
 *
 * ── スコア系 (ai_university_scores UPSERT ラッパー) ──────────────────────
 * POST { action: "record_score", provider_id, quiz_correct }
 *   → クイズ結果を ai_university_scores に UPSERT (user_id, provider_id の複合ユニーク)
 *   → quiz_correct が初めて true になった場合、check_quiz_master を連続呼び出し
 *   返り値: { success, is_new_provider, newly_correct, awarded_badges: string[] }
 *
 * POST { action: "get_scores" } / GET ?action=get_scores
 *   → 認証ユーザー自身の全プロバイダースコアを返す
 *   返り値: { success, scores: [{provider_id, quiz_correct, studied_at}], correct_count }
 *
 * POST { action: "score_leaderboard", limit? } / GET ?action=score_leaderboard&limit=20
 *   → ai_university_leaderboard ビュー (total_correct 降順) 読み出し
 *   返り値: { success, leaderboard: [{rank, user_id, total_correct, providers_studied}] }
 *
 * 認証:
 *   - list (自分) / award / check_* / record_score / get_scores : Supabase JWT 必須
 *   - list (他人) / leaderboard / score_leaderboard             : 認証不要 (public 読み出し)
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

// バッジ定義 (DB migration のコメントと同期)
const STREAK_BADGES: Array<{
  threshold: number;
  badge_id: string;
  badge_name: string;
  icon_emoji: string;
  condition: string;
}> = [
  {
    threshold: 3,
    badge_id: "streak_3d",
    badge_name: "3日連続学習",
    icon_emoji: "🔥",
    condition: "current_streak >= 3",
  },
  {
    threshold: 7,
    badge_id: "streak_7d",
    badge_name: "週間皆勤賞",
    icon_emoji: "🔥",
    condition: "current_streak >= 7",
  },
  {
    threshold: 30,
    badge_id: "streak_30d",
    badge_name: "月間皆勤賞",
    icon_emoji: "🏆",
    condition: "current_streak >= 30",
  },
];

const QUIZ_MASTER_3 = {
  badge_id: "quiz_master_3",
  badge_name: "クイズ3冠",
  icon_emoji: "🌟",
  condition: "3社以上のクイズ正解",
};

const QUIZ_MASTER_ALL = {
  badge_id: "quiz_master_all",
  badge_name: "全社制覇",
  icon_emoji: "👑",
  condition: "全登録プロバイダーでクイズ正解",
};

// 共通: クイズマスターバッジ審査ロジック
// check_quiz_master action と record_score action で共有
async function evaluateQuizMaster(
  // deno-lint-ignore no-explicit-any
  client: any,
  userId: string,
): Promise<{
  correct_count: number;
  total_providers: number;
  awarded: string[];
}> {
  if (SERVICE_ROLE_KEY === "") {
    throw new Error("service_role key missing for quiz master evaluation");
  }
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // ユーザーの正解プロバイダー集合
  const { data: scoreRows, error: scoreErr } = await admin
    .from("ai_university_scores")
    .select("provider_id")
    .eq("user_id", userId)
    .eq("quiz_correct", true);
  if (scoreErr) throw scoreErr;

  const correctSet = new Set<string>();
  for (const row of scoreRows ?? []) {
    const pid = asString((row as { provider_id: unknown }).provider_id);
    if (pid !== "") correctSet.add(pid);
  }
  const correctCount = correctSet.size;

  // 全登録プロバイダー数 (is_active=true)
  const { data: providerRows, error: providerErr } = await admin
    .from("ai_university_content")
    .select("provider")
    .eq("is_active", true);
  if (providerErr) throw providerErr;

  const providerSet = new Set<string>();
  for (const row of providerRows ?? []) {
    const p = asString((row as { provider: unknown }).provider);
    if (p !== "") providerSet.add(p);
  }
  const totalProviders = providerSet.size;

  const awarded: string[] = [];

  if (correctCount >= 3) {
    const { data: r, error: e } = await client.rpc(
      "award_ai_university_badge",
      {
        p_user_id: userId,
        p_badge_id: QUIZ_MASTER_3.badge_id,
        p_badge_name: QUIZ_MASTER_3.badge_name,
        p_icon_emoji: QUIZ_MASTER_3.icon_emoji,
        p_condition: QUIZ_MASTER_3.condition,
      },
    );
    if (e) throw e;
    if (r === true) awarded.push(QUIZ_MASTER_3.badge_id);
  }

  if (totalProviders > 0 && correctCount >= totalProviders) {
    const { data: r, error: e } = await client.rpc(
      "award_ai_university_badge",
      {
        p_user_id: userId,
        p_badge_id: QUIZ_MASTER_ALL.badge_id,
        p_badge_name: QUIZ_MASTER_ALL.badge_name,
        p_icon_emoji: QUIZ_MASTER_ALL.icon_emoji,
        p_condition: QUIZ_MASTER_ALL.condition,
      },
    );
    if (e) throw e;
    if (r === true) awarded.push(QUIZ_MASTER_ALL.badge_id);
  }

  return {
    correct_count: correctCount,
    total_providers: totalProviders,
    awarded,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS });
  }

  if (SUPABASE_URL === "" || SUPABASE_ANON_KEY === "") {
    return json({ success: false, error: "misconfigured" }, 500);
  }

  // ── Parse action + params ────────────────────────────────────────────────
  let action = "";
  let params: Record<string, unknown> = {};

  if (req.method === "GET") {
    const url = new URL(req.url);
    action = url.searchParams.get("action") ?? "list";
    params = {
      user_id: url.searchParams.get("user_id") ?? undefined,
      limit: url.searchParams.get("limit") ?? undefined,
    };
  } else if (req.method === "POST") {
    try {
      params = await req.json();
    } catch {
      params = {};
    }
    action = asString(params.action) || "list";
  } else {
    return json({ success: false, error: "Method not allowed" }, 405);
  }

  // ── leaderboard: public read via service-role ────────────────────────────
  if (action === "leaderboard") {
    if (SERVICE_ROLE_KEY === "") {
      return json(
        {
          success: false,
          error: "leaderboard unavailable: service_role missing",
        },
        500,
      );
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const limit = Math.max(1, Math.min(100, asNumber(params.limit, 20)));

    try {
      const { data, error } = await admin
        .from("ai_university_badges")
        .select("user_id")
        .eq("is_public", true);
      if (error) throw error;

      // user_id 別にカウント集計
      const counts = new Map<string, number>();
      for (const row of data ?? []) {
        const uid = (row as { user_id: string }).user_id;
        counts.set(uid, (counts.get(uid) ?? 0) + 1);
      }

      const ranking = [...counts.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, limit)
        .map(([user_id, badge_count], idx) => ({
          rank: idx + 1,
          user_id,
          badge_count,
        }));

      return json({
        success: true,
        leaderboard: ranking,
        count: ranking.length,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return json({ success: false, error: message }, 500);
    }
  }

  // ── score_leaderboard: クイズ正解数ランキング (public 読み出し) ───────────
  if (action === "score_leaderboard") {
    if (SERVICE_ROLE_KEY === "") {
      return json(
        {
          success: false,
          error: "score_leaderboard unavailable: service_role missing",
        },
        500,
      );
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const limit = Math.max(1, Math.min(100, asNumber(params.limit, 20)));

    try {
      const { data, error } = await admin
        .from("ai_university_leaderboard")
        .select(
          "user_id, display_name, total_correct, providers_studied, last_studied_at, rank",
        )
        .order("rank", { ascending: true })
        .limit(limit);
      if (error) throw error;

      // email を直接返したくないので、display_name は @ 以前のみを返す
      const sanitized = (data ?? []).map((row) => {
        const r = row as Record<string, unknown>;
        const raw = asString(r.display_name);
        const handle = raw.includes("@") ? raw.split("@")[0] : raw;
        return {
          rank: asNumber(r.rank, 0),
          user_id: asString(r.user_id),
          display_name: handle,
          total_correct: asNumber(r.total_correct, 0),
          providers_studied: asNumber(r.providers_studied, 0),
          last_studied_at: r.last_studied_at ?? null,
        };
      });

      return json({
        success: true,
        leaderboard: sanitized,
        count: sanitized.length,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return json({ success: false, error: message }, 500);
    }
  }

  // ── 他人のバッジ閲覧 (is_public のみ / 認証不要) ─────────────────────────
  if (action === "list" && asString(params.user_id) !== "") {
    if (SERVICE_ROLE_KEY === "") {
      return json({ success: false, error: "misconfigured" }, 500);
    }
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const targetUserId = asString(params.user_id);
    try {
      const { data, error } = await admin
        .from("ai_university_badges")
        .select(
          "badge_id, badge_name, icon_emoji, condition, awarded_at, is_public",
        )
        .eq("user_id", targetUserId)
        .eq("is_public", true)
        .order("awarded_at", { ascending: false });
      if (error) throw error;
      return json({
        success: true,
        user_id: targetUserId,
        badges: data ?? [],
        count: (data ?? []).length,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return json({ success: false, error: message }, 500);
    }
  }

  // ── user-scoped actions (list自分 / award / check_*) ─────────────────────
  const authHeader = req.headers.get("authorization") ?? "";
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: { user }, error: authError } = await client.auth.getUser();
  if (authError || !user) {
    return json({ success: false, error: "unauthorized" }, 401);
  }
  const userId = user.id;

  try {
    // ── action: list (自分のバッジ) ────────────────────────────────────────
    if (action === "list") {
      const { data, error } = await client
        .from("ai_university_badges")
        .select(
          "badge_id, badge_name, icon_emoji, condition, awarded_at, is_public",
        )
        .eq("user_id", userId)
        .order("awarded_at", { ascending: false });
      if (error) throw error;

      return json({
        success: true,
        badges: data ?? [],
        count: (data ?? []).length,
      });
    }

    // ── action: award (手動付与) ───────────────────────────────────────────
    if (action === "award") {
      const badgeId = asString(params.badge_id);
      const badgeName = asString(params.badge_name);
      if (badgeId === "" || badgeName === "") {
        return json(
          { success: false, error: "badge_id and badge_name are required" },
          400,
        );
      }
      const iconInput = asString(params.icon_emoji);
      const iconEmoji = iconInput === "" ? "🏅" : iconInput;
      const conditionInput = asString(params.condition);
      const condition = conditionInput === "" ? null : conditionInput;

      const { data, error } = await client.rpc("award_ai_university_badge", {
        p_user_id: userId,
        p_badge_id: badgeId,
        p_badge_name: badgeName,
        p_icon_emoji: iconEmoji,
        p_condition: condition,
      });
      if (error) throw error;

      return json({
        success: true,
        newly_awarded: Boolean(data),
        badge_id: badgeId,
      });
    }

    // ── action: check_streaks ──────────────────────────────────────────────
    if (action === "check_streaks") {
      const { data: streakRow, error: streakErr } = await client
        .from("ai_university_streaks")
        .select("current_streak")
        .eq("user_id", userId)
        .maybeSingle();
      if (streakErr) throw streakErr;

      const currentStreak = streakRow
        ? asNumber(
          (streakRow as Record<string, unknown>).current_streak,
          0,
        )
        : 0;

      const awarded: string[] = [];
      for (const badge of STREAK_BADGES) {
        if (currentStreak < badge.threshold) continue;
        const { data: awardResult, error: awardErr } = await client.rpc(
          "award_ai_university_badge",
          {
            p_user_id: userId,
            p_badge_id: badge.badge_id,
            p_badge_name: badge.badge_name,
            p_icon_emoji: badge.icon_emoji,
            p_condition: badge.condition,
          },
        );
        if (awardErr) throw awardErr;
        if (awardResult === true) {
          awarded.push(badge.badge_id);
        }
      }

      return json({
        success: true,
        current_streak: currentStreak,
        awarded,
      });
    }

    // ── action: check_quiz_master ──────────────────────────────────────────
    if (action === "check_quiz_master") {
      const result = await evaluateQuizMaster(client, userId);
      return json({ success: true, ...result });
    }

    // ── action: record_score ──────────────────────────────────────────────
    // クイズ結果を ai_university_scores に UPSERT し、
    // 正解が新しく記録されたらバッジ審査まで連続実行する
    if (action === "record_score") {
      const providerId = asString(params.provider_id);
      if (providerId === "") {
        return json(
          { success: false, error: "provider_id is required" },
          400,
        );
      }
      const quizCorrect = Boolean(params.quiz_correct);

      // 既存行を取得 (RLS: auth.uid() = user_id で自動絞り込み)
      const { data: existing, error: selectErr } = await client
        .from("ai_university_scores")
        .select("id, quiz_correct")
        .eq("user_id", userId)
        .eq("provider_id", providerId)
        .maybeSingle();
      if (selectErr) throw selectErr;

      const wasCorrect = Boolean(
        existing && (existing as Record<string, unknown>).quiz_correct,
      );
      const isNewProvider = existing === null;
      const newlyCorrect = !wasCorrect && quizCorrect;

      if (existing && typeof existing === "object" && "id" in existing) {
        // UPDATE: 既に正解済みなら quiz_correct は true のまま維持する
        // (一度正解したものを不正解で上書きしない)
        const nextCorrect = wasCorrect || quizCorrect;
        const { error: updateErr } = await client
          .from("ai_university_scores")
          .update({
            quiz_correct: nextCorrect,
            studied_at: new Date().toISOString(),
          })
          .eq("id", (existing as { id: string }).id);
        if (updateErr) throw updateErr;
      } else {
        const { error: insertErr } = await client
          .from("ai_university_scores")
          .insert({
            user_id: userId,
            provider_id: providerId,
            quiz_correct: quizCorrect,
            studied_at: new Date().toISOString(),
          });
        if (insertErr) throw insertErr;
      }

      // 新規に正解した場合のみバッジ審査を実施
      let awardedBadges: string[] = [];
      let correctCount = 0;
      let totalProviders = 0;
      if (newlyCorrect) {
        const evalResult = await evaluateQuizMaster(client, userId);
        awardedBadges = evalResult.awarded;
        correctCount = evalResult.correct_count;
        totalProviders = evalResult.total_providers;
      }

      return json({
        success: true,
        is_new_provider: isNewProvider,
        newly_correct: newlyCorrect,
        awarded_badges: awardedBadges,
        correct_count: correctCount,
        total_providers: totalProviders,
      });
    }

    // ── action: get_scores ────────────────────────────────────────────────
    if (action === "get_scores") {
      const { data, error } = await client
        .from("ai_university_scores")
        .select("provider_id, quiz_correct, studied_at")
        .eq("user_id", userId)
        .order("studied_at", { ascending: false });
      if (error) throw error;

      const scores = data ?? [];
      const correctCount = scores.filter(
        (row) => (row as { quiz_correct: boolean }).quiz_correct,
      ).length;

      return json({
        success: true,
        scores,
        correct_count: correctCount,
        providers_studied: scores.length,
      });
    }

    return json(
      { success: false, error: `Unknown action: ${action}` },
      400,
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("ai-university-badges error:", err);
    return json({ success: false, error: message }, 500);
  }
});
