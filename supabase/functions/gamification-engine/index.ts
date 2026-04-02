// Gamification Engine Edge Function
// ゲーミフィケーション — ストリーク・バッジ・ポイント・リーダーボード
// - デイリーログインストリーク
// - バッジ解除 (アクション達成時)
// - ポイント付与・ランキング
//
// GET  → ストリーク / バッジ / ポイント / リーダーボード
// POST → ストリーク記録 / バッジ付与 / ポイント加算

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

// バッジ定義
const BADGES = [
  { key: "first_note", label: "初めてのノート", description: "ノートを1つ作成", icon: "📝", points: 10 },
  { key: "note_10", label: "ノートライター", description: "ノートを10個作成", icon: "✍️", points: 50 },
  { key: "note_100", label: "プロライター", description: "ノートを100個作成", icon: "📚", points: 200 },
  { key: "streak_7", label: "7日連続", description: "7日連続ログイン", icon: "🔥", points: 100 },
  { key: "streak_30", label: "30日連続", description: "30日連続ログイン", icon: "💎", points: 500 },
  { key: "streak_100", label: "100日連続", description: "100日連続ログイン", icon: "🏆", points: 2000 },
  { key: "first_share", label: "初シェア", description: "メモを初めて公開共有", icon: "🔗", points: 30 },
  { key: "ai_explorer", label: "AI探検家", description: "AIアシスタントを10回利用", icon: "🤖", points: 50 },
  { key: "feature_voter", label: "機能投票者", description: "機能リクエストに投票", icon: "🗳️", points: 20 },
  { key: "profile_complete", label: "プロフィール完成", description: "プロフィールを100%完成", icon: "👤", points: 30 },
  { key: "early_adopter", label: "アーリーアダプター", description: "最初の100人の登録者", icon: "🌟", points: 500 },
  { key: "referral_1", label: "紹介者", description: "1人を紹介", icon: "🤝", points: 100 },
  { key: "referral_5", label: "インフルエンサー", description: "5人を紹介", icon: "📣", points: 500 },
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'streak' | 'badges' | 'points' | 'leaderboard' | 'badge_list'

      if (view === "badge_list") {
        return new Response(
          JSON.stringify({ success: true, badges: BADGES }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "leaderboard") {
        // ポイントランキング (上位20名)
        const { data: topUsers } = await adminClient
          .from("user_profiles")
          .select("user_id, display_name, avatar_url, metadata")
          .order("metadata->gamification_points", { ascending: false })
          .limit(20);

        const leaderboard = (topUsers ?? []).map((u, i) => ({
          rank: i + 1,
          userId: u.user_id,
          displayName: u.display_name ?? "匿名ユーザー",
          avatarUrl: u.avatar_url,
          points: ((u.metadata as Record<string, unknown>)?.gamification_points as number) ?? 0,
        }));

        return new Response(
          JSON.stringify({ success: true, leaderboard }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // 認証必須のビュー
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

      const { data: profile } = await adminClient
        .from("user_profiles")
        .select("metadata")
        .eq("user_id", user.id)
        .maybeSingle();

      const meta = (profile?.metadata as Record<string, unknown>) ?? {};

      if (view === "streak") {
        return new Response(
          JSON.stringify({
            success: true,
            streak: {
              currentStreak: (meta.current_streak as number) ?? 0,
              longestStreak: (meta.longest_streak as number) ?? 0,
              lastLoginDate: (meta.last_login_date as string) ?? null,
            },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "badges") {
        const earnedBadges = (meta.badges as string[]) ?? [];
        const badges = BADGES.map((b) => ({
          ...b,
          earned: earnedBadges.includes(b.key),
        }));

        return new Response(
          JSON.stringify({
            success: true,
            badges,
            earnedCount: earnedBadges.length,
            totalCount: BADGES.length,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: 総合スコア
      const earnedBadges = (meta.badges as string[]) ?? [];
      return new Response(
        JSON.stringify({
          success: true,
          points: (meta.gamification_points as number) ?? 0,
          streak: (meta.current_streak as number) ?? 0,
          badgesEarned: earnedBadges.length,
          badgesTotal: BADGES.length,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

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

      const { data: profile } = await adminClient
        .from("user_profiles")
        .select("metadata")
        .eq("user_id", user.id)
        .maybeSingle();

      const meta = (profile?.metadata as Record<string, unknown>) ?? {};

      if (action === "check_in") {
        // デイリーチェックイン (ストリーク更新)
        const today = new Date().toISOString().slice(0, 10);
        const lastLogin = (meta.last_login_date as string) ?? "";
        const currentStreak = (meta.current_streak as number) ?? 0;
        const longestStreak = (meta.longest_streak as number) ?? 0;

        if (lastLogin === today) {
          return new Response(
            JSON.stringify({ success: true, alreadyCheckedIn: true, streak: currentStreak }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const yesterday = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
        const newStreak = lastLogin === yesterday ? currentStreak + 1 : 1;
        const newLongest = Math.max(longestStreak, newStreak);
        const pointsEarned = 5 + Math.min(newStreak, 30); // 6〜35ポイント

        // バッジチェック
        const badges = [...((meta.badges as string[]) ?? [])];
        const newBadges: string[] = [];
        if (newStreak >= 7 && !badges.includes("streak_7")) { badges.push("streak_7"); newBadges.push("streak_7"); }
        if (newStreak >= 30 && !badges.includes("streak_30")) { badges.push("streak_30"); newBadges.push("streak_30"); }
        if (newStreak >= 100 && !badges.includes("streak_100")) { badges.push("streak_100"); newBadges.push("streak_100"); }

        const badgePoints = newBadges.reduce((sum, key) => {
          const badge = BADGES.find((b) => b.key === key);
          return sum + (badge?.points ?? 0);
        }, 0);

        const totalPoints = ((meta.gamification_points as number) ?? 0) + pointsEarned + badgePoints;

        await adminClient
          .from("user_profiles")
          .update({
            metadata: {
              ...meta,
              current_streak: newStreak,
              longest_streak: newLongest,
              last_login_date: today,
              gamification_points: totalPoints,
              badges,
            },
          })
          .eq("user_id", user.id);

        return new Response(
          JSON.stringify({
            success: true,
            streak: newStreak,
            longestStreak: newLongest,
            pointsEarned: pointsEarned + badgePoints,
            totalPoints,
            newBadges: newBadges.map((k) => BADGES.find((b) => b.key === k)),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "award_badge") {
        const { badge_key } = body;
        if (!badge_key || !BADGES.find((b) => b.key === badge_key)) {
          return new Response(
            JSON.stringify({ success: false, error: "Invalid badge_key" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const badges = [...((meta.badges as string[]) ?? [])];
        if (badges.includes(badge_key)) {
          return new Response(
            JSON.stringify({ success: true, alreadyEarned: true }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        badges.push(badge_key);
        const badge = BADGES.find((b) => b.key === badge_key)!;
        const totalPoints = ((meta.gamification_points as number) ?? 0) + badge.points;

        await adminClient
          .from("user_profiles")
          .update({
            metadata: { ...meta, badges, gamification_points: totalPoints },
          })
          .eq("user_id", user.id);

        return new Response(
          JSON.stringify({ success: true, badge, pointsEarned: badge.points, totalPoints }),
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
    console.error("gamification-engine error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
