// Schedule Health Check Edge Function
// Claude Code Schedule タスクの実行状況を監視し、失敗タスクの改善を提案
//
// GET  → Schedule タスク実行状況サマリー + 失敗検知 + 改善提案
// POST → 失敗タスクの自動リトライ / 改善タスク登録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// 定義済み Schedule タスク一覧
const SCHEDULE_TASKS = [
  { name: "daily-report", cron: "0 9 * * *", description: "日次レポート生成 (毎朝 09:00 JST)" },
  { name: "cs-check", cron: "0 * * * *", description: "CS対応・バグ修正 (毎時)" },
  { name: "weekly-sns-draft", cron: "0 9 * * 1", description: "週次SNSドラフト (月曜 09:00)" },
  { name: "pr-auto-review", cron: "0 */3 * * *", description: "PR自動レビュー (3時間ごと)" },
  { name: "competitor-monitoring", cron: "0 7 * * *", description: "競合モニタリング (毎日 07:00)" },
  { name: "infra-health-check", cron: "30 * * * *", description: "インフラヘルスチェック (毎時30分)" },
  { name: "dependency-audit", cron: "0 8 * * 1", description: "依存パッケージ監査 (月曜 08:00)" },
  { name: "blog-draft", cron: "0 8 * * *", description: "技術ブログ下書き生成 (毎日 08:00)" },
  { name: "edge-function-ui-check", cron: "0 * * * *", description: "Edge Function UI連携チェック (毎時)" },
  { name: "code-review-issues", cron: "0 */3 * * *", description: "コードレビュー+Issue発行 (3時間ごと)" },
  { name: "issue-auto-fix", cron: "0 */2 * * *", description: "GitHub Issue自動修正 (2時間ごと)" },
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
      const hours = parseInt(url.searchParams.get("hours") ?? "24", 10);
      const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();

      // 直近の実行ログを取得
      const { data: runs, error } = await supabase
        .from("schedule_task_runs")
        .select("*")
        .gte("started_at", since)
        .order("started_at", { ascending: false });

      if (error) throw error;

      const runsList = runs ?? [];

      // タスク別集計
      const taskSummary: Record<string, {
        total: number;
        success: number;
        failure: number;
        skipped: number;
        running: number;
        lastRun: string | null;
        lastStatus: string | null;
        avgDuration: number;
      }> = {};

      for (const task of SCHEDULE_TASKS) {
        const taskRuns = runsList.filter((r) => r.task_name === task.name);
        const successRuns = taskRuns.filter((r) => r.status === "success");
        const failureRuns = taskRuns.filter((r) => r.status === "failure");
        const durations = taskRuns
          .filter((r) => r.duration_ms != null)
          .map((r) => r.duration_ms as number);

        taskSummary[task.name] = {
          total: taskRuns.length,
          success: successRuns.length,
          failure: failureRuns.length,
          skipped: taskRuns.filter((r) => r.status === "skipped").length,
          running: taskRuns.filter((r) => r.status === "running").length,
          lastRun: taskRuns[0]?.started_at ?? null,
          lastStatus: taskRuns[0]?.status ?? null,
          avgDuration: durations.length > 0
            ? Math.round(durations.reduce((a, b) => a + b, 0) / durations.length)
            : 0,
        };
      }

      // 失敗タスクの改善提案を生成
      const improvements: Array<{
        task: string;
        issue: string;
        suggestion: string;
        priority: string;
      }> = [];

      for (const [taskName, summary] of Object.entries(taskSummary)) {
        // 直近で失敗が続いている
        if (summary.failure > 0 && summary.lastStatus === "failure") {
          const failRate = summary.total > 0
            ? Math.round((summary.failure / summary.total) * 100)
            : 0;

          improvements.push({
            task: taskName,
            issue: `直近 ${hours}h で ${summary.failure}/${summary.total} 回失敗 (失敗率 ${failRate}%)`,
            suggestion: failRate > 50
              ? "タスクのロジックを見直し。エラーログを確認して根本原因を特定"
              : "間欠的な失敗。ネットワークやAPI制限の可能性。リトライロジックを追加",
            priority: failRate > 50 ? "high" : "medium",
          });
        }

        // 実行されていないタスク
        if (summary.total === 0) {
          const taskDef = SCHEDULE_TASKS.find((t) => t.name === taskName);
          improvements.push({
            task: taskName,
            issue: `直近 ${hours}h で未実行`,
            suggestion: `Schedule 登録を確認: ${taskDef?.cron ?? "cron未設定"}`,
            priority: "high",
          });
        }

        // 実行時間が長すぎる
        if (summary.avgDuration > 120000) {
          improvements.push({
            task: taskName,
            issue: `平均実行時間 ${Math.round(summary.avgDuration / 1000)}秒 (2分超過)`,
            suggestion: "処理の分割やキャッシュ導入を検討",
            priority: "low",
          });
        }
      }

      // 全体のヘルススコア
      const totalRuns = runsList.length;
      const totalFailures = runsList.filter((r) => r.status === "failure").length;
      const healthScore = totalRuns > 0
        ? Math.round(((totalRuns - totalFailures) / totalRuns) * 100)
        : 100;

      return new Response(
        JSON.stringify({
          success: true,
          period: { hours, since },
          healthScore,
          healthStatus: healthScore >= 90 ? "healthy" : healthScore >= 70 ? "degraded" : "unhealthy",
          scheduleTasks: SCHEDULE_TASKS,
          taskSummary,
          improvements: improvements.sort((a, b) =>
            a.priority === "high" ? -1 : b.priority === "high" ? 1 : 0
          ),
          totalRuns,
          totalFailures,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "register_fix_task") {
        // 改善タスクを agent_tasks に登録
        const { task_name, issue, suggestion } = body;

        if (!task_name || !issue) {
          return new Response(
            JSON.stringify({ success: false, error: "task_name and issue are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await supabase
          .from("agent_tasks")
          .insert({
            title: `Schedule修正: ${task_name}`,
            description: `問題: ${issue}\n提案: ${suggestion ?? "調査が必要"}`,
            department: "インフラ・運用",
            priority: "high",
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

      if (action === "record_check") {
        // ヘルスチェック実行結果を記録
        const { results } = body;

        const { data, error } = await supabase
          .from("schedule_task_runs")
          .insert({
            task_name: "schedule-health-check",
            status: results?.healthScore >= 70 ? "success" : "failure",
            started_at: new Date().toISOString(),
            finished_at: new Date().toISOString(),
            output: JSON.stringify(results ?? {}),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, run: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action. Use 'register_fix_task' or 'record_check'" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("schedule-health-check error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
