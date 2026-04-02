// Donation & Crowdfunding Edge Function
// 寄付・クラウドファンディング管理 (GoFundMe/Kickstarter/CAMPFIRE競合)
// - キャンペーン作成・管理
// - 寄付/支援記録
// - リワード管理
// - 目標進捗
// - 支援者統計
//
// GET  → キャンペーン一覧 / 支援者 / リワード / 統計
// POST → キャンペーン作成 / 支援 / リワード追加 / ステータス変更

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CAMPAIGN_CATEGORIES = ["technology", "creative", "community", "education", "health", "environment", "charity", "other"];
const CAMPAIGN_STATUSES = ["draft", "active", "funded", "closed", "cancelled"];

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
      const campaignId = url.searchParams.get("campaign_id");

      if (view === "options") {
        return new Response(JSON.stringify({ success: true, categories: CAMPAIGN_CATEGORIES, statuses: CAMPAIGN_STATUSES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "backers" && campaignId) {
        const { data: backers } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "crowd_backing").eq("metadata->>campaign_id", campaignId)
          .order("created_at", { ascending: false });
        let totalRaised = 0;
        for (const b of backers ?? []) totalRaised += ((b.metadata as Record<string, unknown>).amount as number) ?? 0;
        return new Response(JSON.stringify({
          success: true, totalRaised, backerCount: (backers ?? []).length,
          backers: (backers ?? []).map((b) => ({ ...(b.metadata as Record<string, unknown>), backedAt: b.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "rewards" && campaignId) {
        const { data: rewards } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "crowd_reward").eq("metadata->>campaign_id", campaignId)
          .order("metadata->>min_amount", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          rewards: (rewards ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: campaigns } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "crowd_campaign");
        const { data: backings } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "crowd_backing");
        let totalRaised = 0, funded = 0;
        for (const b of backings ?? []) totalRaised += ((b.metadata as Record<string, unknown>).amount as number) ?? 0;
        for (const c of campaigns ?? []) {
          if ((c.metadata as Record<string, unknown>).status === "funded") funded++;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { totalCampaigns: (campaigns ?? []).length, fundedCampaigns: funded, totalRaised, totalBackers: (backings ?? []).length },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: campaign list
      const status = url.searchParams.get("status");
      let query = adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "crowd_campaign")
        .order("created_at", { ascending: false });
      if (status) query = query.eq("metadata->>status", status);
      const { data: campaigns } = await query.limit(30);
      return new Response(JSON.stringify({
        success: true,
        campaigns: (campaigns ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_campaign") {
        const { title, description, category, goal_amount, deadline, image_url } = body;
        if (!title || !goal_amount) {
          return new Response(JSON.stringify({ success: false, error: "title and goal_amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const campaignId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "crowd_campaign",
          metadata: { campaign_id: campaignId, title, description: description ?? null, category: category ?? "other", goal_amount, current_amount: 0, deadline: deadline ?? null, image_url: image_url ?? null, status: "draft", backer_count: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, campaignId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "back_campaign") {
        const { campaign_id, amount, reward_id, backer_name, message } = body;
        if (!campaign_id || !amount) {
          return new Response(JSON.stringify({ success: false, error: "campaign_id and amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const backingId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "crowd_backing",
          metadata: { backing_id: backingId, campaign_id, amount, reward_id: reward_id ?? null, backer_name: backer_name ?? user.email, message: message ?? null },
          created_at: new Date().toISOString(),
        });
        // Update campaign total
        const { data: campaign } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "crowd_campaign").eq("metadata->>campaign_id", campaign_id).maybeSingle();
        if (campaign) {
          const meta = campaign.metadata as Record<string, unknown>;
          const newAmount = ((meta.current_amount as number) ?? 0) + amount;
          const newCount = ((meta.backer_count as number) ?? 0) + 1;
          const goalReached = newAmount >= ((meta.goal_amount as number) ?? Infinity);
          await adminClient.from("app_analytics").update({
            metadata: { ...meta, current_amount: newAmount, backer_count: newCount, status: goalReached ? "funded" : meta.status },
          }).eq("source", "crowd_campaign").eq("metadata->>campaign_id", campaign_id);
        }
        return new Response(JSON.stringify({ success: true, backingId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_reward") {
        const { campaign_id, title, description, min_amount, max_quantity } = body;
        if (!campaign_id || !title || !min_amount) {
          return new Response(JSON.stringify({ success: false, error: "campaign_id, title, min_amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const rewardId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "crowd_reward",
          metadata: { reward_id: rewardId, campaign_id, title, description: description ?? null, min_amount, max_quantity: max_quantity ?? null, claimed: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, rewardId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_status") {
        const { campaign_id, status } = body;
        if (!campaign_id || !status) {
          return new Response(JSON.stringify({ success: false, error: "campaign_id and status required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "crowd_campaign").eq("metadata->>campaign_id", campaign_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Campaign not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), status } })
          .eq("user_id", user.id).eq("source", "crowd_campaign").eq("metadata->>campaign_id", campaign_id);
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
