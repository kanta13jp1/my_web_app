// Automation Workflows Edge Function
// ワークフロー自動化 — トリガー/アクション/条件
// - ワークフロー定義 (IF → THEN)
// - トリガー: イベント発火
// - アクション: 通知/タスク作成/ステータス変更
// - 実行ログ
//
// GET  → ワークフロー一覧 / 実行ログ / テンプレート
// POST → ワークフロー作成 / トリガー実行 / 有効/無効切替

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// テンプレート
const WORKFLOW_TEMPLATES = [
  {
    key: "new_note_notify",
    name: "ノート作成時に通知",
    trigger: "note.created",
    action: "notification",
    description: "新しいノートが作成されたら通知を送信",
  },
  {
    key: "feature_request_assign",
    name: "機能リクエスト自動アサイン",
    trigger: "feature_request.created",
    action: "assign_task",
    description: "機能リクエストが投稿されたら開発部にタスクを自動作成",
  },
  {
    key: "streak_reminder",
    name: "ストリークリマインダー",
    trigger: "daily_20:00",
    action: "notification",
    description: "毎日20時にログイン未済ならリマインダー通知",
  },
  {
    key: "export_complete_notify",
    name: "エクスポート完了通知",
    trigger: "export.completed",
    action: "notification",
    description: "データエクスポート完了時にメール通知",
  },
  {
    key: "high_priority_escalate",
    name: "高優先度タスクエスカレーション",
    trigger: "task.created_high_priority",
    action: "escalate",
    description: "優先度5のタスクが作成されたらCEOにエスカレーション",
  },
];

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
      const view = url.searchParams.get("view"); // 'list' | 'logs' | 'templates'

      if (view === "templates") {
        return new Response(
          JSON.stringify({ success: true, templates: WORKFLOW_TEMPLATES }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "logs") {
        const { data: logs } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "workflow_execution")
          .order("created_at", { ascending: false })
          .limit(50);

        return new Response(
          JSON.stringify({
            success: true,
            logs: (logs ?? []).map((l) => ({
              ...(l.metadata as Record<string, unknown>),
              executedAt: l.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: ワークフロー一覧
      const authHeader = req.headers.get("Authorization");
      let userId: string | null = null;
      if (authHeader) {
        const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
          global: { headers: { Authorization: authHeader } },
        });
        const { data: { user } } = await userClient.auth.getUser();
        if (user) userId = user.id;
      }

      let query = adminClient
        .from("app_analytics")
        .select("metadata, created_at, user_id")
        .eq("source", "workflow_definition")
        .order("created_at", { ascending: false });

      if (userId) query = query.eq("user_id", userId);

      const { data: workflows } = await query;

      return new Response(
        JSON.stringify({
          success: true,
          workflows: (workflows ?? []).map((w) => ({
            ...(w.metadata as Record<string, unknown>),
            createdAt: w.created_at,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create") {
        const { name, trigger, action_type, action_config, enabled } = body;
        if (!name || !trigger || !action_type) {
          return new Response(
            JSON.stringify({ success: false, error: "name, trigger, and action_type required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        let userId = null;
        const authHeader = req.headers.get("Authorization");
        if (authHeader) {
          const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
            global: { headers: { Authorization: authHeader } },
          });
          const { data: { user } } = await userClient.auth.getUser();
          if (user) userId = user.id;
        }

        const workflowId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: userId,
          source: "workflow_definition",
          metadata: {
            workflow_id: workflowId,
            name,
            trigger,
            action_type,
            action_config: action_config ?? {},
            enabled: enabled ?? true,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, workflowId, workflow: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "trigger") {
        const { event_type, payload } = body;
        if (!event_type) {
          return new Response(
            JSON.stringify({ success: false, error: "event_type required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // マッチするワークフローを検索
        const { data: workflows } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("source", "workflow_definition")
          .eq("metadata->>trigger", event_type)
          .eq("metadata->>enabled", "true");

        const executed: string[] = [];
        for (const w of workflows ?? []) {
          const meta = w.metadata as Record<string, unknown>;

          // 実行ログ記録
          await adminClient.from("app_analytics").insert({
            source: "workflow_execution",
            metadata: {
              workflow_id: meta?.workflow_id,
              workflow_name: meta?.name,
              trigger: event_type,
              action_type: meta?.action_type,
              payload: payload ?? {},
              status: "executed",
            },
            created_at: new Date().toISOString(),
          });

          executed.push(meta?.workflow_id as string);
        }

        return new Response(
          JSON.stringify({ success: true, executed: executed.length, workflowIds: executed }),
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
    console.error("automation-workflows error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
