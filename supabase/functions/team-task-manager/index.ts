// Team Task Manager Edge Function
// 12部署20人の仮想AI組織のタスク管理
// - 部署別タスク一覧 / エージェント一覧
// - タスクの自動割り振り (部署指定 → 部長エージェントがアサイン)
// - エージェント間コミュニケーションログ
// - 部署移動 / エージェント性格管理
// - 進捗の可視化
//
// GET  → タスク一覧・部署一覧・進捗サマリー・メッセージ一覧
// POST → タスク作成 / エージェントアサイン / 部署移動 / メッセージ送信

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
      const view = url.searchParams.get("view");
      // 'agents' | 'tasks' | 'departments' | 'summary' | 'messages' | 'relationships'

      if (view === "agents") {
        const { data, error } = await supabase
          .from("agents")
          .select("id, slug, display_name, role_title, department, status, identity_prompt, last_active_at, metadata, created_at")
          .order("department", { ascending: true });

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, agents: data ?? [] }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "departments") {
        const { data: agents } = await supabase
          .from("agents")
          .select("department, role_title, display_name, status, slug");

        const departments = new Map<string, {
          agents: Array<Record<string, unknown>>;
          count: number;
          activeCount: number;
        }>();

        for (const agent of agents ?? []) {
          const dept = agent.department ?? "未所属";
          if (!departments.has(dept)) {
            departments.set(dept, { agents: [], count: 0, activeCount: 0 });
          }
          const d = departments.get(dept)!;
          d.agents.push({
            display_name: agent.display_name,
            role_title: agent.role_title,
            status: agent.status,
            slug: agent.slug,
          });
          d.count++;
          if (agent.status === "active") d.activeCount++;
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
        const dept = url.searchParams.get("department");
        const status = url.searchParams.get("status");
        const limit = parseInt(url.searchParams.get("limit") ?? "50", 10);

        // agent_tasks を取得し、assignee_agent_id でエージェント情報を結合
        let query = supabase
          .from("agent_tasks")
          .select("*, assignee:agents!assignee_agent_id(display_name, department, role_title), supervisor:agents!supervisor_agent_id(display_name, role_title)")
          .order("created_at", { ascending: false })
          .limit(limit);

        if (status) query = query.eq("status", status);

        const { data, error } = await query;

        // department フィルタは assignee のデータから (agent_tasks テーブル自体に department がない場合)
        let filtered = data ?? [];
        if (dept && filtered.length > 0) {
          filtered = filtered.filter((t) => {
            const assigneeDept = (t.assignee as Record<string, unknown>)?.department;
            return assigneeDept === dept;
          });
        }

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, tasks: filtered }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "messages") {
        // エージェント間メッセージ一覧
        const limit = parseInt(url.searchParams.get("limit") ?? "30", 10);

        const { data, error } = await supabase
          .from("agent_messages")
          .select("*, sender:agents!sender_agent_id(display_name, role_title, department), receiver:agents!receiver_agent_id(display_name, role_title, department)")
          .order("created_at", { ascending: false })
          .limit(limit);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, messages: data ?? [] }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "relationships") {
        // エージェント間の関係性
        const { data, error } = await supabase
          .from("agent_relationships")
          .select("*, source:agents!source_agent_id(display_name, department), target:agents!target_agent_id(display_name, department)")
          .order("created_at", { ascending: false });

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, relationships: data ?? [] }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: サマリー
      const [agentsRes, tasksRes, msgsRes] = await Promise.all([
        supabase.from("agents").select("id, display_name, department, status, role_title"),
        supabase.from("agent_tasks").select("status"),
        supabase.from("agent_messages").select("id", { count: "exact", head: true }),
      ]);

      const agents = agentsRes.data ?? [];
      const tasks = tasksRes.data ?? [];

      const tasksByStatus: Record<string, number> = {};
      for (const t of tasks) {
        const s = (t.status as string) ?? "unknown";
        tasksByStatus[s] = (tasksByStatus[s] ?? 0) + 1;
      }

      const deptMap = new Map<string, { count: number; active: number }>();
      for (const a of agents) {
        const dept = a.department ?? "未所属";
        if (!deptMap.has(dept)) deptMap.set(dept, { count: 0, active: 0 });
        const d = deptMap.get(dept)!;
        d.count++;
        if (a.status === "active") d.active++;
      }

      return new Response(
        JSON.stringify({
          success: true,
          summary: {
            totalAgents: agents.length,
            activeAgents: agents.filter((a) => a.status === "active").length,
            totalDepartments: deptMap.size,
            totalTasks: tasks.length,
            totalMessages: msgsRes.count ?? 0,
            tasksByStatus,
            departments: Object.fromEntries(
              [...deptMap.entries()].sort(([a], [b]) => a.localeCompare(b))
            ),
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_task") {
        const { title, description, department, priority, assignee_agent_id, user_id } = body;

        if (!title) {
          return new Response(
            JSON.stringify({ success: false, error: "title is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // 部署から部長エージェントを自動選択 (supervisor)
        let supervisorId = null;
        let assigneeId = assignee_agent_id;

        if (department) {
          // 部長 (supervisor) を探す
          const { data: supervisor } = await supabase
            .from("agents")
            .select("id")
            .eq("department", department)
            .is("supervisor_agent_id", null) // supervisor がない = 部長
            .eq("status", "active")
            .limit(1)
            .single();

          if (supervisor) supervisorId = supervisor.id;

          // assignee が指定されていなければ部署の空いているエージェントを自動アサイン
          if (!assigneeId) {
            const { data: available } = await supabase
              .from("agents")
              .select("id")
              .eq("department", department)
              .eq("status", "active")
              .limit(1)
              .single();

            if (available) assigneeId = available.id;
          }
        }

        // fallback: assignee も supervisor も見つからない場合
        if (!assigneeId || !supervisorId) {
          const { data: anyAgent } = await supabase
            .from("agents")
            .select("id")
            .eq("status", "active")
            .limit(1)
            .single();

          if (anyAgent) {
            if (!assigneeId) assigneeId = anyAgent.id;
            if (!supervisorId) supervisorId = anyAgent.id;
          }
        }

        // user_id fallback — 最初のユーザーを使用
        let taskUserId = user_id;
        if (!taskUserId) {
          const { data: firstAgent } = await supabase
            .from("agents")
            .select("user_id")
            .limit(1)
            .single();
          taskUserId = firstAgent?.user_id;
        }

        if (!taskUserId || !assigneeId || !supervisorId) {
          return new Response(
            JSON.stringify({ success: false, error: "エージェントが未登録です。先に seed_12dept_20agents() を実行してください" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await supabase
          .from("agent_tasks")
          .insert({
            user_id: taskUserId,
            supervisor_agent_id: supervisorId,
            assignee_agent_id: assigneeId,
            title,
            description: description ?? "",
            priority: priority === "critical" ? "high" : (priority ?? "normal"),
            status: "queued",
            source: "api",
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
        if (output) updates.metadata = { output };
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

      if (action === "move_department") {
        // 部署移動 (部長エージェントが行う)
        const { agent_id, new_department } = body;

        if (!agent_id || !new_department) {
          return new Response(
            JSON.stringify({ success: false, error: "agent_id and new_department are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await supabase
          .from("agents")
          .update({ department: new_department, updated_at: new Date().toISOString() })
          .eq("id", agent_id)
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, agent: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "send_message") {
        // エージェント間メッセージ送信
        const { sender_agent_id, receiver_agent_id, message_type, content, user_id: msgUserId } = body;

        if (!sender_agent_id || !receiver_agent_id || !content) {
          return new Response(
            JSON.stringify({ success: false, error: "sender_agent_id, receiver_agent_id, and content are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        let userId = msgUserId;
        if (!userId) {
          const { data: agent } = await supabase
            .from("agents")
            .select("user_id")
            .eq("id", sender_agent_id)
            .single();
          userId = agent?.user_id;
        }

        const { data, error } = await supabase
          .from("agent_messages")
          .insert({
            user_id: userId,
            sender_agent_id,
            receiver_agent_id,
            message_type: message_type ?? "status_update",
            content,
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, message: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "seed_agents") {
        // エージェント初期化 (seed_12dept_20agents RPC を呼び出し)
        const { user_id: seedUserId } = body;

        if (!seedUserId) {
          return new Response(
            JSON.stringify({ success: false, error: "user_id is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await supabase.rpc("seed_12dept_20agents", {
          p_user_id: seedUserId,
        });

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, message: "12部署20人のエージェントを初期化しました" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action. Use 'create_task', 'update_task', 'move_department', 'send_message', or 'seed_agents'" }),
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
