// Fitness & Health Tracker Edge Function
// フィットネス・健康管理 (Google Fit/Apple Health競合)
// - ワークアウト記録
// - 体重・体組成記録
// - 健康メトリクス (睡眠/歩数/心拍)
// - 目標設定・進捗
// - 週次・月次サマリー
//
// GET  → ワークアウト一覧 / 体重推移 / メトリクス / 目標 / サマリー
// POST → ワークアウト記録 / 体重記録 / メトリクス記録 / 目標設定

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const WORKOUT_TYPES = ["running", "walking", "cycling", "swimming", "gym", "yoga", "hiit", "stretching", "sports", "other"];

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

      if (view === "workout_types") {
        return new Response(JSON.stringify({ success: true, workoutTypes: WORKOUT_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "workouts") {
        const type = url.searchParams.get("type");
        let query = adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "fitness_workout")
          .order("created_at", { ascending: false });
        if (type) query = query.eq("metadata->>workout_type", type);
        const { data: workouts } = await query.limit(50);
        return new Response(JSON.stringify({
          success: true,
          workouts: (workouts ?? []).map((w) => ({ ...(w.metadata as Record<string, unknown>), createdAt: w.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "weight") {
        const { data: records } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "fitness_weight")
          .order("created_at", { ascending: true }).limit(365);
        return new Response(JSON.stringify({
          success: true,
          weightHistory: (records ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), recordedAt: r.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "metrics") {
        const date = url.searchParams.get("date") ?? new Date().toISOString().substring(0, 10);
        const { data: metrics } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "fitness_metric")
          .gte("created_at", `${date}T00:00:00`).lte("created_at", `${date}T23:59:59`);
        return new Response(JSON.stringify({
          success: true, date,
          metrics: (metrics ?? []).map((m) => (m.metadata as Record<string, unknown>)),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "goals") {
        const { data: goals } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "fitness_goal")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          goals: (goals ?? []).map((g) => ({ ...(g.metadata as Record<string, unknown>), createdAt: g.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "summary") {
        const days = parseInt(url.searchParams.get("days") ?? "7");
        const since = new Date(Date.now() - days * 86400000).toISOString();
        const { data: workouts } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "fitness_workout").gte("created_at", since);
        let totalDuration = 0, totalCalories = 0, totalDistance = 0;
        const typeCounts: Record<string, number> = {};
        for (const w of workouts ?? []) {
          const meta = w.metadata as Record<string, unknown>;
          totalDuration += (meta.duration_min as number) ?? 0;
          totalCalories += (meta.calories_burned as number) ?? 0;
          totalDistance += (meta.distance_km as number) ?? 0;
          const t = (meta.workout_type as string) ?? "other";
          typeCounts[t] = (typeCounts[t] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true,
          summary: { days, workoutCount: (workouts ?? []).length, totalDuration, totalCalories, totalDistance: Math.round(totalDistance * 10) / 10, typeCounts },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, views: ["workout_types", "workouts", "weight", "metrics", "goals", "summary"] }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "log_workout") {
        const { workout_type, duration_min, calories_burned, distance_km, notes } = body;
        if (!workout_type) {
          return new Response(JSON.stringify({ success: false, error: "workout_type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const workoutId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "fitness_workout",
          metadata: { workout_id: workoutId, workout_type, duration_min: duration_min ?? 30, calories_burned: calories_burned ?? 0, distance_km: distance_km ?? 0, notes: notes ?? null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, workoutId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "log_weight") {
        const { weight_kg, body_fat_percent, muscle_mass_kg } = body;
        if (!weight_kg) {
          return new Response(JSON.stringify({ success: false, error: "weight_kg required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "fitness_weight",
          metadata: { weight_kg, body_fat_percent: body_fat_percent ?? null, muscle_mass_kg: muscle_mass_kg ?? null, date: new Date().toISOString().substring(0, 10) },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, recorded: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "log_metric") {
        const { metric_type, value, unit } = body;
        if (!metric_type || value === undefined) {
          return new Response(JSON.stringify({ success: false, error: "metric_type and value required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "fitness_metric",
          metadata: { metric_type, value, unit: unit ?? null, date: new Date().toISOString().substring(0, 10) },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, recorded: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "set_goal") {
        const { goal_type, target_value, unit, deadline } = body;
        if (!goal_type || !target_value) {
          return new Response(JSON.stringify({ success: false, error: "goal_type and target_value required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const goalId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "fitness_goal",
          metadata: { goal_id: goalId, goal_type, target_value, current_value: 0, unit: unit ?? null, deadline: deadline ?? null, status: "active" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, goalId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
