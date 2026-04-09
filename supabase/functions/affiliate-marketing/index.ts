// Affiliate Marketing Edge Function
// アフィリエイトマーケティング (Amazon Associates/A8.net/楽天アフィリエイト競合)
// - アフィリエイトリンク管理
// - クリック・コンバージョン追跡
// - 報酬計算
// - パフォーマンスレポート
// - パートナー管理

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const COMMISSION_TYPES = ["percentage", "fixed", "tiered"];
const LINK_STATUSES = ["active", "paused", "expired", "revoked"];
const PAYOUT_STATUSES = ["pending", "approved", "paid", "rejected"];

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

      if (view === "config") return new Response(JSON.stringify({ success: true, commissionTypes: COMMISSION_TYPES, linkStatuses: LINK_STATUSES, payoutStatuses: PAYOUT_STATUSES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "links") {
        const { data: links } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "affiliate_link").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, links: (links ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), createdAt: l.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "performance") {
        const days = parseInt(url.searchParams.get("days") ?? "30");
        const since = new Date(Date.now() - days * 86400000).toISOString();
        // クリック数・コンバージョン数を並列取得
        const [{ data: clicks }, { data: conversions }] = await Promise.all([
          adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "affiliate_click").gte("created_at", since),
          adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "affiliate_conversion").gte("created_at", since),
        ]);
        let totalRevenue = 0;
        let totalCommission = 0;
        for (const c of conversions ?? []) {
          const m = c.metadata as Record<string, unknown>;
          totalRevenue += (m.revenue as number) ?? 0;
          totalCommission += (m.commission as number) ?? 0;
        }
        const conversionRate = (clicks ?? []).length > 0 ? Math.round(((conversions ?? []).length / (clicks ?? []).length) * 10000) / 100 : 0;
        return new Response(JSON.stringify({
          success: true, performance: { period: days, totalClicks: (clicks ?? []).length, totalConversions: (conversions ?? []).length, conversionRate, totalRevenue, totalCommission },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "payouts") {
        const { data: payouts } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "affiliate_payout").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, payouts: (payouts ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, commissionTypes: COMMISSION_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_link") {
        const { product_name, target_url, commission_type, commission_rate } = body;
        if (!product_name || !target_url) return new Response(JSON.stringify({ success: false, error: "product_name and target_url required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const linkId = crypto.randomUUID();
        const trackingCode = `JK-${linkId.slice(0, 8)}`;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "affiliate_link",
          metadata: { link_id: linkId, product_name, target_url, tracking_code: trackingCode, commission_type: commission_type ?? "percentage", commission_rate: commission_rate ?? 5, status: "active", total_clicks: 0, total_conversions: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, linkId, trackingCode }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "track_click") {
        const { link_id, referrer, user_agent } = body;
        if (!link_id) return new Response(JSON.stringify({ success: false, error: "link_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "affiliate_click",
          metadata: { link_id, referrer: referrer ?? "", user_agent: user_agent ?? "", clicked_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_conversion") {
        const { link_id, revenue, order_id } = body;
        if (!link_id || !revenue) return new Response(JSON.stringify({ success: false, error: "link_id and revenue required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: link } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "affiliate_link").eq("metadata->>link_id", link_id).maybeSingle();
        const rate = link ? ((link.metadata as Record<string, unknown>).commission_rate as number) ?? 5 : 5;
        const commission = Math.round(revenue * rate) / 100;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "affiliate_conversion",
          metadata: { link_id, revenue, commission, order_id: order_id ?? null, converted_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, commission }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
