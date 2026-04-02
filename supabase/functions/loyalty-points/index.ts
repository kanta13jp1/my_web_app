// Loyalty Points Edge Function
// ロイヤルティポイント (Amazon/LINE/楽天競合)
// - ポイント付与・消費
// - ポイント履歴
// - ランク制度
// - 特典交換
// - 有効期限管理

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const POINT_ACTIONS: Record<string, number> = {
  login: 5, note_create: 10, task_complete: 15, ai_chat: 5, referral: 100,
  feedback: 20, profile_complete: 50, streak_7day: 30, streak_30day: 100,
  first_purchase: 200, review_post: 25, share_content: 10,
};

const RANKS = [
  { id: "bronze", name: "ブロンズ", minPoints: 0, multiplier: 1.0, color: "#CD7F32" },
  { id: "silver", name: "シルバー", minPoints: 500, multiplier: 1.2, color: "#C0C0C0" },
  { id: "gold", name: "ゴールド", minPoints: 2000, multiplier: 1.5, color: "#FFD700" },
  { id: "platinum", name: "プラチナ", minPoints: 5000, multiplier: 2.0, color: "#E5E4E2" },
  { id: "diamond", name: "ダイヤモンド", minPoints: 15000, multiplier: 3.0, color: "#B9F2FF" },
];

const REWARDS = [
  { id: "premium_7days", name: "プレミアム7日間", cost: 300, description: "プレミアムプラン7日間無料" },
  { id: "premium_30days", name: "プレミアム30日間", cost: 1000, description: "プレミアムプラン30日間無料" },
  { id: "ai_boost_50", name: "AI回数+50", cost: 200, description: "AI質問回数50回追加" },
  { id: "storage_1gb", name: "ストレージ+1GB", cost: 500, description: "ストレージ容量1GB追加" },
  { id: "custom_theme", name: "カスタムテーマ", cost: 150, description: "限定カスタムテーマ解放" },
  { id: "badge_special", name: "特別バッジ", cost: 100, description: "プロフィール用特別バッジ" },
];

function getRank(totalPoints: number) {
  let current = RANKS[0];
  for (const r of RANKS) {
    if (totalPoints >= r.minPoints) current = r;
  }
  const nextRank = RANKS[RANKS.indexOf(current) + 1] ?? null;
  return { current, nextRank, pointsToNext: nextRank ? nextRank.minPoints - totalPoints : 0 };
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

      if (view === "balance") {
        const { data: txns } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "loyalty_points");
        let total = 0;
        let earned = 0;
        let spent = 0;
        for (const t of txns ?? []) {
          const m = t.metadata as Record<string, unknown>;
          const pts = (m.points as number) ?? 0;
          total += pts;
          if (pts > 0) earned += pts; else spent += Math.abs(pts);
        }
        const rank = getRank(earned);
        return new Response(JSON.stringify({ success: true, balance: total, totalEarned: earned, totalSpent: spent, rank: rank.current, nextRank: rank.nextRank, pointsToNext: rank.pointsToNext }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "history") {
        const { data: txns } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "loyalty_points").order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, history: (txns ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), createdAt: t.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "rewards") return new Response(JSON.stringify({ success: true, rewards: REWARDS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      if (view === "ranks") return new Response(JSON.stringify({ success: true, ranks: RANKS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      if (view === "actions") return new Response(JSON.stringify({ success: true, pointActions: POINT_ACTIONS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      return new Response(JSON.stringify({ success: true, pointActions: POINT_ACTIONS, rewards: REWARDS, ranks: RANKS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "earn") {
        const { action_type, description } = body;
        if (!action_type) return new Response(JSON.stringify({ success: false, error: "action_type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const basePoints = POINT_ACTIONS[action_type] ?? 0;
        if (basePoints === 0) return new Response(JSON.stringify({ success: false, error: "Unknown action_type" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Get rank multiplier
        const { data: txns } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "loyalty_points");
        let totalEarned = 0;
        for (const t of txns ?? []) { const pts = (t.metadata as Record<string, unknown>).points as number; if (pts > 0) totalEarned += pts; }
        const rank = getRank(totalEarned);
        const points = Math.round(basePoints * rank.current.multiplier);
        const txnId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "loyalty_points",
          metadata: { txn_id: txnId, type: "earn", action_type, points, base_points: basePoints, multiplier: rank.current.multiplier, rank: rank.current.id, description: description ?? action_type },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, txnId, points, rank: rank.current.id }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "redeem") {
        const { reward_id } = body;
        if (!reward_id) return new Response(JSON.stringify({ success: false, error: "reward_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const reward = REWARDS.find((r) => r.id === reward_id);
        if (!reward) return new Response(JSON.stringify({ success: false, error: "Unknown reward" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Check balance
        const { data: txns } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "loyalty_points");
        let balance = 0;
        for (const t of txns ?? []) balance += ((t.metadata as Record<string, unknown>).points as number) ?? 0;
        if (balance < reward.cost) return new Response(JSON.stringify({ success: false, error: "ポイント不足", balance, required: reward.cost }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const txnId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "loyalty_points",
          metadata: { txn_id: txnId, type: "redeem", reward_id, reward_name: reward.name, points: -reward.cost, description: `特典交換: ${reward.name}` },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, txnId, redeemed: reward.name, pointsUsed: reward.cost, newBalance: balance - reward.cost }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "leaderboard") {
        const { data: all } = await adminClient.from("app_analytics").select("user_id, metadata").eq("source", "loyalty_points");
        const userTotals: Record<string, number> = {};
        for (const t of all ?? []) {
          const pts = ((t.metadata as Record<string, unknown>).points as number) ?? 0;
          if (pts > 0) userTotals[t.user_id] = (userTotals[t.user_id] ?? 0) + pts;
        }
        const leaderboard = Object.entries(userTotals).map(([uid, pts]) => ({ userId: uid, totalEarned: pts, rank: getRank(pts).current })).sort((a, b) => b.totalEarned - a.totalEarned).slice(0, 20);
        return new Response(JSON.stringify({ success: true, leaderboard }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
