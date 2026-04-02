// Edge Function UI Checker Edge Function
// Edge Function UI連携チェッカー (Schedule自動化用)
// - 全Edge Functionのリストと UI 連携状態を確認
// - UI未連携のFunctionを検出
// - 必要なUI実装タスクを自動生成
//
// GET  → 全Function一覧 / UI未連携一覧 / 実装タスク

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// Functions that don't need direct UI (internal/schedule/admin)
const INTERNAL_FUNCTIONS = new Set([
  "schedule-daily-digest", "schedule-health-check", "schedule-task-monitor",
  "health-check", "check-competitor-updates", "send-waitlist-notification",
  "reply-support-request", "get-support-tickets", "get-admin-users",
  "post-x-update", "edge-function-coverage", "development-stats",
  "app-analytics-dashboard", "competitor-feature-sync", "growth-command-center",
  "growth-acquisition-report", "growth-acquisition-signal", "growth-import-commit",
  "growth-import-preview", "growth-share-signal", "growth-referral",
  "growth-weekly-digest", "growth-achievement-summary", "schedule-result-tracker",
  "blog-auto-publisher", "edge-function-ui-checker", "code-review-issues",
  "trigger-analysis", "seo-optimizer", "notify-feature-request",
  "api-rate-limiter", "content-moderation",
]);

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    if (req.method !== "GET") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const url = new URL(req.url);
    const view = url.searchParams.get("view");

    // Get all tracked functions from edge-function-coverage registry
    // by querying the function itself (if available)
    const { data: trackedStatus } = await adminClient.from("app_analytics").select("metadata")
      .eq("source", "edge_function_status").order("created_at", { ascending: false }).limit(200);

    const trackedMap = new Map<string, Record<string, unknown>>();
    for (const s of trackedStatus ?? []) {
      const meta = s.metadata as Record<string, unknown>;
      const name = meta.function_name as string;
      if (name && !trackedMap.has(name)) {
        trackedMap.set(name, meta);
      }
    }

    if (view === "missing_ui") {
      // Functions that have no UI but should
      const missing = [];
      for (const [name, meta] of trackedMap) {
        if (INTERNAL_FUNCTIONS.has(name)) continue;
        if (!(meta.has_ui_call as boolean)) {
          missing.push({
            function_name: name,
            description: meta.description,
            suggested_path: meta.suggested_path ?? `/${name.replace(/-/g, "_")}`,
          });
        }
      }
      return new Response(JSON.stringify({
        success: true,
        missingUi: missing,
        count: missing.length,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (view === "tasks") {
      // Generate implementation tasks for missing UI
      const tasks = [];
      for (const [name, meta] of trackedMap) {
        if (INTERNAL_FUNCTIONS.has(name)) continue;
        if (!(meta.has_ui_call as boolean)) {
          tasks.push({
            title: `UI実装: ${name}`,
            description: `Edge Function '${name}' (${meta.description ?? ""}) のフロントエンドUI実装が必要です。\n推奨パス: ${meta.suggested_path ?? `/${name}`}`,
            priority: "medium",
            type: "ui_implementation",
          });
        }
      }
      return new Response(JSON.stringify({
        success: true,
        tasks,
        totalTasks: tasks.length,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Default: full status
    const allFunctions = [...trackedMap.entries()].map(([name, meta]) => ({
      name,
      description: meta.description,
      has_ui: meta.has_ui_call ?? false,
      ui_path: meta.ui_path ?? null,
      is_internal: INTERNAL_FUNCTIONS.has(name),
    }));

    const withUi = allFunctions.filter((f) => f.has_ui || f.is_internal).length;
    const needsUi = allFunctions.filter((f) => !f.has_ui && !f.is_internal).length;

    return new Response(JSON.stringify({
      success: true,
      functions: allFunctions,
      summary: {
        total: allFunctions.length,
        withUi,
        needsUi,
        internal: allFunctions.filter((f) => f.is_internal).length,
        coveragePercent: allFunctions.length > 0 ? Math.round(withUi / allFunctions.length * 100) : 0,
      },
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
