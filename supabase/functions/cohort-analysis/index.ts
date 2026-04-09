// Cohort Analysis Edge Function
// コホート分析 (Google Analytics競合)
// - ユーザーコホート (登録月別)
// - リテンション分析
// - ファネル分析
// - イベント追跡集計
//
// GET → コホート / リテンション / ファネル / イベント集計

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    // Admin only
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || authHeader !== `Bearer ${SERVICE_ROLE_KEY}`) {
      return new Response(JSON.stringify({ success: false, error: "Admin access required" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'cohort' | 'retention' | 'funnel' | 'events'

      if (view === "cohort") {
        const { data: users } = await adminClient.from("user_profiles").select("user_id, created_at");
        const cohorts = new Map<string, number>();
        for (const u of users ?? []) {
          const month = new Date(u.created_at).toISOString().slice(0, 7);
          cohorts.set(month, (cohorts.get(month) ?? 0) + 1);
        }
        return new Response(JSON.stringify({
          success: true,
          cohorts: [...cohorts.entries()].map(([month, count]) => ({ month, count })).sort((a, b) => a.month.localeCompare(b.month)),
          totalUsers: (users ?? []).length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "retention") {
        const days = parseInt(url.searchParams.get("days") ?? "30");
        const since = new Date(Date.now() - days * 86400000).toISOString();
        const { data: activities } = await adminClient.from("app_analytics").select("user_id, created_at").gte("created_at", since).limit(10000);

        // Group by day
        const dailyActive = new Map<string, Set<string>>();
        for (const a of activities ?? []) {
          const day = new Date(a.created_at).toISOString().slice(0, 10);
          if (!dailyActive.has(day)) dailyActive.set(day, new Set());
          dailyActive.get(day)!.add(a.user_id);
        }

        const retention = [...dailyActive.entries()].map(([date, users]) => ({ date, activeUsers: users.size })).sort((a, b) => a.date.localeCompare(b.date));

        return new Response(JSON.stringify({ success: true, days, retention }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "funnel") {
        // Simple funnel: signup → first_note → streak_3 → share (3クエリ並列)
        const [{ data: users }, { data: noteUsers }, { data: streakUsers }] = await Promise.all([
          adminClient.from("user_profiles").select("user_id", { count: "exact" }),
          adminClient.from("notes").select("user_id").limit(10000),
          adminClient.from("user_profiles").select("user_id, metadata").not("metadata", "is", null),
        ]);
        const totalSignups = (users ?? []).length;
        const uniqueNoteUsers = new Set((noteUsers ?? []).map((n) => n.user_id)).size;
        const streakCount = (streakUsers ?? []).filter((u) => {
          const meta = u.metadata as Record<string, unknown>;
          return ((meta?.current_streak as number) ?? 0) >= 3;
        }).length;

        return new Response(JSON.stringify({
          success: true,
          funnel: [
            { step: "登録", count: totalSignups, rate: 100 },
            { step: "初回ノート作成", count: uniqueNoteUsers, rate: totalSignups > 0 ? Math.round(uniqueNoteUsers / totalSignups * 100) : 0 },
            { step: "3日連続ログイン", count: streakCount, rate: totalSignups > 0 ? Math.round(streakCount / totalSignups * 100) : 0 },
          ],
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "events") {
        const days = parseInt(url.searchParams.get("days") ?? "7");
        const since = new Date(Date.now() - days * 86400000).toISOString();
        const { data: events } = await adminClient.from("app_analytics").select("source, created_at").gte("created_at", since).limit(10000);

        const eventCounts = new Map<string, number>();
        for (const e of events ?? []) {
          eventCounts.set(e.source, (eventCounts.get(e.source) ?? 0) + 1);
        }

        return new Response(JSON.stringify({
          success: true,
          days,
          events: [...eventCounts.entries()].map(([source, count]) => ({ source, count })).sort((a, b) => b.count - a.count),
          totalEvents: (events ?? []).length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, views: ["cohort", "retention", "funnel", "events"] }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
