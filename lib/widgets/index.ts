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
    const { period } = await req.json().catch(() => ({ period: "今日の実績" }));

    let startDate = new Date(0);
    const now = new Date();

    switch (period) {
      case '今日の実績': startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate()); break;
      case '今週の実績': startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - now.getDay()); break;
      case '直近2週間の実績': startDate = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000); break;
      case '今月の実績': startDate = new Date(now.getFullYear(), now.getMonth(), 1); break;
      case '直近2ヶ月の実績': startDate = new Date(now.getFullYear(), now.getMonth() - 1, 1); break;
      case '直近3ヶ月の実績': startDate = new Date(now.getFullYear(), now.getMonth() - 2, 1); break;
      case '直近半年の実績': startDate = new Date(now.getFullYear(), now.getMonth() - 5, 1); break;
      case '直近1年の実績': startDate = new Date(now.getFullYear() - 1, now.getMonth(), now.getDate()); break;
      case '直近2年の実績': startDate = new Date(now.getFullYear() - 2, now.getMonth(), now.getDate()); break;
      case '直近3年の実績': startDate = new Date(now.getFullYear() - 3, now.getMonth(), now.getDate()); break;
      case '直近5年の実績': startDate = new Date(now.getFullYear() - 5, now.getMonth(), now.getDate()); break;
      case '直近10年の実績': startDate = new Date(now.getFullYear() - 10, now.getMonth(), now.getDate()); break;
      case 'すべての実績':
      default: startDate = new Date(0); break;
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // development_achievements テーブルから期間内の完了済みタスクを取得
    const { data, error } = await admin
      .from("development_achievements")
      .select("title, completed_at")
      .gte("completed_at", startDate.toISOString())
      .order("completed_at", { ascending: false });

    let achievements: string[] = [];

    if (!error && data && data.length > 0) {
      achievements = data.map((d: { title: string }) => d.title);
    }

    return new Response(JSON.stringify({ achievements }), {
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