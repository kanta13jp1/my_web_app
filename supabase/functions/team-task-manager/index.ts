// Team Task Manager Edge Function
// 12部署20人の仮想AI組織のタスク管理
// - 部署別タスク一覧
// - タスクの自動割り振り
// - エージェント間コミュニケーションログ
// - 進捗の可視化
//
// GET  → タスク一覧・部署一覧・進捗サマリー
// POST → タスク作成 / エージェントアサイン

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
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'agents' | 'tasks' | 'departments' | 'summary'

      if (view === "agents") {
        // エージェント一覧
        const { data, error } = await supabase
          .from("ai_agents")
          .select("*")
          .order("department", { ascending: true });

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, agents: data ?? [] }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "departments") {
        // 部署別サマリー
        const { data: agents } = await supabase
          .from("ai_agents")
          .select("department, role, name, status");

        const departments = new Map<string, { agents: Array<Record<string, unknown>>; count: number }>();
        for (const agent of agents ?? []) {
          const dept = agent.department ?? "未所属";
          if (!departments.has(dept)) {
            departments.set(dept, { agents: [], count: 0 });
          }
          const d = departments.get(dept)!;
          d.agents.push(agent);
          d.count++;
        }

        return new Response(
          JSON.stringify({
            success: true,
            departments: Object.fromEntries(departments),
            totalDepartments: departments.size,
            totalAgents: (agents ?? []).length,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "tasks") {
        // タスク一覧
        const dept = url.searchParams.get("department");
        const status = url.searchParams.get("status");
        const limit = parseInt(url.searchParams.get("limit") ?? "50", 10);

        let query = supabase
          .from("agent_tasks")
          .select("*, ai_agents!assigned_agent_id(name, department, role)")
          .order("created_at", { ascending: false })
          .limit(limit);

        if (dept) query = query.eq("department", dept);
        if (status) query = query.eq("status", status);

        const { data, error } = await query;
        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, tasks: data ?? [] }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: サマリー
      const [agentsRes, tasksRes] = await Promise.all([
        supabase.from("ai_agents").select("*", { count: "exact" }),
        supabase.from("agent_tasks").select("status"),
      ]);

      const agents = agentsRes.data ?? [];
      const tasks = tasksRes.data ?? [];

      const tasksByStatus: Record<string, number> = {};
      for (const t of tasks) {
        const s = (t.status as string) ?? "unknown";
        tasksByStatus[s] = (tasksByStatus[s] ?? 0) + 1;
      }

      // 部署別集計
      const deptSet = new Set<string>();
      for (const a of agents) {
        if (a.department) deptSet.add(a.department);
      }

      return new Response(
        JSON.stringify({
          success: true,
          summary: {
            totalAgents: agents.length,
            totalDepartments: deptSet.size,
            totalTasks: tasks.length,
            tasksByStatus,
            departments: [...deptSet].sort(),
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_task") {
        // タスク作成
        const { title, description, department, priority, assigned_agent_id } = body;

        if (!title) {
          return new Response(
            JSON.stringify({ success: false, error: "title is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // エージェント自動アサイン (部署指定時)
        let agentId = assigned_agent_id;
        if (!agentId && department) {
          const { data: available } = await supabase
            .from("ai_agents")
            .select("id")
            .eq("department", department)
            .eq("status", "active")
            .limit(1)
            .single();

          if (available) agentId = available.id;
        }

        const { data, error } = await supabase
          .from("agent_tasks")
          .insert({
            title,
            description: description ?? null,
            department: department ?? null,
            priority: priority ?? "medium",
            assigned_agent_id: agentId ?? null,
            status: "pending",
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, task: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "update_task") {
        const { task_id, status, output } = body;

        if (!task_id || !status) {
          return new Response(
            JSON.stringify({ success: false, error: "task_id and status are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const updates: Record<string, unknown> = { status };
        if (output) updates.output = output;
        if (status === "completed") updates.completed_at = new Date().toISOString();

        const { data, error } = await supabase
          .from("agent_tasks")
          .update(updates)
          .eq("id", task_id)
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, task: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action. Use 'create_task' or 'update_task'" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("team-task-manager error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
