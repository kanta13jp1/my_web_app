// Pomodoro Timer Edge Function
// ポモドーロタイマー (生産性ツール)
// - セッション記録 (25分作業/5分休憩)
// - 日別・週別統計
// - タスク連携
// - カスタム時間設定
//
// GET  → 統計 / 履歴
// POST → セッション記録 / 設定

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
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "Authorization required" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'today' | 'week' | 'history' | 'settings'

      if (view === "settings") {
        const { data: settings } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "pomodoro_settings")
          .maybeSingle();

        const defaults = { workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, sessionsBeforeLongBreak: 4 };
        return new Response(
          JSON.stringify({ success: true, settings: (settings?.metadata as Record<string, unknown>) ?? defaults }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const now = new Date();
      let since: string;
      if (view === "week") {
        const d = new Date(now);
        d.setDate(d.getDate() - d.getDay());
        d.setHours(0, 0, 0, 0);
        since = d.toISOString();
      } else {
        since = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
      }

      const { data: sessions } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "pomodoro_session")
        .gte("created_at", since)
        .order("created_at", { ascending: false });

      const totalSessions = (sessions ?? []).length;
      let totalMinutes = 0;
      for (const s of sessions ?? []) {
        totalMinutes += ((s.metadata as Record<string, unknown>)?.duration as number) ?? 25;
      }

      return new Response(
        JSON.stringify({
          success: true,
          sessions: (sessions ?? []).map((s) => ({
            ...(s.metadata as Record<string, unknown>),
            completedAt: s.created_at,
          })),
          totalSessions,
          totalMinutes,
          totalHours: Math.round(totalMinutes / 60 * 10) / 10,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "complete") {
        const { duration, task, type } = body;

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "pomodoro_session",
          metadata: {
            session_id: crypto.randomUUID(),
            duration: duration ?? 25,
            type: type ?? "work", // 'work' | 'short_break' | 'long_break'
            task: task ?? null,
            date: new Date().toISOString().slice(0, 10),
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, session: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "save_settings") {
        const { workMinutes, shortBreakMinutes, longBreakMinutes, sessionsBeforeLongBreak } = body;

        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "pomodoro_settings")
          .maybeSingle();

        const settings = {
          workMinutes: workMinutes ?? 25,
          shortBreakMinutes: shortBreakMinutes ?? 5,
          longBreakMinutes: longBreakMinutes ?? 15,
          sessionsBeforeLongBreak: sessionsBeforeLongBreak ?? 4,
        };

        if (existing) {
          const { error } = await adminClient
            .from("app_analytics")
            .update({ metadata: settings })
            .eq("user_id", user.id)
            .eq("source", "pomodoro_settings");
          if (error) throw error;
        } else {
          const { error } = await adminClient.from("app_analytics").insert({
            user_id: user.id,
            source: "pomodoro_settings",
            metadata: settings,
            created_at: new Date().toISOString(),
          });
          if (error) throw error;
        }

        return new Response(
          JSON.stringify({ success: true, settings }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("pomodoro-timer error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
