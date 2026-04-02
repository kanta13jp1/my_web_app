// Time Tracker Edge Function
// 勤怠・時間追跡 (ジョブカン競合)
// - 出退勤打刻
// - プロジェクト別時間記録
// - 日/週/月の作業時間集計
// - 残業アラート
//
// GET  → 勤怠記録 / 集計 / プロジェクト別
// POST → 打刻 / 時間記録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response(JSON.stringify({ success: false, error: "Auth required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'today' | 'week' | 'month' | 'projects'
      const now = new Date();

      let since: string;
      if (view === "week") { const d = new Date(now); d.setDate(d.getDate() - d.getDay()); d.setHours(0,0,0,0); since = d.toISOString(); }
      else if (view === "month") { since = new Date(now.getFullYear(), now.getMonth(), 1).toISOString(); }
      else { since = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString(); }

      const { data: entries } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "time_entry").gte("created_at", since)
        .order("created_at", { ascending: false });

      if (view === "projects") {
        const projectHours = new Map<string, number>();
        for (const e of entries ?? []) {
          const meta = e.metadata as Record<string, unknown>;
          const proj = (meta?.project as string) ?? "未分類";
          const hours = (meta?.hours as number) ?? 0;
          projectHours.set(proj, (projectHours.get(proj) ?? 0) + hours);
        }
        return new Response(JSON.stringify({
          success: true, projects: [...projectHours.entries()].map(([name, hours]) => ({ name, hours: Math.round(hours * 100) / 100 })).sort((a, b) => b.hours - a.hours),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      let totalHours = 0;
      for (const e of entries ?? []) { totalHours += ((e.metadata as Record<string, unknown>)?.hours as number) ?? 0; }

      return new Response(JSON.stringify({
        success: true,
        entries: (entries ?? []).map(e => ({ ...(e.metadata as Record<string, unknown>), recordedAt: e.created_at })),
        totalHours: Math.round(totalHours * 100) / 100,
        overtimeAlert: totalHours > (view === "month" ? 160 : view === "week" ? 40 : 8),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "clock_in" || action === "clock_out") {
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "time_entry",
          metadata: { type: action, timestamp: new Date().toISOString(), hours: 0 },
          created_at: new Date().toISOString(),
        }).select().single();
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, entry: data }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record") {
        const { project, hours, description, date } = body;
        if (!hours) return new Response(JSON.stringify({ success: false, error: "hours required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "time_entry",
          metadata: { type: "manual", project: project ?? "未分類", hours, description: description ?? "", date: date ?? new Date().toISOString().slice(0, 10) },
          created_at: new Date().toISOString(),
        }).select().single();
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, entry: data }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
