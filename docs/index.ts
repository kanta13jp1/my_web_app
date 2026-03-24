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

    // 1. 登録ユーザー数の取得 (ダミーデータ排除・実データ集計)
    const { count: totalUsers, error: userError } = await admin
      .from("user_profiles")
      .select("*", { count: "exact", head: true });
    if (userError) throw userError;

    // 2. システム全体の総メモ数の取得
    const { count: totalNotes, error: notesError } = await admin
      .from("notes")
      .select("*", { count: "exact", head: true });
    if (notesError) throw notesError;

    // 3. 本日の新規登録者数の取得
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const { count: todaySignups, error: signupError } = await admin
      .from("user_profiles")
      .select("*", { count: "exact", head: true })
      .gte("created_at", today.toISOString());
    if (signupError) throw signupError;

    // KPIダッシュボード用データを集約して返却
    const dashboardData = {
      totalUsers: totalUsers || 0,
      totalNotes: totalNotes || 0,
      todaySignups: todaySignups || 0,
      // 今後必要に応じて、週間アクティブユーザー(WAU)や収益データ等を追加
      lastUpdatedAt: new Date().toISOString(),
    };

    return new Response(JSON.stringify({ data: dashboardData }), {
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