// Event Ticketing Edge Function
// イベント・チケット管理 (Facebook Events/LINE競合)
// - イベント作成・管理
// - チケット発行・QRコード
// - 参加者管理
// - チェックイン
// - イベント統計
//
// GET  → イベント一覧 / チケット / 参加者 / 統計
// POST → イベント作成 / チケット発行 / チェックイン / RSVP

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const EVENT_CATEGORIES = ["conference", "meetup", "workshop", "webinar", "party", "concert", "sports", "other"];

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
      const eventId = url.searchParams.get("event_id");

      if (view === "categories") {
        return new Response(JSON.stringify({ success: true, categories: EVENT_CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "tickets" && eventId) {
        const { data: tickets } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "event_ticket").eq("metadata->>event_id", eventId)
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          tickets: (tickets ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), issuedAt: t.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "attendees" && eventId) {
        const { data: attendees } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "event_ticket").eq("metadata->>event_id", eventId);
        const checked = (attendees ?? []).filter((a) => (a.metadata as Record<string, unknown>).checked_in === true).length;
        return new Response(JSON.stringify({
          success: true,
          totalTickets: (attendees ?? []).length, checkedIn: checked,
          attendees: (attendees ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), issuedAt: a.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: events } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "event");
        const { data: tickets } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "event_ticket");
        let totalRevenue = 0;
        for (const t of tickets ?? []) totalRevenue += ((t.metadata as Record<string, unknown>).price as number) ?? 0;
        return new Response(JSON.stringify({
          success: true,
          stats: { totalEvents: (events ?? []).length, totalTickets: (tickets ?? []).length, totalRevenue },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: event list
      const { data: events } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "event")
        .order("created_at", { ascending: false }).limit(30);
      return new Response(JSON.stringify({
        success: true,
        events: (events ?? []).map((e) => ({ ...(e.metadata as Record<string, unknown>), createdAt: e.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_event") {
        const { title, description, category, date, end_date, location, capacity, price, is_online } = body;
        if (!title || !date) {
          return new Response(JSON.stringify({ success: false, error: "title and date required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const eventId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "event",
          metadata: { event_id: eventId, title, description: description ?? null, category: category ?? "other", date, end_date: end_date ?? null, location: location ?? null, capacity: capacity ?? 100, price: price ?? 0, is_online: is_online ?? false, status: "upcoming" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, eventId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "issue_ticket") {
        const { event_id, attendee_name, attendee_email, ticket_type, price } = body;
        if (!event_id || !attendee_name) {
          return new Response(JSON.stringify({ success: false, error: "event_id and attendee_name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const ticketId = crypto.randomUUID();
        const qrCode = `TICKET-${ticketId.substring(0, 8).toUpperCase()}`;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "event_ticket",
          metadata: { ticket_id: ticketId, event_id, attendee_name, attendee_email: attendee_email ?? null, ticket_type: ticket_type ?? "general", price: price ?? 0, qr_code: qrCode, checked_in: false },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, ticketId, qrCode }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "check_in") {
        const { ticket_id } = body;
        if (!ticket_id) {
          return new Response(JSON.stringify({ success: false, error: "ticket_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "event_ticket").eq("metadata->>ticket_id", ticket_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Ticket not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        if (meta.checked_in) {
          return new Response(JSON.stringify({ success: false, error: "Already checked in" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").update({ metadata: { ...meta, checked_in: true, checked_in_at: new Date().toISOString() } })
          .eq("user_id", user.id).eq("source", "event_ticket").eq("metadata->>ticket_id", ticket_id);
        return new Response(JSON.stringify({ success: true, checkedIn: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
