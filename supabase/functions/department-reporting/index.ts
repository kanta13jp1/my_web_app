// Department Reporting Edge Function
// 部署別KPIレポート — CFO室/各部門向け分析
// - 部署別タスク完了率・効率スコア
// - エージェントパフォーマンス集計
// - コスト・生産性指標
//
// GET  → 部署別KPI / 全社サマリー / トレンド

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const url = new URL(req.url);
    const view = url.searchParams.get("view"); // 'summary' | 'department' | 'trends'
    const department = url.searchParams.get("department");

    // 全エージェント + タスクを取得
    const [agentsRes, tasksRes] = await Promise.all([
      adminClient.from("agents").select("id, display_name, department, role_title, is_active"),
      adminClient.from("agent_tasks").select("id, assignee_agent_id, status, priority, created_at, completed_at"),
    ]);

    const agents = agentsRes.data ?? [];
    const tasks = tasksRes.data ?? [];

    // 部署ごとにデータを集計
    const deptMap = new Map<string, {
      agents: number;
      activeAgents: number;
      totalTasks: number;
      completedTasks: number;
      inProgressTasks: number;
      pendingTasks: number;
      avgCompletionTimeHours: number;
    }>();

    // エージェントを部署別に集計
    for (const agent of agents) {
      const dept = agent.department ?? "未所属";
      if (!deptMap.has(dept)) {
        deptMap.set(dept, {
          agents: 0, activeAgents: 0, totalTasks: 0,
          completedTasks: 0, inProgressTasks: 0, pendingTasks: 0,
          avgCompletionTimeHours: 0,
        });
      }
      const d = deptMap.get(dept)!;
      d.agents++;
      if (agent.is_active) d.activeAgents++;
    }

    // タスクを部署別に集計
    for (const task of tasks) {
      const agent = agents.find((a) => a.id === task.assignee_agent_id);
      const dept = agent?.department ?? "未所属";
      if (!deptMap.has(dept)) {
        deptMap.set(dept, {
          agents: 0, activeAgents: 0, totalTasks: 0,
          completedTasks: 0, inProgressTasks: 0, pendingTasks: 0,
          avgCompletionTimeHours: 0,
        });
      }
      const d = deptMap.get(dept)!;
      d.totalTasks++;
      if (task.status === "completed" || task.status === "done") d.completedTasks++;
      else if (task.status === "in_progress") d.inProgressTasks++;
      else d.pendingTasks++;
    }

    if (view === "department" && department) {
      const deptData = deptMap.get(department);
      if (!deptData) {
        return new Response(
          JSON.stringify({ success: false, error: "Department not found" }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const deptAgents = agents.filter((a) => a.department === department);
      const deptTasks = tasks.filter((t) => {
        const agent = agents.find((a) => a.id === t.assignee_agent_id);
        return agent?.department === department;
      });

      const completionRate = deptData.totalTasks > 0
        ? Math.round((deptData.completedTasks / deptData.totalTasks) * 100) : 0;

      const efficiencyScore = Math.min(100, Math.round(
        completionRate * 0.6 +
        (deptData.activeAgents > 0 ? Math.min(100, (deptData.completedTasks / deptData.activeAgents) * 10) : 0) * 0.4
      ));

      return new Response(
        JSON.stringify({
          success: true,
          department,
          kpi: {
            ...deptData,
            completionRate,
            efficiencyScore,
          },
          agents: deptAgents.map((a) => ({
            id: a.id,
            name: a.display_name,
            role: a.role_title,
            active: a.is_active,
            taskCount: deptTasks.filter((t) => t.assignee_agent_id === a.id).length,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // summary or default: 全社サマリー
    const departments = [...deptMap.entries()].map(([name, data]) => {
      const completionRate = data.totalTasks > 0
        ? Math.round((data.completedTasks / data.totalTasks) * 100) : 0;

      return {
        name,
        ...data,
        completionRate,
        efficiencyScore: Math.min(100, Math.round(
          completionRate * 0.6 +
          (data.activeAgents > 0 ? Math.min(100, (data.completedTasks / data.activeAgents) * 10) : 0) * 0.4
        )),
      };
    }).sort((a, b) => b.efficiencyScore - a.efficiencyScore);

    const totalCompleted = departments.reduce((sum, d) => sum + d.completedTasks, 0);
    const totalTasks = departments.reduce((sum, d) => sum + d.totalTasks, 0);

    return new Response(
      JSON.stringify({
        success: true,
        companyKpi: {
          totalDepartments: departments.length,
          totalAgents: agents.length,
          activeAgents: agents.filter((a) => a.is_active).length,
          totalTasks,
          completedTasks: totalCompleted,
          overallCompletionRate: totalTasks > 0 ? Math.round((totalCompleted / totalTasks) * 100) : 0,
        },
        departments,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("department-reporting error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
