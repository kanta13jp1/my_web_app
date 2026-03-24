import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // user_profiles テーブルから現在の登録者数を取得 (実データ集計)
    const { count, error } = await admin
      .from("user_profiles")
      .select("*", { count: "exact", head: true });

    if (error) throw error;

    const userCount = count || 0;

    // 目標計画のリスト (将来的には DB の growth_plans テーブル等から動的に取得する想定)
    const plans = [
      { label: '短期計画', deadline: '2026年06月30日', target: 100 },
      { label: '中期計画', deadline: '2027年03月25日', target: 10000 },
      { label: '長期計画', deadline: '2029年03月25日', target: 100000000 },
      { label: 'vs NOTION', deadline: '2029年03月25日', target: 100000000 },
      { label: 'vs EverNote', deadline: '2030年03月25日', target: 250000000 },
      { label: 'vs MoneyForward', deadline: '2028年03月25日', target: 15000000 },
      { label: 'vs X', deadline: '2031年03月25日', target: 600000000 },
      { label: 'vs Animaworks', deadline: '2026年12月31日', target: 500000 },
      { label: 'vs Claude Code', deadline: '2026年12月31日', target: 500000 },
      { label: 'vs Codex', deadline: '2027年06月30日', target: 1000000 },
      { label: 'vs netkeiba', deadline: '2028年06月30日', target: 10000000 },
      { label: 'vs OpenClaw', deadline: '2027年06月30日', target: 1000000 },
      { label: 'vs Claude works', deadline: '2026年12月31日', target: 500000 },
      { label: 'vs Chatwork', deadline: '2027年12月31日', target: 6000000 },
      { label: 'vs Slack', deadline: '2029年12月31日', target: 65000000 },
      { label: 'vs ジョブカン', deadline: '2027年12月31日', target: 5000000 },
    ];

    return new Response(JSON.stringify({ userCount, plans }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});