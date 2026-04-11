// Personal Dashboard Edge Function
// Notion 3.4 ダッシュボードビュー対抗: ユーザーの KPI・週次推移・習慣・直近ノートを集計
//
// POST { action: 'get_overview', user_id: string }
//   → { kpi, weekly_activity, habit_stats, recent_notes }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function toMmDd(date: Date): string {
  const mm = String(date.getMonth() + 1).padStart(2, "0");
  const dd = String(date.getDate()).padStart(2, "0");
  return `${mm}/${dd}`;
}

function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function calcStreak(dates: Set<string>, refDate: Date): number {
  let streak = 0;
  const d = new Date(refDate);
  while (true) {
    const s = isoDate(d);
    if (!dates.has(s)) break;
    streak++;
    d.setDate(d.getDate() - 1);
  }
  return streak;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing authorization header");

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userErr } = await supabase.auth.getUser();
    if (userErr || !user) throw new Error("Unauthorized");

    const body = (await req.json().catch(() => ({}))) as { action?: string; user_id?: string };
    if (body.action !== "get_overview") throw new Error(`Unknown action: ${body.action}`);

    const userId = user.id;
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const todayStr = isoDate(now);
    const sevenDaysAgoStr = sevenDaysAgo.toISOString();

    // ── 1. ノート集計 ──────────────────────────────────────────────────────
    const { data: noteRows } = await supabase
      .from("app_analytics")
      .select("metadata, created_at")
      .eq("user_id", userId)
      .eq("source", "quick_note")
      .neq("metadata->>archived", "true")
      .order("created_at", { ascending: false })
      .limit(200);

    const totalNotes = noteRows?.length ?? 0;
    const recentNotes = (noteRows ?? []).slice(0, 5).map((r) => ({
      id: (r.metadata as Record<string, unknown>)?.["note_id"] ?? "",
      title: (r.metadata as Record<string, unknown>)?.["title"] ?? "無題",
      created_at: r.created_at,
    }));
    const noteGrowth = (noteRows ?? []).filter(
      (r) => new Date(r.created_at) >= sevenDaysAgo,
    ).length;

    // ── 2. タスク集計 ──────────────────────────────────────────────────────
    const { data: taskRows } = await supabase
      .from("app_analytics")
      .select("metadata, created_at")
      .eq("user_id", userId)
      .eq("source", "kanban_card")
      .gte("created_at", sevenDaysAgoStr);

    const allTasks = taskRows ?? [];
    const completedTasks = allTasks.filter(
      (r) => (r.metadata as Record<string, unknown>)?.["status"] === "done",
    );
    const taskRate = allTasks.length > 0
      ? completedTasks.length / allTasks.length
      : 0;

    // ── 3. フォーカス集計 ─────────────────────────────────────────────────
    const { data: focusRows } = await supabase
      .from("focus_sessions")
      .select("duration_minutes, started_at")
      .eq("user_id", userId)
      .gte("started_at", sevenDaysAgoStr);

    const totalFocusMin = (focusRows ?? []).reduce(
      (sum, r) => sum + (r.duration_minutes ?? 25),
      0,
    );

    // ── 4. 習慣集計 ───────────────────────────────────────────────────────
    const { data: habitDefs } = await supabase
      .from("app_analytics")
      .select("metadata")
      .eq("user_id", userId)
      .eq("source", "habit_definition");

    const { data: habitCheckins } = await supabase
      .from("app_analytics")
      .select("metadata, created_at")
      .eq("user_id", userId)
      .eq("source", "habit_checkin")
      .gte("created_at", new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString());

    // 習慣ごとのチェックイン日セット
    const checkinsByHabit = new Map<string, Set<string>>();
    for (const row of habitCheckins ?? []) {
      const meta = row.metadata as Record<string, unknown>;
      const habitId = String(meta?.["habit_id"] ?? "");
      const dateStr = isoDate(new Date(row.created_at));
      if (!checkinsByHabit.has(habitId)) checkinsByHabit.set(habitId, new Set());
      checkinsByHabit.get(habitId)!.add(dateStr);
    }

    const habitStats = (habitDefs ?? []).slice(0, 5).map((row) => {
      const meta = row.metadata as Record<string, unknown>;
      const habitId = String(meta?.["habit_id"] ?? "");
      const name = String(meta?.["name"] ?? "習慣");
      const dates = checkinsByHabit.get(habitId) ?? new Set<string>();
      return {
        name,
        streak: calcStreak(dates, now),
        completed_today: dates.has(todayStr),
      };
    });

    const maxStreak = habitStats.reduce((max, h) => Math.max(max, h.streak), 0);

    // ── 5. 週次推移 ───────────────────────────────────────────────────────
    const weeklyActivity = Array.from({ length: 7 }, (_, i) => {
      const day = new Date(now.getTime() - (6 - i) * 24 * 60 * 60 * 1000);
      const dayStr = isoDate(day);
      const notes = (noteRows ?? []).filter(
        (r) => isoDate(new Date(r.created_at)) === dayStr,
      ).length;
      const tasks = (taskRows ?? []).filter(
        (r) => isoDate(new Date(r.created_at)) === dayStr &&
          (r.metadata as Record<string, unknown>)?.["status"] === "done",
      ).length;
      const focusMin = (focusRows ?? [])
        .filter((r) => isoDate(new Date(r.started_at)) === dayStr)
        .reduce((sum, r) => sum + (r.duration_minutes ?? 25), 0);
      return { date: toMmDd(day), notes, tasks, focus_min: focusMin };
    });

    return json({
      success: true,
      kpi: {
        total_notes: totalNotes,
        tasks_completed: completedTasks.length,
        focus_minutes: totalFocusMin,
        habit_streak: maxStreak,
        note_growth: noteGrowth,
        task_rate: Math.round(taskRate * 100) / 100,
      },
      weekly_activity: weeklyActivity,
      habit_stats: habitStats,
      recent_notes: recentNotes,
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return json({ success: false, error: msg }, 400);
  }
});
