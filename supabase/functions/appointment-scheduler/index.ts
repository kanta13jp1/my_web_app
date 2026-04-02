// Appointment Scheduler Edge Function
// 予約スケジューラー (Google Calendar/Calendly競合)
// - 予約枠設定
// - 予約受付・確認
// - リマインダー
// - キャンセル・変更
// - 予約統計

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const APPOINTMENT_TYPES = ["meeting", "consultation", "interview", "medical", "beauty", "lesson", "repair", "other"];
const APPOINTMENT_STATUSES = ["pending", "confirmed", "cancelled", "completed", "no_show"];
const TIME_SLOTS = ["09:00", "09:30", "10:00", "10:30", "11:00", "11:30", "13:00", "13:30", "14:00", "14:30", "15:00", "15:30", "16:00", "16:30", "17:00"];

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");
      const date = url.searchParams.get("date");

      if (view === "types") {
        return new Response(JSON.stringify({ success: true, appointmentTypes: APPOINTMENT_TYPES, statuses: APPOINTMENT_STATUSES, timeSlots: TIME_SLOTS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "slots" && date) {
        const { data: booked } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "appointment_slot").eq("metadata->>date", date);
        const bookedTimes = (booked ?? []).map((b) => (b.metadata as Record<string, unknown>).time as string);
        const available = TIME_SLOTS.filter((t) => !bookedTimes.includes(t));
        return new Response(JSON.stringify({ success: true, date, available, booked: bookedTimes }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "upcoming") {
        const today = new Date().toISOString().slice(0, 10);
        const { data: appointments } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "appointment")
          .gte("metadata->>date", today).order("created_at", { ascending: true }).limit(20);
        return new Response(JSON.stringify({ success: true, appointments: (appointments ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "history") {
        const { data: appointments } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "appointment")
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, appointments: (appointments ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: all } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "appointment");
        const statusCount: Record<string, number> = {};
        for (const a of all ?? []) {
          const s = ((a.metadata as Record<string, unknown>).status as string) ?? "pending";
          statusCount[s] = (statusCount[s] ?? 0) + 1;
        }
        const noShowRate = (all ?? []).length > 0 ? Math.round(((statusCount["no_show"] ?? 0) / (all ?? []).length) * 100) : 0;
        return new Response(JSON.stringify({
          success: true, stats: {
            total: (all ?? []).length, statusBreakdown: statusCount,
            completionRate: (all ?? []).length > 0 ? Math.round(((statusCount["completed"] ?? 0) / (all ?? []).length) * 100) : 0,
            noShowRate,
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default
      const { data: appointments } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "appointment")
        .order("created_at", { ascending: false }).limit(20);
      return new Response(JSON.stringify({ success: true, appointments: (appointments ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "book") {
        const { type, date: apptDate, time, duration_minutes, title, notes, client_name, client_email } = body;
        if (!apptDate || !time) return new Response(JSON.stringify({ success: false, error: "date and time required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const appointmentId = crypto.randomUUID();
        const confirmCode = appointmentId.substring(0, 6).toUpperCase();
        // Mark slot as booked
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "appointment_slot",
          metadata: { date: apptDate, time, appointment_id: appointmentId },
          created_at: new Date().toISOString(),
        });
        // Create appointment
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "appointment",
          metadata: {
            appointment_id: appointmentId, type: type ?? "meeting",
            date: apptDate, time, duration_minutes: duration_minutes ?? 30,
            title: title ?? "", notes: notes ?? "",
            client_name: client_name ?? "", client_email: client_email ?? "",
            status: "confirmed", confirm_code: confirmCode,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, appointmentId, confirmCode }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "cancel") {
        const { appointment_id } = body;
        if (!appointment_id) return new Response(JSON.stringify({ success: false, error: "appointment_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "appointment").eq("metadata->>appointment_id", appointment_id).maybeSingle();
        if (!existing) return new Response(JSON.stringify({ success: false, error: "Appointment not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = existing.metadata as Record<string, unknown>;
        await adminClient.from("app_analytics").update({ metadata: { ...meta, status: "cancelled" } })
          .eq("user_id", user.id).eq("source", "appointment").eq("metadata->>appointment_id", appointment_id);
        // Free slot
        await adminClient.from("app_analytics").delete()
          .eq("user_id", user.id).eq("source", "appointment_slot").eq("metadata->>appointment_id", appointment_id);
        return new Response(JSON.stringify({ success: true, cancelled: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "complete") {
        const { appointment_id } = body;
        if (!appointment_id) return new Response(JSON.stringify({ success: false, error: "appointment_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "appointment").eq("metadata->>appointment_id", appointment_id).maybeSingle();
        if (!existing) return new Response(JSON.stringify({ success: false, error: "Appointment not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), status: "completed" } })
          .eq("user_id", user.id).eq("source", "appointment").eq("metadata->>appointment_id", appointment_id);
        return new Response(JSON.stringify({ success: true, completed: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
