// User Activity Tracker Edge Function
// ユーザーのアクティビティを記録・分析して成長施策に活用
// - ページビュー / 機能利用 / セッション時間
// - リテンション分析 / アクティブユーザー率
// - エンゲージメントスコア計算
//
// GET  → アクティビティサマリー / ユーザー別分析
// POST → アクティビティ記録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'summary' | 'retention' | 'engagement'
      const days = parseInt(url.searchParams.get("days") ?? "30", 10);

      const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
      });

      const since = new Date(Date.now() - days * 86400000).toISOString();

      if (view === "retention") {
        // リテンション分析: ユーザーの直近アクティビティ (2クエリ並列)
        const [{ data: profiles }, { data: analytics }] = await Promise.all([
          adminClient
            .from("user_profiles")
            .select("user_id, display_name, created_at, updated_at"),
          adminClient
            .from("app_analytics")
            .select("user_id, created_at")
            .gte("created_at", since),
        ]);

        // ユーザー別の最終活動日を計算
        const userActivity = new Map<string, { lastSeen: string; eventCount: number }>();
        for (const event of analytics ?? []) {
          const uid = event.user_id as string;
          if (!uid) continue;
          const existing = userActivity.get(uid);
          if (!existing || event.created_at > existing.lastSeen) {
            userActivity.set(uid, {
              lastSeen: event.created_at as string,
              eventCount: (existing?.eventCount ?? 0) + 1,
            });
          } else {
            existing.eventCount++;
          }
        }

        const now = Date.now();
        let dau = 0; // Daily Active
        let wau = 0; // Weekly Active
        let mau = 0; // Monthly Active
        let churned = 0;

        for (const [, data] of userActivity) {
          const lastMs = new Date(data.lastSeen).getTime();
          const daysSince = (now - lastMs) / 86400000;
          if (daysSince <= 1) dau++;
          if (daysSince <= 7) wau++;
          if (daysSince <= 30) mau++;
          if (daysSince > 30) churned++;
        }

        const totalUsers = (profiles ?? []).length;

        return new Response(
          JSON.stringify({
            success: true,
            retention: {
              totalUsers,
              dau,
              wau,
              mau,
              churned,
              dauRate: totalUsers > 0 ? Math.round((dau / totalUsers) * 100) : 0,
              wauRate: totalUsers > 0 ? Math.round((wau / totalUsers) * 100) : 0,
              mauRate: totalUsers > 0 ? Math.round((mau / totalUsers) * 100) : 0,
            },
            period: { days, since },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "engagement") {
        // エンゲージメント分析
        const [notesRes, reactionsRes, commentsRes, requestsRes] = await Promise.all([
          adminClient.from("notes").select("user_id, created_at").gte("created_at", since),
          adminClient.from("app_analytics").select("user_id, source, created_at").gte("created_at", since),
          adminClient.from("app_analytics").select("user_id, created_at").gte("created_at", since).eq("source", "comment"),
          adminClient.from("feature_requests").select("user_id, created_at").gte("created_at", since),
        ]);

        const noteCount = (notesRes.data ?? []).length;
        const eventCount = (reactionsRes.data ?? []).length;
        const commentCount = (commentsRes.data ?? []).length;
        const requestCount = (requestsRes.data ?? []).length;

        // エンゲージメントスコア (0-100)
        const score = Math.min(100, Math.round(
          (noteCount * 10 + eventCount * 2 + commentCount * 5 + requestCount * 15) / Math.max(days, 1)
        ));

        return new Response(
          JSON.stringify({
            success: true,
            engagement: {
              score,
              notesCreated: noteCount,
              analyticsEvents: eventCount,
              comments: commentCount,
              featureRequests: requestCount,
            },
            period: { days, since },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: サマリー
      const { data: recentEvents } = await adminClient
        .from("app_analytics")
        .select("source, created_at")
        .gte("created_at", since)
        .order("created_at", { ascending: false })
        .limit(100);

      // ソース別集計
      const sourceMap = new Map<string, number>();
      for (const event of recentEvents ?? []) {
        const src = (event.source as string) ?? "unknown";
        sourceMap.set(src, (sourceMap.get(src) ?? 0) + 1);
      }

      return new Response(
        JSON.stringify({
          success: true,
          summary: {
            totalEvents: (recentEvents ?? []).length,
            bySource: Object.fromEntries(sourceMap),
          },
          period: { days, since },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      // アクティビティ記録
      const authHeader = req.headers.get("Authorization");
      const body = await req.json().catch(() => ({}));
      const { source, metadata } = body;

      if (!source) {
        return new Response(
          JSON.stringify({ success: false, error: "source is required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // ユーザーIDを取得 (認証済みの場合)
      let userId = null;
      if (authHeader) {
        const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
          global: { headers: { Authorization: authHeader } },
        });
        const { data: { user } } = await userClient.auth.getUser();
        if (user) userId = user.id;
      }

      const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
      });

      const { data, error } = await adminClient
        .from("app_analytics")
        .insert({
          user_id: userId,
          source,
          metadata: metadata ?? {},
          created_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true, event: data }),
        { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("user-activity-tracker error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
