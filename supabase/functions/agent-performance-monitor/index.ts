// Agent Performance Monitor Edge Function
// エージェント個別パフォーマンス監視
// - タスク完了率 / 応答時間 / 品質スコア
// - 部署内ランキング
// - パフォーマンスアラート
//
// GET  → エージェント別スコア / ランキング / アラート
// POST → パフォーマンス記録

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

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'ranking' | 'agent' | 'alerts'
      const agentId = url.searchParams.get("agent_id");

      const [agentsRes, tasksRes, memoriesRes] = await Promise.all([
        adminClient.from("agents").select("id, display_name, department, role_title, is_active, metadata"),
        adminClient.from("agent_tasks").select("id, assignee_agent_id, status, priority, created_at, completed_at"),
        adminClient.from("agent_memories").select("agent_id, layer").eq("layer", "activity_log"),
      ]);

      const agents = agentsRes.data ?? [];
      const tasks = tasksRes.data ?? [];
      const memories = memoriesRes.data ?? [];

      // エージェント別スコア算出
      const agentScores = agents.map((agent) => {
        const agentTasks = tasks.filter((t) => t.assignee_agent_id === agent.id);
        const completed = agentTasks.filter((t) => t.status === "completed" || t.status === "done").length;
        const total = agentTasks.length;
        const completionRate = total > 0 ? Math.round((completed / total) * 100) : 0;

        // メモリ活動量
        const activityCount = memories.filter((m) => m.agent_id === agent.id).length;

        // パフォーマンススコア (0-100)
        const score = Math.min(100, Math.round(
          completionRate * 0.5 +
          Math.min(50, total * 5) * 0.3 +
          Math.min(50, activityCount * 10) * 0.2
        ));

        return {
          agentId: agent.id,
          name: agent.display_name,
          department: agent.department,
          role: agent.role_title,
          isActive: agent.is_active,
          totalTasks: total,
          completedTasks: completed,
          completionRate,
          activityCount,
          performanceScore: score,
        };
      });

      if (view === "agent" && agentId) {
        const agentScore = agentScores.find((a) => a.agentId === agentId);
        if (!agentScore) {
          return new Response(
            JSON.stringify({ success: false, error: "Agent not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // 詳細タスクリスト
        const agentTasks = tasks
          .filter((t) => t.assignee_agent_id === agentId)
          .map((t) => ({ id: t.id, status: t.status, priority: t.priority, createdAt: t.created_at }))
          .slice(0, 20);

        return new Response(
          JSON.stringify({ success: true, agent: agentScore, recentTasks: agentTasks }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "alerts") {
        // パフォーマンスアラート
        const alerts = agentScores
          .filter((a) => a.isActive && (a.performanceScore < 30 || (a.totalTasks > 5 && a.completionRate < 40)))
          .map((a) => ({
            agentId: a.agentId,
            name: a.name,
            department: a.department,
            score: a.performanceScore,
            completionRate: a.completionRate,
            issue: a.performanceScore < 30 ? "低パフォーマンス" : "低完了率",
            suggestion: a.completionRate < 40
              ? "タスクの再割り当てまたは支援エージェントの追加を検討"
              : "タスク難易度の調整を検討",
          }));

        return new Response(
          JSON.stringify({ success: true, alerts, alertCount: alerts.length }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: ランキング
      const sorted = [...agentScores].sort((a, b) => b.performanceScore - a.performanceScore);

      return new Response(
        JSON.stringify({
          success: true,
          ranking: sorted.map((a, i) => ({ rank: i + 1, ...a })),
          averageScore: agentScores.length > 0
            ? Math.round(agentScores.reduce((sum, a) => sum + a.performanceScore, 0) / agentScores.length)
            : 0,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action, agent_id } = body;

      if (action === "record_activity") {
        if (!agent_id) {
          return new Response(
            JSON.stringify({ success: false, error: "agent_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { activity_type, details } = body;

        const { data, error } = await adminClient
          .from("agent_memories")
          .insert({
            agent_id,
            layer: "activity_log",
            content: `[${activity_type ?? "activity"}] ${details ?? ""}`,
            metadata: { type: activity_type, details, recorded_at: new Date().toISOString() },
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, memory: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
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
    console.error("agent-performance-monitor error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
