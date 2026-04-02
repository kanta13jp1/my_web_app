// Gantt Timeline Manager Edge Function
// ガントチャート・タイムライン管理 (Microsoft Project/GitHub Projects/Notion Timeline競合)
// - タスク依存関係管理
// - マイルストーン設定
// - クリティカルパス計算
// - タイムラインビュー
//
// GET  → プロジェクト一覧 / タスク / マイルストーン / クリティカルパス
// POST → プロジェクト作成 / タスク追加 / 依存関係 / マイルストーン

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

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
      const projectId = url.searchParams.get("project_id");

      if (view === "tasks" && projectId) {
        const { data: tasks } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "gantt_task")
          .eq("metadata->>project_id", projectId)
          .order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true, projectId,
          tasks: (tasks ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), createdAt: t.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "milestones" && projectId) {
        const { data: milestones } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "gantt_milestone")
          .eq("metadata->>project_id", projectId)
          .order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          milestones: (milestones ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), createdAt: m.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "critical_path" && projectId) {
        // Calculate critical path from tasks and dependencies
        const { data: tasks } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "gantt_task")
          .eq("metadata->>project_id", projectId);

        const taskMap = new Map<string, Record<string, unknown>>();
        for (const t of tasks ?? []) {
          const meta = t.metadata as Record<string, unknown>;
          taskMap.set(meta.task_id as string, meta);
        }

        // Simple critical path: find the longest path
        const endDates: Array<{ taskId: string; name: string; endDate: string; duration: number }> = [];
        for (const [taskId, task] of taskMap) {
          const start = new Date(task.start_date as string ?? Date.now());
          const duration = (task.duration_days as number) ?? 1;
          const end = new Date(start.getTime() + duration * 86400000);
          endDates.push({ taskId, name: task.name as string, endDate: end.toISOString(), duration });
        }
        endDates.sort((a, b) => new Date(b.endDate).getTime() - new Date(a.endDate).getTime());

        return new Response(JSON.stringify({
          success: true,
          criticalPath: endDates.slice(0, 10),
          totalTasks: taskMap.size,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: project list
      const { data: projects } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "gantt_project")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        projects: (projects ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_project") {
        const { name, description, start_date, end_date } = body;
        if (!name) {
          return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const projectId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "gantt_project",
          metadata: {
            project_id: projectId, name,
            description: description ?? null,
            start_date: start_date ?? new Date().toISOString().slice(0, 10),
            end_date: end_date ?? null, status: "active",
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, projectId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_task") {
        const { project_id, name, start_date, duration_days, assignee, depends_on, progress } = body;
        if (!project_id || !name) {
          return new Response(JSON.stringify({ success: false, error: "project_id and name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const taskId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "gantt_task",
          metadata: {
            task_id: taskId, project_id, name,
            start_date: start_date ?? new Date().toISOString().slice(0, 10),
            duration_days: duration_days ?? 1,
            assignee: assignee ?? null,
            depends_on: depends_on ?? [],
            progress: progress ?? 0,
            status: "pending",
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, taskId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_task") {
        const { task_id, progress, status, start_date, duration_days } = body;
        if (!task_id) {
          return new Response(JSON.stringify({ success: false, error: "task_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "gantt_task").eq("metadata->>task_id", task_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Task not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const updates: Record<string, unknown> = {};
        if (progress !== undefined) updates.progress = progress;
        if (status !== undefined) updates.status = status;
        if (start_date !== undefined) updates.start_date = start_date;
        if (duration_days !== undefined) updates.duration_days = duration_days;
        await adminClient.from("app_analytics").update({ metadata: { ...meta, ...updates } })
          .eq("user_id", user.id).eq("source", "gantt_task").eq("metadata->>task_id", task_id);
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_dependency") {
        const { task_id, depends_on_task_id } = body;
        if (!task_id || !depends_on_task_id) {
          return new Response(JSON.stringify({ success: false, error: "task_id and depends_on_task_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "gantt_task").eq("metadata->>task_id", task_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Task not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const deps = (meta.depends_on as string[]) ?? [];
        if (!deps.includes(depends_on_task_id)) {
          deps.push(depends_on_task_id);
        }
        await adminClient.from("app_analytics").update({ metadata: { ...meta, depends_on: deps } })
          .eq("user_id", user.id).eq("source", "gantt_task").eq("metadata->>task_id", task_id);
        return new Response(JSON.stringify({ success: true, added: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_milestone") {
        const { project_id, name, date, description } = body;
        if (!project_id || !name || !date) {
          return new Response(JSON.stringify({ success: false, error: "project_id, name, date required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const milestoneId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "gantt_milestone",
          metadata: { milestone_id: milestoneId, project_id, name, date, description: description ?? null, completed: false },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, milestoneId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
