// CRM Sales Pipeline Edge Function
// CRM・営業パイプライン (Amazon/Google/Salesforce競合)
// - リード管理
// - 商談(Deal)ステージ管理
// - 活動ログ
// - AIリードスコアリング
// - 売上予測連携
//
// GET  → リード一覧 / パイプライン / 活動 / 統計
// POST → リード作成 / 商談作成 / ステージ更新 / 活動記録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const DEAL_STAGES = ["lead", "qualified", "proposal", "negotiation", "closed_won", "closed_lost"];
const ACTIVITY_TYPES = ["call", "email", "meeting", "note", "task", "demo"];
const LEAD_SOURCES = ["web", "referral", "advertisement", "social", "cold_call", "event", "partner", "other"];

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

      if (view === "options") {
        return new Response(JSON.stringify({ success: true, dealStages: DEAL_STAGES, activityTypes: ACTIVITY_TYPES, leadSources: LEAD_SOURCES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "pipeline") {
        const { data: deals } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "crm_deal");
        const pipeline: Record<string, { count: number; value: number }> = {};
        for (const s of DEAL_STAGES) pipeline[s] = { count: 0, value: 0 };
        for (const d of deals ?? []) {
          const meta = d.metadata as Record<string, unknown>;
          const stage = (meta.stage as string) ?? "lead";
          if (pipeline[stage]) {
            pipeline[stage].count++;
            pipeline[stage].value += (meta.value as number) ?? 0;
          }
        }
        const totalValue = Object.values(pipeline).reduce((s, p) => s + p.value, 0);
        return new Response(JSON.stringify({ success: true, pipeline, totalValue, totalDeals: (deals ?? []).length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "activities") {
        const dealId = url.searchParams.get("deal_id");
        let query = adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "crm_activity")
          .order("created_at", { ascending: false });
        if (dealId) query = query.eq("metadata->>deal_id", dealId);
        const { data: activities } = await query.limit(50);
        return new Response(JSON.stringify({
          success: true,
          activities: (activities ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: deals } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "crm_deal");
        let wonValue = 0, lostValue = 0, openValue = 0, wonCount = 0;
        for (const d of deals ?? []) {
          const meta = d.metadata as Record<string, unknown>;
          const value = (meta.value as number) ?? 0;
          if (meta.stage === "closed_won") { wonValue += value; wonCount++; }
          else if (meta.stage === "closed_lost") lostValue += value;
          else openValue += value;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: {
            totalDeals: (deals ?? []).length, wonCount,
            winRate: (deals ?? []).length > 0 ? Math.round(wonCount / (deals ?? []).length * 100) : 0,
            wonValue, lostValue, openValue,
            avgDealSize: wonCount > 0 ? Math.round(wonValue / wonCount) : 0,
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: leads/deals list
      const stage = url.searchParams.get("stage");
      let query = adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "crm_deal")
        .order("created_at", { ascending: false });
      if (stage) query = query.eq("metadata->>stage", stage);
      const { data: deals } = await query.limit(50);
      return new Response(JSON.stringify({
        success: true,
        deals: (deals ?? []).map((d) => ({ ...(d.metadata as Record<string, unknown>), createdAt: d.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_lead") {
        const { name, email, company, phone, source, notes } = body;
        if (!name) {
          return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const dealId = crypto.randomUUID();
        // AI lead scoring
        let score = 50;
        if (email) score += 10;
        if (company) score += 15;
        if (phone) score += 10;
        if (source === "referral") score += 15;

        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "crm_deal",
          metadata: {
            deal_id: dealId, name, email: email ?? null, company: company ?? null,
            phone: phone ?? null, lead_source: source ?? "web",
            stage: "lead", value: 0, score, notes: notes ?? null,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, dealId, score }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_stage") {
        const { deal_id, stage, value } = body;
        if (!deal_id || !stage) {
          return new Response(JSON.stringify({ success: false, error: "deal_id and stage required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        if (!DEAL_STAGES.includes(stage)) {
          return new Response(JSON.stringify({ success: false, error: "Invalid stage" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "crm_deal").eq("metadata->>deal_id", deal_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Deal not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const updates: Record<string, unknown> = { stage };
        if (value !== undefined) updates.value = value;
        await adminClient.from("app_analytics").update({ metadata: { ...meta, ...updates } })
          .eq("user_id", user.id).eq("source", "crm_deal").eq("metadata->>deal_id", deal_id);
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "log_activity") {
        const { deal_id, activity_type, description, duration_minutes } = body;
        if (!deal_id || !activity_type) {
          return new Response(JSON.stringify({ success: false, error: "deal_id and activity_type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const activityId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "crm_activity",
          metadata: { activity_id: activityId, deal_id, activity_type, description: description ?? null, duration_minutes: duration_minutes ?? 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, activityId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
