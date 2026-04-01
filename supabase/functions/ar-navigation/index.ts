// AR Navigation Edge Function
// AR ナビゲーション (Google Maps/Apple Maps/Pokémon GO競合)
// - ルート管理
// - ウェイポイント
// - AR マーカー配置
// - 歩数・移動記録
// - スポット発見

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const TRANSPORT_MODES = ["walk", "bicycle", "car", "train", "bus"];
const MARKER_TYPES = ["poi", "restaurant", "shop", "event", "custom", "danger", "photo_spot"];
const ROUTE_STATUSES = ["planned", "active", "completed", "cancelled"];

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

      if (view === "config") return new Response(JSON.stringify({ success: true, transportModes: TRANSPORT_MODES, markerTypes: MARKER_TYPES, routeStatuses: ROUTE_STATUSES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "routes") {
        const { data: routes } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "ar_route").order("created_at", { ascending: false }).limit(20);
        return new Response(JSON.stringify({ success: true, routes: (routes ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "markers") {
        const lat = parseFloat(url.searchParams.get("lat") ?? "0");
        const lon = parseFloat(url.searchParams.get("lon") ?? "0");
        const radius = parseFloat(url.searchParams.get("radius") ?? "5");
        const { data: markers } = await adminClient.from("app_analytics").select("metadata, created_at").eq("source", "ar_marker");
        const R = 6371;
        const nearby = (markers ?? []).filter((m) => {
          const meta = m.metadata as Record<string, unknown>;
          const mLat = (meta.lat as number) ?? 0;
          const mLon = (meta.lon as number) ?? 0;
          if (lat === 0 && lon === 0) return true;
          const dLat = (mLat - lat) * Math.PI / 180;
          const dLon = (mLon - lon) * Math.PI / 180;
          const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat * Math.PI / 180) * Math.cos(mLat * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
          const dist = R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
          return dist <= radius;
        }).map((m) => ({ ...(m.metadata as Record<string, unknown>), createdAt: m.created_at }));
        return new Response(JSON.stringify({ success: true, markers: nearby }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "activity_log") {
        const { data: logs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "ar_activity").order("created_at", { ascending: false }).limit(30);
        let totalSteps = 0;
        let totalDistance = 0;
        for (const l of logs ?? []) {
          const m = l.metadata as Record<string, unknown>;
          totalSteps += (m.steps as number) ?? 0;
          totalDistance += (m.distance_km as number) ?? 0;
        }
        return new Response(JSON.stringify({
          success: true,
          logs: (logs ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), createdAt: l.created_at })),
          summary: { totalSteps, totalDistanceKm: Math.round(totalDistance * 100) / 100, calories: Math.round(totalSteps * 0.04) },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, transportModes: TRANSPORT_MODES, markerTypes: MARKER_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_route") {
        const { name, waypoints, transport_mode } = body;
        if (!name || !waypoints) return new Response(JSON.stringify({ success: false, error: "name and waypoints required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const routeId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "ar_route",
          metadata: { route_id: routeId, name, waypoints, transport_mode: transport_mode ?? "walk", status: "planned", total_distance_km: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, routeId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "place_marker") {
        const { lat, lon, marker_type, name, description } = body;
        if (lat === undefined || lon === undefined || !name) return new Response(JSON.stringify({ success: false, error: "lat, lon, name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const markerId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "ar_marker",
          metadata: { marker_id: markerId, lat, lon, marker_type: marker_type ?? "custom", name, description: description ?? "", created_by: user.id },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, markerId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "log_activity") {
        const { steps, distance_km, duration_minutes, transport_mode } = body;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "ar_activity",
          metadata: { steps: steps ?? 0, distance_km: distance_km ?? 0, duration_minutes: duration_minutes ?? 0, transport_mode: transport_mode ?? "walk", logged_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "complete_route") {
        const { route_id } = body;
        if (!route_id) return new Response(JSON.stringify({ success: false, error: "route_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: route } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "ar_route").eq("metadata->>route_id", route_id).maybeSingle();
        if (!route) return new Response(JSON.stringify({ success: false, error: "Route not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").update({ metadata: { ...(route.metadata as Record<string, unknown>), status: "completed", completed_at: new Date().toISOString() } })
          .eq("user_id", user.id).eq("source", "ar_route").eq("metadata->>route_id", route_id);
        return new Response(JSON.stringify({ success: true, completed: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
