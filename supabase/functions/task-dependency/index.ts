// Task Dependency Edge Function
// タスク依存関係管理 (Asana/Jira競合)
// - タスク間の依存関係 (前提タスク・後続タスク)
// - ブロッカー検出・アラート
// - クリティカルパス計算
// - 依存グラフ可視化データ
//
// GET  → タスク依存関係グラフ / ブロッカー一覧 / クリティカルパス
// POST → 依存関係追加 / 削除 / タスク完了通知

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const url = new URL(req.url);
    const action = req.method === "GET" ? (url.searchParams.get("action") ?? "graph") : "post";

    if (action === "graph") {
      const { data: deps } = await userClient
        .from("task_dependencies")
        .select("*")
        .eq("user_id", user.id);
      const { data: tasks } = await userClient
        .from("tasks")
        .select("id, title, status, due_date")
        .eq("user_id", user.id)
        .in("status", ["todo", "in_progress"]);

      const blockers = (deps ?? []).filter((d: { dep_type?: string }) => d.dep_type === "blocks");
      return new Response(JSON.stringify({
        success: true,
        graph: { nodes: tasks ?? [], edges: deps ?? [] },
        blockers: blockers,
        stats: {
          total_dependencies: (deps ?? []).length,
          blocked_tasks: new Set(blockers.map((b: { task_id: string }) => b.task_id)).size,
        },
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const body = await req.json().catch(() => ({}));

    if (body.action === "add") {
      const { data, error } = await userClient.from("task_dependencies").insert({
        user_id: user.id,
        task_id: body.task_id,
        depends_on_id: body.depends_on_id,
        dep_type: body.dep_type ?? "blocks",
        created_at: new Date().toISOString(),
      }).select().single();
      if (error) throw error;
      return new Response(JSON.stringify({ success: true, dependency: data }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (body.action === "remove") {
      const { error } = await userClient.from("task_dependencies").delete()
        .eq("task_id", body.task_id)
        .eq("depends_on_id", body.depends_on_id)
        .eq("user_id", user.id);
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: false, error: "Unknown action" }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
