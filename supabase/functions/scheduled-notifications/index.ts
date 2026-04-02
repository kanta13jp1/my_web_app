// Scheduled Notifications Edge Function
// 通知スケジューリング (Slack/Discord競合)
// - リマインダー設定
// - 定期通知
// - 条件付き通知
// - 通知キュー管理
//
// GET  → スケジュール一覧 / 履歴
// POST → スケジュール作成 / 実行 / 削除

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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'active' | 'history' | 'upcoming'

      if (view === "history") {
        const { data: history } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "notification_sent").order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({
          success: true,
          history: (history ?? []).map((h) => ({ ...(h.metadata as Record<string, unknown>), sentAt: h.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      const { data: schedules } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "notification_schedule").order("created_at", { ascending: false });

      let list = (schedules ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at }));
      if (view === "active") {
        list = list.filter((s) => s.active === true);
      }

      if (view === "upcoming") {
        const now = new Date().toISOString();
        list = list.filter((s) => s.active === true && (s.next_fire as string) > now);
        list.sort((a, b) => ((a.next_fire as string) ?? "").localeCompare((b.next_fire as string) ?? ""));
      }

      return new Response(JSON.stringify({ success: true, schedules: list }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create") {
        const { title, message, schedule_type, fire_at, repeat_interval, condition } = body;
        if (!title || !message) {
          return new Response(JSON.stringify({ success: false, error: "title and message required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const scheduleId = crypto.randomUUID();
        const nextFire = fire_at ?? new Date(Date.now() + 3600000).toISOString(); // Default: 1h later

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "notification_schedule",
          metadata: {
            schedule_id: scheduleId, title, message,
            schedule_type: schedule_type ?? "once", // 'once' | 'recurring'
            fire_at: fire_at ?? null, next_fire: nextFire,
            repeat_interval: repeat_interval ?? null, // minutes
            condition: condition ?? null, active: true,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;
        return new Response(JSON.stringify({ success: true, scheduleId, schedule: data }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "fire") {
        const { schedule_id } = body;
        if (!schedule_id) {
          return new Response(JSON.stringify({ success: false, error: "schedule_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: schedule } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "notification_schedule").eq("metadata->>schedule_id", schedule_id).maybeSingle();
        if (!schedule) {
          return new Response(JSON.stringify({ success: false, error: "Schedule not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const meta = schedule.metadata as Record<string, unknown>;

        // Create notification
        await adminClient.from("app_notifications").insert({
          user_id: user.id, title: meta.title as string, body: meta.message as string,
          notification_type: "scheduled", is_read: false,
        });

        // Log sent
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "notification_sent",
          metadata: { schedule_id, title: meta.title, message: meta.message },
          created_at: new Date().toISOString(),
        });

        // Update next fire or deactivate
        if (meta.schedule_type === "recurring" && meta.repeat_interval) {
          const interval = (meta.repeat_interval as number) * 60000;
          const nextFire = new Date(Date.now() + interval).toISOString();
          await adminClient.from("app_analytics").update({ metadata: { ...meta, next_fire: nextFire } }).eq("user_id", user.id).eq("source", "notification_schedule").eq("metadata->>schedule_id", schedule_id);
        } else {
          await adminClient.from("app_analytics").update({ metadata: { ...meta, active: false } }).eq("user_id", user.id).eq("source", "notification_schedule").eq("metadata->>schedule_id", schedule_id);
        }

        return new Response(JSON.stringify({ success: true, fired: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "delete") {
        const { schedule_id } = body;
        if (!schedule_id) {
          return new Response(JSON.stringify({ success: false, error: "schedule_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").delete().eq("user_id", user.id).eq("source", "notification_schedule").eq("metadata->>schedule_id", schedule_id);
        return new Response(JSON.stringify({ success: true, deleted: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
