// App Analytics Dashboard Edge Function
// アプリ分析ダッシュボード — KPI・トレンド・ユーザー行動分析
//
// GET → 分析データ (日次/週次/月次 KPI, ページ別アクセス, Edge Function 利用率)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'kpi' | 'trends' | 'functions' | 'overview'
      const days = parseInt(url.searchParams.get("days") ?? "30", 10);

      const since = new Date(Date.now() - days * 86400000).toISOString();

      if (view === "functions") {
        // Edge Function 利用率
        const { data: funcStatus } = await supabase
          .from("edge_function_ui_status")
          .select("*")
          .order("call_count", { ascending: false });

        return new Response(
          JSON.stringify({
            success: true,
            functions: funcStatus ?? [],
            totalTracked: (funcStatus ?? []).length,
            totalCalls: (funcStatus ?? []).reduce((sum, f) => sum + ((f.call_count as number) ?? 0), 0),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "trends") {
        // 日別トレンド (app_analytics)
        const { data: analytics } = await supabase
          .from("app_analytics")
          .select("created_at, source")
          .gte("created_at", since)
          .order("created_at", { ascending: true });

        // 日別集計
        const dailyMap = new Map<string, { views: number; shares: number; signups: number }>();

        for (const row of analytics ?? []) {
          const date = (row.created_at as string)?.slice(0, 10) ?? "unknown";
          if (!dailyMap.has(date)) dailyMap.set(date, { views: 0, shares: 0, signups: 0 });
          const d = dailyMap.get(date)!;

          const source = (row.source as string) ?? "";
          if (source.startsWith("share_") || source === "x_share") d.shares++;
          else if (source === "signup") d.signups++;
          else d.views++;
        }

        const trendData = [...dailyMap.entries()]
          .sort(([a], [b]) => a.localeCompare(b))
          .map(([date, data]) => ({ date, ...data }));

        return new Response(
          JSON.stringify({ success: true, trends: trendData, days }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: KPI overview
      const [usersRes, notesRes, achievementsRes, requestsRes, ticketsRes, blogsRes, notificationsRes] = await Promise.all([
        supabase.from("user_profiles").select("*", { count: "exact", head: true }),
        supabase.from("notes").select("*", { count: "exact", head: true }),
        supabase.from("development_achievements").select("*", { count: "exact", head: true }),
        supabase.from("feature_requests").select("*", { count: "exact", head: true }),
        supabase.from("support_tickets").select("*", { count: "exact", head: true }),
        supabase.from("blog_posts").select("*", { count: "exact", head: true }),
        supabase.from("app_notifications").select("*", { count: "exact", head: true }),
      ]);

      // 直近の登録ユーザー数変動
      const { data: recentUsers } = await supabase
        .from("user_profiles")
        .select("created_at")
        .gte("created_at", since)
        .order("created_at", { ascending: true });

      const userGrowth = (recentUsers ?? []).map((u) => ({
        date: (u.created_at as string)?.slice(0, 10),
      }));

      // Edge Function 数
      const { data: funcStatus } = await supabase
        .from("edge_function_ui_status")
        .select("*", { count: "exact", head: true });

      return new Response(
        JSON.stringify({
          success: true,
          kpi: {
            totalUsers: usersRes.count ?? 0,
            totalNotes: notesRes.count ?? 0,
            totalAchievements: achievementsRes.count ?? 0,
            totalFeatureRequests: requestsRes.count ?? 0,
            totalTickets: ticketsRes.count ?? 0,
            totalBlogPosts: blogsRes.count ?? 0,
            totalNotifications: notificationsRes.count ?? 0,
            totalEdgeFunctions: 160, // current count
            trackedFunctions: funcStatus?.count ?? 0,
          },
          userGrowth,
          period: { days, since },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("app-analytics-dashboard error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
