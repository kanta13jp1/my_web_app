// Schedule Task Monitor Edge Function
// Claude Code Schedule 実行ログの取得・失敗検知・管理ダッシュボード連携
//
// GET  → 実行ログ一覧取得 (最新50件)
// POST → 実行ログ記録 (Schedule から呼び出し)

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
      // 実行ログ一覧を取得
      const url = new URL(req.url);
      const taskName = url.searchParams.get("task");
      const status = url.searchParams.get("status");
      const limit = parseInt(url.searchParams.get("limit") ?? "50", 10);

      let query = supabase
        .from("schedule_task_runs")
        .select("*")
        .order("started_at", { ascending: false })
        .limit(limit);

      if (taskName) query = query.eq("task_name", taskName);
      if (status) query = query.eq("status", status);

      const { data, error } = await query;
      if (error) throw error;

      // サマリー統計
      const { data: stats } = await supabase.rpc("get_schedule_task_stats").single();

      return new Response(
        JSON.stringify({
          success: true,
          runs: data ?? [],
          stats: stats ?? {
            total_runs: 0,
            success_count: 0,
            failure_count: 0,
            last_run_at: null,
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      // 実行ログを記録
      const body = await req.json();
      const {
        task_name,
        status,
        started_at,
        finished_at,
        duration_ms,
        output,
        error_message,
      } = body;

      if (!task_name || !status) {
        return new Response(
          JSON.stringify({ success: false, error: "task_name and status are required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const { data, error } = await supabase
        .from("schedule_task_runs")
        .insert({
          task_name,
          status, // 'success' | 'failure' | 'running' | 'skipped'
          started_at: started_at ?? new Date().toISOString(),
          finished_at: finished_at ?? (status !== "running" ? new Date().toISOString() : null),
          duration_ms: duration_ms ?? null,
          output: output ?? null,
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
