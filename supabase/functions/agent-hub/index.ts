// agent-hub — Consolidated Agent Management EF
// Merges: agent-department-manager + agent-performance-monitor + agent-personality + agent-runtime-cycle + agent-task-router
//
// GET  ?action=departments   → department overview/goals (agent-department-manager)
// GET  ?action=performance   → performance ranking/agent/alerts (agent-performance-monitor)
// GET  ?action=personality   → personality/memories summary (agent-personality)
// GET  ?action=routing       → routing workload/unassigned/log (agent-task-router)
//
// POST { action: "create_department" }       → (agent-department-manager)
// POST { action: "assign_agent" }            → (agent-department-manager)
// POST { action: "set_supervisor" }          → (agent-department-manager)
// POST { action: "record_activity" }         → (agent-performance-monitor)
// POST { action: "update_personality" }      → (agent-personality)
// POST { action: "record_memory" }           → (agent-personality)
// POST { action: "learn_from_conversation" } → (agent-personality)
// POST { action: "runtime_cycle" }           → (agent-runtime-cycle, requires x-cron-token)
// POST { action: "auto_assign" }             → (agent-task-router)
// POST { action: "escalate" }               → (agent-task-router)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-token",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("AGENT_RUNTIME_CRON_SECRET") ?? "";

// 12 default departments (agent-department-manager)
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

// Department → task category mapping (agent-task-router)
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
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const url = new URL(req.url);
    const getAction = url.searchParams.get("action") ?? "departments";

    // ── POST ──────────────────────────────────────────────────────────────────
    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      // ─── agent-department-manager POST actions ───
      if (action === "create_department") {
        const { department_name, goal, agent_ids } = body;
        if (!department_name) return json400("department_name is required");
        if (agent_ids && agent_ids.length > 0) {
          const { error } = await supabase.from("agents")
            .update({ department: department_name, updated_at: new Date().toISOString() })
            .in("id", agent_ids);
          if (error) throw error;
        }
        return new Response(JSON.stringify({ success: true, department: department_name, goal: goal ?? null, movedAgents: (agent_ids ?? []).length }), {
          status: 201,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      if (action === "assign_agent") {
        const { agent_id, department, role_title } = body;
        if (!agent_id || !department) return json400("agent_id and department are required");
        const updates: Record<string, unknown> = { department, updated_at: new Date().toISOString() };
        if (role_title) updates.role_title = role_title;
        const { data, error } = await supabase.from("agents").update(updates).eq("id", agent_id).select().single();
        if (error) throw error;
        return jsonOk({ success: true, agent: data });
      }

      if (action === "set_supervisor") {
        const { agent_id, supervisor_agent_id } = body;
        if (!agent_id) return json400("agent_id is required");
        const { data, error } = await supabase.from("agents")
          .update({ supervisor_agent_id: supervisor_agent_id ?? null, updated_at: new Date().toISOString() })
          .eq("id", agent_id).select().single();
        if (error) throw error;
        return jsonOk({ success: true, agent: data });
      }

      // ─── agent-performance-monitor POST actions ───
      if (action === "record_activity") {
        const { agent_id, activity_type, details } = body;
        if (!agent_id) return json400("agent_id required");
        const { data, error } = await supabase.from("agent_memories").insert({
          agent_id,
          layer: "activity_log",
          content: `[${activity_type ?? "activity"}] ${details ?? ""}`,
          metadata: { type: activity_type, details, recorded_at: new Date().toISOString() },
        }).select().single();
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, memory: data }), {
          status: 201,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // ─── agent-personality POST actions ───
      if (action === "update_personality") {
        const { agent_id, identity_prompt, personality_traits } = body;
        if (!agent_id) return json400("agent_id is required");
        const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };
        if (identity_prompt) updates.identity_prompt = identity_prompt;
        if (personality_traits) {
          const { data: current } = await supabase.from("agents").select("metadata").eq("id", agent_id).single();
          const currentMeta = (current?.metadata ?? {}) as Record<string, unknown>;
          updates.metadata = { ...currentMeta, personality_traits };
        }
        const { data, error } = await supabase.from("agents").update(updates).eq("id", agent_id).select().single();
        if (error) throw error;
        return jsonOk({ success: true, agent: data });
      }

      if (action === "record_memory") {
        const { agent_id, user_id, layer, content, metadata } = body;
        if (!agent_id || !content) return json400("agent_id and content are required");
        let userId = user_id;
        if (!userId) {
          const { data: agent } = await supabase.from("agents").select("user_id").eq("id", agent_id).single();
          userId = agent?.user_id;
        }
        const { data, error } = await supabase.from("agent_memories").insert({
          agent_id, user_id: userId,
          layer: layer ?? "episodes",
          content, metadata: metadata ?? {},
          created_at: new Date().toISOString(),
        }).select().single();
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, memory: data }), {
          status: 201,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      if (action === "learn_from_conversation") {
        const { agent_id, user_id, conversation_summary, detected_traits } = body;
        if (!agent_id || !conversation_summary) return json400("agent_id and conversation_summary are required");
        let userId = user_id;
        if (!userId) {
          const { data: agent } = await supabase.from("agents").select("user_id").eq("id", agent_id).single();
          userId = agent?.user_id;
        }
        const { data: memory, error: memError } = await supabase.from("agent_memories").insert({
          agent_id, user_id: userId,
          layer: "knowledge",
          content: conversation_summary,
          metadata: { detected_traits: detected_traits ?? [], type: "personality_learning" },
          created_at: new Date().toISOString(),
        }).select().single();
        if (memError) throw memError;
        if (detected_traits && detected_traits.length > 0) {
          const { data: agent } = await supabase.from("agents").select("metadata").eq("id", agent_id).single();
          const meta = (agent?.metadata ?? {}) as Record<string, unknown>;
          const existingTraits = (meta.learned_traits ?? []) as string[];
          await supabase.from("agents").update({
            metadata: { ...meta, learned_traits: [...new Set([...existingTraits, ...detected_traits])] },
            updated_at: new Date().toISOString(),
          }).eq("id", agent_id);
        }
        return jsonOk({ success: true, memory });
      }

      // ─── agent-runtime-cycle POST (requires cron token) ───
      if (action === "runtime_cycle") {
        const token = req.headers.get("x-cron-token") ?? (req.headers.get("authorization") ?? "").replace(/^bearer /i, "");
        if (!CRON_SECRET || token !== CRON_SECRET) {
          return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
            status: 401,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
        const { mode, userId, runNightly, runForgetting, retentionDays } = body;
        const runtimeMode = mode ?? "cycle";
        const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false, persistSession: false } });
        let result: unknown;
        if (runtimeMode === "heartbeat") {
          const { data, error } = await admin.rpc("run_agent_heartbeat", { p_user_id: userId ?? null });
          if (error) throw error;
          result = data;
        } else if (runtimeMode === "nightly") {
          const { data, error } = await admin.rpc("run_agent_nightly_consolidation", { p_user_id: userId ?? null });
          if (error) throw error;
          result = data;
        } else if (runtimeMode === "forgetting") {
          const days = Math.max(1, typeof retentionDays === "number" ? retentionDays : 30);
          const { data, error } = await admin.rpc("run_agent_memory_forgetting", { p_user_id: userId ?? null, p_retention_days: days });
          if (error) throw error;
          result = data;
        } else {
          const pRunNightly = typeof runNightly === "boolean" ? runNightly : false;
          const pRunForgetting = typeof runForgetting === "boolean" ? runForgetting : false;
          const { data, error } = await admin.rpc("run_agent_runtime_cycle", { p_user_id: userId ?? null, p_run_nightly: pRunNightly, p_run_forgetting: pRunForgetting });
          if (error) throw error;
          result = data;
        }
        return jsonOk({ success: true, mode: runtimeMode, user_id: userId ?? null, result });
      }

      // ─── agent-task-router POST actions ───
      if (action === "auto_assign") {
        const { data: unassigned } = await supabase.from("agent_tasks")
          .select("id, title, description, priority").is("assignee_agent_id", null)
          .eq("status", "pending").order("priority", { ascending: false }).limit(20);
        if (!unassigned || unassigned.length === 0) {
          return jsonOk({ success: true, assigned: 0, message: "No unassigned tasks" });
        }
        const { data: agents } = await supabase.from("agents").select("id, display_name, department, role_title, is_active").eq("is_active", true);
        const assignments: Array<{ taskId: string; agentId: string; department: string }> = [];
        for (const task of unassigned) {
          const text = `${task.title} ${task.description ?? ""}`.toLowerCase();
          let bestDept = "開発部";
          let bestScore = 0;
          for (const [dept, skills] of Object.entries(DEPARTMENT_SKILLS)) {
            const score = skills.filter((s) => text.includes(s)).length;
            if (score > bestScore) { bestScore = score; bestDept = dept; }
          }
          const deptAgents = (agents ?? []).filter((a) => a.department === bestDept);
          if (deptAgents.length === 0) {
            const fallback = (agents ?? [])[0];
            if (fallback) assignments.push({ taskId: task.id, agentId: fallback.id, department: fallback.department ?? "未所属" });
            continue;
          }
          const selectedAgent = deptAgents[assignments.length % deptAgents.length];
          assignments.push({ taskId: task.id, agentId: selectedAgent.id, department: bestDept });
        }
        for (const a of assignments) {
          await supabase.from("agent_tasks").update({ assignee_agent_id: a.agentId, status: "in_progress" }).eq("id", a.taskId);
        }
        if (assignments.length > 0) {
          await supabase.from("app_analytics").insert({ source: "task_routing", metadata: { action: "auto_assign", assignments, count: assignments.length }, created_at: new Date().toISOString() });
        }
        return jsonOk({ success: true, assigned: assignments.length, assignments });
      }

      if (action === "escalate") {
        const { task_id, reason } = body;
        if (!task_id) return json400("task_id is required");
        const { data: ceo } = await supabase.from("agents").select("id").eq("department", "CEO室").is("supervisor_agent_id", null).limit(1).maybeSingle();
        if (!ceo) {
          return new Response(JSON.stringify({ success: false, error: "CEO agent not found" }), {
            status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
        await supabase.from("agent_tasks").update({ assignee_agent_id: ceo.id, priority: 5, status: "in_progress" }).eq("id", task_id);
        await supabase.from("app_analytics").insert({ source: "task_routing", metadata: { action: "escalate", taskId: task_id, escalatedTo: ceo.id, reason: reason ?? "" }, created_at: new Date().toISOString() });
        return jsonOk({ success: true, escalatedTo: ceo.id });
      }

      return json400("Unknown action. Valid: create_department, assign_agent, set_supervisor, record_activity, update_personality, record_memory, learn_from_conversation, runtime_cycle, auto_assign, escalate");
    }

    // ── GET ───────────────────────────────────────────────────────────────────
    if (req.method === "GET") {

      // action=departments (agent-department-manager)
      if (getAction === "departments") {
        const view = url.searchParams.get("view");
        const [{ data: agents, error }, { data: tasks }] = await Promise.all([
          supabase.from("agents").select("id, display_name, role_title, department, status, supervisor_agent_id").order("department", { ascending: true }),
          supabase.from("agent_tasks").select("assignee_agent_id, status"),
        ]);
        if (error) throw error;

        const deptMap = new Map<string, { agents: Array<Record<string, unknown>>; director: Record<string, unknown> | null; activeCount: number; totalCount: number }>();
        for (const agent of agents ?? []) {
          const dept = agent.department ?? "未所属";
          if (!deptMap.has(dept)) deptMap.set(dept, { agents: [], director: null, activeCount: 0, totalCount: 0 });
          const d = deptMap.get(dept)!;
          d.agents.push(agent);
          d.totalCount++;
          if (agent.status === "active") d.activeCount++;
          if (!agent.supervisor_agent_id) d.director = agent;
        }

        if (view === "goals") {
          const agentTaskCount = new Map<string, { total: number; completed: number }>();
          for (const t of tasks ?? []) {
            const aid = t.assignee_agent_id;
            if (!aid) continue;
            if (!agentTaskCount.has(aid)) agentTaskCount.set(aid, { total: 0, completed: 0 });
            const c = agentTaskCount.get(aid)!;
            c.total++;
            if (t.status === "completed") c.completed++;
          }
          const departmentGoals = DEFAULT_DEPARTMENTS.map((dept) => {
            const deptData = deptMap.get(dept.label);
            const deptAgentIds = (deptData?.agents ?? []).map((a) => (a as Record<string, unknown>).id as string);
            let totalTasks = 0; let completedTasks = 0;
            for (const aid of deptAgentIds) {
              const counts = agentTaskCount.get(aid);
              if (counts) { totalTasks += counts.total; completedTasks += counts.completed; }
            }
            return { ...dept, agentCount: deptData?.totalCount ?? 0, activeCount: deptData?.activeCount ?? 0, director: deptData?.director ? (deptData.director as Record<string, unknown>).display_name : null, totalTasks, completedTasks, completionRate: totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0 };
          });
          return jsonOk({ success: true, departmentGoals });
        }

        // default overview
        return jsonOk({
          success: true,
          departments: Object.fromEntries([...deptMap.entries()].map(([dept, data]) => [dept, {
            director: data.director ? (data.director as Record<string, unknown>).display_name : null,
            totalAgents: data.totalCount, activeAgents: data.activeCount,
            agents: data.agents.map((a) => ({ id: (a as Record<string, unknown>).id, display_name: (a as Record<string, unknown>).display_name, role_title: (a as Record<string, unknown>).role_title, status: (a as Record<string, unknown>).status })),
          }])),
          defaultDepartments: DEFAULT_DEPARTMENTS,
          totalAgents: (agents ?? []).length,
          totalDepartments: deptMap.size,
        });
      }

      // action=performance (agent-performance-monitor)
      if (getAction === "performance") {
        const view = url.searchParams.get("view");
        const agentId = url.searchParams.get("agent_id");
        const [agentsRes, tasksRes, memoriesRes] = await Promise.all([
          supabase.from("agents").select("id, display_name, department, role_title, is_active, metadata"),
          supabase.from("agent_tasks").select("id, assignee_agent_id, status, priority, created_at, completed_at"),
          supabase.from("agent_memories").select("agent_id, layer").eq("layer", "activity_log"),
        ]);
        const agents = agentsRes.data ?? [];
        const allTasks = tasksRes.data ?? [];
        const memories = memoriesRes.data ?? [];

        const agentScores = agents.map((agent) => {
          const agentTasks = allTasks.filter((t) => t.assignee_agent_id === agent.id);
          const completed = agentTasks.filter((t) => t.status === "completed" || t.status === "done").length;
          const total = agentTasks.length;
          const completionRate = total > 0 ? Math.round((completed / total) * 100) : 0;
          const activityCount = memories.filter((m) => m.agent_id === agent.id).length;
          const score = Math.min(100, Math.round(completionRate * 0.5 + Math.min(50, total * 5) * 0.3 + Math.min(50, activityCount * 10) * 0.2));
          return { agentId: agent.id, name: agent.display_name, department: agent.department, role: agent.role_title, isActive: agent.is_active, totalTasks: total, completedTasks: completed, completionRate, activityCount, performanceScore: score };
        });

        if (view === "agent" && agentId) {
          const agentScore = agentScores.find((a) => a.agentId === agentId);
          if (!agentScore) return new Response(JSON.stringify({ success: false, error: "Agent not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
          const agentTasks = allTasks.filter((t) => t.assignee_agent_id === agentId).map((t) => ({ id: t.id, status: t.status, priority: t.priority, createdAt: t.created_at })).slice(0, 20);
          return jsonOk({ success: true, agent: agentScore, recentTasks: agentTasks });
        }
        if (view === "alerts") {
          const alerts = agentScores.filter((a) => a.isActive && (a.performanceScore < 30 || (a.totalTasks > 5 && a.completionRate < 40))).map((a) => ({ agentId: a.agentId, name: a.name, department: a.department, score: a.performanceScore, completionRate: a.completionRate, issue: a.performanceScore < 30 ? "低パフォーマンス" : "低完了率", suggestion: a.completionRate < 40 ? "タスクの再割り当てまたは支援エージェントの追加を検討" : "タスク難易度の調整を検討" }));
          return jsonOk({ success: true, alerts, alertCount: alerts.length });
        }
        const sorted = [...agentScores].sort((a, b) => b.performanceScore - a.performanceScore);
        return jsonOk({ success: true, ranking: sorted.map((a, i) => ({ rank: i + 1, ...a })), averageScore: agentScores.length > 0 ? Math.round(agentScores.reduce((sum, a) => sum + a.performanceScore, 0) / agentScores.length) : 0 });
      }

      // action=personality (agent-personality)
      if (getAction === "personality") {
        const view = url.searchParams.get("view");
        const agentId = url.searchParams.get("agent_id");

        if (view === "memories" && agentId) {
          const { data, error } = await supabase.from("agent_memories").select("*").eq("agent_id", agentId).order("created_at", { ascending: false }).limit(50);
          if (error) throw error;
          const byLayer: Record<string, unknown[]> = {};
          for (const m of data ?? []) {
            const layer = (m.layer as string) ?? "unknown";
            if (!byLayer[layer]) byLayer[layer] = [];
            byLayer[layer].push(m);
          }
          return jsonOk({ success: true, memories: data ?? [], byLayer });
        }
        if (view === "personality" && agentId) {
          const { data: agent, error } = await supabase.from("agents").select("id, slug, display_name, role_title, department, identity_prompt, metadata").eq("id", agentId).single();
          if (error) throw error;
          return jsonOk({ success: true, agent, personality: parsePersonality(agent?.identity_prompt ?? "") });
        }

        const { data: agents, error } = await supabase.from("agents").select("id, slug, display_name, role_title, department, identity_prompt, metadata, status").order("department", { ascending: true });
        if (error) throw error;
        return jsonOk({ success: true, agents: (agents ?? []).map((a) => ({ id: a.id, slug: a.slug, display_name: a.display_name, role_title: a.role_title, department: a.department, status: a.status, personality: parsePersonality(a.identity_prompt ?? ""), hasCustomPersonality: !!(a.metadata as Record<string, unknown>)?.personality_traits })) });
      }

      // action=routing (agent-task-router)
      if (getAction === "routing") {
        const view = url.searchParams.get("view");

        if (view === "workload") {
          const [{ data: agents }, { data: tasks }] = await Promise.all([
            supabase.from("agents").select("id, display_name, department, role_title, is_active"),
            supabase.from("agent_tasks").select("assignee_agent_id, status").in("status", ["pending", "in_progress"]),
          ]);
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
          const workload = [...deptLoad.entries()].map(([dept, data]) => ({ department: dept, ...data, loadScore: data.agents > 0 ? Math.round(((data.activeTasks + data.pendingTasks) / data.agents) * 100) / 100 : 0 })).sort((a, b) => b.loadScore - a.loadScore);
          return jsonOk({ success: true, workload });
        }
        if (view === "unassigned") {
          const { data: tasks } = await supabase.from("agent_tasks").select("id, title, description, priority, status, created_at").is("assignee_agent_id", null).in("status", ["pending"]).order("created_at", { ascending: true });
          return jsonOk({ success: true, unassigned: tasks ?? [], count: (tasks ?? []).length });
        }
        if (view === "routing_log") {
          const { data: logs } = await supabase.from("app_analytics").select("metadata, created_at").eq("source", "task_routing").order("created_at", { ascending: false }).limit(50);
          return jsonOk({ success: true, logs: (logs ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), routedAt: l.created_at })) });
        }

        // summary
        const [tasksRes, agentsRes] = await Promise.all([
          supabase.from("agent_tasks").select("*", { count: "exact", head: true }).is("assignee_agent_id", null).eq("status", "pending"),
          supabase.from("agents").select("*", { count: "exact", head: true }).eq("is_active", true),
        ]);
        return jsonOk({ success: true, summary: { unassignedTasks: tasksRes.count ?? 0, activeAgents: agentsRes.count ?? 0, departments: Object.keys(DEPARTMENT_SKILLS).length } });
      }

      return json400("Unknown action. Valid GET actions: departments, performance, personality, routing");
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("agent-hub error:", err);
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

function jsonOk(data: unknown): Response {
  return new Response(JSON.stringify(data), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function json400(message: string): Response {
  return new Response(JSON.stringify({ success: false, error: message }), {
    status: 400,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Infer personality traits from identity_prompt keywords (agent-personality)
function parsePersonality(prompt: string): { traits: string[]; style: string; strengths: string[] } {
  const traits: string[] = [];
  const strengths: string[] = [];
  const traitMap: Record<string, string> = { "慎重": "慎重", "大胆": "大胆", "分析": "分析的", "論理": "論理的", "共感": "共感力", "創造": "創造的", "リーダー": "リーダーシップ", "実行": "実行力", "計画": "計画的", "柔軟": "柔軟性", "正確": "正確性", "迅速": "迅速", "戦略": "戦略的思考", "コミュニケーション": "コミュニケーション力" };
  for (const [keyword, trait] of Object.entries(traitMap)) {
    if (prompt.includes(keyword)) traits.push(trait);
  }
  if (prompt.includes("CEO") || prompt.includes("リーダー")) strengths.push("意思決定", "ビジョン策定");
  if (prompt.includes("開発") || prompt.includes("CTO")) strengths.push("技術判断", "アーキテクチャ設計");
  if (prompt.includes("営業") || prompt.includes("Sales")) strengths.push("顧客開拓", "交渉力");
  if (prompt.includes("経理") || prompt.includes("CFO")) strengths.push("財務分析", "予算管理");
  const style = traits.length > 2 ? "多面的" : traits.length > 0 ? "専門特化" : "汎用";
  return { traits, style, strengths };
}
