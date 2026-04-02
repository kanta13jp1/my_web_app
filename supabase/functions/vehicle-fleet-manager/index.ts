// Vehicle & Fleet Manager Edge Function
// 車両・フリート管理 (企業向け/個人向け)
// - 車両登録・管理
// - 走行記録
// - 燃費管理
// - メンテナンス予定
// - コスト統計

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const VEHICLE_TYPES = ["sedan", "suv", "truck", "van", "motorcycle", "ev", "hybrid", "other"];

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
      const vehicleId = url.searchParams.get("vehicle_id");
      if (view === "types") return new Response(JSON.stringify({ success: true, vehicleTypes: VEHICLE_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      if (view === "trips" && vehicleId) {
        const { data: trips } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "vehicle_trip").eq("metadata->>vehicle_id", vehicleId).order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, trips: (trips ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), createdAt: t.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (view === "fuel" && vehicleId) {
        const { data: refuels } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "vehicle_fuel").eq("metadata->>vehicle_id", vehicleId).order("created_at", { ascending: false }).limit(50);
        let totalLiters = 0, totalCost = 0;
        for (const r of refuels ?? []) {
          totalLiters += ((r.metadata as Record<string, unknown>).liters as number) ?? 0;
          totalCost += ((r.metadata as Record<string, unknown>).cost as number) ?? 0;
        }
        return new Response(JSON.stringify({ success: true, totalLiters, totalCost, refuels: (refuels ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (view === "maintenance" && vehicleId) {
        const { data: records } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "vehicle_maintenance").eq("metadata->>vehicle_id", vehicleId).order("created_at", { ascending: false }).limit(30);
        return new Response(JSON.stringify({ success: true, records: (records ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (view === "stats") {
        const { data: vehicles } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "vehicle");
        const { data: trips } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "vehicle_trip");
        const { data: fuel } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "vehicle_fuel");
        let totalKm = 0, totalFuelCost = 0;
        for (const t of trips ?? []) totalKm += ((t.metadata as Record<string, unknown>).distance_km as number) ?? 0;
        for (const f of fuel ?? []) totalFuelCost += ((f.metadata as Record<string, unknown>).cost as number) ?? 0;
        return new Response(JSON.stringify({ success: true, stats: { totalVehicles: (vehicles ?? []).length, totalTrips: (trips ?? []).length, totalKm: Math.round(totalKm), totalFuelCost } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: vehicles } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "vehicle").order("created_at", { ascending: false });
      return new Response(JSON.stringify({ success: true, vehicles: (vehicles ?? []).map((v) => ({ ...(v.metadata as Record<string, unknown>), createdAt: v.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;
      if (action === "register_vehicle") {
        const { name, vehicle_type, make, model, year, plate_number, odometer_km } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const vehicleId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "vehicle", metadata: { vehicle_id: vehicleId, name, vehicle_type: vehicle_type ?? "sedan", make: make ?? null, model: model ?? null, year: year ?? null, plate_number: plate_number ?? null, odometer_km: odometer_km ?? 0 }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, vehicleId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (action === "log_trip") {
        const { vehicle_id, start_location, end_location, distance_km, purpose } = body;
        if (!vehicle_id || !distance_km) return new Response(JSON.stringify({ success: false, error: "vehicle_id and distance_km required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "vehicle_trip", metadata: { vehicle_id, start_location: start_location ?? null, end_location: end_location ?? null, distance_km, purpose: purpose ?? "business" }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, logged: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (action === "log_fuel") {
        const { vehicle_id, liters, cost, odometer_km } = body;
        if (!vehicle_id || !liters) return new Response(JSON.stringify({ success: false, error: "vehicle_id and liters required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "vehicle_fuel", metadata: { vehicle_id, liters, cost: cost ?? 0, odometer_km: odometer_km ?? null, price_per_liter: cost && liters ? Math.round(cost / liters * 10) / 10 : null }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, logged: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (action === "log_maintenance") {
        const { vehicle_id, title, cost, mileage_km, next_due_km } = body;
        if (!vehicle_id || !title) return new Response(JSON.stringify({ success: false, error: "vehicle_id and title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "vehicle_maintenance", metadata: { vehicle_id, title, cost: cost ?? 0, mileage_km: mileage_km ?? null, next_due_km: next_due_km ?? null }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, logged: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
