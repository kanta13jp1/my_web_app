// Pet Care Manager Edge Function
// ペットケア管理 (ライフスタイル統合)
// - ペット情報管理
// - 健康記録 (ワクチン/通院)
// - 食事・体重記録
// - 散歩ログ
// - ペット用品管理
//
// GET  → ペット一覧 / 健康記録 / 食事 / 散歩 / 統計
// POST → ペット登録 / 健康記録 / 食事記録 / 散歩記録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const PET_TYPES = ["dog", "cat", "bird", "fish", "hamster", "rabbit", "reptile", "other"];
const HEALTH_RECORD_TYPES = ["vaccine", "checkup", "surgery", "medication", "allergy", "other"];

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
      const petId = url.searchParams.get("pet_id");

      if (view === "options") {
        return new Response(JSON.stringify({ success: true, petTypes: PET_TYPES, healthRecordTypes: HEALTH_RECORD_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "health" && petId) {
        const { data: records } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "pet_health").eq("metadata->>pet_id", petId)
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({
          success: true,
          healthRecords: (records ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), recordedAt: r.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "meals" && petId) {
        const { data: meals } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "pet_meal").eq("metadata->>pet_id", petId)
          .order("created_at", { ascending: false }).limit(30);
        return new Response(JSON.stringify({
          success: true,
          meals: (meals ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), recordedAt: m.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "walks" && petId) {
        const { data: walks } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "pet_walk").eq("metadata->>pet_id", petId)
          .order("created_at", { ascending: false }).limit(30);
        return new Response(JSON.stringify({
          success: true,
          walks: (walks ?? []).map((w) => ({ ...(w.metadata as Record<string, unknown>), recordedAt: w.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats" && petId) {
        const { data: walks } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "pet_walk").eq("metadata->>pet_id", petId);
        let totalWalkMin = 0, totalDistance = 0;
        for (const w of walks ?? []) {
          const meta = w.metadata as Record<string, unknown>;
          totalWalkMin += (meta.duration_min as number) ?? 0;
          totalDistance += (meta.distance_km as number) ?? 0;
        }
        const { data: weights } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "pet_health").eq("metadata->>pet_id", petId).eq("metadata->>type", "weight")
          .order("created_at", { ascending: false }).limit(1);
        const latestWeight = weights?.[0] ? ((weights[0].metadata as Record<string, unknown>).value as number) : null;
        return new Response(JSON.stringify({
          success: true,
          stats: { totalWalks: (walks ?? []).length, totalWalkMinutes: totalWalkMin, totalDistanceKm: Math.round(totalDistance * 10) / 10, latestWeight },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: pet list
      const { data: pets } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "pet")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        pets: (pets ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "register_pet") {
        const { name, pet_type, breed, birthday, photo_url } = body;
        if (!name || !pet_type) {
          return new Response(JSON.stringify({ success: false, error: "name and pet_type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const petId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "pet",
          metadata: { pet_id: petId, name, pet_type, breed: breed ?? null, birthday: birthday ?? null, photo_url: photo_url ?? null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, petId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "log_health") {
        const { pet_id, type, description, vet_name, next_date, value } = body;
        if (!pet_id || !type) {
          return new Response(JSON.stringify({ success: false, error: "pet_id and type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "pet_health",
          metadata: { pet_id, type, description: description ?? null, vet_name: vet_name ?? null, next_date: next_date ?? null, value: value ?? null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, recorded: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "log_meal") {
        const { pet_id, food_name, amount_g, meal_time } = body;
        if (!pet_id || !food_name) {
          return new Response(JSON.stringify({ success: false, error: "pet_id and food_name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "pet_meal",
          metadata: { pet_id, food_name, amount_g: amount_g ?? 0, meal_time: meal_time ?? "morning" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, recorded: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "log_walk") {
        const { pet_id, duration_min, distance_km, route, notes } = body;
        if (!pet_id) {
          return new Response(JSON.stringify({ success: false, error: "pet_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "pet_walk",
          metadata: { pet_id, duration_min: duration_min ?? 30, distance_km: distance_km ?? 1, route: route ?? null, notes: notes ?? null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, recorded: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
