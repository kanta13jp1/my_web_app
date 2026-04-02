// Workflow Templates Edge Function
// ワークフローテンプレート (Notion/Slack/ジョブカン競合)
// - テンプレート作成・共有
// - ステップ管理
// - 承認フロー
// - テンプレートギャラリー
// - インスタンス実行

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const TEMPLATE_CATEGORIES = ["hr", "finance", "engineering", "marketing", "sales", "support", "general"];
const STEP_TYPES = ["task", "approval", "notification", "condition", "delay", "webhook"];
const BUILTIN_TEMPLATES = [
  { id: "expense_approval", name: "経費承認フロー", category: "finance", steps: [
    { type: "task", name: "経費申請入力", assignee: "requester" },
    { type: "approval", name: "上長承認", assignee: "manager" },
    { type: "condition", name: "金額確認", condition: "amount > 50000" },
    { type: "approval", name: "経理承認", assignee: "finance" },
    { type: "notification", name: "完了通知", target: "requester" },
  ]},
  { id: "new_hire", name: "新入社員オンボーディング", category: "hr", steps: [
    { type: "task", name: "アカウント作成", assignee: "it" },
    { type: "task", name: "備品準備", assignee: "admin" },
    { type: "task", name: "メンター割り当て", assignee: "manager" },
    { type: "notification", name: "ウェルカムメール", target: "new_hire" },
    { type: "task", name: "初回1on1", assignee: "manager" },
  ]},
  { id: "bug_fix", name: "バグ修正フロー", category: "engineering", steps: [
    { type: "task", name: "バグ調査", assignee: "developer" },
    { type: "task", name: "修正実装", assignee: "developer" },
    { type: "approval", name: "コードレビュー", assignee: "reviewer" },
    { type: "task", name: "テスト", assignee: "qa" },
    { type: "task", name: "デプロイ", assignee: "devops" },
  ]},
  { id: "content_publish", name: "コンテンツ公開フロー", category: "marketing", steps: [
    { type: "task", name: "下書き作成", assignee: "writer" },
    { type: "approval", name: "編集レビュー", assignee: "editor" },
    { type: "approval", name: "法務確認", assignee: "legal" },
    { type: "task", name: "公開", assignee: "publisher" },
    { type: "notification", name: "SNS告知", target: "marketing" },
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

    const url = new URL(req.url);
    const view = url.searchParams.get("view");

    // Flutter の functions.invoke() はデフォルトで POST を送るが、
    // query params 付きの場合は GET と同じ処理を行う
    if (req.method === "GET" || (req.method === "POST" && view !== null)) {

      if (view === "gallery") return new Response(JSON.stringify({ success: true, templates: BUILTIN_TEMPLATES, categories: TEMPLATE_CATEGORIES, stepTypes: STEP_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "instances") {
        const { data: instances } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "workflow_instance").order("created_at", { ascending: false }).limit(30);
        return new Response(JSON.stringify({ success: true, instances: (instances ?? []).map((i) => ({ ...(i.metadata as Record<string, unknown>), createdAt: i.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: instances } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "workflow_instance");
        const completed = (instances ?? []).filter((i) => (i.metadata as Record<string, unknown>).status === "completed").length;
        const active = (instances ?? []).filter((i) => (i.metadata as Record<string, unknown>).status === "active").length;
        return new Response(JSON.stringify({
          success: true, stats: { total: (instances ?? []).length, completed, active, pending: (instances ?? []).length - completed - active },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: user's custom templates
      const { data: custom } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "workflow_template").order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        customTemplates: (custom ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), createdAt: t.created_at })),
        builtinTemplates: BUILTIN_TEMPLATES,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST" && view === null) {
      let body: Record<string, unknown> = {};
      try {
        body = await req.json().catch(() => ({}));
      } catch {
        return new Response(JSON.stringify({ success: false, error: "Invalid or empty JSON body" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { action } = body;

      if (action === "create_template") {
        const { name, category, steps, description } = body;
        if (!name || !steps) return new Response(JSON.stringify({ success: false, error: "name and steps required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const tId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "workflow_template",
          metadata: { template_id: tId, name, category: category ?? "general", steps, description: description ?? "", is_public: false },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, templateId: tId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "start_workflow") {
        const { template_id, name } = body;
        if (!template_id) return new Response(JSON.stringify({ success: false, error: "template_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Find template
        let steps;
        const builtin = BUILTIN_TEMPLATES.find((t) => t.id === template_id);
        if (builtin) {
          steps = builtin.steps;
        } else {
          const { data: custom } = await adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "workflow_template").eq("metadata->>template_id", template_id).maybeSingle();
          if (!custom) return new Response(JSON.stringify({ success: false, error: "Template not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
          steps = (custom.metadata as Record<string, unknown>).steps;
        }
        const instanceId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "workflow_instance",
          metadata: {
            instance_id: instanceId, template_id, name: name ?? "Workflow",
            steps, current_step: 0, status: "active",
            started_at: new Date().toISOString(), completed_at: null,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, instanceId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "advance_step") {
        const { instance_id } = body;
        if (!instance_id) return new Response(JSON.stringify({ success: false, error: "instance_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: instance } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "workflow_instance").eq("metadata->>instance_id", instance_id).maybeSingle();
        if (!instance) return new Response(JSON.stringify({ success: false, error: "Instance not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = instance.metadata as Record<string, unknown>;
        const steps = (meta.steps as Array<unknown>) ?? [];
        const nextStep = ((meta.current_step as number) ?? 0) + 1;
        const isComplete = nextStep >= steps.length;
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, current_step: nextStep, status: isComplete ? "completed" : "active", completed_at: isComplete ? new Date().toISOString() : null },
        }).eq("user_id", user.id).eq("source", "workflow_instance").eq("metadata->>instance_id", instance_id);
        return new Response(JSON.stringify({ success: true, currentStep: nextStep, isComplete }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
