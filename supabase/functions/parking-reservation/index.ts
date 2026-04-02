// Parking & Reservation Manager Edge Function
// 駐車場・予約管理 (akippa/タイムズ競合)
// - 駐車場スペース管理
// - 予約作成・管理
// - 料金計算
// - 空き状況確認
// - 収益統計

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
    if (!authHeader) return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");
      if (view === "availability") {
        const date = url.searchParams.get("date") ?? new Date().toISOString().substring(0, 10);
        const { data: spaces } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "parking_space");
        const { data: reservations } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "parking_reservation").eq("metadata->>date", date);
        const reserved = new Set((reservations ?? []).map((r) => (r.metadata as Record<string, unknown>).space_id));
        const available = (spaces ?? []).filter((s) => !reserved.has((s.metadata as Record<string, unknown>).space_id as string));
        return new Response(JSON.stringify({ success: true, date, totalSpaces: (spaces ?? []).length, available: available.length, reserved: reserved.size }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (view === "reservations") {
        const { data: res } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "parking_reservation").order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, reservations: (res ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (view === "stats") {
        const { data: spaces } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "parking_space");
        const { data: res } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "parking_reservation");
        let totalRevenue = 0;
        for (const r of res ?? []) totalRevenue += ((r.metadata as Record<string, unknown>).fee as number) ?? 0;
        return new Response(JSON.stringify({ success: true, stats: { totalSpaces: (spaces ?? []).length, totalReservations: (res ?? []).length, totalRevenue } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: spaces } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "parking_space").order("created_at", { ascending: false });
      return new Response(JSON.stringify({ success: true, spaces: (spaces ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;
      if (action === "add_space") {
        const { name, location, hourly_rate, type } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const spaceId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "parking_space", metadata: { space_id: spaceId, name, location: location ?? null, hourly_rate: hourly_rate ?? 300, type: type ?? "standard" }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, spaceId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (action === "reserve") {
        const { space_id, date, start_time, end_time, vehicle_number } = body;
        if (!space_id || !date) return new Response(JSON.stringify({ success: false, error: "space_id and date required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const reservationId = crypto.randomUUID();
        const hours = start_time && end_time ? (parseInt(end_time) - parseInt(start_time)) : 1;
        const { data: space } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "parking_space").eq("metadata->>space_id", space_id).maybeSingle();
        const rate = space ? ((space.metadata as Record<string, unknown>).hourly_rate as number) ?? 300 : 300;
        const fee = hours * rate;
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "parking_reservation", metadata: { reservation_id: reservationId, space_id, date, start_time: start_time ?? "09:00", end_time: end_time ?? "18:00", vehicle_number: vehicle_number ?? null, fee, status: "confirmed" }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, reservationId, fee }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
