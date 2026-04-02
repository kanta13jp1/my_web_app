// Travel Itinerary Planner Edge Function
// 旅行プランナー (Google Maps/Notion競合)
// - 旅行プラン作成
// - 日程別アクティビティ管理
// - 予約情報管理 (ホテル/フライト/レンタカー)
// - パッキングリスト
// - 旅行予算管理
//
// GET  → 旅行一覧 / 日程 / 予約 / パッキング / 予算
// POST → 旅行作成 / アクティビティ追加 / 予約追加 / パッキング管理

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const BOOKING_TYPES = ["hotel", "flight", "train", "bus", "rental_car", "restaurant", "activity", "other"];

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
      const tripId = url.searchParams.get("trip_id");

      if (view === "booking_types") {
        return new Response(JSON.stringify({ success: true, bookingTypes: BOOKING_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "itinerary" && tripId) {
        const { data: activities } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "trip_activity").eq("metadata->>trip_id", tripId)
          .order("created_at", { ascending: true });
        // Group by day
        const byDay: Record<string, Array<Record<string, unknown>>> = {};
        for (const a of activities ?? []) {
          const meta = a.metadata as Record<string, unknown>;
          const day = (meta.day as string) ?? "Day 1";
          if (!byDay[day]) byDay[day] = [];
          byDay[day].push(meta);
        }
        return new Response(JSON.stringify({ success: true, tripId, itinerary: byDay }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "bookings" && tripId) {
        const { data: bookings } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "trip_booking").eq("metadata->>trip_id", tripId)
          .order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          bookings: (bookings ?? []).map((b) => ({ ...(b.metadata as Record<string, unknown>), createdAt: b.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "packing" && tripId) {
        const { data: list } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "trip_packing").eq("metadata->>trip_id", tripId).maybeSingle();
        return new Response(JSON.stringify({
          success: true,
          packingList: list ? (list.metadata as Record<string, unknown>).items : [],
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "budget" && tripId) {
        const { data: bookings } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "trip_booking").eq("metadata->>trip_id", tripId);
        let totalSpent = 0;
        const byType: Record<string, number> = {};
        for (const b of bookings ?? []) {
          const meta = b.metadata as Record<string, unknown>;
          const cost = (meta.cost as number) ?? 0;
          const type = (meta.booking_type as string) ?? "other";
          totalSpent += cost;
          byType[type] = (byType[type] ?? 0) + cost;
        }
        const { data: trip } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "trip").eq("metadata->>trip_id", tripId).maybeSingle();
        const budget = trip ? ((trip.metadata as Record<string, unknown>).budget as number) ?? 0 : 0;
        return new Response(JSON.stringify({
          success: true,
          budget: { total: budget, spent: totalSpent, remaining: budget - totalSpent, byType },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: trip list
      const { data: trips } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "trip")
        .order("created_at", { ascending: false }).limit(20);
      return new Response(JSON.stringify({
        success: true,
        trips: (trips ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), createdAt: t.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_trip") {
        const { title, destination, start_date, end_date, budget, notes } = body;
        if (!title || !destination) {
          return new Response(JSON.stringify({ success: false, error: "title and destination required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const tripId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "trip",
          metadata: { trip_id: tripId, title, destination, start_date: start_date ?? null, end_date: end_date ?? null, budget: budget ?? 0, notes: notes ?? null, status: "planning" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, tripId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_activity") {
        const { trip_id, day, time, title, location, description, duration_min } = body;
        if (!trip_id || !title) {
          return new Response(JSON.stringify({ success: false, error: "trip_id and title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const activityId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "trip_activity",
          metadata: { activity_id: activityId, trip_id, day: day ?? "Day 1", time: time ?? "09:00", title, location: location ?? null, description: description ?? null, duration_min: duration_min ?? 60 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, activityId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_booking") {
        const { trip_id, booking_type, title, confirmation_number, check_in, check_out, cost, notes } = body;
        if (!trip_id || !booking_type || !title) {
          return new Response(JSON.stringify({ success: false, error: "trip_id, booking_type, title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const bookingId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "trip_booking",
          metadata: { booking_id: bookingId, trip_id, booking_type, title, confirmation_number: confirmation_number ?? null, check_in: check_in ?? null, check_out: check_out ?? null, cost: cost ?? 0, notes: notes ?? null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, bookingId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_packing") {
        const { trip_id, items } = body;
        if (!trip_id || !items) {
          return new Response(JSON.stringify({ success: false, error: "trip_id and items required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "trip_packing").eq("metadata->>trip_id", trip_id).maybeSingle();
        if (existing) {
          await adminClient.from("app_analytics").update({ metadata: { trip_id, items } })
            .eq("user_id", user.id).eq("source", "trip_packing").eq("metadata->>trip_id", trip_id);
        } else {
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "trip_packing",
            metadata: { trip_id, items },
            created_at: new Date().toISOString(),
          });
        }
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
