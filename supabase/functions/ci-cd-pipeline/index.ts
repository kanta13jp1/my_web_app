// CI/CD Pipeline Edge Function
// CI/CDパイプライン管理 (GitHub Actions/Claude Code競合)
// - ビルド・デプロイ記録
// - パイプライン実行ログ
// - デプロイ統計
// - ロールバック管理
//
// GET  → パイプライン一覧 / 実行履歴 / 統計
// POST → パイプライン実行 / 記録 / ロールバック

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

      if (view === "stats") {
        const { data: runs } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "pipeline_run");
        const total = (runs ?? []).length;
        let success = 0, failed = 0;
        for (const r of runs ?? []) {
          const meta = r.metadata as Record<string, unknown>;
          if (meta.status === "success") success++;
          else if (meta.status === "failed") failed++;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { totalRuns: total, successCount: success, failedCount: failed, successRate: total > 0 ? Math.round(success / total * 100) : 0 },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "pipelines") {
        const { data: pipelines } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "pipeline_config").order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          pipelines: (pipelines ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: recent runs
      const pipelineId = url.searchParams.get("pipeline_id");
      let query = adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "pipeline_run").order("created_at", { ascending: false });
      if (pipelineId) {
        query = query.eq("metadata->>pipeline_id", pipelineId);
      }
      const { data: runs } = await query.limit(50);
      return new Response(JSON.stringify({
        success: true,
        runs: (runs ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_pipeline") {
        const { name, trigger, steps, branch } = body;
        if (!name) {
          return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const pipelineId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "pipeline_config",
          metadata: {
            pipeline_id: pipelineId, name,
            trigger: trigger ?? "manual",
            steps: steps ?? ["build", "test", "deploy"],
            branch: branch ?? "main", active: true,
          },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, pipelineId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_run") {
        const { pipeline_id, status, duration_ms, commit_sha, logs, steps_result } = body;
        if (!pipeline_id || !status) {
          return new Response(JSON.stringify({ success: false, error: "pipeline_id and status required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const runId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "pipeline_run",
          metadata: {
            run_id: runId, pipeline_id, status,
            duration_ms: duration_ms ?? 0,
            commit_sha: commit_sha ?? null,
            logs: logs ?? null,
            steps_result: steps_result ?? null,
          },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, runId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "rollback") {
        const { pipeline_id, target_run_id, reason } = body;
        if (!pipeline_id || !target_run_id) {
          return new Response(JSON.stringify({ success: false, error: "pipeline_id and target_run_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const rollbackId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "pipeline_run",
          metadata: {
            run_id: rollbackId, pipeline_id,
            status: "rollback", target_run_id,
            reason: reason ?? null,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, rollbackId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
