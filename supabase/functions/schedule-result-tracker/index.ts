// Schedule Result Tracker Edge Function
// Claude Code Schedule実行結果追跡
// - Schedule タスク実行結果の記録・確認
// - 管理者ダッシュボードでの結果表示用
// - 失敗タスクの検出・改善提案
//
// GET  → 結果一覧 / タスク別 / 失敗一覧 / 統計
// POST → 結果記録 / ステータス更新

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const SCHEDULE_TASKS = [
  { key: "daily-report", name: "日次レポート", schedule: "毎朝 09:00 JST" },
  { key: "cs-check", name: "CSチェック", schedule: "毎時" },
  { key: "weekly-sns-draft", name: "週次SNSドラフト", schedule: "毎週月曜 09:00 JST" },
  { key: "pr-auto-review", name: "PR自動レビュー", schedule: "3時間ごと" },
  { key: "competitor-monitoring", name: "競合モニタリング", schedule: "毎日 07:00 JST" },
  { key: "infra-health-check", name: "インフラヘルスチェック", schedule: "毎時30分" },
  { key: "dependency-audit", name: "依存パッケージ監査", schedule: "毎週月曜 08:00 JST" },
  { key: "blog-draft", name: "ブログ下書き", schedule: "毎日 08:00 JST" },
  { key: "edge-function-ui-check", name: "Edge Function UI連携チェック", schedule: "毎時" },
  { key: "code-review-issue", name: "コードレビュー・Issue発行", schedule: "3時間ごと" },
  { key: "issue-auto-fix", name: "Issue自動修正", schedule: "3時間ごと" },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");
      const taskKey = url.searchParams.get("task");

      if (view === "tasks") {
        return new Response(JSON.stringify({ success: true, tasks: SCHEDULE_TASKS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "failures") {
        const { data: failures } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "schedule_result").eq("metadata->>status", "failed")
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({
          success: true,
          failures: (failures ?? []).map((f) => ({ ...(f.metadata as Record<string, unknown>), createdAt: f.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: results } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "schedule_result");
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
        return new Response(JSON.stringify({
          success: true,
          stats: { total: (results ?? []).length, success, failed, skipped, successRate: (results ?? []).length > 0 ? Math.round(success / (results ?? []).length * 100) : 0 },
          taskStats,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default or task-specific results
      let query = adminClient.from("app_analytics").select("metadata, created_at")
        .eq("source", "schedule_result")
        .order("created_at", { ascending: false });
      if (taskKey) {
        query = query.eq("metadata->>task", taskKey);
      }
      const { data: results } = await query.limit(100);
      return new Response(JSON.stringify({
        success: true,
        results: (results ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "record") {
        const { task, status, duration_ms, details, error_message } = body;
        if (!task || !status) {
          return new Response(JSON.stringify({ success: false, error: "task and status required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const resultId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: "00000000-0000-0000-0000-000000000000", source: "schedule_result",
          metadata: {
            result_id: resultId, task, status,
            duration_ms: duration_ms ?? 0,
            details: details ?? null,
            error_message: error_message ?? null,
            completed_at: new Date().toISOString(),
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, resultId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
