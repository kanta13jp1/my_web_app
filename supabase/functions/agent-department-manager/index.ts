// Agent Department Manager Edge Function
// 企画責任者エージェントによる部署管理
// - 部署の自動作成・削除
// - 責任範囲のルール設計
// - エージェントのアサイン・部署移動
// - 部署間のゴール重複防止
//
// GET  → 部署一覧・ルール・目標
// POST → 部署作成 / ルール更新 / エージェント移動

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// デフォルトの12部署定義
const DEFAULT_DEPARTMENTS = [
  { key: "ceo", label: "CEO室", goal: "全社戦略・意思決定", maxAgents: 3 },
  { key: "cfo", label: "CFO室", goal: "財務・予算・経理", maxAgents: 3 },
  { key: "cmo", label: "CMO室", goal: "マーケティング・広告・宣伝", maxAgents: 3 },
  { key: "cho", label: "CHO室", goal: "健康・ウェルネス管理", maxAgents: 2 },
  { key: "chro", label: "CHRO室", goal: "人事・採用・組織開発", maxAgents: 3 },
  { key: "planning", label: "企画部", goal: "企画立案・プロダクト管理", maxAgents: 3 },
  { key: "development", label: "開発部", goal: "技術開発・実装", maxAgents: 5 },
  { key: "sales", label: "営業部", goal: "顧客獲得・営業活動", maxAgents: 3 },
  { key: "cs", label: "CS部", goal: "カスタマーサポート・ユーザー対応", maxAgents: 2 },
  { key: "legal", label: "法務部", goal: "法務・コンプライアンス", maxAgents: 2 },
  { key: "pr", label: "広報部", goal: "広報・PR・ブログ運営", maxAgents: 2 },
  { key: "procurement", label: "調達部", goal: "調達・ベンダー管理", maxAgents: 2 },
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'overview' | 'rules' | 'goals'

      // 全エージェントを部署別に集計
      const { data: agents, error } = await supabase
        .from("agents")
        .select("id, display_name, role_title, department, status, supervisor_agent_id")
        .order("department", { ascending: true });

      if (error) throw error;

      const deptMap = new Map<string, {
        agents: Array<Record<string, unknown>>;
        director: Record<string, unknown> | null;
        activeCount: number;
        totalCount: number;
      }>();

      for (const agent of agents ?? []) {
        const dept = agent.department ?? "未所属";
        if (!deptMap.has(dept)) {
          deptMap.set(dept, { agents: [], director: null, activeCount: 0, totalCount: 0 });
        }
        const d = deptMap.get(dept)!;
        d.agents.push(agent);
        d.totalCount++;
        if (agent.status === "active") d.activeCount++;
        // supervisor がない = 部長
        if (!agent.supervisor_agent_id) d.director = agent;
      }

      // 部署タスク数を集計
      const { data: tasks } = await supabase
        .from("agent_tasks")
        .select("assignee_agent_id, status");

      const agentTaskCount = new Map<string, { total: number; completed: number }>();
      for (const t of tasks ?? []) {
        const aid = t.assignee_agent_id;
        if (!aid) continue;
        if (!agentTaskCount.has(aid)) agentTaskCount.set(aid, { total: 0, completed: 0 });
        const c = agentTaskCount.get(aid)!;
        c.total++;
        if (t.status === "completed") c.completed++;
      }

      if (view === "goals") {
        // 各部署のゴールと進捗
        const departmentGoals = DEFAULT_DEPARTMENTS.map((dept) => {
          const deptData = deptMap.get(dept.label);
          const deptAgentIds = (deptData?.agents ?? []).map((a) => (a as Record<string, unknown>).id as string);
          let totalTasks = 0;
          let completedTasks = 0;
          for (const aid of deptAgentIds) {
            const counts = agentTaskCount.get(aid);
            if (counts) {
              totalTasks += counts.total;
              completedTasks += counts.completed;
            }
          }

          return {
            ...dept,
            agentCount: deptData?.totalCount ?? 0,
            activeCount: deptData?.activeCount ?? 0,
            director: deptData?.director ? (deptData.director as Record<string, unknown>).display_name : null,
            totalTasks,
            completedTasks,
            completionRate: totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0,
          };
        });

        return new Response(
          JSON.stringify({ success: true, departmentGoals }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: overview
      const overview = {
        departments: Object.fromEntries(
          [...deptMap.entries()].map(([dept, data]) => [
            dept,
            {
              director: data.director ? (data.director as Record<string, unknown>).display_name : null,
              totalAgents: data.totalCount,
              activeAgents: data.activeCount,
              agents: data.agents.map((a) => ({
                id: (a as Record<string, unknown>).id,
                display_name: (a as Record<string, unknown>).display_name,
                role_title: (a as Record<string, unknown>).role_title,
                status: (a as Record<string, unknown>).status,
              })),
            },
          ])
        ),
        defaultDepartments: DEFAULT_DEPARTMENTS,
        totalAgents: (agents ?? []).length,
        totalDepartments: deptMap.size,
      };

      return new Response(
        JSON.stringify({ success: true, ...overview }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_department") {
        // 新部署を作成 (エージェントを新部署に移動)
        const { department_name, goal, agent_ids } = body;

        if (!department_name) {
          return new Response(
            JSON.stringify({ success: false, error: "department_name is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // 指定されたエージェントを新部署に移動
        if (agent_ids && agent_ids.length > 0) {
          const { error } = await supabase
            .from("agents")
            .update({
              department: department_name,
              updated_at: new Date().toISOString(),
            })
            .in("id", agent_ids);

          if (error) throw error;
        }

        return new Response(
          JSON.stringify({
            success: true,
            department: department_name,
            goal: goal ?? null,
            movedAgents: (agent_ids ?? []).length,
          }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "assign_agent") {
        // エージェントを部署にアサイン
        const { agent_id, department, role_title } = body;

        if (!agent_id || !department) {
          return new Response(
            JSON.stringify({ success: false, error: "agent_id and department are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const updates: Record<string, unknown> = {
          department,
          updated_at: new Date().toISOString(),
        };
        if (role_title) updates.role_title = role_title;

        const { data, error } = await supabase
          .from("agents")
          .update(updates)
          .eq("id", agent_id)
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, agent: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "set_supervisor") {
        // 部長を設定
        const { agent_id, supervisor_agent_id } = body;

        if (!agent_id) {
          return new Response(
            JSON.stringify({ success: false, error: "agent_id is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await supabase
          .from("agents")
          .update({
            supervisor_agent_id: supervisor_agent_id ?? null,
            updated_at: new Date().toISOString(),
          })
          .eq("id", agent_id)
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, agent: data }),
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
    console.error("agent-department-manager error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
