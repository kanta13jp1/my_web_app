// Agent Task Router Edge Function
// AIエージェント間のインテリジェントタスク割り振り
// - 部署・スキルベースの自動割り当て
// - タスク優先度に基づく自動ルーティング
// - 負荷分散 (部署ごとのタスク数均等化)
// - エスカレーション (部長→CEO)
//
// GET  → ルーティング状況 / 部署負荷 / 未割り当てタスク
// POST → タスク自動割り当て / 再割り当て / エスカレーション

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// 部署→タスクカテゴリのマッピング
const DEPARTMENT_SKILLS: Record<string, string[]> = {
  "CEO室": ["strategy", "decision", "vision", "escalation"],
  "CFO室": ["finance", "budget", "revenue", "cost", "accounting"],
  "CMO室": ["marketing", "branding", "acquisition", "content"],
  "CHO室": ["health", "wellness", "engagement", "culture"],
  "CHRO室": ["hiring", "hr", "onboarding", "training"],
  "企画部": ["planning", "feature", "roadmap", "research"],
  "開発部": ["development", "bug", "implementation", "code"],
  "営業部": ["sales", "partnership", "deal", "outreach"],
  "CS部": ["support", "ticket", "faq", "satisfaction"],
  "法務部": ["legal", "compliance", "terms", "privacy"],
  "広報部": ["pr", "social", "blog", "announcement"],
  "調達部": ["procurement", "vendor", "tool", "infrastructure"],
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'workload' | 'unassigned' | 'routing_log'

      if (view === "workload") {
        // 部署別タスク負荷 — エージェントとタスクを並列取得
        const [{ data: agents }, { data: tasks }] = await Promise.all([
          adminClient.from("agents").select("id, display_name, department, role_title, is_active"),
          adminClient.from("agent_tasks").select("assignee_agent_id, status").in("status", ["pending", "in_progress"]),
        ]);

        // 部署ごとの集計
        const deptLoad = new Map<string, { agents: number; activeTasks: number; pendingTasks: number }>();

        for (const agent of agents ?? []) {
          const dept = agent.department ?? "未所属";
          if (!deptLoad.has(dept)) deptLoad.set(dept, { agents: 0, activeTasks: 0, pendingTasks: 0 });
          if (agent.is_active) deptLoad.get(dept)!.agents++;
        }

        for (const task of tasks ?? []) {
          const agent = (agents ?? []).find((a) => a.id === task.assignee_agent_id);
          const dept = agent?.department ?? "未所属";
          if (!deptLoad.has(dept)) deptLoad.set(dept, { agents: 0, activeTasks: 0, pendingTasks: 0 });
          if (task.status === "in_progress") deptLoad.get(dept)!.activeTasks++;
          else deptLoad.get(dept)!.pendingTasks++;
        }

        const workload = [...deptLoad.entries()].map(([dept, data]) => ({
          department: dept,
          ...data,
          loadScore: data.agents > 0 ? Math.round(((data.activeTasks + data.pendingTasks) / data.agents) * 100) / 100 : 0,
        })).sort((a, b) => b.loadScore - a.loadScore);

        return new Response(
          JSON.stringify({ success: true, workload }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "unassigned") {
        // 未割り当てタスク
        const { data: tasks } = await adminClient
          .from("agent_tasks")
          .select("id, title, description, priority, status, created_at")
          .is("assignee_agent_id", null)
          .in("status", ["pending"])
          .order("created_at", { ascending: true });

        return new Response(
          JSON.stringify({ success: true, unassigned: tasks ?? [], count: (tasks ?? []).length }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "routing_log") {
        // ルーティング履歴
        const { data: logs } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "task_routing")
          .order("created_at", { ascending: false })
          .limit(50);

        return new Response(
          JSON.stringify({
            success: true,
            logs: (logs ?? []).map((l) => ({
              ...(l.metadata as Record<string, unknown>),
              routedAt: l.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: サマリー
      const [tasksRes, agentsRes] = await Promise.all([
        adminClient.from("agent_tasks").select("*", { count: "exact", head: true }).is("assignee_agent_id", null).eq("status", "pending"),
        adminClient.from("agents").select("*", { count: "exact", head: true }).eq("is_active", true),
      ]);

      return new Response(
        JSON.stringify({
          success: true,
          summary: {
            unassignedTasks: tasksRes.count ?? 0,
            activeAgents: agentsRes.count ?? 0,
            departments: Object.keys(DEPARTMENT_SKILLS).length,
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "auto_assign") {
        // 未割り当てタスクを自動ルーティング
        const { data: unassigned } = await adminClient
          .from("agent_tasks")
          .select("id, title, description, priority")
          .is("assignee_agent_id", null)
          .eq("status", "pending")
          .order("priority", { ascending: false })
          .limit(20);

        if (!unassigned || unassigned.length === 0) {
          return new Response(
            JSON.stringify({ success: true, assigned: 0, message: "No unassigned tasks" }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: agents } = await adminClient
          .from("agents")
          .select("id, display_name, department, role_title, is_active")
          .eq("is_active", true);

        // 各タスクの最適な部署を判定
        const assignments: Array<{ taskId: string; agentId: string; department: string }> = [];

        for (const task of unassigned) {
          const text = `${task.title} ${task.description ?? ""}`.toLowerCase();

          // キーワードマッチングで最適部署を特定
          let bestDept = "開発部"; // デフォルト
          let bestScore = 0;

          for (const [dept, skills] of Object.entries(DEPARTMENT_SKILLS)) {
            const score = skills.filter((s) => text.includes(s)).length;
            if (score > bestScore) {
              bestScore = score;
              bestDept = dept;
            }
          }

          // 部署内のエージェントから最も負荷が低いものを選択
          const deptAgents = (agents ?? []).filter((a) => a.department === bestDept);
          if (deptAgents.length === 0) {
            // フォールバック: 任意のアクティブエージェント
            const fallback = (agents ?? [])[0];
            if (fallback) {
              assignments.push({ taskId: task.id, agentId: fallback.id, department: fallback.department ?? "未所属" });
            }
            continue;
          }

          // シンプルなラウンドロビン割り当て
          const selectedAgent = deptAgents[assignments.length % deptAgents.length];
          assignments.push({ taskId: task.id, agentId: selectedAgent.id, department: bestDept });
        }

        // 割り当て実行
        for (const a of assignments) {
          await adminClient
            .from("agent_tasks")
            .update({ assignee_agent_id: a.agentId, status: "in_progress" })
            .eq("id", a.taskId);
        }

        // ルーティングログ
        if (assignments.length > 0) {
          await adminClient.from("app_analytics").insert({
            source: "task_routing",
            metadata: {
              action: "auto_assign",
              assignments: assignments.map((a) => ({
                taskId: a.taskId,
                agentId: a.agentId,
                department: a.department,
              })),
              count: assignments.length,
            },
            created_at: new Date().toISOString(),
          });
        }

        return new Response(
          JSON.stringify({ success: true, assigned: assignments.length, assignments }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "escalate") {
        // タスクをエスカレーション (部長 → CEO)
        const { task_id, reason } = body;
        if (!task_id) {
          return new Response(
            JSON.stringify({ success: false, error: "task_id is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // CEO エージェントを検索
        const { data: ceo } = await adminClient
          .from("agents")
          .select("id")
          .eq("department", "CEO室")
          .is("supervisor_agent_id", null)
          .limit(1)
          .maybeSingle();

        if (!ceo) {
          return new Response(
            JSON.stringify({ success: false, error: "CEO agent not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        await adminClient
          .from("agent_tasks")
          .update({
            assignee_agent_id: ceo.id,
            priority: 5,
            status: "in_progress",
          })
          .eq("id", task_id);

        // ログ記録
        await adminClient.from("app_analytics").insert({
          source: "task_routing",
          metadata: { action: "escalate", taskId: task_id, escalatedTo: ceo.id, reason: reason ?? "" },
          created_at: new Date().toISOString(),
        });

        return new Response(
          JSON.stringify({ success: true, escalatedTo: ceo.id }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("agent-task-router error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
