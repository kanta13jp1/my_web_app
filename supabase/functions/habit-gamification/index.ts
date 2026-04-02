// Habit Gamification Edge Function
// 習慣ゲーミフィケーション (Duolingo/Forest競合)
// - デイリーチャレンジ
// - 実績バッジ
// - レベル・経験値
// - ランキング
// - ストリーク管理

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const BADGE_DEFINITIONS = [
  { id: "first_step", name: "はじめの一歩", description: "初回アクション完了", xp: 10, icon: "star" },
  { id: "streak_3", name: "3日連続", description: "3日連続達成", xp: 30, icon: "fire" },
  { id: "streak_7", name: "1週間連続", description: "7日連続達成", xp: 100, icon: "fire" },
  { id: "streak_30", name: "30日連続", description: "30日連続達成", xp: 500, icon: "trophy" },
  { id: "streak_100", name: "100日連続", description: "100日連続達成", xp: 2000, icon: "crown" },
  { id: "level_5", name: "レベル5到達", description: "レベル5に到達", xp: 200, icon: "shield" },
  { id: "level_10", name: "レベル10到達", description: "レベル10に到達", xp: 500, icon: "shield" },
  { id: "tasks_10", name: "タスク10完了", description: "累計10タスク完了", xp: 50, icon: "check" },
  { id: "tasks_50", name: "タスク50完了", description: "累計50タスク完了", xp: 200, icon: "check" },
  { id: "tasks_100", name: "タスク100完了", description: "累計100タスク完了", xp: 500, icon: "medal" },
  { id: "early_bird", name: "早起き達成", description: "朝6時前にアクション", xp: 30, icon: "sun" },
  { id: "night_owl", name: "夜型達成", description: "深夜0時以降にアクション", xp: 20, icon: "moon" },
];

const CHALLENGE_TEMPLATES = [
  { type: "daily_login", title: "デイリーログイン", description: "今日ログインする", xp: 5 },
  { type: "complete_task", title: "タスク1つ完了", description: "タスクを1つ完了する", xp: 10 },
  { type: "write_note", title: "メモを書く", description: "メモを1つ作成する", xp: 10 },
  { type: "share_content", title: "コンテンツ共有", description: "何かを共有する", xp: 15 },
  { type: "explore_feature", title: "新機能探索", description: "新しい機能を使う", xp: 20 },
];

function calculateLevel(totalXp: number): { level: number; currentXp: number; nextLevelXp: number } {
  let level = 1;
  let xpForNext = 100;
  let accumulated = 0;
  while (accumulated + xpForNext <= totalXp) {
    accumulated += xpForNext;
    level++;
    xpForNext = Math.round(xpForNext * 1.5);
  }
  return { level, currentXp: totalXp - accumulated, nextLevelXp: xpForNext };
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

      if (view === "profile") {
        const { data: profile } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "gamification_profile").maybeSingle();
        if (!profile) {
          // Create default profile
          const defaultProfile = { total_xp: 0, streak_days: 0, last_active: null, total_tasks: 0, badges: [] };
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "gamification_profile",
            metadata: defaultProfile, created_at: new Date().toISOString(),
          });
          return new Response(JSON.stringify({ success: true, profile: { ...defaultProfile, ...calculateLevel(0) } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = profile.metadata as Record<string, unknown>;
        const totalXp = (meta.total_xp as number) ?? 0;
        return new Response(JSON.stringify({ success: true, profile: { ...meta, ...calculateLevel(totalXp) } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "badges") {
        const { data: profile } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "gamification_profile").maybeSingle();
        const earned = ((profile?.metadata as Record<string, unknown>)?.badges as string[]) ?? [];
        return new Response(JSON.stringify({
          success: true,
          badges: BADGE_DEFINITIONS.map((b) => ({ ...b, earned: earned.includes(b.id) })),
          earnedCount: earned.length, totalCount: BADGE_DEFINITIONS.length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "challenges") {
        const today = new Date().toISOString().slice(0, 10);
        const { data: completed } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "challenge_completion").eq("metadata->>date", today);
        const completedTypes = (completed ?? []).map((c) => (c.metadata as Record<string, unknown>).type as string);
        return new Response(JSON.stringify({
          success: true, date: today,
          challenges: CHALLENGE_TEMPLATES.map((c) => ({ ...c, completed: completedTypes.includes(c.type) })),
          completedCount: completedTypes.length, totalCount: CHALLENGE_TEMPLATES.length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "leaderboard") {
        const { data: profiles } = await adminClient.from("app_analytics").select("user_id, metadata")
          .eq("source", "gamification_profile").order("metadata->>total_xp", { ascending: false }).limit(20);
        return new Response(JSON.stringify({
          success: true,
          leaderboard: (profiles ?? []).map((p, i) => {
            const m = p.metadata as Record<string, unknown>;
            return { rank: i + 1, userId: p.user_id, totalXp: (m.total_xp as number) ?? 0, ...calculateLevel((m.total_xp as number) ?? 0), streakDays: (m.streak_days as number) ?? 0 };
          }),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, badges: BADGE_DEFINITIONS, challenges: CHALLENGE_TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "complete_challenge") {
        const { type } = body;
        if (!type) return new Response(JSON.stringify({ success: false, error: "type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const challenge = CHALLENGE_TEMPLATES.find((c) => c.type === type);
        if (!challenge) return new Response(JSON.stringify({ success: false, error: "Unknown challenge type" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const today = new Date().toISOString().slice(0, 10);
        // Check if already completed today
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "challenge_completion").eq("metadata->>date", today).eq("metadata->>type", type).maybeSingle();
        if (existing) return new Response(JSON.stringify({ success: false, error: "Already completed today" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });

        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "challenge_completion",
          metadata: { type, date: today, xp: challenge.xp },
          created_at: new Date().toISOString(),
        });

        // Update profile XP
        const { data: profile } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "gamification_profile").maybeSingle();
        const meta = (profile?.metadata as Record<string, unknown>) ?? { total_xp: 0, streak_days: 0, total_tasks: 0, badges: [], last_active: null };
        const newXp = ((meta.total_xp as number) ?? 0) + challenge.xp;
        const newTasks = ((meta.total_tasks as number) ?? 0) + 1;

        // Streak check
        const yesterday = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
        const lastActive = (meta.last_active as string) ?? "";
        let streak = (meta.streak_days as number) ?? 0;
        if (lastActive === yesterday) streak++;
        else if (lastActive !== today) streak = 1;

        // Badge check
        const badges = [...((meta.badges as string[]) ?? [])];
        const newBadges: string[] = [];
        if (newTasks >= 1 && !badges.includes("first_step")) { badges.push("first_step"); newBadges.push("first_step"); }
        if (streak >= 3 && !badges.includes("streak_3")) { badges.push("streak_3"); newBadges.push("streak_3"); }
        if (streak >= 7 && !badges.includes("streak_7")) { badges.push("streak_7"); newBadges.push("streak_7"); }
        if (streak >= 30 && !badges.includes("streak_30")) { badges.push("streak_30"); newBadges.push("streak_30"); }
        if (streak >= 100 && !badges.includes("streak_100")) { badges.push("streak_100"); newBadges.push("streak_100"); }
        if (newTasks >= 10 && !badges.includes("tasks_10")) { badges.push("tasks_10"); newBadges.push("tasks_10"); }
        if (newTasks >= 50 && !badges.includes("tasks_50")) { badges.push("tasks_50"); newBadges.push("tasks_50"); }
        if (newTasks >= 100 && !badges.includes("tasks_100")) { badges.push("tasks_100"); newBadges.push("tasks_100"); }

        // Add XP from new badges
        let bonusXp = 0;
        for (const b of newBadges) {
          const def = BADGE_DEFINITIONS.find((d) => d.id === b);
          if (def) bonusXp += def.xp;
        }

        const updatedMeta = { ...meta, total_xp: newXp + bonusXp, streak_days: streak, total_tasks: newTasks, badges, last_active: today };

        if (profile) {
          await adminClient.from("app_analytics").update({ metadata: updatedMeta })
            .eq("user_id", user.id).eq("source", "gamification_profile");
        } else {
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "gamification_profile",
            metadata: updatedMeta, created_at: new Date().toISOString(),
          });
        }

        return new Response(JSON.stringify({
          success: true, xpEarned: challenge.xp + bonusXp, totalXp: newXp + bonusXp,
          ...calculateLevel(newXp + bonusXp), streak, newBadges,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
