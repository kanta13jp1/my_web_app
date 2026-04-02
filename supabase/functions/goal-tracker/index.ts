// Goal Tracker Edge Function
// 目標管理 (Notion/Liven競合)
// - 目標設定 (短期/中期/長期)
// - マイルストーン管理
// - 進捗追跡
// - 達成記録
//
// GET  → 目標一覧 / 進捗 / 達成済み
// POST → 目標作成 / マイルストーン更新 / 達成記録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "Authorization required" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'active' | 'completed' | 'detail'
      const goalId = url.searchParams.get("goal_id");
      const timeframe = url.searchParams.get("timeframe"); // 'short' | 'mid' | 'long'

      if (view === "detail" && goalId) {
        const { data: goal } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "goal")
          .eq("metadata->>goal_id", goalId)
          .maybeSingle();

        if (!goal) {
          return new Response(
            JSON.stringify({ success: false, error: "Goal not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        return new Response(
          JSON.stringify({ success: true, goal: { ...(goal.metadata as Record<string, unknown>), createdAt: goal.created_at } }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const { data: goals } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "goal")
        .order("created_at", { ascending: false });

      let goalList = (goals ?? []).map((g) => ({
        ...(g.metadata as Record<string, unknown>),
        createdAt: g.created_at,
      }));

      if (timeframe) {
        goalList = goalList.filter((g) => g.timeframe === timeframe);
      }

      if (view === "completed") {
        goalList = goalList.filter((g) => g.status === "completed");
      } else if (view === "active") {
        goalList = goalList.filter((g) => g.status !== "completed" && g.status !== "cancelled");
      }

      // Calculate progress for each goal
      const enriched = goalList.map((g) => {
        const milestones = (g.milestones as Array<{ done: boolean }>) ?? [];
        const total = milestones.length;
        const done = milestones.filter((m) => m.done).length;
        const progress = total > 0 ? Math.round((done / total) * 100) : 0;
        return { ...g, progress, milestoneDone: done, milestoneTotal: total };
      });

      return new Response(
        JSON.stringify({ success: true, goals: enriched }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create") {
        const { title, description, timeframe: tf, deadline, milestones } = body;
        if (!title) {
          return new Response(
            JSON.stringify({ success: false, error: "title required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const goalId = crypto.randomUUID();
        const ms = (milestones ?? []).map((m: { title: string }) => ({
          id: crypto.randomUUID(),
          title: m.title,
          done: false,
        }));

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "goal",
          metadata: {
            goal_id: goalId,
            title,
            description: description ?? "",
            timeframe: tf ?? "short",
            deadline: deadline ?? null,
            milestones: ms,
            status: "active",
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, goalId, goal: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "update_milestone") {
        const { goal_id, milestone_id, done } = body;
        if (!goal_id || !milestone_id) {
          return new Response(
            JSON.stringify({ success: false, error: "goal_id and milestone_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "goal")
          .eq("metadata->>goal_id", goal_id)
          .maybeSingle();

        if (!existing) {
          return new Response(
            JSON.stringify({ success: false, error: "Goal not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const meta = existing.metadata as Record<string, unknown>;
        const milestones = (meta.milestones as Array<{ id: string; title: string; done: boolean }>) ?? [];
        const updated = milestones.map((m) =>
          m.id === milestone_id ? { ...m, done: done ?? true } : m
        );

        const allDone = updated.every((m) => m.done);
        const newStatus = allDone ? "completed" : (meta.status as string);

        const { error } = await adminClient
          .from("app_analytics")
          .update({ metadata: { ...meta, milestones: updated, status: newStatus } })
          .eq("user_id", user.id)
          .eq("source", "goal")
          .eq("metadata->>goal_id", goal_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, updated: true, allCompleted: allDone }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "update_status") {
        const { goal_id, status: newStatus } = body;
        if (!goal_id || !newStatus) {
          return new Response(
            JSON.stringify({ success: false, error: "goal_id and status required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "goal")
          .eq("metadata->>goal_id", goal_id)
          .maybeSingle();

        if (!existing) {
          return new Response(
            JSON.stringify({ success: false, error: "Goal not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await adminClient
          .from("app_analytics")
          .update({ metadata: { ...(existing.metadata as Record<string, unknown>), status: newStatus } })
          .eq("user_id", user.id)
          .eq("source", "goal")
          .eq("metadata->>goal_id", goal_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, updated: true, status: newStatus }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("goal-tracker error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
