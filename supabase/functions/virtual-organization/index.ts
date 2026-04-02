// Virtual Organization Edge Function
// 仮想AI組織管理 (12部署20エージェント)
// - 部署・エージェント構成管理
// - タスク自動割振り
// - 部署間コミュニケーション
// - 組織図表示
// - エージェント性格・記憶管理
//
// GET  → 組織図 / 部署一覧 / エージェント一覧 / タスク状況 / 性格ログ
// POST → 部署作成 / エージェント配置 / タスク割振り / 性格更新

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const DEFAULT_DEPARTMENTS = [
  { key: "executive", name: "経営企画", icon: "👔", description: "全体戦略・ゴール設定" },
  { key: "engineering", name: "開発", icon: "💻", description: "フロントエンド・バックエンド開発" },
  { key: "marketing", name: "マーケティング", icon: "📣", description: "広告・宣伝・SNS運用" },
  { key: "sales", name: "営業", icon: "🤝", description: "顧客獲得・パートナーシップ" },
  { key: "cs", name: "カスタマーサポート", icon: "🎧", description: "チケット対応・FAQ管理" },
  { key: "hr", name: "人事", icon: "👥", description: "採用・評価・組織設計" },
  { key: "finance", name: "経理", icon: "💰", description: "会計・予算・決算" },
  { key: "legal", name: "法務", icon: "⚖️", description: "契約・コンプライアンス" },
  { key: "design", name: "デザイン", icon: "🎨", description: "UI/UX・ブランド設計" },
  { key: "data", name: "データ分析", icon: "📊", description: "KPI分析・BI" },
  { key: "procurement", name: "調達", icon: "📦", description: "購買・ベンダー管理" },
  { key: "qa", name: "品質管理", icon: "✅", description: "テスト・品質保証" },
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

      if (view === "departments") {
        return new Response(JSON.stringify({ success: true, departments: DEFAULT_DEPARTMENTS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "org_chart") {
        // Get agents from agents table
        const { data: agents } = await adminClient.from("agents").select("*").order("department");
        const orgChart: Record<string, Array<Record<string, unknown>>> = {};
        for (const dept of DEFAULT_DEPARTMENTS) {
          orgChart[dept.key] = (agents ?? [])
            .filter((a) => a.department === dept.key)
            .map((a) => ({ id: a.id, name: a.display_name, role: a.role_title, department: a.department }));
        }
        return new Response(JSON.stringify({ success: true, orgChart, totalAgents: (agents ?? []).length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "agents") {
        const dept = url.searchParams.get("department");
        let query = adminClient.from("agents").select("*");
        if (dept) query = query.eq("department", dept);
        const { data: agents } = await query.order("display_name");
        return new Response(JSON.stringify({
          success: true,
          agents: (agents ?? []).map((a) => ({
            id: a.id, name: a.display_name, role: a.role_title,
            department: a.department, supervisor_id: a.supervisor_agent_id,
          })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "task_status") {
        const { data: tasks } = await adminClient.from("agent_tasks").select("*")
          .order("created_at", { ascending: false }).limit(50);
        const statusCounts: Record<string, number> = {};
        for (const t of tasks ?? []) {
          statusCounts[t.status] = (statusCounts[t.status] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true,
          tasks: (tasks ?? []).map((t) => ({
            id: t.id, title: t.title, status: t.status,
            assignee: t.assignee_agent_id, supervisor: t.supervisor_agent_id,
            priority: t.priority,
          })),
          statusCounts,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "personality") {
        const agentId = url.searchParams.get("agent_id");
        if (!agentId) {
          return new Response(JSON.stringify({ success: false, error: "agent_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: memories } = await adminClient.from("agent_memories").select("*")
          .eq("agent_id", agentId).order("created_at", { ascending: false }).limit(20);
        const { data: personality } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "agent_personality").eq("metadata->>agent_id", agentId).maybeSingle();
        return new Response(JSON.stringify({
          success: true,
          personality: personality?.metadata ?? null,
          recentMemories: memories ?? [],
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: summary
      const { data: agents } = await adminClient.from("agents").select("*", { count: "exact", head: true });
      const { data: tasks } = await adminClient.from("agent_tasks").select("*", { count: "exact", head: true });
      return new Response(JSON.stringify({
        success: true,
        summary: {
          departments: DEFAULT_DEPARTMENTS.length,
          totalAgents: agents?.length ?? 0,
          totalTasks: tasks?.length ?? 0,
        },
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "assign_task") {
        const { title, description, department, priority } = body;
        if (!title || !department) {
          return new Response(JSON.stringify({ success: false, error: "title and department required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        // Find available agent in department
        const { data: agents } = await adminClient.from("agents").select("id, display_name")
          .eq("department", department).limit(1);
        const assignee = agents?.[0];

        const { data: task, error } = await adminClient.from("agent_tasks").insert({
          title, description: description ?? null,
          assignee_agent_id: assignee?.id ?? null,
          status: "pending", priority: priority ?? "medium",
        }).select().single();

        if (error) throw error;
        return new Response(JSON.stringify({
          success: true, taskId: task.id,
          assignedTo: assignee?.display_name ?? "unassigned",
        }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_personality") {
        const { agent_id, traits, strengths, weaknesses, communication_style } = body;
        if (!agent_id) {
          return new Response(JSON.stringify({ success: false, error: "agent_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        // Check if personality already exists
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "agent_personality").eq("metadata->>agent_id", agent_id).maybeSingle();

        const personality = {
          agent_id, traits: traits ?? [],
          strengths: strengths ?? [], weaknesses: weaknesses ?? [],
          communication_style: communication_style ?? "professional",
          updated_at: new Date().toISOString(),
        };

        if (existing) {
          await adminClient.from("app_analytics").update({
            metadata: { ...(existing.metadata as Record<string, unknown>), ...personality },
          }).eq("source", "agent_personality").eq("metadata->>agent_id", agent_id);
        } else {
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "agent_personality",
            metadata: personality, created_at: new Date().toISOString(),
          });
        }

        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "transfer_agent") {
        const { agent_id, new_department } = body;
        if (!agent_id || !new_department) {
          return new Response(JSON.stringify({ success: false, error: "agent_id and new_department required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { error } = await adminClient.from("agents").update({ department: new_department }).eq("id", agent_id);
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, transferred: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
