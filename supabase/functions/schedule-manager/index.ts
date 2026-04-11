// schedule-manager — Consolidated Schedule Monitoring EF
// Merges: schedule-execution-logger + schedule-health-check + schedule-result-tracker + schedule-task-monitor
//
// GET  ?action=list              → execution log dashboard (schedule-execution-logger)
// GET  ?action=task_detail       → per-task history (schedule-execution-logger)
// GET  ?action=health_summary    → quick health widget (schedule-execution-logger)
// GET  ?action=health            → detailed health + improvements (schedule-health-check)
// GET  ?action=results           → result tracker (schedule-result-tracker)
// GET  ?action=monitor           → raw run log (schedule-task-monitor)
//
// POST { action: "log_execution" }     → log execution (schedule-execution-logger)
// POST { action: "register_fix_task" } → create fix task (schedule-health-check)
// POST { action: "record_check" }      → record health check (schedule-health-check)
// POST { action: "record_result" }     → record result (schedule-result-tracker)
// POST { action: "log_task" }          → log raw run (schedule-task-monitor)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// Unified schedule task list (superset of all 3 EFs)
const SCHEDULE_TASKS = [
  { id: "daily-report",          key: "daily-report",          name: "日次レポート",                 cron: "0 0 * * *",   schedule: "毎朝 09:00 JST",     description: "毎朝09:00 JST — AI分析・GitHub Issue修復・健全性チェック" },
  { id: "cs-check",              key: "cs-check",              name: "CSチェック",                    cron: "0 * * * *",   schedule: "毎時",                description: "毎時 — 未返信チケット対応・バグ修正・エスカレーション" },
  { id: "github-issue-fix",      key: "github-issue-fix",      name: "GitHub Issue自動修正",          cron: "0 1 * * *",   schedule: "毎日10:00 JST",      description: "毎日10:00 JST — Open Issueを自動対応・クローズ" },
  { id: "weekly-sns-draft",      key: "weekly-sns-draft",      name: "週次SNSドラフト",               cron: "0 0 * * 1",   schedule: "毎週月曜 09:00 JST", description: "毎週月曜09:00 JST — 実績サマリー・SNS投稿ドラフト" },
  { id: "pr-auto-review",        key: "pr-auto-review",        name: "PR自動レビュー",                cron: "0 */3 * * *", schedule: "3時間ごと",           description: "3時間ごと — GitHub PRコードレビュー" },
  { id: "competitor-monitoring", key: "competitor-monitoring", name: "競合モニタリング",               cron: "0 22 * * *",  schedule: "毎日 07:00 JST",     description: "毎日07:00 JST — 競合21社のWebサイト・機能変更モニタリング" },
  { id: "infra-health-check",    key: "infra-health-check",    name: "インフラヘルスチェック",         cron: "30 * * * *",  schedule: "毎時30分",            description: "毎時30分 — DB・テーブル・レスポンスタイム確認" },
  { id: "dependency-audit",      key: "dependency-audit",      name: "依存パッケージ監査",            cron: "0 23 * * 1",  schedule: "毎週月曜 08:00 JST", description: "毎週月曜08:00 JST — 脆弱性チェック" },
  { id: "blog-draft",            key: "blog-draft",            name: "ブログ下書き",                  cron: "0 23 * * *",  schedule: "毎日 08:00 JST",     description: "毎日08:00 JST — 技術ブログ下書き生成" },
  { id: "edge-function-ui-check",key: "edge-function-ui-check",name: "Edge Function UI連携チェック",  cron: "0 * * * *",   schedule: "毎時",                description: "毎時 — Edge Function UI導線チェック" },
  { id: "code-review-issues",    key: "code-review-issue",     name: "コードレビュー・Issue発行",     cron: "0 */3 * * *", schedule: "3時間ごと",           description: "3時間ごと — コードレビュー+Issue発行" },
  { id: "issue-auto-fix",        key: "issue-auto-fix",        name: "Issue自動修正",                 cron: "0 */2 * * *", schedule: "2時間ごと",           description: "2時間ごと — GitHub Issue自動修正" },
  { id: "schedule-run-history",  key: "schedule-run-history",  name: "スケジュール実行履歴",           cron: "",            schedule: "オンデマンド",        description: "オンデマンド — 各タスク実行履歴をEFでUI表示" },
];

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const url = new URL(req.url);
    const getAction = url.searchParams.get("action") ?? "list";

    // ── POST ──────────────────────────────────────────────────────────────────
    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      // log_execution (schedule-execution-logger POST)
      if (action === "log_execution") {
        const { taskId, status, summary, durationMs, errorMessage, artifactsCreated } = body;
        if (!taskId || !status) {
          return json400("taskId and status are required");
        }
        const { error } = await supabase.from("app_analytics").insert({
          source: "schedule-execution-logger",
          metadata: {
            event_type: "schedule_execution",
            taskId,
            taskName: SCHEDULE_TASKS.find((t) => t.id === taskId)?.name ?? taskId,
            status,
            summary: summary ?? "",
            durationMs: durationMs ?? 0,
            errorMessage: errorMessage ?? null,
            artifactsCreated: artifactsCreated ?? [],
            executedAt: new Date().toISOString(),
          },
        });
        if (error) throw error;
        return jsonOk({ success: true, logged: { taskId, status } });
      }

      // register_fix_task (schedule-health-check POST register_fix_task)
      if (action === "register_fix_task") {
        const { task_name, issue, suggestion } = body;
        if (!task_name || !issue) {
          return json400("task_name and issue are required");
        }
        const { data, error } = await supabase.from("agent_tasks").insert({
          title: `Schedule修正: ${task_name}`,
          description: `問題: ${issue}\n提案: ${suggestion ?? "調査が必要"}`,
          department: "インフラ・運用",
          priority: "high",
          status: "pending",
          created_at: new Date().toISOString(),
        }).select().single();
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, task: data }), {
          status: 201,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // record_check (schedule-health-check POST record_check)
      if (action === "record_check") {
        const { results } = body;
        const { data, error } = await supabase.from("schedule_task_runs").insert({
          task_name: "schedule-health-check",
          status: (results?.healthScore ?? 0) >= 70 ? "success" : "failure",
          started_at: new Date().toISOString(),
          finished_at: new Date().toISOString(),
          output: JSON.stringify(results ?? {}),
        }).select().single();
        if (error) throw error;
        return jsonOk({ success: true, run: data });
      }

      // record_result (schedule-result-tracker POST record)
      if (action === "record_result") {
        const { task, status, duration_ms, details, error_message } = body;
        if (!task || !status) {
          return json400("task and status are required");
        }
        const resultId = crypto.randomUUID();
        const { error } = await supabase.from("app_analytics").insert({
          source: "schedule_result",
          metadata: {
            result_id: resultId, task, status,
            duration_ms: duration_ms ?? 0,
            details: details ?? null,
            error_message: error_message ?? null,
            completed_at: new Date().toISOString(),
          },
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, resultId }), {
          status: 201,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // log_task (schedule-task-monitor POST)
      if (action === "log_task") {
        const { task_id, status, started_at, finished_at, summary, error_message } = body;
        if (!task_id || !status) {
          return json400("task_id and status are required");
        }
        const normalizedStatus = status === "failure" ? "error" : status;
        const validStatuses = ["running", "success", "error", "skipped"];
        if (!validStatuses.includes(normalizedStatus)) {
          return json400(`Invalid status: ${status}`);
        }
        const { data, error } = await supabase.from("schedule_task_runs").insert({
          task_id,
          status: normalizedStatus,
          started_at: started_at ?? new Date().toISOString(),
          finished_at: finished_at ?? (normalizedStatus !== "running" ? new Date().toISOString() : null),
          summary: summary ?? null,
          error_message: error_message ?? null,
        }).select().single();
        if (error) throw error;
        return jsonOk({ success: true, run: data });
      }

      return json400("Unknown action. Valid: log_execution, register_fix_task, record_check, record_result, log_task");
    }

    // ── GET ───────────────────────────────────────────────────────────────────
    if (req.method === "GET") {

      // action=list (schedule-execution-logger: dashboard)
      if (getAction === "list") {
        const days = parseInt(url.searchParams.get("days") ?? "7", 10);
        const since = new Date(Date.now() - days * 86400000).toISOString();
        const { data: logs, error } = await supabase.from("app_analytics")
          .select("*").eq("source", "schedule-execution-logger")
          .gte("created_at", since).order("created_at", { ascending: false }).limit(200);
        if (error) throw error;

        const taskSummaries = SCHEDULE_TASKS.map((task) => {
          const taskLogs = (logs ?? []).filter((l: Record<string, unknown>) => {
            const m = l.metadata as Record<string, unknown> | null;
            return m?.taskId === task.id;
          });
          const successes = taskLogs.filter((l: Record<string, unknown>) => (l.metadata as Record<string, unknown> | null)?.status === "success").length;
          const failures = taskLogs.filter((l: Record<string, unknown>) => (l.metadata as Record<string, unknown> | null)?.status === "failure").length;
          const lastRun = taskLogs.length > 0 ? ((taskLogs[0].metadata as Record<string, unknown>)?.executedAt ?? null) : null;
          const lastStatus = taskLogs.length > 0 ? ((taskLogs[0].metadata as Record<string, unknown>)?.status ?? "unknown") : "never_run";
          return {
            ...task,
            totalRuns: taskLogs.length,
            successes,
            failures,
            successRate: taskLogs.length > 0 ? Math.round((successes / taskLogs.length) * 100) : 0,
            lastRun,
            lastStatus,
            lastError: failures > 0 ? ((taskLogs.find((l: Record<string, unknown>) => (l.metadata as Record<string, unknown> | null)?.status === "failure")?.metadata as Record<string, unknown> | undefined)?.errorMessage ?? null) : null,
          };
        });

        const overallHealth = taskSummaries.every((t) => t.lastStatus === "success" || t.lastStatus === "never_run")
          ? "healthy"
          : taskSummaries.some((t) => t.lastStatus === "failure") ? "degraded" : "unknown";

        return jsonOk({
          overallHealth,
          period: `${days} days`,
          tasks: taskSummaries,
          recentLogs: (logs ?? []).slice(0, 20).map((l: Record<string, unknown>) => l.metadata),
        });
      }

      // action=task_detail (schedule-execution-logger: task detail)
      if (getAction === "task_detail") {
        const taskId = url.searchParams.get("taskId");
        if (!taskId) return json400("taskId is required");
        const { data: taskLogs } = await supabase.from("app_analytics").select("*")
          .eq("source", "schedule-execution-logger")
          .filter("metadata->>taskId", "eq", taskId)
          .order("created_at", { ascending: false }).limit(100);
        const taskDef = SCHEDULE_TASKS.find((t) => t.id === taskId);
        return jsonOk({
          task: taskDef ?? { id: taskId, name: taskId },
          totalRuns: (taskLogs ?? []).length,
          history: (taskLogs ?? []).map((l: Record<string, unknown>) => l.metadata),
        });
      }

      // action=health_summary (schedule-execution-logger: quick widget)
      if (getAction === "health_summary") {
        const { data: recentLogs } = await supabase.from("app_analytics").select("*")
          .eq("source", "schedule-execution-logger")
          .gte("created_at", new Date(Date.now() - 86400000).toISOString())
          .order("created_at", { ascending: false }).limit(50);
        const failedTasks = (recentLogs ?? []).filter((l: Record<string, unknown>) => (l.metadata as Record<string, unknown> | null)?.status === "failure");
        return jsonOk({
          totalTaskTypes: SCHEDULE_TASKS.length,
          executionsToday: (recentLogs ?? []).length,
          failuresToday: failedTasks.length,
          health: failedTasks.length === 0 ? "healthy" : "needs_attention",
          failedTaskIds: [...new Set(failedTasks.map((l: Record<string, unknown>) => (l.metadata as Record<string, unknown> | null)?.taskId))],
        });
      }

      // action=health (schedule-health-check: full health + improvements)
      if (getAction === "health") {
        const hours = parseInt(url.searchParams.get("hours") ?? "24", 10);
        const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
        const { data: runs, error } = await supabase.from("schedule_task_runs")
          .select("*").gte("started_at", since).order("started_at", { ascending: false });
        if (error) throw error;
        const runsList = runs ?? [];

        const taskSummary: Record<string, {
          total: number; success: number; failure: number; skipped: number; running: number;
          lastRun: string | null; lastStatus: string | null; avgDuration: number;
        }> = {};

        for (const task of SCHEDULE_TASKS) {
          const taskRuns = runsList.filter((r) => r.task_name === task.id || r.task_name === task.key);
          const durations = taskRuns.filter((r) => r.duration_ms != null).map((r) => r.duration_ms as number);
          taskSummary[task.id] = {
            total: taskRuns.length,
            success: taskRuns.filter((r) => r.status === "success").length,
            failure: taskRuns.filter((r) => r.status === "failure" || r.status === "error").length,
            skipped: taskRuns.filter((r) => r.status === "skipped").length,
            running: taskRuns.filter((r) => r.status === "running").length,
            lastRun: taskRuns[0]?.started_at ?? null,
            lastStatus: taskRuns[0]?.status ?? null,
            avgDuration: durations.length > 0 ? Math.round(durations.reduce((a, b) => a + b, 0) / durations.length) : 0,
          };
        }

        const improvements: Array<{ task: string; issue: string; suggestion: string; priority: string }> = [];
        for (const [taskName, summary] of Object.entries(taskSummary)) {
          if (summary.failure > 0 && summary.lastStatus === "failure") {
            const failRate = summary.total > 0 ? Math.round((summary.failure / summary.total) * 100) : 0;
            improvements.push({
              task: taskName,
              issue: `直近 ${hours}h で ${summary.failure}/${summary.total} 回失敗 (失敗率 ${failRate}%)`,
              suggestion: failRate > 50 ? "タスクのロジックを見直し。エラーログを確認して根本原因を特定" : "間欠的な失敗。リトライロジックを追加",
              priority: failRate > 50 ? "high" : "medium",
            });
          }
          if (summary.total === 0) {
            improvements.push({
              task: taskName,
              issue: `直近 ${hours}h で未実行`,
              suggestion: `Schedule 登録を確認`,
              priority: "high",
            });
          }
          if (summary.avgDuration > 120000) {
            improvements.push({
              task: taskName,
              issue: `平均実行時間 ${Math.round(summary.avgDuration / 1000)}秒 (2分超過)`,
              suggestion: "処理の分割やキャッシュ導入を検討",
              priority: "low",
            });
          }
        }

        const totalRuns = runsList.length;
        const totalFailures = runsList.filter((r) => r.status === "failure" || r.status === "error").length;
        const healthScore = totalRuns > 0 ? Math.round(((totalRuns - totalFailures) / totalRuns) * 100) : 100;

        return jsonOk({
          success: true,
          period: { hours, since },
          healthScore,
          healthStatus: healthScore >= 90 ? "healthy" : healthScore >= 70 ? "degraded" : "unhealthy",
          taskSummary,
          improvements: improvements.sort((a, b) => {
            const order: Record<string, number> = { high: 0, medium: 1, low: 2 };
            return (order[a.priority] ?? 3) - (order[b.priority] ?? 3);
          }),
          totalRuns,
          totalFailures,
        });
      }

      // action=results (schedule-result-tracker: result tracker)
      if (getAction === "results") {
        const view = url.searchParams.get("view");
        const taskKey = url.searchParams.get("task");

        if (view === "tasks") {
          return jsonOk({ success: true, tasks: SCHEDULE_TASKS.map((t) => ({ key: t.key, name: t.name, schedule: t.schedule })) });
        }
        if (view === "failures") {
          const { data: failures } = await supabase.from("app_analytics").select("metadata, created_at")
            .eq("source", "schedule_result").eq("metadata->>status", "failed")
            .order("created_at", { ascending: false }).limit(50);
          return jsonOk({ success: true, failures: (failures ?? []).map((f) => ({ ...(f.metadata as Record<string, unknown>), createdAt: f.created_at })) });
        }
        if (view === "stats") {
          const { data: results } = await supabase.from("app_analytics").select("metadata").eq("source", "schedule_result");
          let success = 0, failed = 0, skipped = 0;
          const taskStats: Record<string, { success: number; failed: number; lastRun: string }> = {};
          for (const r of results ?? []) {
            const meta = r.metadata as Record<string, unknown>;
            const status = meta.status as string;
            const task = meta.task as string;
            if (status === "success") success++;
            else if (status === "failed") failed++;
            else skipped++;
            if (!taskStats[task]) taskStats[task] = { success: 0, failed: 0, lastRun: "" };
            if (status === "success") taskStats[task].success++;
            else if (status === "failed") taskStats[task].failed++;
            taskStats[task].lastRun = (meta.completed_at as string) ?? "";
          }
          const total = (results ?? []).length;
          return jsonOk({ success: true, stats: { total, success, failed, skipped, successRate: total > 0 ? Math.round(success / total * 100) : 0 }, taskStats });
        }

        let query = supabase.from("app_analytics").select("metadata, created_at")
          .eq("source", "schedule_result").order("created_at", { ascending: false });
        if (taskKey) query = query.eq("metadata->>task", taskKey);
        const { data: results } = await query.limit(100);
        return jsonOk({ success: true, results: (results ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) });
      }

      // action=monitor (schedule-task-monitor: raw run log)
      if (getAction === "monitor") {
        const taskId = url.searchParams.get("task");
        const status = url.searchParams.get("status");
        const limit = parseInt(url.searchParams.get("limit") ?? "50", 10);

        let query = supabase.from("schedule_task_runs").select("*")
          .order("started_at", { ascending: false }).limit(limit);
        if (taskId) query = query.eq("task_id", taskId);
        if (status) query = query.eq("status", status);

        const { data, error } = await query;
        if (error) throw error;
        const runs = data ?? [];
        return jsonOk({
          success: true,
          runs,
          stats: {
            total_runs: runs.length,
            success_count: runs.filter((r) => r.status === "success").length,
            error_count: runs.filter((r) => r.status === "error").length,
            last_run_at: runs.length > 0 ? runs[0].started_at : null,
          },
        });
      }

      return json400("Unknown action. Valid GET actions: list, task_detail, health_summary, health, results, monitor");
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("schedule-manager error:", err);
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
