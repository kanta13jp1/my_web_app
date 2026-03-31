// Habit Tracker Edge Function
// 習慣トラッカー (Liven/Habitica競合)
// - 習慣定義 (毎日/週N回/月N回)
// - チェックイン記録
// - 達成率・ストリーク
// - 習慣カテゴリ
//
// GET  → 習慣一覧 / 達成率 / ストリーク
// POST → 習慣作成 / チェックイン

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
      const view = url.searchParams.get("view"); // 'list' | 'stats' | 'today'

      // Get all habits
      const { data: habits } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "habit_definition")
        .order("created_at", { ascending: true });

      // Get recent checkins (last 30 days)
      const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString();
      const { data: checkins } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "habit_checkin")
        .gte("created_at", thirtyDaysAgo);

      const today = new Date().toISOString().slice(0, 10);

      const habitList = (habits ?? []).map((h) => {
        const meta = h.metadata as Record<string, unknown>;
        const habitId = meta?.habit_id as string;
        const frequency = (meta?.frequency as string) ?? "daily";
        const targetPerWeek = (meta?.target_per_week as number) ?? 7;

        // Calculate streak and completion
        const myCheckins = (checkins ?? [])
          .filter((c) => (c.metadata as Record<string, unknown>)?.habit_id === habitId)
          .map((c) => (c.metadata as Record<string, unknown>)?.date as string)
          .sort();

        const uniqueDays = [...new Set(myCheckins)];
        const completedToday = uniqueDays.includes(today);

        // Calculate streak
        let streak = 0;
        const d = new Date();
        if (!completedToday) d.setDate(d.getDate() - 1); // Start from yesterday if not done today
        while (true) {
          const dateStr = d.toISOString().slice(0, 10);
          if (uniqueDays.includes(dateStr)) {
            streak++;
            d.setDate(d.getDate() - 1);
          } else {
            break;
          }
        }
        if (completedToday) streak++; // Add today

        // Last 7 days completion rate
        const last7 = [];
        for (let i = 0; i < 7; i++) {
          const dd = new Date(Date.now() - i * 86400000).toISOString().slice(0, 10);
          last7.push(dd);
        }
        const daysCompleted7 = last7.filter((dd) => uniqueDays.includes(dd)).length;
        const target7 = frequency === "daily" ? 7 : targetPerWeek;
        const completionRate = Math.round((daysCompleted7 / target7) * 100);

        return {
          ...meta,
          streak,
          completedToday,
          completionRate: Math.min(completionRate, 100),
          totalCheckins: uniqueDays.length,
          createdAt: h.created_at,
        };
      });

      if (view === "today") {
        return new Response(
          JSON.stringify({
            success: true,
            date: today,
            habits: habitList.map((h) => ({
              habit_id: h.habit_id,
              name: h.name,
              completedToday: h.completedToday,
              streak: h.streak,
            })),
            completedCount: habitList.filter((h) => h.completedToday).length,
            totalHabits: habitList.length,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "stats") {
        const avgCompletion = habitList.length > 0
          ? Math.round(habitList.reduce((s, h) => s + (h.completionRate as number), 0) / habitList.length)
          : 0;
        const longestStreak = habitList.length > 0
          ? Math.max(...habitList.map((h) => h.streak as number))
          : 0;

        return new Response(
          JSON.stringify({
            success: true,
            stats: {
              totalHabits: habitList.length,
              avgCompletionRate: avgCompletion,
              longestStreak,
              totalCheckins: (checkins ?? []).length,
            },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: true, habits: habitList }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create") {
        const { name, category, frequency, target_per_week, description } = body;
        if (!name) {
          return new Response(
            JSON.stringify({ success: false, error: "name required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const habitId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "habit_definition",
          metadata: {
            habit_id: habitId,
            name,
            category: category ?? "general",
            frequency: frequency ?? "daily",
            target_per_week: target_per_week ?? 7,
            description: description ?? "",
            active: true,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, habitId, habit: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "checkin") {
        const { habit_id, date } = body;
        if (!habit_id) {
          return new Response(
            JSON.stringify({ success: false, error: "habit_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const checkinDate = date ?? new Date().toISOString().slice(0, 10);

        // Check for duplicate
        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "habit_checkin")
          .eq("metadata->>habit_id", habit_id)
          .eq("metadata->>date", checkinDate)
          .maybeSingle();

        if (existing) {
          return new Response(
            JSON.stringify({ success: true, alreadyCheckedIn: true, date: checkinDate }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "habit_checkin",
          metadata: { habit_id, date: checkinDate },
          created_at: new Date().toISOString(),
        });

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, checkedIn: true, date: checkinDate }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
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
    console.error("habit-tracker error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
