// Schedule Task Monitor Edge Function
// Claude Code Schedule 実行ログの取得・失敗検知・管理ダッシュボード連携
//
// GET  → 実行ログ一覧取得 (最新50件)
// POST → 実行ログ記録 (Schedule から呼び出し)
//
// schema: schedule_task_runs (task_id, status: running|success|error|skipped, ...)

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
      const taskId = url.searchParams.get("task");
      const status = url.searchParams.get("status");
      const limit = parseInt(url.searchParams.get("limit") ?? "50", 10);

      let query = supabase
        .from("schedule_task_runs")
        .select("*")
        .order("started_at", { ascending: false })
        .limit(limit);

      if (taskId) query = query.eq("task_id", taskId);
      if (status) query = query.eq("status", status);

      const { data, error } = await query;
      if (error) throw error;

      // 集計統計 (RPC なしでクライアント側で計算)
      const runs = data ?? [];
      const stats = {
        total_runs: runs.length,
        success_count: runs.filter((r) => r.status === "success").length,
        error_count: runs.filter((r) => r.status === "error").length,
        last_run_at: runs.length > 0 ? runs[0].started_at : null,
      };

      return new Response(
        JSON.stringify({ success: true, runs, stats }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const {
        task_id,
        status,
        started_at,
        finished_at,
        summary,
        error_message,
      } = body;

      if (!task_id || !status) {
        return new Response(
          JSON.stringify({ success: false, error: "task_id and status are required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // status を許容値に正規化 (failure → error)
      const normalizedStatus = status === "failure" ? "error" : status;
      const validStatuses = ["running", "success", "error", "skipped"];
      if (!validStatuses.includes(normalizedStatus)) {
        return new Response(
          JSON.stringify({ success: false, error: `Invalid status: ${status}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const { data, error } = await supabase
        .from("schedule_task_runs")
        .insert({
          task_id,
          status: normalizedStatus,
          started_at: started_at ?? new Date().toISOString(),
          finished_at: finished_at ??
            (normalizedStatus !== "running" ? new Date().toISOString() : null),
          summary: summary ?? null,
          error_message: error_message ?? null,
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
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("schedule-task-monitor error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
