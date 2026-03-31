// Meeting Manager Edge Function
// ミーティング管理 (Google Meet/Microsoft Teams/Slack Huddles競合)
// - ミーティング作成・RSVP管理
// - アジェンダ作成
// - 議事録 (calendar-eventsと連携)
// - アクションアイテム抽出
// - 会議統計
//
// GET  → ミーティング一覧 / 詳細 / アジェンダ / 議事録 / 統計
// POST → 作成 / RSVP / アジェンダ追加 / 議事録保存

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const RSVP_STATUS = ["accepted", "declined", "tentative", "pending"];

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
      const view = url.searchParams.get("view");
      const meetingId = url.searchParams.get("meeting_id");

      if (view === "detail" && meetingId) {
        const { data: meeting } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "meeting")
          .eq("metadata->>meeting_id", meetingId).maybeSingle();
        if (!meeting) {
          return new Response(JSON.stringify({ success: false, error: "Meeting not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        // Get agenda items
        const { data: agenda } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "meeting_agenda")
          .eq("metadata->>meeting_id", meetingId)
          .order("created_at", { ascending: true });
        // Get minutes
        const { data: minutes } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "meeting_minutes")
          .eq("metadata->>meeting_id", meetingId).maybeSingle();

        return new Response(JSON.stringify({
          success: true,
          meeting: { ...(meeting.metadata as Record<string, unknown>), createdAt: meeting.created_at },
          agenda: (agenda ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })),
          minutes: minutes ? { ...(minutes.metadata as Record<string, unknown>), createdAt: minutes.created_at } : null,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "upcoming") {
        const now = new Date().toISOString();
        const { data: meetings } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "meeting")
          .gte("metadata->>start_time", now)
          .order("created_at", { ascending: true }).limit(20);
        return new Response(JSON.stringify({
          success: true,
          meetings: (meetings ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), createdAt: m.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: meetings } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "meeting");
        const total = (meetings ?? []).length;
        let totalDuration = 0;
        for (const m of meetings ?? []) {
          totalDuration += ((m.metadata as Record<string, unknown>).duration_minutes as number) ?? 30;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { totalMeetings: total, totalMinutes: totalDuration, avgDurationMinutes: total > 0 ? Math.round(totalDuration / total) : 0 },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: meeting list
      const { data: meetings } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "meeting")
        .order("created_at", { ascending: false }).limit(50);
      return new Response(JSON.stringify({
        success: true,
        meetings: (meetings ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), createdAt: m.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create") {
        const { title, start_time, duration_minutes, attendees, location, description, recurring } = body;
        if (!title || !start_time) {
          return new Response(JSON.stringify({ success: false, error: "title and start_time required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meetingId = crypto.randomUUID();
        const attendeeList = (attendees ?? []).map((a: string) => ({ email: a, rsvp: "pending" }));
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "meeting",
          metadata: {
            meeting_id: meetingId, title, start_time,
            duration_minutes: duration_minutes ?? 30,
            attendees: attendeeList,
            organizer: user.email,
            location: location ?? null,
            description: description ?? null,
            recurring: recurring ?? null,
            status: "scheduled",
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, meetingId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "rsvp") {
        const { meeting_id, status } = body;
        if (!meeting_id || !status) {
          return new Response(JSON.stringify({ success: false, error: "meeting_id and status required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        if (!RSVP_STATUS.includes(status)) {
          return new Response(JSON.stringify({ success: false, error: "Invalid RSVP status" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "meeting").eq("metadata->>meeting_id", meeting_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Meeting not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const attendees = (meta.attendees as Array<Record<string, unknown>>) ?? [];
        const attendee = attendees.find((a) => a.email === user.email);
        if (attendee) {
          attendee.rsvp = status;
        } else {
          attendees.push({ email: user.email, rsvp: status });
        }
        await adminClient.from("app_analytics").update({ metadata: { ...meta, attendees } })
          .eq("user_id", user.id).eq("source", "meeting").eq("metadata->>meeting_id", meeting_id);
        return new Response(JSON.stringify({ success: true, rsvp: status }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_agenda") {
        const { meeting_id, topic, duration_minutes, presenter } = body;
        if (!meeting_id || !topic) {
          return new Response(JSON.stringify({ success: false, error: "meeting_id and topic required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const agendaId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "meeting_agenda",
          metadata: {
            agenda_id: agendaId, meeting_id, topic,
            duration_minutes: duration_minutes ?? 5,
            presenter: presenter ?? null, completed: false,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, agendaId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "save_minutes") {
        const { meeting_id, content, action_items, decisions } = body;
        if (!meeting_id || !content) {
          return new Response(JSON.stringify({ success: false, error: "meeting_id and content required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const minutesId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "meeting_minutes",
          metadata: {
            minutes_id: minutesId, meeting_id, content,
            action_items: action_items ?? [],
            decisions: decisions ?? [],
            recorded_by: user.email,
          },
          created_at: new Date().toISOString(),
        });

        // Create action items as tasks if provided
        for (const item of action_items ?? []) {
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "meeting_action_item",
            metadata: {
              meeting_id, description: item.description ?? item,
              assignee: item.assignee ?? null,
              due_date: item.due_date ?? null,
              completed: false,
            },
            created_at: new Date().toISOString(),
          });
        }

        return new Response(JSON.stringify({ success: true, minutesId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
