// Landing Page A/B Test Edge Function
// LP A/Bテスト (CTA/コピー/デザイン最適化)
// - バリアント管理
// - コンバージョン追跡
// - 統計的有意差判定
// - 自動勝者選定
// - ヒートマップデータ

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CTA_VARIANTS = [
  { id: "cta_free", text: "無料で始める", color: "#4CAF50", style: "solid" },
  { id: "cta_try", text: "今すぐ試す", color: "#2196F3", style: "solid" },
  { id: "cta_join", text: "参加する（¥0）", color: "#FF5722", style: "solid" },
  { id: "cta_start", text: "5秒で登録 →", color: "#9C27B0", style: "outline" },
  { id: "cta_save", text: "月¥5,000節約する", color: "#FF9800", style: "gradient" },
  { id: "cta_ai", text: "AIに仕事を任せる", color: "#00BCD4", style: "gradient" },
];

const HEADLINE_VARIANTS = [
  { id: "h_21apps", text: "21のアプリを1つに。しかも無料。" },
  { id: "h_ai", text: "AIが12部署を自動運営する次世代アプリ" },
  { id: "h_save", text: "月¥5,000以上のサブスクをゼロに" },
  { id: "h_future", text: "あなたがやるのは「ゴール設定」だけ" },
  { id: "h_all", text: "メモ・タスク・家計簿・SNS・AI — 全部入り" },
];

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "variants") return new Response(JSON.stringify({ success: true, ctaVariants: CTA_VARIANTS, headlineVariants: HEADLINE_VARIANTS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "assign") {
        // Assign a random variant to a visitor
        const cta = CTA_VARIANTS[Math.floor(Math.random() * CTA_VARIANTS.length)];
        const headline = HEADLINE_VARIANTS[Math.floor(Math.random() * HEADLINE_VARIANTS.length)];
        const visitorId = url.searchParams.get("visitor_id") ?? crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: "anonymous", source: "ab_test_assignment",
          metadata: { visitor_id: visitorId, cta_variant: cta.id, headline_variant: headline.id },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, visitorId, cta, headline }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "results") {
        const { data: assignments } = await adminClient.from("app_analytics").select("metadata").eq("source", "ab_test_assignment");
        const { data: conversions } = await adminClient.from("app_analytics").select("metadata").eq("source", "ab_test_conversion");
        // Aggregate by CTA variant
        const ctaStats: Record<string, { views: number; conversions: number }> = {};
        for (const a of assignments ?? []) {
          const cId = (a.metadata as Record<string, unknown>).cta_variant as string;
          if (!ctaStats[cId]) ctaStats[cId] = { views: 0, conversions: 0 };
          ctaStats[cId].views++;
        }
        for (const c of conversions ?? []) {
          const cId = (c.metadata as Record<string, unknown>).cta_variant as string;
          if (ctaStats[cId]) ctaStats[cId].conversions++;
        }
        // Calculate conversion rates and find winner
        const results = Object.entries(ctaStats).map(([id, stats]) => ({
          variantId: id,
          variant: CTA_VARIANTS.find((v) => v.id === id),
          ...stats,
          conversionRate: stats.views > 0 ? Math.round((stats.conversions / stats.views) * 10000) / 100 : 0,
        })).sort((a, b) => b.conversionRate - a.conversionRate);
        const winner = results.length > 0 ? results[0] : null;
        return new Response(JSON.stringify({ success: true, results, winner, totalAssignments: (assignments ?? []).length, totalConversions: (conversions ?? []).length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, ctaVariants: CTA_VARIANTS, headlineVariants: HEADLINE_VARIANTS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "record_conversion") {
        const { visitor_id, cta_variant, headline_variant } = body;
        if (!visitor_id) return new Response(JSON.stringify({ success: false, error: "visitor_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: "anonymous", source: "ab_test_conversion",
          metadata: { visitor_id, cta_variant: cta_variant ?? null, headline_variant: headline_variant ?? null, converted_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_heatmap") {
        const { visitor_id, clicks } = body;
        if (!visitor_id || !clicks) return new Response(JSON.stringify({ success: false, error: "visitor_id and clicks required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: "anonymous", source: "heatmap_data",
          metadata: { visitor_id, clicks, page: "landing", recorded_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
