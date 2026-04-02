// Calendar Events Edge Function
// カレンダー・イベント管理
// - イベント CRUD
// - リマインダー
// - 繰り返しイベント
// - カレンダービュー (日/週/月)
//
// GET  → イベント一覧 / 今日のイベント / リマインダー
// POST → イベント作成 / 更新 / 削除

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

    // 認証
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
      const view = url.searchParams.get("view"); // 'today' | 'week' | 'month' | 'upcoming'
      const now = new Date();

      let startDate: string;
      let endDate: string;

      if (view === "today") {
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
        endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1).toISOString();
      } else if (view === "week") {
        const dayOfWeek = now.getDay();
        const start = new Date(now);
        start.setDate(now.getDate() - dayOfWeek);
        start.setHours(0, 0, 0, 0);
        startDate = start.toISOString();
        endDate = new Date(start.getTime() + 7 * 86400000).toISOString();
      } else if (view === "month") {
        startDate = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
        endDate = new Date(now.getFullYear(), now.getMonth() + 1, 1).toISOString();
      } else {
        // upcoming: 今日から30日
        startDate = now.toISOString();
        endDate = new Date(now.getTime() + 30 * 86400000).toISOString();
      }

      const { data: events } = await adminClient
        .from("app_analytics")
        .select("id, metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "calendar_event")
        .gte("metadata->>start_at", startDate)
        .lte("metadata->>start_at", endDate)
        .order("created_at", { ascending: true })
        .limit(100);

      return new Response(
        JSON.stringify({
          success: true,
          events: (events ?? []).map((e) => ({
            id: e.id,
            ...(e.metadata as Record<string, unknown>),
            createdAt: e.created_at,
          })),
          period: { start: startDate, end: endDate, view: view ?? "upcoming" },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create") {
        const { title, description, start_at, end_at, all_day, reminder_minutes, recurrence, color } = body;

        if (!title || !start_at) {
          return new Response(
            JSON.stringify({ success: false, error: "title and start_at required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const eventId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "calendar_event",
          metadata: {
            event_id: eventId,
            title,
            description: description ?? "",
            start_at,
            end_at: end_at ?? new Date(new Date(start_at).getTime() + 3600000).toISOString(),
            all_day: all_day ?? false,
            reminder_minutes: reminder_minutes ?? 30,
            recurrence: recurrence ?? "none", // 'none' | 'daily' | 'weekly' | 'monthly'
            color: color ?? "#4285f4",
            status: "active",
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, event: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "update") {
        const { event_id, updates } = body;
        if (!event_id || !updates) {
          return new Response(
            JSON.stringify({ success: false, error: "event_id and updates required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // 既存イベントを取得
        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "calendar_event")
          .eq("metadata->>event_id", event_id)
          .maybeSingle();

        if (!existing) {
          return new Response(
            JSON.stringify({ success: false, error: "Event not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const updatedMeta = { ...(existing.metadata as Record<string, unknown>), ...updates };

        const { error } = await adminClient
          .from("app_analytics")
          .update({ metadata: updatedMeta })
          .eq("user_id", user.id)
          .eq("source", "calendar_event")
          .eq("metadata->>event_id", event_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, updated: true }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "delete") {
        const { event_id } = body;
        if (!event_id) {
          return new Response(
            JSON.stringify({ success: false, error: "event_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await adminClient
          .from("app_analytics")
          .delete()
          .eq("user_id", user.id)
          .eq("source", "calendar_event")
          .eq("metadata->>event_id", event_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, deleted: true }),
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
    console.error("calendar-events error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
