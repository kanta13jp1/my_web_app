// Custom Dashboard Builder Edge Function
// カスタムダッシュボードビルダー (Notion/Google Data Studio競合)
// - ウィジェット配置
// - データソース接続
// - レイアウト保存
// - テンプレート
// - 共有

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const WIDGET_TYPES = ["number", "chart", "table", "list", "progress", "calendar", "weather", "clock", "note", "image", "iframe"];
const WIDGET_SIZES = ["small", "medium", "large", "full"];
const DASHBOARD_TEMPLATES = [
  { id: "executive", name: "エグゼクティブ", description: "KPI概要ダッシュボード", widgets: [
    { type: "number", title: "総ユーザー数", source: "users", size: "small" },
    { type: "chart", title: "週間アクティブユーザー", source: "weekly_active", size: "medium" },
    { type: "progress", title: "目標進捗", source: "goals", size: "small" },
    { type: "list", title: "最新アクティビティ", source: "recent_activity", size: "large" },
  ]},
  { id: "developer", name: "開発者", description: "開発状況ダッシュボード", widgets: [
    { type: "number", title: "Edge Functions", source: "edge_functions", size: "small" },
    { type: "chart", title: "デプロイ履歴", source: "deploys", size: "medium" },
    { type: "table", title: "オープンIssues", source: "issues", size: "large" },
    { type: "progress", title: "スプリント進捗", source: "sprint", size: "small" },
  ]},
  { id: "marketing", name: "マーケティング", description: "マーケティングダッシュボード", widgets: [
    { type: "number", title: "PV数", source: "pageviews", size: "small" },
    { type: "chart", title: "トラフィック推移", source: "traffic", size: "large" },
    { type: "table", title: "リファラー", source: "referrers", size: "medium" },
    { type: "number", title: "コンバージョン率", source: "conversion", size: "small" },
  ]},
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
      const dashboardId = url.searchParams.get("dashboard_id");

      if (view === "types") return new Response(JSON.stringify({ success: true, widgetTypes: WIDGET_TYPES, widgetSizes: WIDGET_SIZES, templates: DASHBOARD_TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "dashboard" && dashboardId) {
        const { data: dashboard } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "custom_dashboard").eq("metadata->>dashboard_id", dashboardId).maybeSingle();
        if (!dashboard) return new Response(JSON.stringify({ success: false, error: "Dashboard not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        return new Response(JSON.stringify({ success: true, dashboard: { ...(dashboard.metadata as Record<string, unknown>), createdAt: dashboard.created_at } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: user's dashboards
      const { data: dashboards } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "custom_dashboard").order("created_at", { ascending: false });
      return new Response(JSON.stringify({ success: true, dashboards: (dashboards ?? []).map((d) => ({ ...(d.metadata as Record<string, unknown>), createdAt: d.created_at })), templates: DASHBOARD_TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create") {
        const { name, template_id, widgets, layout } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const dId = crypto.randomUUID();
        const templateWidgets = template_id ? DASHBOARD_TEMPLATES.find((t) => t.id === template_id)?.widgets : null;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "custom_dashboard",
          metadata: { dashboard_id: dId, name, widgets: widgets ?? templateWidgets ?? [], layout: layout ?? "grid", is_default: false, shared: false, template_id: template_id ?? null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, dashboardId: dId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_widgets") {
        const { dashboard_id, widgets } = body;
        if (!dashboard_id || !widgets) return new Response(JSON.stringify({ success: false, error: "dashboard_id and widgets required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "custom_dashboard").eq("metadata->>dashboard_id", dashboard_id).maybeSingle();
        if (!existing) return new Response(JSON.stringify({ success: false, error: "Dashboard not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), widgets } })
          .eq("user_id", user.id).eq("source", "custom_dashboard").eq("metadata->>dashboard_id", dashboard_id);
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "set_default") {
        const { dashboard_id } = body;
        if (!dashboard_id) return new Response(JSON.stringify({ success: false, error: "dashboard_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Clear other defaults
        const { data: all } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "custom_dashboard");
        for (const d of all ?? []) {
          const m = d.metadata as Record<string, unknown>;
          if (m.is_default) {
            await adminClient.from("app_analytics").update({ metadata: { ...m, is_default: false } })
              .eq("user_id", user.id).eq("source", "custom_dashboard").eq("metadata->>dashboard_id", m.dashboard_id as string);
          }
        }
        const { data: target } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "custom_dashboard").eq("metadata->>dashboard_id", dashboard_id).maybeSingle();
        if (target) {
          await adminClient.from("app_analytics").update({ metadata: { ...(target.metadata as Record<string, unknown>), is_default: true } })
            .eq("user_id", user.id).eq("source", "custom_dashboard").eq("metadata->>dashboard_id", dashboard_id);
        }
        return new Response(JSON.stringify({ success: true, isDefault: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
