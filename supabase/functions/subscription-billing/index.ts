// Subscription Billing Edge Function
// サブスクリプション課金管理 (Amazon/Slack/Microsoft競合)
// - プラン管理
// - 課金履歴
// - 請求書生成
// - クーポン
// - 使用量制限

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const PLANS = [
  { id: "free", name: "Free", price: 0, currency: "JPY", interval: "month", features: ["メモ100件", "AI質問5回/日", "基本機能"], limits: { notes: 100, ai_queries: 5, storage_mb: 100 } },
  { id: "starter", name: "Starter", price: 980, currency: "JPY", interval: "month", features: ["メモ無制限", "AI質問50回/日", "全機能", "優先サポート"], limits: { notes: -1, ai_queries: 50, storage_mb: 5000 } },
  { id: "pro", name: "Pro", price: 2980, currency: "JPY", interval: "month", features: ["メモ無制限", "AI質問無制限", "全機能", "API アクセス", "チーム共有"], limits: { notes: -1, ai_queries: -1, storage_mb: 50000 } },
  { id: "enterprise", name: "Enterprise", price: 9800, currency: "JPY", interval: "month", features: ["全機能", "専用サポート", "SLA保証", "カスタム連携", "監査ログ"], limits: { notes: -1, ai_queries: -1, storage_mb: -1 } },
];

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

      if (view === "plans") return new Response(JSON.stringify({ success: true, plans: PLANS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "current") {
        const { data: sub } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "user_subscription").maybeSingle();
        if (!sub) return new Response(JSON.stringify({ success: true, plan: PLANS[0], subscription: null }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = sub.metadata as Record<string, unknown>;
        const plan = PLANS.find((p) => p.id === m.plan_id) ?? PLANS[0];
        return new Response(JSON.stringify({ success: true, plan, subscription: m }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "invoices") {
        const { data: invoices } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "billing_invoice").order("created_at", { ascending: false }).limit(12);
        return new Response(JSON.stringify({ success: true, invoices: (invoices ?? []).map((i) => ({ ...(i.metadata as Record<string, unknown>), createdAt: i.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "usage") {
        const { count: noteCount } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true }).eq("user_id", user.id).eq("source", "note");
        const { data: sub } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "user_subscription").maybeSingle();
        const planId = sub ? ((sub.metadata as Record<string, unknown>).plan_id as string) : "free";
        const plan = PLANS.find((p) => p.id === planId) ?? PLANS[0];
        return new Response(JSON.stringify({
          success: true, usage: { notes: noteCount ?? 0, notesLimit: plan.limits.notes, storageUsedMb: 0, storageLimitMb: plan.limits.storage_mb },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, plans: PLANS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "subscribe") {
        const { plan_id } = body;
        const plan = PLANS.find((p) => p.id === plan_id);
        if (!plan) return new Response(JSON.stringify({ success: false, error: "Invalid plan" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete().eq("user_id", user.id).eq("source", "user_subscription");
        const subId = crypto.randomUUID();
        const now = new Date();
        const expiresAt = new Date(now.getTime() + 30 * 86400000);
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "user_subscription",
          metadata: { subscription_id: subId, plan_id, status: "active", started_at: now.toISOString(), expires_at: expiresAt.toISOString(), auto_renew: true },
          created_at: now.toISOString(),
        });
        // Create invoice
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "billing_invoice",
          metadata: { invoice_id: crypto.randomUUID(), plan_id, amount: plan.price, currency: plan.currency, status: "paid", paid_at: now.toISOString() },
          created_at: now.toISOString(),
        });
        return new Response(JSON.stringify({ success: true, subscriptionId: subId, plan: plan.name, expiresAt: expiresAt.toISOString() }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "apply_coupon") {
        const { coupon_code } = body;
        if (!coupon_code) return new Response(JSON.stringify({ success: false, error: "coupon_code required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: coupon } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "billing_coupon").eq("metadata->>code", coupon_code).maybeSingle();
        if (!coupon) return new Response(JSON.stringify({ success: false, error: "Invalid coupon" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const cm = coupon.metadata as Record<string, unknown>;
        return new Response(JSON.stringify({ success: true, discount: cm.discount_percent ?? 0, description: cm.description ?? "" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
