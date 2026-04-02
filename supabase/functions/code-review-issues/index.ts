// Code Review & GitHub Issue Manager Edge Function
// コードレビュー結果の記録・GitHub Issue 管理
//
// GET  → レビュー結果一覧 / Issue 一覧
// POST → レビュー結果記録 / Issue 作成提案

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const GITHUB_PAT = Deno.env.get("GITHUB_PAT") ?? "";
const GITHUB_REPO = "kanta13jp1/my_web_app";

// レビュー観点
const REVIEW_CATEGORIES = [
  { key: "security", label: "セキュリティ", severity: "critical" },
  { key: "performance", label: "パフォーマンス", severity: "high" },
  { key: "lint", label: "Lintエラー・型エラー", severity: "medium" },
  { key: "logic", label: "ロジックバグ", severity: "high" },
  { key: "ux", label: "UX/UI 問題", severity: "medium" },
  { key: "convention", label: "コーディング規約違反", severity: "low" },
  { key: "test", label: "テスト不足", severity: "medium" },
  { key: "docs", label: "ドキュメント不足", severity: "low" },
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
      const view = url.searchParams.get("view"); // 'reviews' | 'issues' | 'summary'
      const limit = parseInt(url.searchParams.get("limit") ?? "30", 10);

      if (view === "issues") {
        // Issue 一覧 (agent_tasks テーブルから code-review 関連を取得)
        const { data, error } = await supabase
          .from("agent_tasks")
          .select("*")
          .like("title", "%レビュー%")
          .order("created_at", { ascending: false })
          .limit(limit);

        if (error) throw error;

        return new Response(
          JSON.stringify({
            success: true,
            issues: data ?? [],
            total: (data ?? []).length,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "reviews") {
        // レビュー結果一覧 (schedule_task_runs から code-review 関連)
        const { data, error } = await supabase
          .from("schedule_task_runs")
          .select("*")
          .eq("task_name", "code-review-issues")
          .order("started_at", { ascending: false })
          .limit(limit);

        if (error) throw error;

        return new Response(
          JSON.stringify({
            success: true,
            reviews: data ?? [],
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: サマリー
      const [reviewsRes, issuesRes] = await Promise.all([
        supabase
          .from("schedule_task_runs")
          .select("*", { count: "exact", head: true })
          .eq("task_name", "code-review-issues"),
        supabase
          .from("agent_tasks")
          .select("status")
          .like("title", "%レビュー%"),
      ]);

      const issues = issuesRes.data ?? [];
      const issuesByStatus: Record<string, number> = {};
      for (const issue of issues) {
        const s = (issue.status as string) ?? "unknown";
        issuesByStatus[s] = (issuesByStatus[s] ?? 0) + 1;
      }

      return new Response(
        JSON.stringify({
          success: true,
          summary: {
            totalReviews: reviewsRes.count ?? 0,
            totalIssues: issues.length,
            issuesByStatus,
            reviewCategories: REVIEW_CATEGORIES,
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "record_review") {
        // レビュー結果を記録
        const { findings, files_reviewed, duration_ms } = body;

        const findingsList = findings ?? [];
        const hasCritical = findingsList.some(
          (f: { severity: string }) => f.severity === "critical"
        );

        const { data, error } = await supabase
          .from("schedule_task_runs")
          .insert({
            task_name: "code-review-issues",
            status: hasCritical ? "failure" : "success",
            started_at: new Date().toISOString(),
            finished_at: new Date().toISOString(),
            duration_ms: duration_ms ?? null,
            output: JSON.stringify({
              files_reviewed: files_reviewed ?? 0,
              findings: findingsList,
              findingsCount: findingsList.length,
            }),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, review: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "create_issue") {
        // レビュー指摘から Issue (agent_task) を作成
        const { title, description, category, severity, file_path } = body;

        if (!title) {
          return new Response(
            JSON.stringify({ success: false, error: "title is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const priority = severity === "critical" ? "critical"
          : severity === "high" ? "high"
          : severity === "medium" ? "medium"
          : "low";

        const { data, error } = await supabase
          .from("agent_tasks")
          .insert({
            title: `コードレビュー: ${title}`,
            description: [
              description ?? "",
              category ? `カテゴリ: ${category}` : "",
              file_path ? `ファイル: ${file_path}` : "",
            ].filter(Boolean).join("\n"),
            department: "品質管理",
            priority,
            status: "pending",
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        // GitHub Issue も作成 (GITHUB_PAT が設定されている場合)
        let githubIssueUrl = null;
        if (GITHUB_PAT) {
          try {
            const ghBody = [
              description ?? "",
              "",
              `**カテゴリ**: ${category ?? "未分類"}`,
              `**重要度**: ${severity ?? "low"}`,
              file_path ? `**ファイル**: \`${file_path}\`` : "",
              "",
              "---",
              `*自動生成: code-review-issues Edge Function*`,
            ].filter(Boolean).join("\n");

            const ghRes = await fetch(`https://api.github.com/repos/${GITHUB_REPO}/issues`, {
              method: "POST",
              headers: {
                Authorization: `token ${GITHUB_PAT}`,
                Accept: "application/vnd.github.v3+json",
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                title: `[コードレビュー] ${title}`,
                body: ghBody,
                labels: ["code-review", severity ?? "low"],
              }),
            });
            if (ghRes.ok) {
              const ghData = await ghRes.json();
              githubIssueUrl = ghData.html_url;
            }
          } catch (_ghErr) {
            // GitHub API failure should not block the response
          }
        }

        return new Response(
          JSON.stringify({ success: true, issue: data, githubIssueUrl }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "resolve_issue") {
        // Issue を解決済みにする
        const { task_id, resolution } = body;

        if (!task_id) {
          return new Response(
            JSON.stringify({ success: false, error: "task_id is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await supabase
          .from("agent_tasks")
          .update({
            status: "completed",
            output: resolution ?? "修正完了",
            completed_at: new Date().toISOString(),
          })
          .eq("id", task_id)
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, issue: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
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
    console.error("code-review-issues error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
