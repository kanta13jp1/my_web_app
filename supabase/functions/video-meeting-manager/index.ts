// Video Meeting Manager Edge Function
// ビデオ会議管理 (Zoom/Google Meet/Teams競合)
// - ミーティングルーム作成
// - 参加者管理
// - AI議事録・要約
// - アクションアイテム抽出
// - 会議統計
//
// GET  → ルーム一覧 / 参加者 / 議事録 / アクションアイテム / 統計
// POST → ルーム作成 / 参加 / 議事録保存 / アクションアイテム作成

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const MEETING_TYPES = ["video", "audio", "webinar", "screen_share"];

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
      const roomId = url.searchParams.get("room_id");

      if (view === "meeting_types") {
        return new Response(JSON.stringify({ success: true, meetingTypes: MEETING_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "participants" && roomId) {
        const { data: participants } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "vmeet_participant").eq("metadata->>room_id", roomId)
          .order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          participants: (participants ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), joinedAt: p.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "transcript" && roomId) {
        const { data: transcript } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "vmeet_transcript").eq("metadata->>room_id", roomId).maybeSingle();
        return new Response(JSON.stringify({
          success: true,
          transcript: transcript ? (transcript.metadata as Record<string, unknown>) : null,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "action_items") {
        let query = adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "vmeet_action")
          .order("created_at", { ascending: false });
        if (roomId) query = query.eq("metadata->>room_id", roomId);
        const { data: actions } = await query.limit(50);
        return new Response(JSON.stringify({
          success: true,
          actionItems: (actions ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: rooms } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "vmeet_room");
        let totalDuration = 0, totalParticipants = 0;
        for (const r of rooms ?? []) {
          const meta = r.metadata as Record<string, unknown>;
          totalDuration += (meta.duration_min as number) ?? 0;
          totalParticipants += (meta.participant_count as number) ?? 0;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { totalMeetings: (rooms ?? []).length, totalDurationMin: totalDuration, avgDuration: (rooms ?? []).length > 0 ? Math.round(totalDuration / (rooms ?? []).length) : 0, totalParticipants },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: room list
      const { data: rooms } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "vmeet_room")
        .order("created_at", { ascending: false }).limit(30);
      return new Response(JSON.stringify({
        success: true,
        rooms: (rooms ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_room") {
        const { title, meeting_type, scheduled_at, duration_min, max_participants, is_recorded } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const roomId = crypto.randomUUID();
        const joinCode = `${roomId.substring(0, 3)}-${roomId.substring(3, 7)}-${roomId.substring(7, 11)}`.toUpperCase();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "vmeet_room",
          metadata: { room_id: roomId, title, meeting_type: meeting_type ?? "video", scheduled_at: scheduled_at ?? null, duration_min: duration_min ?? 60, max_participants: max_participants ?? 50, is_recorded: is_recorded ?? true, join_code: joinCode, status: "scheduled", participant_count: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, roomId, joinCode }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "join") {
        const { room_id, participant_name, participant_email } = body;
        if (!room_id || !participant_name) {
          return new Response(JSON.stringify({ success: false, error: "room_id and participant_name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "vmeet_participant",
          metadata: { room_id, participant_name, participant_email: participant_email ?? null, joined_at: new Date().toISOString(), left_at: null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, joined: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "save_transcript") {
        const { room_id, content, summary, key_points } = body;
        if (!room_id || !content) {
          return new Response(JSON.stringify({ success: false, error: "room_id and content required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "vmeet_transcript",
          metadata: { room_id, content, summary: summary ?? null, key_points: key_points ?? [], word_count: content.split(/\s+/).length },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, saved: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_action_item") {
        const { room_id, title, assignee, due_date } = body;
        if (!room_id || !title) {
          return new Response(JSON.stringify({ success: false, error: "room_id and title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const itemId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "vmeet_action",
          metadata: { action_id: itemId, room_id, title, assignee: assignee ?? null, due_date: due_date ?? null, status: "pending" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, actionId: itemId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
