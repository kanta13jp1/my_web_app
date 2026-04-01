// Data Visualization & Charts Edge Function
// データ可視化・チャート生成 (Google Sheets/Notion競合)
// - チャートデータ保存
// - チャートタイプ管理
// - ダッシュボード構成
// - データソース連携
// - エクスポート

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CHART_TYPES = ["bar", "line", "pie", "doughnut", "area", "scatter", "radar", "heatmap", "treemap", "funnel"];
const DATA_SOURCES = ["manual", "app_analytics", "edge_function", "csv_import", "api"];
const COLOR_PALETTES = {
  default: ["#4CAF50", "#2196F3", "#FF9800", "#F44336", "#9C27B0", "#00BCD4", "#795548", "#607D8B"],
  pastel: ["#B2DFDB", "#BBDEFB", "#FFE0B2", "#FFCDD2", "#E1BEE7", "#B2EBF2", "#D7CCC8", "#CFD8DC"],
  vivid: ["#00E676", "#2979FF", "#FF9100", "#FF1744", "#D500F9", "#00E5FF", "#6D4C41", "#455A64"],
};

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
      const chartId = url.searchParams.get("chart_id");
      const dashboardId = url.searchParams.get("dashboard_id");

      if (view === "types") return new Response(JSON.stringify({ success: true, chartTypes: CHART_TYPES, dataSources: DATA_SOURCES, colorPalettes: COLOR_PALETTES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "chart" && chartId) {
        const { data: chart } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "chart_config").eq("metadata->>chart_id", chartId).maybeSingle();
        if (!chart) return new Response(JSON.stringify({ success: false, error: "Chart not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        return new Response(JSON.stringify({ success: true, chart: { ...(chart.metadata as Record<string, unknown>), createdAt: chart.created_at } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "dashboard" && dashboardId) {
        const { data: dashboard } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "chart_dashboard").eq("metadata->>dashboard_id", dashboardId).maybeSingle();
        if (!dashboard) return new Response(JSON.stringify({ success: false, error: "Dashboard not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const chartIds = ((dashboard.metadata as Record<string, unknown>).chart_ids as string[]) ?? [];
        const charts = [];
        for (const cId of chartIds) {
          const { data: c } = await adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "chart_config").eq("metadata->>chart_id", cId).maybeSingle();
          if (c) charts.push(c.metadata as Record<string, unknown>);
        }
        return new Response(JSON.stringify({ success: true, dashboard: { ...(dashboard.metadata as Record<string, unknown>), createdAt: dashboard.created_at }, charts }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "dashboards") {
        const { data: dashboards } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "chart_dashboard").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, dashboards: (dashboards ?? []).map((d) => ({ ...(d.metadata as Record<string, unknown>), createdAt: d.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: user's charts
      const { data: charts } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "chart_config").order("created_at", { ascending: false }).limit(30);
      return new Response(JSON.stringify({ success: true, charts: (charts ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_chart") {
        const { title, type, data_source, labels, datasets, options } = body;
        if (!title || !type) return new Response(JSON.stringify({ success: false, error: "title and type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const cId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "chart_config",
          metadata: {
            chart_id: cId, title, type, data_source: data_source ?? "manual",
            labels: labels ?? [], datasets: datasets ?? [],
            options: options ?? { responsive: true }, palette: "default",
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, chartId: cId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_dashboard") {
        const { name, chart_ids, layout } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const dId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "chart_dashboard",
          metadata: { dashboard_id: dId, name, chart_ids: chart_ids ?? [], layout: layout ?? "grid" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, dashboardId: dId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_chart_data") {
        const { chart_id, labels, datasets } = body;
        if (!chart_id) return new Response(JSON.stringify({ success: false, error: "chart_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "chart_config").eq("metadata->>chart_id", chart_id).maybeSingle();
        if (!existing) return new Response(JSON.stringify({ success: false, error: "Chart not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = existing.metadata as Record<string, unknown>;
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, labels: labels ?? meta.labels, datasets: datasets ?? meta.datasets },
        }).eq("user_id", user.id).eq("source", "chart_config").eq("metadata->>chart_id", chart_id);
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
