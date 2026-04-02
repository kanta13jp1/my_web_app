import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

/** デフォルトの計画データ（growth_plans テーブルが空のとき自動シード） */
const DEFAULT_PLANS = [
  { label: "短期計画", deadline: "2026年06月30日", target: 100, features_done: 0, features_total: 0 },
  { label: "中期計画", deadline: "2026年12月31日", target: 1000, features_done: 0, features_total: 0 },
  { label: "長期計画", deadline: "2027年12月31日", target: 10000, features_done: 0, features_total: 0 },
  // features_done = done+partial from get-competitor-features (2026-04-02 actual count)
  { label: "vs NOTION", deadline: "2033年12月31日", target: 100000000, features_done: 12, features_total: 18 },
  { label: "vs EverNote", deadline: "2032年12月31日", target: 250000000, features_done: 9, features_total: 14 },
  { label: "vs MoneyForward", deadline: "2030年12月31日", target: 15000000, features_done: 7, features_total: 12 },
  { label: "vs X", deadline: "2036年12月31日", target: 600000000, features_done: 5, features_total: 11 },
  { label: "vs Animaworks", deadline: "2027年12月31日", target: 500000, features_done: 11, features_total: 17 },
  { label: "vs Claude Code", deadline: "2027年12月31日", target: 500000, features_done: 7, features_total: 12 },
  { label: "vs Codex", deadline: "2028年06月30日", target: 1000000, features_done: 2, features_total: 5 },
  { label: "vs netkeiba", deadline: "2029年12月31日", target: 17000000, features_done: 3, features_total: 7 },
  { label: "vs OpenClaw", deadline: "2028年06月30日", target: 1000000, features_done: 2, features_total: 5 },
  { label: "vs Claude Cowork", deadline: "2027年12月31日", target: 500000, features_done: 0, features_total: 3 },
  { label: "vs Chatwork", deadline: "2028年12月31日", target: 6000000, features_done: 2, features_total: 4 },
  { label: "vs Slack", deadline: "2034年12月31日", target: 65000000, features_done: 1, features_total: 3 },
  { label: "vs ジョブカン", deadline: "2028年06月30日", target: 5000000, features_done: 1, features_total: 3 },
  { label: "vs Amazon", deadline: "2038年12月31日", target: 310000000, features_done: 3, features_total: 7 },
  { label: "vs Google", deadline: "2045年12月31日", target: 4300000000, features_done: 7, features_total: 8 },
  { label: "vs Microsoft", deadline: "2042年12月31日", target: 1500000000, features_done: 5, features_total: 6 },
  { label: "vs Discord", deadline: "2035年12月31日", target: 200000000, features_done: 3, features_total: 5 },
  { label: "vs LINE", deadline: "2035年12月31日", target: 196000000, features_done: 3, features_total: 6 },
  { label: "vs Facebook", deadline: "2040年12月31日", target: 3070000000, features_done: 4, features_total: 6 },
  { label: "vs Liven", deadline: "2028年06月30日", target: 1000000, features_done: 3, features_total: 4 },
  { label: "vs GitHub", deadline: "2037年12月31日", target: 100000000, features_done: 6, features_total: 6 },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // ---- 並列取得: 登録ユーザー数 + 計画データ + 開発実績件数 ----
    const [
      { count: userCount, error: countError },
      { data: plansData, error: plansError },
      { count: achievementsCount },
    ] = await Promise.all([
      admin.from("user_profiles").select("user_id", { count: "exact", head: true }),
      admin
        .from("growth_plans")
        .select("label, deadline, target, features_done, features_total")
        .order("target", { ascending: true }),
      admin
        .from("development_achievements")
        .select("id", { count: "exact", head: true }),
    ]);

    if (countError) throw new Error(countError.message);

    const totalAchievements = achievementsCount ?? 0;

    if (plansError) {
      return jsonResponse({
        userCount: userCount ?? 0,
        achievementsCount: totalAchievements,
        plans: _withAchievements(DEFAULT_PLANS, totalAchievements),
      });
    }

    let plans = (plansData ?? []) as Array<{
      label: string;
      deadline: string;
      target: number;
      features_done: number;
      features_total: number;
    }>;

    if (plans.length === 0) {
      const { error: insertError } = await admin
        .from("growth_plans")
        .insert(DEFAULT_PLANS);
      if (insertError) {
        console.error("Failed to seed growth_plans:", insertError.message);
      }
      plans = DEFAULT_PLANS;
    }

    return jsonResponse({
      userCount: userCount ?? 0,
      achievementsCount: totalAchievements,
      plans: _withAchievements(plans, totalAchievements),
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse({
      error: message,
      userCount: 0,
      achievementsCount: 0,
      plans: DEFAULT_PLANS,
    }, 500);
  }
});

/**
 * 短期/中期/長期計画の features_done/features_total を
 * development_achievements の件数で動的に埋める。
 */
function _withAchievements<T extends {
  label: string;
  features_done: number;
  features_total: number;
}>(plans: T[], achievementsCount: number): T[] {
  // 短期/中期/長期の目標実績件数（ロードマップの計画タスク数）
  const TARGET_SHORT = 50;
  const TARGET_MID = 200;
  const TARGET_LONG = 500;

  return plans.map((p) => {
    if (p.label === "短期計画") {
      return {
        ...p,
        features_done: Math.min(achievementsCount, TARGET_SHORT),
        features_total: TARGET_SHORT,
      };
    }
    if (p.label === "中期計画") {
      return {
        ...p,
        features_done: Math.min(achievementsCount, TARGET_MID),
        features_total: TARGET_MID,
      };
    }
    if (p.label === "長期計画") {
      return {
        ...p,
        features_done: Math.min(achievementsCount, TARGET_LONG),
        features_total: TARGET_LONG,
      };
    }
    return p;
  });
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
