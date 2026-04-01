// Geo Check-in Edge Function
// 位置情報チェックイン (Facebook/LINE/Google Maps/Foursquare競合)
// - スポットチェックイン
// - 訪問履歴
// - スポットレビュー
// - ランキング
// - 近くのスポット

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const SPOT_CATEGORIES = ["restaurant", "cafe", "shop", "park", "office", "gym", "station", "temple", "museum", "hotel", "hospital", "school", "other"];

function haversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

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

      if (view === "categories") return new Response(JSON.stringify({ success: true, categories: SPOT_CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "my_checkins") {
        const { data: checkins } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "geo_checkin").order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, checkins: (checkins ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "spot") {
        const spotId = url.searchParams.get("spot_id");
        if (!spotId) return new Response(JSON.stringify({ success: false, error: "spot_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: spot } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "geo_spot").eq("metadata->>spot_id", spotId).maybeSingle();
        if (!spot) return new Response(JSON.stringify({ success: false, error: "Spot not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { count: checkinCount } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("source", "geo_checkin").eq("metadata->>spot_id", spotId);
        const { data: reviews } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "spot_review").eq("metadata->>spot_id", spotId).order("created_at", { ascending: false }).limit(10);
        return new Response(JSON.stringify({
          success: true,
          spot: { ...(spot.metadata as Record<string, unknown>), createdAt: spot.created_at },
          checkinCount: checkinCount ?? 0,
          reviews: (reviews ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "nearby") {
        const lat = parseFloat(url.searchParams.get("lat") ?? "0");
        const lon = parseFloat(url.searchParams.get("lon") ?? "0");
        const radius = parseFloat(url.searchParams.get("radius") ?? "5");
        if (lat === 0 && lon === 0) return new Response(JSON.stringify({ success: false, error: "lat and lon required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: spots } = await adminClient.from("app_analytics").select("metadata, created_at").eq("source", "geo_spot");
        const nearby = (spots ?? [])
          .map((s) => {
            const m = s.metadata as Record<string, unknown>;
            const dist = haversineDistance(lat, lon, m.lat as number, m.lon as number);
            return { ...m, distance_km: Math.round(dist * 100) / 100, createdAt: s.created_at };
          })
          .filter((s) => s.distance_km <= radius)
          .sort((a, b) => a.distance_km - b.distance_km)
          .slice(0, 20);
        return new Response(JSON.stringify({ success: true, nearby, radius }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "ranking") {
        const { data: all } = await adminClient.from("app_analytics").select("user_id").eq("source", "geo_checkin");
        const counts: Record<string, number> = {};
        for (const c of all ?? []) counts[c.user_id] = (counts[c.user_id] ?? 0) + 1;
        const ranking = Object.entries(counts).map(([uid, cnt]) => ({ userId: uid, checkins: cnt })).sort((a, b) => b.checkins - a.checkins).slice(0, 20);
        return new Response(JSON.stringify({ success: true, ranking }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, categories: SPOT_CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_spot") {
        const { name, category, lat, lon, address, description } = body;
        if (!name || lat === undefined || lon === undefined) return new Response(JSON.stringify({ success: false, error: "name, lat, lon required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const spotId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "geo_spot",
          metadata: { spot_id: spotId, name, category: category ?? "other", lat, lon, address: address ?? "", description: description ?? "", created_by: user.id },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, spotId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "checkin") {
        const { spot_id, lat, lon, comment } = body;
        if (!spot_id) return new Response(JSON.stringify({ success: false, error: "spot_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const checkinId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "geo_checkin",
          metadata: { checkin_id: checkinId, spot_id, lat: lat ?? null, lon: lon ?? null, comment: comment ?? "", checked_in_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, checkinId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "review") {
        const { spot_id, rating, comment } = body;
        if (!spot_id || !rating) return new Response(JSON.stringify({ success: false, error: "spot_id and rating required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const reviewId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "spot_review",
          metadata: { review_id: reviewId, spot_id, rating: Math.min(5, Math.max(1, rating)), comment: comment ?? "", user_email: user.email },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, reviewId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
