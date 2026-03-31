// AI Workflow Automation Edge Function
// AIワークフロー自動化 (Zapier/Power Automate/Slack Workflows競合)
// - ワークフロー定義 (トリガー→条件→アクション)
// - AI判定ステップ
// - 実行履歴・ログ
// - テンプレート
// - 統計
//
// GET  → ワークフロー一覧 / 実行履歴 / テンプレート / 統計
// POST → ワークフロー作成 / 実行 / 有効化・無効化

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const TRIGGER_TYPES = ["schedule", "webhook", "event", "condition", "manual"];
const ACTION_TYPES = ["send_email", "send_notification", "create_task", "update_record", "ai_classify", "ai_summarize", "ai_generate", "http_request", "delay", "condition_branch"];
const WORKFLOW_TEMPLATES = [
  { key: "new_lead_notify", name: "新規リード通知", trigger: "event", actions: ["ai_classify", "send_notification"] },
  { key: "daily_summary", name: "日次サマリー自動生成", trigger: "schedule", actions: ["ai_summarize", "send_email"] },
  { key: "ticket_auto_reply", name: "チケット自動返信", trigger: "event", actions: ["ai_classify", "ai_generate", "send_email"] },
  { key: "content_moderation", name: "コンテンツ自動モデレーション", trigger: "event", actions: ["ai_classify", "condition_branch", "send_notification"] },
  { key: "weekly_report", name: "週次レポート生成", trigger: "schedule", actions: ["ai_summarize", "create_task", "send_email"] },
];

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
        return new Response(JSON.stringify({ success: true, triggerTypes: TRIGGER_TYPES, actionTypes: ACTION_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "templates") {
        return new Response(JSON.stringify({ success: true, templates: WORKFLOW_TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "executions") {
        const workflowId = url.searchParams.get("workflow_id");
        let query = adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "workflow_execution")
          .order("created_at", { ascending: false });
        if (workflowId) query = query.eq("metadata->>workflow_id", workflowId);
        const { data: execs } = await query.limit(50);
        return new Response(JSON.stringify({
          success: true,
          executions: (execs ?? []).map((e) => ({ ...(e.metadata as Record<string, unknown>), executedAt: e.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: workflows } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "ai_workflow");
        const { data: execs } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "workflow_execution");
        const active = (workflows ?? []).filter((w) => (w.metadata as Record<string, unknown>).is_enabled).length;
        const successful = (execs ?? []).filter((e) => (e.metadata as Record<string, unknown>).status === "success").length;
        return new Response(JSON.stringify({
          success: true,
          stats: { totalWorkflows: (workflows ?? []).length, activeWorkflows: active, totalExecutions: (execs ?? []).length, successRate: (execs ?? []).length > 0 ? Math.round(successful / (execs ?? []).length * 100) : 0 },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: workflow list
      const { data: workflows } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "ai_workflow")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        workflows: (workflows ?? []).map((w) => ({ ...(w.metadata as Record<string, unknown>), createdAt: w.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_workflow") {
        const { name, description, trigger_type, trigger_config, steps } = body;
        if (!name || !trigger_type || !steps) {
          return new Response(JSON.stringify({ success: false, error: "name, trigger_type, steps required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const workflowId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "ai_workflow",
          metadata: { workflow_id: workflowId, name, description: description ?? null, trigger_type, trigger_config: trigger_config ?? {}, steps, is_enabled: true, execution_count: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, workflowId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "execute") {
        const { workflow_id, input_data } = body;
        if (!workflow_id) {
          return new Response(JSON.stringify({ success: false, error: "workflow_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: workflow } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "ai_workflow").eq("metadata->>workflow_id", workflow_id).maybeSingle();
        if (!workflow) {
          return new Response(JSON.stringify({ success: false, error: "Workflow not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const wMeta = workflow.metadata as Record<string, unknown>;
        const steps = (wMeta.steps as Array<Record<string, unknown>>) ?? [];
        // Simulate execution
        const stepResults = steps.map((s, i) => ({ step: i + 1, action: s.action_type, status: "success", output: `Step ${i + 1} completed` }));
        const execId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "workflow_execution",
          metadata: { execution_id: execId, workflow_id, workflow_name: wMeta.name, status: "success", input: input_data ?? {}, step_results: stepResults, duration_ms: steps.length * 150 },
          created_at: new Date().toISOString(),
        });
        // Update execution count
        await adminClient.from("app_analytics").update({ metadata: { ...wMeta, execution_count: ((wMeta.execution_count as number) ?? 0) + 1 } })
          .eq("user_id", user.id).eq("source", "ai_workflow").eq("metadata->>workflow_id", workflow_id);
        return new Response(JSON.stringify({ success: true, executionId: execId, stepResults }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "toggle_enabled") {
        const { workflow_id } = body;
        if (!workflow_id) {
          return new Response(JSON.stringify({ success: false, error: "workflow_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "ai_workflow").eq("metadata->>workflow_id", workflow_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Workflow not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const newEnabled = !(meta.is_enabled as boolean);
        await adminClient.from("app_analytics").update({ metadata: { ...meta, is_enabled: newEnabled } })
          .eq("user_id", user.id).eq("source", "ai_workflow").eq("metadata->>workflow_id", workflow_id);
        return new Response(JSON.stringify({ success: true, isEnabled: newEnabled }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
