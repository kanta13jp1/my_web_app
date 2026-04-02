// Referral Program Edge Function
// 紹介プログラム (成長戦略・ユーザー獲得)
// - 紹介コード生成
// - 紹介追跡
// - 報酬管理
// - リーダーボード
// - 紹介統計

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const REWARD_TYPES = ["premium_days", "storage_bonus", "feature_unlock", "credit"];
const REFERRAL_STATUSES = ["pending", "signed_up", "activated", "rewarded"];

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    const url = new URL(req.url);
    const view = url.searchParams.get("view");

    // Flutter の functions.invoke() はデフォルトで POST を送るが、
    // query params (view) 付きの場合は GET と同じ一覧取得として処理する
    if (req.method === "GET" || (req.method === "POST" && view !== null)) {

      if (view === "my_code") {
        const { data: code } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "referral_code").maybeSingle();
        if (!code) {
          // Auto-generate referral code
          const refCode = `JK-${user.id.substring(0, 6).toUpperCase()}`;
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "referral_code",
            metadata: { code: refCode, referral_url: `https://my-web-app-b67f4.web.app/?ref=${refCode}`, total_referrals: 0, total_rewards: 0 },
            created_at: new Date().toISOString(),
          });
          return new Response(JSON.stringify({ success: true, code: refCode, referralUrl: `https://my-web-app-b67f4.web.app/?ref=${refCode}`, totalReferrals: 0 }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const m = code.metadata as Record<string, unknown>;
        return new Response(JSON.stringify({ success: true, code: m.code, referralUrl: m.referral_url, totalReferrals: m.total_referrals ?? 0, totalRewards: m.total_rewards ?? 0 }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "referrals") {
        const { data: referrals } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "referral_record").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, referrals: (referrals ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "rewards") {
        const { data: rewards } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "referral_reward").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, rewards: (rewards ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "leaderboard") {
        const { data: codes } = await adminClient.from("app_analytics").select("user_id, metadata")
          .eq("source", "referral_code").order("metadata->>total_referrals", { ascending: false }).limit(20);
        return new Response(JSON.stringify({
          success: true,
          leaderboard: (codes ?? []).map((c, i) => ({ rank: i + 1, userId: c.user_id, totalReferrals: ((c.metadata as Record<string, unknown>).total_referrals as number) ?? 0 })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, rewardTypes: REWARD_TYPES, statuses: REFERRAL_STATUSES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST" && view === null) {
      let body: Record<string, unknown> = {};
      try {
        body = await req.json().catch(() => ({}));
      } catch {
        return new Response(JSON.stringify({ success: false, error: "Invalid or empty JSON body" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { action } = body;

      if (action === "track_referral") {
        const { referral_code, referred_email } = body;
        if (!referral_code) return new Response(JSON.stringify({ success: false, error: "referral_code required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: codeRecord } = await adminClient.from("app_analytics").select("user_id, metadata")
          .eq("source", "referral_code").eq("metadata->>code", referral_code).maybeSingle();
        if (!codeRecord) return new Response(JSON.stringify({ success: false, error: "Invalid referral code" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const refId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: codeRecord.user_id, source: "referral_record",
          metadata: { referral_id: refId, referred_email: referred_email ?? "", referral_code, status: "signed_up", referred_user_id: user.id },
          created_at: new Date().toISOString(),
        });
        // Update count
        const meta = codeRecord.metadata as Record<string, unknown>;
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, total_referrals: ((meta.total_referrals as number) ?? 0) + 1 },
        }).eq("user_id", codeRecord.user_id).eq("source", "referral_code");
        // Grant reward
        const rewardId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: codeRecord.user_id, source: "referral_reward",
          metadata: { reward_id: rewardId, type: "premium_days", amount: 7, referral_id: refId, description: "紹介報酬: プレミアム7日間" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, referralId: refId, rewardGranted: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
