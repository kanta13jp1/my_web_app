import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

// Schedule task definitions matching CLAUDE.md
const SCHEDULE_TASKS = [
  { id: "daily-report", name: "日次レポート", cron: "0 0 * * *", description: "毎朝09:00 JST — AI分析・GitHub Issue修復・健全性チェック" },
  { id: "cs-check", name: "CSチェック", cron: "0 * * * *", description: "毎時 — 未返信チケット対応・バグ修正・エスカレーション" },
  { id: "weekly-sns-draft", name: "週次SNSドラフト", cron: "0 0 * * 1", description: "毎週月曜09:00 JST — 実績サマリー・SNS投稿ドラフト" },
  { id: "pr-auto-review", name: "PR自動レビュー", cron: "0 */3 * * *", description: "3時間ごと — GitHub PRコードレビュー" },
  { id: "competitor-monitoring", name: "競合モニタリング", cron: "0 22 * * *", description: "毎日07:00 JST — 競合14社のWebサイト・機能変更" },
  { id: "infra-health-check", name: "インフラヘルスチェック", cron: "30 * * * *", description: "毎時30分 — DB・テーブル・レスポンスタイム確認" },
  { id: "dependency-audit", name: "依存パッケージ監査", cron: "0 23 * * 1", description: "毎週月曜08:00 JST — 脆弱性チェック" },
  { id: "blog-draft", name: "ブログ下書き", cron: "0 23 * * *", description: "毎日08:00 JST — 技術ブログ下書き生成" },
];

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const url = new URL(req.url);
    const action = url.searchParams.get("action") ?? "list";

    // POST: Log a schedule execution result
    if (req.method === "POST") {
      const body = await req.json();
      const { taskId, status, summary, durationMs, errorMessage, artifactsCreated } = body;

      if (!taskId || !status) {
        return new Response(
          JSON.stringify({ error: "taskId and status are required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const logEntry = {
        source: "schedule-execution-logger",
        event_type: `schedule_${status}`,
        event_data: {
          taskId,
          taskName: SCHEDULE_TASKS.find(t => t.id === taskId)?.name ?? taskId,
          status, // success, failure, partial, skipped
          summary: summary ?? "",
          durationMs: durationMs ?? 0,
          errorMessage: errorMessage ?? null,
          artifactsCreated: artifactsCreated ?? [],
          executedAt: new Date().toISOString(),
        },
      };

      const { error: insertError } = await supabase
        .from("app_analytics")
        .insert(logEntry);

      if (insertError) {
        return new Response(
          JSON.stringify({ error: insertError.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ success: true, logged: logEntry.event_data }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // GET: List execution history / dashboard data
    if (action === "list") {
      const days = parseInt(url.searchParams.get("days") ?? "7");
      const since = new Date(Date.now() - days * 86400000).toISOString();

      const { data: logs, error: logsError } = await supabase
        .from("app_analytics")
        .select("*")
        .eq("source", "schedule-execution-logger")
        .gte("created_at", since)
        .order("created_at", { ascending: false })
        .limit(200);

      if (logsError) {
        return new Response(
          JSON.stringify({ error: logsError.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Build dashboard summary per task
      const taskSummaries = SCHEDULE_TASKS.map(task => {
        const taskLogs = (logs ?? []).filter(
          (l: Record<string, unknown>) => {
            const ed = l.event_data as Record<string, unknown> | null;
            return ed?.taskId === task.id;
          }
        );
        const successes = taskLogs.filter(
          (l: Record<string, unknown>) => {
            const ed = l.event_data as Record<string, unknown> | null;
            return ed?.status === "success";
          }
        ).length;
        const failures = taskLogs.filter(
          (l: Record<string, unknown>) => {
            const ed = l.event_data as Record<string, unknown> | null;
            return ed?.status === "failure";
          }
        ).length;
        const lastRun = taskLogs.length > 0
          ? (taskLogs[0].event_data as Record<string, unknown>)?.executedAt ?? null
          : null;
        const lastStatus = taskLogs.length > 0
          ? (taskLogs[0].event_data as Record<string, unknown>)?.status ?? "unknown"
          : "never_run";

        return {
          ...task,
          totalRuns: taskLogs.length,
          successes,
          failures,
          successRate: taskLogs.length > 0 ? Math.round((successes / taskLogs.length) * 100) : 0,
          lastRun,
          lastStatus,
          lastError: failures > 0
            ? (taskLogs.find(
                (l: Record<string, unknown>) => {
                  const ed = l.event_data as Record<string, unknown> | null;
                  return ed?.status === "failure";
                }
              )?.event_data as Record<string, unknown> | undefined)?.errorMessage ?? null
            : null,
        };
      });

      const overallHealth = taskSummaries.every(t => t.lastStatus === "success" || t.lastStatus === "never_run")
        ? "healthy"
        : taskSummaries.some(t => t.lastStatus === "failure")
        ? "degraded"
        : "unknown";

      return new Response(
        JSON.stringify({
          overallHealth,
          period: `${days} days`,
          tasks: taskSummaries,
          recentLogs: (logs ?? []).slice(0, 20).map((l: Record<string, unknown>) => l.event_data),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // action=task_detail — detailed history for one task
    if (action === "task_detail") {
      const taskId = url.searchParams.get("taskId");
      if (!taskId) {
        return new Response(
          JSON.stringify({ error: "taskId is required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: logs } = await supabase
        .from("app_analytics")
        .select("*")
        .eq("source", "schedule-execution-logger")
        .order("created_at", { ascending: false })
        .limit(100);

      const taskLogs = (logs ?? []).filter(
        (l: Record<string, unknown>) => {
          const ed = l.event_data as Record<string, unknown> | null;
          return ed?.taskId === taskId;
        }
      );

      const taskDef = SCHEDULE_TASKS.find(t => t.id === taskId);

      return new Response(
        JSON.stringify({
          task: taskDef ?? { id: taskId, name: taskId },
          totalRuns: taskLogs.length,
          history: taskLogs.map((l: Record<string, unknown>) => l.event_data),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // action=health_summary — quick health for dashboard widget
    if (action === "health_summary") {
      const { data: recentLogs } = await supabase
        .from("app_analytics")
        .select("*")
        .eq("source", "schedule-execution-logger")
        .gte("created_at", new Date(Date.now() - 86400000).toISOString())
        .order("created_at", { ascending: false })
        .limit(50);

      const failedTasks = (recentLogs ?? []).filter(
        (l: Record<string, unknown>) => {
          const ed = l.event_data as Record<string, unknown> | null;
          return ed?.status === "failure";
        }
      );

      return new Response(
        JSON.stringify({
          totalTaskTypes: SCHEDULE_TASKS.length,
          executionsToday: (recentLogs ?? []).length,
          failuresToday: failedTasks.length,
          health: failedTasks.length === 0 ? "healthy" : "needs_attention",
          failedTaskIds: [...new Set(failedTasks.map(
            (l: Record<string, unknown>) => {
              const ed = l.event_data as Record<string, unknown> | null;
              return ed?.taskId;
            }
          ))],
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: "Unknown action", validActions: ["list", "task_detail", "health_summary"] }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
