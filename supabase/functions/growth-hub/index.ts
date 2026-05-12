// growth-hub — グロース・バイラル・マーケティング統合EF
// Merges (20 EFs): growth-acquisition, growth-command-center, growth-referral,
//   growth-share-signal, growth-achievement-summary, growth-import-preview,
//   growth-import-commit, get-growth-roadmap-progress, video-ad-generator,
//   viral-share-engine, x-media-post, growth-automation-controller,
//   landing-ab-test, referral-program, share-quote, generate-quote-image,
//   seo-optimizer, send-waitlist-notification, viral-ad-generator, viral-growth-engine

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  getXAccountHandle,
  isXConfigured,
  postTweet,
  uploadMediaFromUrl,
} from "../_shared/x-client.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return null;
  const c = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const {
    data: { user },
  } = await c.auth.getUser();
  return user?.id ?? null;
}

async function listItems(
  admin: SupabaseClient,
  source: string,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin
    .from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  meta: Record<string, unknown>,
) {
  const { data, error } = await admin
    .from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at")
    .single();
  if (error) throw new Error(error.message);
  return data;
}

type ReferralCodeRow = {
  id: number;
  user_id: string;
  referral_code: string;
  total_referrals: number | null;
  successful_referrals: number | null;
  bonus_points_earned: number | null;
  created_at: string;
  updated_at: string;
};

type ReferralRow = {
  id: number;
  referrer_user_id: string;
  referred_user_id: string;
  referral_code: string;
  bonus_points: number | null;
  status: string | null;
  completed_at: string | null;
  created_at: string;
};

const TOUCHPOINT_DEFS = [
  {
    id: "landing",
    label: "Landing",
    touchSignal: "touch_landing",
    signupSignal: "signup_submit_landing",
  },
  {
    id: "import",
    label: "Import",
    touchSignal: "touch_import",
    signupSignal: "signup_submit_import",
  },
  {
    id: "public_memo",
    label: "Public memo",
    touchSignal: "touch_public_memo",
    signupSignal: "signup_submit_public_memo",
  },
  {
    id: "referral",
    label: "Referral",
    touchSignal: "touch_referral",
    signupSignal: "signup_submit_referral",
  },
  {
    id: "comparison",
    label: "Comparison",
    touchSignal: "touch_comparison",
    signupSignal: "signup_submit_comparison",
  },
  {
    id: "guitar",
    label: "Guitar",
    touchSignal: "touch_guitar_gallery",
    signupSignal: "signup_submit_guitar",
  },
];

const IMPORT_PREVIEW_DEFS = [
  {
    id: "notion",
    label: "Notion previews",
    signalKey: "import_preview_notion",
  },
  {
    id: "evernote",
    label: "Evernote previews",
    signalKey: "import_preview_evernote",
  },
  {
    id: "markdown",
    label: "Markdown previews",
    signalKey: "import_preview_markdown",
  },
];

const SUPPORTED_ACQUISITION_SIGNALS = new Set([
  "touch_landing",
  "touch_import",
  "touch_public_memo",
  "touch_referral",
  "touch_comparison",
  "touch_guitar_gallery",
  "import_preview_notion",
  "import_preview_evernote",
  "import_preview_markdown",
  "import_signup_cta",
  "public_memo_signup_cta",
  "signup_submit_landing",
  "signup_submit_import",
  "signup_submit_public_memo",
  "signup_submit_referral",
  "signup_submit_comparison",
  "signup_submit_guitar",
]);

function formatDateKey(date: Date): string {
  return `${date.getFullYear()}-${
    String(date.getMonth() + 1).padStart(2, "0")
  }-${String(date.getDate()).padStart(2, "0")}`;
}

function resolveDateKey(rawDateKey: unknown): string {
  return typeof rawDateKey === "string" &&
      /^\d{4}-\d{2}-\d{2}$/.test(rawDateKey)
    ? rawDateKey
    : formatDateKey(new Date());
}

function isSupportedAcquisitionSignal(signalKey: string): boolean {
  return SUPPORTED_ACQUISITION_SIGNALS.has(signalKey) ||
    /^touch_comparison_[a-z0-9_-]{1,64}$/i.test(signalKey);
}

async function recordAcquisitionSignal(
  admin: SupabaseClient,
  rawSignalKey: unknown,
  rawDateKey?: unknown,
) {
  const signalKey = String(rawSignalKey ?? "").trim();
  if (!signalKey || !isSupportedAcquisitionSignal(signalKey)) {
    return {
      success: false,
      error: "signalKey required / unsupported",
    };
  }

  const dateKey = resolveDateKey(rawDateKey);
  const { data: existing, error: existingError } = await admin
    .from("app_analytics")
    .select("date, source_details")
    .eq("date", dateKey)
    .maybeSingle();
  if (existingError) throw new Error(existingError.message);

  if (!existing) {
    const { error } = await admin.from("app_analytics").upsert({
      date: dateKey,
      landing_views: 0,
      conversions: 0,
      share_count: 0,
      source_details: { [signalKey]: 1 },
    });
    if (error) throw new Error(error.message);
    return { success: true, signalKey, dateKey };
  }

  const details = (existing.source_details ?? {}) as Record<string, unknown>;
  const next: Record<string, number> = {};
  for (const [key, value] of Object.entries(details)) {
    const count = typeof value === "number" ? value : Number(value);
    if (Number.isFinite(count) && count > 0) next[key] = count;
  }
  next[signalKey] = (next[signalKey] ?? 0) + 1;

  const { error } = await admin
    .from("app_analytics")
    .update({ source_details: next })
    .eq("date", dateKey);
  if (error) throw new Error(error.message);
  return { success: true, signalKey, dateKey };
}

async function buildAcquisitionTouchpointReport(
  admin: SupabaseClient,
  rawWindowDays: unknown,
) {
  const windowDaysRaw = typeof rawWindowDays === "number"
    ? rawWindowDays
    : Number(rawWindowDays ?? 30);
  const windowDays = Number.isFinite(windowDaysRaw)
    ? Math.max(7, Math.min(90, Math.trunc(windowDaysRaw)))
    : 30;
  const endDate = new Date();
  endDate.setHours(0, 0, 0, 0);
  const startDate = new Date(endDate);
  startDate.setDate(startDate.getDate() - (windowDays - 1));
  const startKey = formatDateKey(startDate);
  const endKey = formatDateKey(endDate);
  const { data, error } = await admin
    .from("app_analytics")
    .select("date, source_details")
    .gte("date", startKey)
    .lte("date", endKey)
    .order("date", { ascending: true });
  if (error) throw new Error(error.message);

  const counts: Record<string, number> = {};
  for (const row of data ?? []) {
    const details = (row.source_details ?? {}) as Record<string, unknown>;
    for (const [key, value] of Object.entries(details)) {
      const count = typeof value === "number" ? value : Number(value);
      if (Number.isFinite(count) && count > 0) {
        counts[key] = (counts[key] ?? 0) + count;
      }
    }
  }

  const touchpoints = TOUCHPOINT_DEFS.map((def) => {
    const touches = counts[def.touchSignal] ?? 0;
    const signups = counts[def.signupSignal] ?? 0;
    const rate = touches > 0 ? Math.round((signups / touches) * 1000) / 10 : 0;
    return {
      id: def.id,
      label: def.label,
      touchpoint: def.label,
      touchCount: touches,
      signupSubmitCount: signups,
      signupSubmits: signups,
      touches,
      signups,
      rate,
    };
  });
  const totalTouches = touchpoints.reduce(
    (total, item) => total + item.touches,
    0,
  );
  const totalSignups = touchpoints.reduce(
    (total, item) => total + item.signups,
    0,
  );
  const conversionRate = totalTouches > 0
    ? Math.round((totalSignups / totalTouches) * 1000) / 10
    : 0;
  const importPreviews = IMPORT_PREVIEW_DEFS.map((def) => ({
    id: def.id,
    label: def.label,
    previewCount: counts[def.signalKey] ?? 0,
  }));

  return {
    success: true,
    windowDays,
    startDate: startKey,
    endDate: endKey,
    summary: { totalTouches, totalSignups, conversionRate },
    touchpoints,
    importPreviews,
    importSignupCtaCount: counts["import_signup_cta"] ?? 0,
    publicMemoSignupCtaCount: counts["public_memo_signup_cta"] ?? 0,
  };
}

function generateReferralCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return Array.from(bytes)
    .map((byte) => alphabet[byte % alphabet.length])
    .join("");
}

async function fetchReferralCode(
  admin: SupabaseClient,
  userId: string,
): Promise<ReferralCodeRow | null> {
  const { data, error } = await admin
    .from("referral_codes")
    .select(
      "id, user_id, referral_code, total_referrals, successful_referrals, bonus_points_earned, created_at, updated_at",
    )
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return (data as ReferralCodeRow | null) ?? null;
}

async function ensureReferralCode(
  admin: SupabaseClient,
  userId: string,
): Promise<ReferralCodeRow> {
  const existing = await fetchReferralCode(admin, userId);
  if (existing) return existing;

  for (let attempt = 0; attempt < 8; attempt++) {
    const code = generateReferralCode();
    const { error } = await admin.from("referral_codes").insert({
      user_id: userId,
      referral_code: code,
    });
    if (!error) {
      const created = await fetchReferralCode(admin, userId);
      if (created) return created;
    }
    if (!String(error?.message ?? "").includes("duplicate")) {
      throw new Error(error?.message ?? "Failed to create referral code");
    }
  }

  const afterRetry = await fetchReferralCode(admin, userId);
  if (afterRetry) return afterRetry;
  throw new Error("Failed to create unique referral code");
}

async function applyPendingReferral(
  admin: SupabaseClient,
  referredUserId: string,
  rawPendingCode: unknown,
): Promise<boolean> {
  const pendingCode = String(rawPendingCode ?? "").trim().toUpperCase();
  if (!pendingCode) return false;

  const { data: existingReferral, error: existingError } = await admin
    .from("referrals")
    .select("id")
    .eq("referred_user_id", referredUserId)
    .maybeSingle();
  if (existingError) throw new Error(existingError.message);
  if (existingReferral) return true;

  const { data: referrer, error: referrerError } = await admin
    .from("referral_codes")
    .select("user_id, referral_code")
    .eq("referral_code", pendingCode)
    .maybeSingle();
  if (referrerError) throw new Error(referrerError.message);
  if (!referrer) return false;

  const referrerUserId = String(
    (referrer as { user_id?: string }).user_id ?? "",
  );
  if (!referrerUserId || referrerUserId === referredUserId) return true;

  const { error: insertError } = await admin.from("referrals").insert({
    referrer_user_id: referrerUserId,
    referred_user_id: referredUserId,
    referral_code: pendingCode,
    bonus_points: 500,
    status: "completed",
    completed_at: new Date().toISOString(),
  });
  if (insertError && !String(insertError.message).includes("duplicate")) {
    throw new Error(insertError.message);
  }

  const { data: rows, error: countError } = await admin
    .from("referrals")
    .select("status, bonus_points")
    .eq("referrer_user_id", referrerUserId);
  if (countError) throw new Error(countError.message);

  const totalReferrals = (rows ?? []).length;
  const successfulReferrals =
    (rows ?? []).filter((row) => row.status === "completed").length;
  const bonusPointsEarned = (rows ?? []).reduce((sum, row) => {
    return row.status === "completed"
      ? sum + (Number(row.bonus_points) || 0)
      : sum;
  }, 0);

  const { error: updateError } = await admin
    .from("referral_codes")
    .update({
      total_referrals: totalReferrals,
      successful_referrals: successfulReferrals,
      bonus_points_earned: bonusPointsEarned,
    })
    .eq("user_id", referrerUserId);
  if (updateError) throw new Error(updateError.message);

  return true;
}

async function buildReferralPayload(
  admin: SupabaseClient,
  userId: string,
  pendingCode?: unknown,
) {
  const clearPendingCode = await applyPendingReferral(
    admin,
    userId,
    pendingCode,
  );
  const referralCode = await ensureReferralCode(admin, userId);
  const { data: referrals, error } = await admin
    .from("referrals")
    .select(
      "id, referrer_user_id, referred_user_id, referral_code, bonus_points, status, completed_at, created_at",
    )
    .eq("referrer_user_id", userId)
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);

  const rows = (referrals ?? []) as ReferralRow[];
  const successfulReferrals =
    rows.filter((row) => row.status === "completed").length;
  return {
    success: true,
    referralCode,
    referrals: rows,
    items: rows.map((row) => ({
      id: row.id,
      created_at: row.created_at,
      metadata: {
        code: referralCode.referral_code,
        referral_code: row.referral_code,
        status: row.status,
        bonus_points: row.bonus_points,
        completed_at: row.completed_at,
      },
    })),
    totalReferrals: rows.length,
    successfulReferrals,
    clearPendingCode,
  };
}

async function _deleteItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  id: string,
) {
  const { error } = await admin
    .from("hub_data")
    .delete()
    .eq("id", id)
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

function _applyAchievements<
  T extends { label: string; features_done: number; features_total: number },
>(
  plans: T[],
  achievementsCount: number,
): T[] {
  return plans.map((p) => {
    if (p.label === "短期計画") {
      return {
        ...p,
        features_done: Math.min(achievementsCount, 50),
        features_total: 50,
      };
    }
    if (p.label === "中期計画") {
      return {
        ...p,
        features_done: Math.min(achievementsCount, 200),
        features_total: 200,
      };
    }
    if (p.label === "長期計画") {
      return {
        ...p,
        features_done: Math.min(achievementsCount, 500),
        features_total: 500,
      };
    }
    return p;
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    const action = (body.action as string) ?? "";

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Public actions that don't require auth
    const publicActions = [
      "waitlist.notify",
      "acquisition.report",
      "acquisition.signal",
      "acquisition.track",
      "acquisition.touchpoint_report",
    ];
    let userId: string | null = null;
    if (!publicActions.includes(action)) {
      userId = await getUserId(req);
      if (!userId) return json({ error: "Unauthorized" }, 401);
    }

    switch (action) {
      // ─── Acquisition ───────────────────────────────────────────────────────
      case "acquisition.get": {
        const items = await listItems(admin, "growth_signal", userId!);
        return json({ success: true, items });
      }

      case "acquisition.track": {
        const result = await recordAcquisitionSignal(
          admin,
          body.signalKey ?? body.channel,
          body.dateKey,
        );
        return json(result, result.success ? 200 : 400);
      }

      case "acquisition.report": {
        const report = await buildAcquisitionTouchpointReport(
          admin,
          body.windowDays,
        );
        return json({ ...report, report });
      }

      // ─── Landing touchpoint signals (global / anonymous, app_analytics.source_details) ─
      case "acquisition.signal": {
        const result = await recordAcquisitionSignal(
          admin,
          body.signalKey,
          body.dateKey,
        );
        return json(result, result.success ? 200 : 400);
      }

      case "acquisition.touchpoint_report": {
        return json(
          await buildAcquisitionTouchpointReport(admin, body.windowDays),
        );
      }

      // ─── Command Center ─────────────────────────────────────────────────────
      // ─── Daily Challenges ─────────────────────────────────────────────────
      case "daily.challenges_generate": {
        const dateStr = typeof body.date === "string" &&
            /^\d{4}-\d{2}-\d{2}$/.test(body.date as string)
          ? (body.date as string)
          : (() => {
            const d = new Date();
            return `${d.getFullYear()}-${
              String(d.getMonth() + 1).padStart(2, "0")
            }-${String(d.getDate()).padStart(2, "0")}`;
          })();
        const defaults = [
          {
            challenge_type: "create_notes",
            challenge_title: "今日のメモ作成",
            challenge_description: "3つのメモを作成しよう",
            target_value: 3,
            reward_points: 50,
          },
          {
            challenge_type: "earn_points",
            challenge_title: "ポイント獲得",
            challenge_description: "100ポイントを獲得しよう",
            target_value: 100,
            reward_points: 30,
          },
          {
            challenge_type: "share_notes",
            challenge_title: "メモを共有",
            challenge_description: "1つのメモを共有しよう",
            target_value: 1,
            reward_points: 40,
          },
        ];
        const rows = defaults.map((d) => ({
          ...d,
          challenge_date: dateStr,
          is_active: true,
        }));
        const { data: upserted, error: upErr } = await admin
          .from("daily_challenges")
          .upsert(rows, {
            onConflict: "challenge_date,challenge_type",
            ignoreDuplicates: true,
          })
          .select("id, challenge_type");
        if (upErr) throw new Error(upErr.message);
        return json({
          success: true,
          dateKey: dateStr,
          insertedCount: upserted?.length ?? 0,
          totalDefaults: defaults.length,
        });
      }

      case "command.analyze": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({
            success: true,
            analysis: "Gemini API key not configured",
            stage: "unknown",
          });
        }
        const userCount = Number(body.totalUsers ?? 0);
        const stage = userCount < 100
          ? "Pre-PMF"
          : userCount < 1000
          ? "Early traction"
          : "Scale-up";
        const prompt =
          `あなたは自分株式会社のCGO（最高グロース責任者）です。ユーザー数: ${userCount}人, ステージ: ${stage}. 今週の最優先アクションを3つ提案してください。JSON形式: {"stage":"...","actions":["...","...","..."]}`;
        const res = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
          },
        );
        const result = await res.json();
        const text = (
          result as {
            candidates?: [{ content: { parts: [{ text: string }] } }];
          }
        ).candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
        try {
          return json({
            success: true,
            ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")),
          });
        } catch {
          return json({ success: true, analysis: text, stage });
        }
      }

      // ─── Referral ────────────────────────────────────────────────────────────
      case "referral.list": {
        return json(
          await buildReferralPayload(admin, userId!, body.pendingCode),
        );
      }

      case "referral.create": {
        const payload = await buildReferralPayload(admin, userId!);
        if (body.email) {
          const item = await addItem(admin, "referral_invite", userId!, {
            referral_code: payload.referralCode.referral_code,
            invited_email: body.email,
            status: "pending",
          });
          return json({ ...payload, item });
        }
        return json(payload);
      }

      case "referral.complete": {
        if (body.pendingCode) {
          return json(
            await buildReferralPayload(admin, userId!, body.pendingCode),
          );
        }
        const { error } = await admin
          .from("hub_data")
          .update({
            metadata: {
              user_id: userId!,
              status: "completed",
              completed_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id))
          .eq("source", "referral");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      case "referral.complete_pending": {
        return json(
          await buildReferralPayload(admin, userId!, body.pendingCode),
        );
      }

      // ─── Share Signal ────────────────────────────────────────────────────────
      case "share.track": {
        const item = await addItem(admin, "share_signal", userId!, {
          content_id: body.content_id,
          channel: body.channel ?? "unknown",
          url: body.url,
        });
        return json({ success: true, item });
      }

      case "share.list": {
        const items = await listItems(admin, "share_signal", userId!);
        return json({ success: true, items });
      }

      // ─── Achievement ─────────────────────────────────────────────────────────
      case "achievement.list": {
        const items = await listItems(admin, "growth_achievement", userId!);
        return json({ success: true, items });
      }

      case "achievement.unlock": {
        const item = await addItem(admin, "growth_achievement", userId!, {
          type: body.type,
          title: body.title,
          unlocked_at: new Date().toISOString(),
        });
        return json({ success: true, item });
      }

      // ─── Import ──────────────────────────────────────────────────────────────
      case "import.preview": {
        const items = await listItems(admin, "import_preview", userId!);
        return json({ success: true, items });
      }

      case "import.create": {
        const item = await addItem(admin, "import_preview", userId!, {
          source: body.source,
          count: body.count ?? 0,
          status: "pending",
        });
        return json({ success: true, item });
      }

      case "import.commit": {
        const item = await addItem(admin, "import_commit", userId!, {
          preview_id: body.preview_id,
          committed_at: new Date().toISOString(),
        });
        return json({ success: true, item });
      }

      // ─── Roadmap Progress (実データ: growth_plans テーブル) ───────────────────
      case "roadmap.progress": {
        const [
          authListResult,
          { data: plansData },
          { count: achievementsCount },
        ] = await Promise.all([
          admin.auth.admin.listUsers({ page: 1, perPage: 1 }),
          admin
            .from("growth_plans")
            .select(
              "label, deadline, target, features_done, features_total, sort_order",
            )
            .order("sort_order", { ascending: true })
            .order("target", { ascending: true }),
          admin
            .from("development_achievements")
            .select("id", { count: "exact", head: true }),
        ]);
        const totalUsers =
          ((authListResult.data as { total?: number } | null)?.total) ?? 0;
        const totalAchievements = achievementsCount ?? 0;
        const plans = _applyAchievements(
          (plansData ?? []) as Array<
            {
              label: string;
              deadline: string;
              target: number;
              features_done: number;
              features_total: number;
              sort_order?: number;
            }
          >,
          totalAchievements,
        );
        return json({
          success: true,
          userCount: totalUsers,
          achievementsCount: totalAchievements,
          plans,
        });
      }

      // ─── Video Ad ─────────────────────────────────────────────────────────────
      case "video_ad.create": {
        const item = await addItem(admin, "video_ad", userId!, {
          title: body.title,
          script: body.script ?? "",
          style: body.style ?? "energetic",
          platform: body.platform ?? "tiktok",
          status: "draft",
        });
        return json({ success: true, item });
      }

      case "video_ad.list": {
        const items = await listItems(admin, "video_ad", userId!);
        return json({ success: true, items });
      }

      // ─── Viral Share ──────────────────────────────────────────────────────────
      case "viral.share": {
        const item = await addItem(admin, "viral_share", userId!, {
          content: body.content,
          channel: body.channel ?? "twitter",
          share_url: body.share_url,
        });
        return json({ success: true, item });
      }

      case "viral.list": {
        const items = await listItems(admin, "viral_share", userId!);
        return json({ success: true, items });
      }

      // ─── X Post ───────────────────────────────────────────────────────────────
      case "x.post": {
        const text = String(body.text ?? "").trim();
        const mediaUrl = String(body.mediaUrl ?? body.media_url ?? "").trim();
        const mediaType = String(body.mediaType ?? body.media_type ?? "")
          .trim();
        const dryRun = body.dryRun === true;
        if (!text) return json({ success: false, error: "text required" }, 400);
        if (text.length > 280) {
          return json({
            success: false,
            error: "text exceeds 280 characters",
          }, 400);
        }

        const baseLog = {
          text,
          posted_at: new Date().toISOString(),
          source: body.source ?? "growth-hub",
          media_url: mediaUrl || null,
        };

        if (dryRun || !isXConfigured()) {
          const log = await addItem(admin, "x_post_log", userId!, {
            ...baseLog,
            status: dryRun ? "dry_run" : "credentials_missing",
          });
          return json({
            success: true,
            posted: false,
            dryRun,
            account: getXAccountHandle(),
            text,
            log,
            warning: dryRun
              ? undefined
              : "X API credentials are not configured in Supabase secrets.",
          });
        }

        const uploadedMedia = mediaUrl
          ? await uploadMediaFromUrl(mediaUrl, {
            mediaType: mediaType || undefined,
          })
          : null;
        const result = await postTweet({
          text,
          mediaIds: uploadedMedia ? [uploadedMedia.mediaId] : undefined,
        });
        const log = await addItem(admin, "x_post_log", userId!, {
          ...baseLog,
          status: "posted",
          tweet_id: result.tweetId,
          account: result.account,
          media_id: uploadedMedia?.mediaId ?? null,
          media_type: uploadedMedia?.mediaType ?? null,
        });
        return json({
          success: true,
          posted: true,
          text,
          tweetId: result.tweetId,
          account: result.account,
          log,
        });
      }

      // ─── Automation ───────────────────────────────────────────────────────────
      case "automation.analyze": {
        const geminiKey2 = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey2) return json({ success: true, recommendations: [] });
        const p2 = `グロース自動化の推奨事項を3つ提案してください。現状: ${
          JSON.stringify(body)
        }. JSON: {"recommendations":[{"action":"...","priority":"high|medium|low","impact":"..."}]}`;
        const r2 = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey2}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ contents: [{ parts: [{ text: p2 }] }] }),
          },
        );
        const res2 = await r2.json();
        const t2 = (
          res2 as {
            candidates?: [{ content: { parts: [{ text: string }] } }];
          }
        ).candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
        try {
          return json({
            success: true,
            ...JSON.parse(t2.replace(/```json\n?|\n?```/g, "")),
          });
        } catch {
          return json({ success: true, text: t2 });
        }
      }

      // ─── A/B Test ─────────────────────────────────────────────────────────────
      case "ab.list": {
        const items = await listItems(admin, "ab_test", userId!);
        return json({ success: true, items });
      }

      case "ab.create": {
        const item = await addItem(admin, "ab_test", userId!, {
          name: body.name,
          variants: body.variants ?? [],
          status: "active",
        });
        return json({ success: true, item });
      }

      case "ab.result": {
        const items = await listItems(admin, "ab_test", userId!, 100);
        return json({ success: true, tests: items });
      }

      // ─── Landing Page A/B Test (global, app_analytics 集計) ─────────────────
      case "landing.list_variants": {
        const CTA_VARIANTS = [
          {
            id: "cta_free",
            text: "無料で始める",
            color: "#4CAF50",
            style: "solid",
          },
          {
            id: "cta_try",
            text: "今すぐ試す",
            color: "#2196F3",
            style: "solid",
          },
          {
            id: "cta_join",
            text: "参加する（¥0）",
            color: "#FF5722",
            style: "solid",
          },
          {
            id: "cta_start",
            text: "5秒で登録 →",
            color: "#9C27B0",
            style: "outline",
          },
          {
            id: "cta_save",
            text: "月¥5,000節約する",
            color: "#FF9800",
            style: "gradient",
          },
          {
            id: "cta_ai",
            text: "AIに仕事を任せる",
            color: "#00BCD4",
            style: "gradient",
          },
        ];
        const HEADLINE_VARIANTS = [
          { id: "h_21apps", text: "21のアプリを1つに。しかも無料。" },
          { id: "h_ai", text: "AIが12部署を自動運営する次世代アプリ" },
          { id: "h_save", text: "月¥5,000以上のサブスクをゼロに" },
          { id: "h_future", text: "あなたがやるのは「ゴール設定」だけ" },
          { id: "h_all", text: "メモ・タスク・家計簿・SNS・AI — 全部入り" },
        ];
        const { data: assignments } = await admin
          .from("app_analytics")
          .select("metadata")
          .eq("source", "ab_test_assignment");
        const { data: conversions } = await admin
          .from("app_analytics")
          .select("metadata")
          .eq("source", "ab_test_conversion");
        const ctaStats: Record<string, { views: number; conversions: number }> =
          {};
        for (const a of assignments ?? []) {
          const cId = (a.metadata as Record<string, unknown>)
            .cta_variant as string;
          if (!cId) continue;
          if (!ctaStats[cId]) ctaStats[cId] = { views: 0, conversions: 0 };
          ctaStats[cId].views++;
        }
        for (const c of conversions ?? []) {
          const cId = (c.metadata as Record<string, unknown>)
            .cta_variant as string;
          if (cId && ctaStats[cId]) ctaStats[cId].conversions++;
        }
        const variants = [
          ...CTA_VARIANTS.map((v) => {
            const s = ctaStats[v.id] ?? { views: 0, conversions: 0 };
            const cvr = s.views > 0
              ? Math.round((s.conversions / s.views) * 10000) / 100
              : 0;
            return {
              ...v,
              kind: "cta",
              views: s.views,
              conversions: s.conversions,
              conversion_rate: cvr,
            };
          }),
          ...HEADLINE_VARIANTS.map((v) => ({
            ...v,
            kind: "headline",
            views: 0,
            conversions: 0,
            conversion_rate: 0,
          })),
        ];
        return json({ success: true, variants });
      }

      // ─── Quote ────────────────────────────────────────────────────────────────
      case "quote.create": {
        const item = await addItem(admin, "share_quote", userId!, {
          text: body.text,
          author: body.author ?? "",
          category: body.category ?? "general",
        });
        return json({ success: true, item });
      }

      case "quote.list": {
        const items = await listItems(admin, "share_quote", userId!);
        return json({ success: true, items });
      }

      case "quote.image": {
        // Return a placeholder image generation request stored in hub_data
        const item = await addItem(admin, "quote_image", userId!, {
          text: body.text,
          style: body.style ?? "minimal",
          status: "pending",
        });
        return json({ success: true, item });
      }

      // ─── SEO ──────────────────────────────────────────────────────────────────
      case "seo.optimize": {
        const geminiKey3 = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey3) return json({ success: true, suggestions: [] });
        const p3 =
          `次のページのSEOを最適化してください: タイトル="${body.title}", 説明="${body.description}", キーワード="${body.keywords}". JSON: {"title":"...","description":"...","keywords":[],"score":0}`;
        const r3 = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey3}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ contents: [{ parts: [{ text: p3 }] }] }),
          },
        );
        const res3 = await r3.json();
        const t3 = (
          res3 as {
            candidates?: [{ content: { parts: [{ text: string }] } }];
          }
        ).candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
        try {
          return json({
            success: true,
            ...JSON.parse(t3.replace(/```json\n?|\n?```/g, "")),
          });
        } catch {
          return json({ success: true, text: t3 });
        }
      }

      // ─── Waitlist ─────────────────────────────────────────────────────────────
      case "waitlist.notify": {
        const resendKey = Deno.env.get("RESEND_API_KEY") ?? "";
        if (!resendKey) {
          return json({ error: "RESEND_API_KEY not configured" }, 503);
        }
        const wr = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${resendKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: "noreply@jibun.app",
            to: body.email,
            subject: "自分株式会社 — ウェイトリスト通知",
            html: `<p>${body.message ?? "ご登録ありがとうございます。"}</p>`,
          }),
        });
        return json({ success: wr.ok });
      }

      // ─── Viral Ad ─────────────────────────────────────────────────────────────
      case "viral_ad.create": {
        const item = await addItem(admin, "viral_ad", userId!, {
          title: body.title,
          headline: body.headline ?? "",
          cta: body.cta ?? "",
          platform: body.platform ?? "social",
          status: "draft",
        });
        return json({ success: true, item });
      }

      case "viral_ad.list": {
        const items = await listItems(admin, "viral_ad", userId!);
        return json({ success: true, items });
      }

      // ─── Viral Engine ─────────────────────────────────────────────────────────
      case "engine.run": {
        const item = await addItem(admin, "viral_engine_run", userId!, {
          trigger: body.trigger ?? "manual",
          target: body.target ?? "all",
          status: "queued",
        });
        return json({ success: true, item });
      }

      case "engine.stats": {
        const items = await listItems(admin, "viral_engine_run", userId!);
        return json({ success: true, items });
      }

      // ─── Default ──────────────────────────────────────────────────────────────
      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
