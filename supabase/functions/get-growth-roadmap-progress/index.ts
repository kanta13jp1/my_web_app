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
  { label: "短期計画", deadline: "2026年06月30日", target: 100 },
  { label: "中期計画", deadline: "2026年12月31日", target: 1000 },
  { label: "長期計画", deadline: "2027年12月31日", target: 10000 },
  { label: "vs Animaworks", deadline: "2027年12月31日", target: 500000 },
  { label: "vs Claude Code", deadline: "2027年12月31日", target: 500000 },
  { label: "vs Claude works", deadline: "2027年12月31日", target: 500000 },
  { label: "vs ジョブカン", deadline: "2028年06月30日", target: 5000000 },
  { label: "vs Chatwork", deadline: "2028年12月31日", target: 6000000 },
  { label: "vs Codex", deadline: "2028年06月30日", target: 1000000 },
  { label: "vs OpenClaw", deadline: "2028年06月30日", target: 1000000 },
  { label: "vs netkeiba", deadline: "2029年12月31日", target: 17000000 },
  { label: "vs MoneyForward", deadline: "2030年12月31日", target: 15000000 },
  { label: "vs EverNote", deadline: "2032年12月31日", target: 250000000 },
  { label: "vs NOTION", deadline: "2033年12月31日", target: 100000000 },
  { label: "vs Slack", deadline: "2034年12月31日", target: 65000000 },
  { label: "vs X", deadline: "2036年12月31日", target: 600000000 },
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

    // ---- 登録ユーザー数を取得 ----
    const { count: userCount, error: countError } = await admin
      .from("user_profiles")
      .select("user_id", { count: "exact", head: true });

    if (countError) throw new Error(countError.message);

    // ---- growth_plans テーブルから計画データを取得 ----
    const { data: plansData, error: plansError } = await admin
      .from("growth_plans")
      .select("label, deadline, target")
      .order("target", { ascending: true });

    if (plansError) {
      // テーブルが存在しない場合はデフォルトを返す
      return jsonResponse({
        userCount: userCount ?? 0,
        plans: DEFAULT_PLANS,
      });
    }

    let plans = plansData ?? [];

    // テーブルが空の場合はデフォルトデータをシードして返す
    if (plans.length === 0) {
      const { error: insertError } = await admin
        .from("growth_plans")
        .insert(DEFAULT_PLANS);

      // シード失敗時もデフォルトをそのまま返す（エラーを伝播させない）
      if (insertError) {
        console.error("Failed to seed growth_plans:", insertError.message);
      }
      plans = DEFAULT_PLANS;
    }

    return jsonResponse({
      userCount: userCount ?? 0,
      plans,
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse({ error: message, userCount: 0, plans: DEFAULT_PLANS }, 500);
  }
});

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
