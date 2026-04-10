// my-ai-agent — マイAIエージェント フロー実行エンジン
//
// Notion Custom Agents 対抗: ユーザー定義タスク自動化フローの管理・実行
//
// GET  ?action=list                    → エージェント一覧
// GET  ?action=get&agent_id=<uuid>     → エージェント詳細 + 実行履歴
// POST { action: "create", ... }       → エージェント作成
// POST { action: "update", ... }       → エージェント更新
// POST { action: "run", agent_id }     → エージェント実行
// POST { action: "delete", agent_id }  → エージェント削除
//
// ステップ種別 (steps[].type):
//   "ai_chat"        — Anthropic APIでAI応答生成
//   "http_request"   — 外部URL呼び出し
//   "send_notification" — notification-center EFに通知送信
//   "supabase_insert"   — 任意テーブルにレコード挿入 (ホワイトリスト制限)
//
// ストレージ: app_analytics テーブル (source="ai_agent" / "ai_agent_run")
// ※ 将来的に Windows版が ai_agents/ai_agent_runs テーブルを migration で作成予定

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
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";

// 許可されたステップ種別
const ALLOWED_STEP_TYPES = new Set([
  "ai_chat",
  "http_request",
  "send_notification",
  "supabase_insert",
]);

// supabase_insert が書き込み可能なテーブル (allowlist)
const INSERTABLE_TABLES = new Set([
  "notes",
  "app_analytics",
  "feature_requests",
]);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ── ステップ実行 ─────────────────────────────────────────────────────────────

async function runStep(
  stepType: string,
  // deno-lint-ignore no-explicit-any
  config: Record<string, any>,
  context: Record<string, unknown>,
  // deno-lint-ignore no-explicit-any
  admin: any,
): Promise<{ output: unknown; error?: string }> {
  try {
    // ── ai_chat ────────────────────────────────────────────────────────────
    if (stepType === "ai_chat") {
      if (!ANTHROPIC_API_KEY) {
        return { output: null, error: "ANTHROPIC_API_KEY が設定されていません" };
      }
      const prompt = String(config.prompt ?? "").replace(
        /\{\{(\w+)\}\}/g,
        (_, key) => String(context[key] ?? ""),
      );
      const model = config.model ?? "claude-haiku-20240307";
      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model,
          max_tokens: config.max_tokens ?? 1024,
          messages: [{ role: "user", content: prompt }],
        }),
      });
      if (!res.ok) {
        const errText = await res.text();
        return { output: null, error: `Anthropic API error ${res.status}: ${errText}` };
      }
      const data = await res.json() as {
        content: Array<{ text: string }>;
      };
      const text = data.content?.[0]?.text ?? "";
      return { output: text };
    }

    // ── http_request ───────────────────────────────────────────────────────
    if (stepType === "http_request") {
      const url = String(config.url ?? "");
      if (!url.startsWith("https://")) {
        return { output: null, error: "url must start with https://" };
      }
      const method = (config.method ?? "GET").toUpperCase();
      const reqBody = config.body
        ? JSON.stringify(config.body)
        : undefined;
      const res = await fetch(url, {
        method,
        headers: { "Content-Type": "application/json", ...(config.headers ?? {}) },
        body: reqBody,
        signal: AbortSignal.timeout(10_000),
      });
      const text = await res.text();
      let parsed: unknown = text;
      try { parsed = JSON.parse(text); } catch { /* keep as text */ }
      return { output: { status: res.status, body: parsed } };
    }

    // ── send_notification ──────────────────────────────────────────────────
    if (stepType === "send_notification") {
      const title = String(config.title ?? "エージェント通知");
      const message = String(config.message ?? "").replace(
        /\{\{(\w+)\}\}/g,
        (_, key) => String(context[key] ?? ""),
      );
      const { error } = await admin.from("app_analytics").insert({
        source: "notification",
        metadata: {
          type: "agent",
          title,
          message,
          userId: context.userId ?? null,
          createdAt: new Date().toISOString(),
        },
      });
      if (error) return { output: null, error: error.message };
      return { output: { sent: true, title, message } };
    }

    // ── supabase_insert ────────────────────────────────────────────────────
    if (stepType === "supabase_insert") {
      const table = String(config.table ?? "");
      if (!INSERTABLE_TABLES.has(table)) {
        return { output: null, error: `Table '${table}' is not allowed for insert` };
      }
      const record = config.record ?? {};
      const { data, error } = await admin.from(table).insert(record).select().single();
      if (error) return { output: null, error: error.message };
      return { output: data };
    }

    return { output: null, error: `Unknown step type: ${stepType}` };
  } catch (e) {
    return { output: null, error: e instanceof Error ? e.message : String(e) };
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (SUPABASE_URL === "" || SUPABASE_ANON_KEY === "" || SERVICE_ROLE_KEY === "") {
    return json({ success: false, error: "misconfigured" }, 500);
  }

  // 認証確認
  const authHeader = req.headers.get("authorization") ?? "";
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) {
    return json({ success: false, error: "unauthorized" }, 401);
  }
  const userId = user.id;

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // ── GET ──────────────────────────────────────────────────────────────────
  if (req.method === "GET") {
    const url = new URL(req.url);
    const action = url.searchParams.get("action") ?? "list";

    if (action === "list") {
      const { data, error } = await admin
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("source", "ai_agent")
        .eq("metadata->>userId", userId)
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) return json({ success: false, error: error.message }, 500);
      const agents = (data ?? []).map((r) => ({
        ...(r.metadata as Record<string, unknown>),
        createdAt: r.created_at,
      }));
      return json({ success: true, agents });
    }

    if (action === "get") {
      const agentId = url.searchParams.get("agent_id");
      if (!agentId) return json({ success: false, error: "agent_id required" }, 400);
      const { data: agentRows } = await admin
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("source", "ai_agent")
        .eq("metadata->>agentId", agentId)
        .eq("metadata->>userId", userId)
        .maybeSingle();
      if (!agentRows) return json({ success: false, error: "agent not found" }, 404);
      const { data: runs } = await admin
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("source", "ai_agent_run")
        .eq("metadata->>agentId", agentId)
        .order("created_at", { ascending: false })
        .limit(10);
      return json({
        success: true,
        agent: { ...(agentRows.metadata as Record<string, unknown>), createdAt: agentRows.created_at },
        runs: (runs ?? []).map((r) => ({
          ...(r.metadata as Record<string, unknown>),
          createdAt: r.created_at,
        })),
      });
    }

    return json({ success: false, error: `Unknown GET action: ${action}` }, 400);
  }

  // ── POST ─────────────────────────────────────────────────────────────────
  if (req.method === "POST") {
    // deno-lint-ignore no-explicit-any
    const body: any = await req.json().catch(() => ({}));
    const { action } = body;

    // ── create ──────────────────────────────────────────────────────────────
    if (action === "create") {
      const name = String(body.name ?? "").trim();
      const description = String(body.description ?? "").trim();
      const steps = Array.isArray(body.steps) ? body.steps : [];
      const triggerType = body.trigger_type ?? "manual";

      if (!name) return json({ success: false, error: "name is required" }, 400);
      if (steps.length === 0) return json({ success: false, error: "steps cannot be empty" }, 400);

      // ステップ検証
      for (const step of steps) {
        if (!ALLOWED_STEP_TYPES.has(step.type)) {
          return json({ success: false, error: `Invalid step type: ${step.type}` }, 400);
        }
      }

      const agentId = crypto.randomUUID();
      const { error } = await admin.from("app_analytics").insert({
        source: "ai_agent",
        metadata: {
          agentId,
          userId,
          name,
          description,
          triggerType,
          steps,
          isActive: true,
          runCount: 0,
          createdAt: new Date().toISOString(),
        },
      });
      if (error) return json({ success: false, error: error.message }, 500);
      return json({ success: true, agentId, name }, 201);
    }

    // ── update ──────────────────────────────────────────────────────────────
    if (action === "update") {
      const { agent_id: agentId, name, description, steps, is_active } = body;
      if (!agentId) return json({ success: false, error: "agent_id is required" }, 400);

      const { data: existing } = await admin
        .from("app_analytics")
        .select("id, metadata")
        .eq("source", "ai_agent")
        .eq("metadata->>agentId", agentId)
        .eq("metadata->>userId", userId)
        .maybeSingle();
      if (!existing) return json({ success: false, error: "agent not found" }, 404);

      if (steps !== undefined) {
        for (const step of steps) {
          if (!ALLOWED_STEP_TYPES.has(step.type)) {
            return json({ success: false, error: `Invalid step type: ${step.type}` }, 400);
          }
        }
      }

      const meta = existing.metadata as Record<string, unknown>;
      const updated = {
        ...meta,
        ...(name !== undefined ? { name } : {}),
        ...(description !== undefined ? { description } : {}),
        ...(steps !== undefined ? { steps } : {}),
        ...(is_active !== undefined ? { isActive: is_active } : {}),
        updatedAt: new Date().toISOString(),
      };
      const { error } = await admin
        .from("app_analytics")
        .update({ metadata: updated })
        .eq("id", existing.id);
      if (error) return json({ success: false, error: error.message }, 500);
      return json({ success: true, agentId });
    }

    // ── delete ──────────────────────────────────────────────────────────────
    if (action === "delete") {
      const { agent_id: agentId } = body;
      if (!agentId) return json({ success: false, error: "agent_id is required" }, 400);

      const { error } = await admin
        .from("app_analytics")
        .delete()
        .eq("source", "ai_agent")
        .eq("metadata->>agentId", agentId)
        .eq("metadata->>userId", userId);
      if (error) return json({ success: false, error: error.message }, 500);
      return json({ success: true, agentId });
    }

    // ── run ─────────────────────────────────────────────────────────────────
    if (action === "run") {
      const { agent_id: agentId, input_context } = body;
      if (!agentId) return json({ success: false, error: "agent_id is required" }, 400);

      const { data: agentRow } = await admin
        .from("app_analytics")
        .select("id, metadata")
        .eq("source", "ai_agent")
        .eq("metadata->>agentId", agentId)
        .eq("metadata->>userId", userId)
        .maybeSingle();
      if (!agentRow) return json({ success: false, error: "agent not found" }, 404);

      const agentMeta = agentRow.metadata as Record<string, unknown>;
      if (!agentMeta.isActive) {
        return json({ success: false, error: "agent is not active" }, 400);
      }

      const steps = (agentMeta.steps as Array<{ type: string; config: Record<string, unknown> }>) ?? [];
      const runId = crypto.randomUUID();
      const startedAt = new Date().toISOString();
      const stepResults: Array<{ step: number; type: string; output: unknown; error?: string }> = [];

      // コンテキスト (前のステップ出力を引き継ぐ)
      const context: Record<string, unknown> = {
        userId,
        agentId,
        runId,
        ...(input_context ?? {}),
      };

      let anyFailed = false;
      for (let i = 0; i < steps.length; i++) {
        const step = steps[i];
        const result = await runStep(step.type, step.config ?? {}, context, admin);
        stepResults.push({ step: i, type: step.type, output: result.output, error: result.error });
        if (result.error) {
          anyFailed = true;
          break; // エラー時はフロー停止
        }
        // 次のステップにアウトプットを引き継ぐ
        context[`step_${i}_output`] = result.output;
      }

      const completedAt = new Date().toISOString();
      const status = anyFailed ? "failed" : "completed";

      // 実行履歴を保存
      await admin.from("app_analytics").insert({
        source: "ai_agent_run",
        metadata: { runId, agentId, userId, status, stepResults, startedAt, completedAt },
      });

      // エージェントの実行カウントを更新
      await admin.from("app_analytics").update({
        metadata: {
          ...agentMeta,
          runCount: (toNumber(agentMeta.runCount) + 1),
          lastRunAt: completedAt,
        },
      }).eq("id", agentRow.id);

      return json({ success: !anyFailed, runId, status, stepResults, completedAt });
    }

    return json({ success: false, error: `Unknown action: ${action}` }, 400);
  }

  return json({ success: false, error: "Method not allowed" }, 405);
});

function toNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return 0;
}
