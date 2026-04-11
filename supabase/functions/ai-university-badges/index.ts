/**
 * ai-university-badges — AI大学 達成バッジ管理EF
 *
 * `award_ai_university_badge` RPC のラッパー + 条件評価ロジック。
 *
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
 * 認証:
 *   - list (自分) / award / check_* : Supabase JWT 必須
 *   - list (他人) / leaderboard       : 認証不要 (RLS で is_public=true に絞られる)
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
      if (SERVICE_ROLE_KEY === "") {
        return json({ success: false, error: "misconfigured" }, 500);
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

      return json({
        success: true,
        correct_count: correctCount,
        total_providers: totalProviders,
        awarded,
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
