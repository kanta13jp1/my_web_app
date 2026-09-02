// tools-hub — 個人生産性ツール統合EF
// Merges (30 EFs): password-generator, password-vault, currency-converter,
//   weather-widget, qr-code-generator, markdown-renderer, pomodoro-timer,
//   focus-timer, clipboard-history, quick-note, goal-tracker, contact-manager,
//   reading-list, bookmark-manager, bookmark-sync, tag-manager, template-library,
//   address-book, emergency-contacts, news-rss-aggregator, changelog-manager,
//   multi-language, habit-tracker, habit-gamification, virtual-pet, poll-survey,
//   form-builder, note-sharing-enhanced, content-versioning, mindmap-diagram
//
// GET/POST ?action=<action> or body { action: "..." }
// All data stored in hub_data table (source column = feature name)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  buildOAuthProtectedResourceMetadata,
  isOAuthProtectedResourceMetadataRequest,
  logMcpInvocation,
  type McpAuthContext,
  requireScope,
  toolResourceUrn,
  validateBearer,
} from "../_shared/mcp_auth_guard.ts";
import {
  buildMcpClientRegistration,
} from "../_shared/mcp_client_registration.ts";
import {
  buildSaasApprovalStatus,
  externalSaasGateReason,
  isPendingSaasApprovalStatus,
  normalizeSaasApprovalDecision,
  normalizeSaasConnectorSettings,
  SAAS_APPROVAL_REQUEST_SOURCE,
  SAAS_APPROVAL_SETTINGS_SOURCE,
  type SaasApprovalDecision,
} from "../_shared/saas_human_approval.ts";
import {
  type EvalAutomationCalendarEvent,
  type EvalAutomationTask,
  executeEvalApprovalAutomation,
  selectEvalApprovalAutomationPayload,
} from "./eval_approval_automation.ts";
import {
  buildMcpFeatureRequestPayload,
  buildMcpNotePayload,
  buildMcpToolCatalog,
  hasMcpWriteConfirmation,
  mcpActionToToolName,
  mcpConfirmationPhrase,
  type McpMyWebAppToolName,
  mcpRequestedScopes,
} from "../_shared/mcp_my_web_app_tools.ts";
import {
  connectorsAvailableToUser,
  MCP_FILE_CONTEXT_SOURCE,
  type McpFileConnectorConfig,
  normalizeExternalFileContent,
  normalizeExternalFileSearchResults,
  parseMcpFileConnectorConfigs,
  publicMcpFileConnector,
} from "../_shared/mcp_external_file.ts";
import { callExternalMcpTool } from "../_shared/mcp_external_file_client.ts";
import {
  dispatchLocalBusinessReferenceAction,
  fetchLocalBusinessReferences,
} from "../_shared/local_business_reference.ts";
import {
  createSupabaseJibunApiStore,
  handleJibunApiAction,
} from "./jibun_api.ts";
import {
  dedupeWbsTasksById,
  normalizeWbsListPagination,
  paginateWbsTasks,
} from "./wbs_list_tasks.ts";
import {
  ASSET_MANAGEMENT_PINNED_ISSUE_SCHEDULE,
  buildWbsReschedulePlan,
} from "./wbs_reschedule_realistic.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

class ToolsHubRequestError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
    this.name = "ToolsHubRequestError";
  }
}

function configuredMcpFileConnectors(): McpFileConnectorConfig[] {
  try {
    return parseMcpFileConnectorConfigs(
      Deno.env.get("MCP_FILE_CONNECTORS_JSON") ?? "",
      Deno.env.get("MCP_FILE_CONNECTOR_ALLOWED_HOSTS") ?? "",
    );
  } catch (error) {
    console.error("MCP file connector configuration rejected", error);
    throw new ToolsHubRequestError(503, "mcp_file_connector_unavailable");
  }
}

function mcpFileConnectorForUser(
  userId: string,
  connectorId: unknown,
): McpFileConnectorConfig {
  const requestedId = String(connectorId ?? "").trim().toLowerCase();
  if (!requestedId) {
    throw new ToolsHubRequestError(400, "connector_id is required");
  }
  const connector = connectorsAvailableToUser(
    configuredMcpFileConnectors(),
    userId,
  ).find((item) => item.id === requestedId);
  if (!connector) {
    throw new ToolsHubRequestError(404, "mcp_file_connector_not_found");
  }
  return connector;
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function externalMcpAuditContext(userId: string): McpAuthContext {
  return {
    client_id: `app-user:${userId}`,
    subject: userId,
    scopes: ["read"],
    aud: [toolResourceUrn("external-file-search")],
  };
}

function json(
  data: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function parseBooleanish(value: unknown, defaultValue: boolean): boolean {
  if (typeof value === "boolean") return value;
  const normalized = String(value ?? "").trim().toLowerCase();
  if (["true", "1", "yes", "on"].includes(normalized)) return true;
  if (["false", "0", "no", "off"].includes(normalized)) return false;
  return defaultValue;
}

function buildCareerKpiPayload(
  body: Record<string, unknown>,
): Record<string, unknown> {
  return {
    month_key: normalizeText(body.month_key, "1970-01"),
    annual_goal: normalizeText(body.annual_goal),
    category: normalizeText(body.category, "career"),
    metric_name: normalizeText(body.metric_name),
    target_value: normalizeNumber(body.target_value),
    actual_value: normalizeNumber(body.actual_value),
    unit: normalizeText(body.unit),
    reflection: normalizeText(body.reflection),
    next_action: normalizeText(body.next_action),
  };
}

function normalizeText(value: unknown, fallback = ""): string {
  const text = String(value ?? "").trim();
  return text.length === 0 ? fallback : text;
}

function normalizeNumber(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function getHarveyBaseUrl(region: unknown): string {
  const normalized = String(region ?? "").trim().toLowerCase();
  if (normalized === "eu") return "https://eu.api.harvey.ai";
  if (normalized === "au") return "https://au.api.harvey.ai";
  return "https://api.harvey.ai";
}

function normalizeHarveyKnowledgeSources(
  value: unknown,
): Array<Record<string, unknown>> {
  if (Array.isArray(value)) {
    return value.map((item) => asRecord(item)).filter((
      item,
    ): item is Record<string, unknown> => item !== null);
  }
  if (typeof value === "string" && value.trim().length > 0) {
    try {
      const parsed = JSON.parse(value);
      if (Array.isArray(parsed)) {
        return parsed.map((item) => asRecord(item)).filter((
          item,
        ): item is Record<string, unknown> => item !== null);
      }
    } catch {
      return [];
    }
  }
  return [];
}

async function callHarveyCompletion(body: Record<string, unknown>) {
  const token = Deno.env.get("HARVEY_API_KEY") ?? "";
  if (!token) {
    return { ok: false, status: 503, error: "HARVEY_API_KEY not configured" };
  }

  const prompt = String(body.prompt ?? "").trim();
  if (!prompt) {
    return { ok: false, status: 400, error: "prompt is required" };
  }

  const includeCitations = parseBooleanish(
    body.include_citations ?? body.includeCitations,
    true,
  );
  const modeRaw = String(body.mode ?? "draft").trim().toLowerCase();
  const mode = modeRaw === "assist" ? "assist" : "draft";
  const clientMatterId = String(
    body.client_matter_id ?? body.clientMatterId ?? "",
  ).trim();
  const model = String(body.model ?? "").trim();
  const knowledgeSources = normalizeHarveyKnowledgeSources(
    body.knowledge_sources ?? body.knowledgeSources,
  );
  if (
    knowledgeSources.length === 0 &&
    parseBooleanish(body.use_web ?? body.useWeb, false)
  ) {
    knowledgeSources.push({ type: "web" });
  }

  const form = new FormData();
  form.set("prompt", prompt);
  form.set("stream", "false");
  form.set("mode", mode);
  if (clientMatterId) form.set("client_matter_id", clientMatterId);
  if (knowledgeSources.length > 0) {
    form.set("knowledge_sources", JSON.stringify(knowledgeSources));
  }
  if (model) form.set("model", model);

  const baseUrl = getHarveyBaseUrl(body.region);
  const endpoint = `${baseUrl}/api/v2/completion?include_citations=${
    includeCitations ? "true" : "false"
  }`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: form,
  });
  const rawText = await response.text();

  let parsed: Record<string, unknown> = {};
  try {
    parsed = asRecord(JSON.parse(rawText)) ?? {};
  } catch {
    parsed = {};
  }

  if (!response.ok) {
    return {
      ok: false,
      status: response.status,
      error: String(
        parsed.error ??
          parsed.message ??
          `Harvey API error: ${response.status}`,
      ),
      details: rawText.slice(0, 500),
    };
  }

  return {
    ok: true,
    status: response.status,
    data: {
      provider: "harvey",
      mode,
      base_url: baseUrl,
      response: String(parsed.response ?? ""),
      response_with_citations: parsed.response_with_citations ?? null,
      sources: Array.isArray(parsed.sources) ? parsed.sources : [],
      model: model.length > 0 ? model : parsed.model ?? null,
      used_knowledge_sources: knowledgeSources,
    },
  };
}

function wbsPriorityRank(priority: unknown): number {
  const value = String(priority ?? "").toLowerCase();
  if (value === "high") return 3;
  if (value === "medium") return 2;
  if (value === "low") return 1;
  return 0;
}

const ADDITIONAL_REQUEST_TEXT = "\u8ffd\u52a0\u8981\u671b";
const USER_REQUEST_CATEGORY_TEXT = "\u30e6\u30fc\u30b6\u30fc\u8981\u671b";

function hasAdditionalRequestText(value: unknown): boolean {
  return String(value ?? "").includes(ADDITIONAL_REQUEST_TEXT);
}

function isAdditionalRequestIssue(
  title: unknown,
  labels: string[] = [],
): boolean {
  return hasAdditionalRequestText(title) ||
    labels.some((label) => hasAdditionalRequestText(label));
}

function isFeatureRequestTask(task: Record<string, unknown>): boolean {
  const category = String(task.category ?? "");
  const title = String(task.title ?? "");
  return category === USER_REQUEST_CATEGORY_TEXT ||
    hasAdditionalRequestText(category) ||
    hasAdditionalRequestText(title);
}

function isGithubIssueLinkedTask(task: Record<string, unknown>): boolean {
  return githubIssueNumberFromTask(task) !== null ||
    String(task.github_issue_state ?? "").trim() !== "";
}

function dateOnlyUtc(date: Date): Date {
  const copy = new Date(date);
  copy.setUTCHours(0, 0, 0, 0);
  return copy;
}

function formatIsoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function additionalRequestStartDate(now: Date): string {
  return formatIsoDate(dateOnlyUtc(now));
}

function additionalRequestEndDate(now: Date): string {
  return formatIsoDate(dateOnlyUtc(now));
}

function githubIssueStartDate(now: Date): string {
  return formatIsoDate(dateOnlyUtc(now));
}

function wbsTaskSortBucket(task: Record<string, unknown>): number {
  const status = String(task.status ?? "");
  if (status === "completed") return 5;
  if (isFeatureRequestTask(task)) return 0;
  if (isGithubIssueLinkedTask(task)) return 1;
  if (status === "in_progress") return 2;
  if (status === "pending") return 3;
  if (status === "blocked") return 4;
  return 4;
}

function compareOptionalDate(a: unknown, b: unknown): number {
  const aValue = typeof a === "string" && a ? Date.parse(a) : Number.NaN;
  const bValue = typeof b === "string" && b ? Date.parse(b) : Number.NaN;
  const aMissing = Number.isNaN(aValue);
  const bMissing = Number.isNaN(bValue);
  if (aMissing && bMissing) return 0;
  if (aMissing) return 1;
  if (bMissing) return -1;
  return aValue - bValue;
}

function compareWbsTasks(
  a: Record<string, unknown>,
  b: Record<string, unknown>,
): number {
  const bucketCmp = wbsTaskSortBucket(a) - wbsTaskSortBucket(b);
  if (bucketCmp !== 0) return bucketCmp;

  const priorityCmp = wbsPriorityRank(b.priority) - wbsPriorityRank(a.priority);
  if (priorityCmp !== 0) return priorityCmp;

  const categoryOrderCmp = Number(a.category_order ?? 999) -
    Number(b.category_order ?? 999);
  if (categoryOrderCmp !== 0) return categoryOrderCmp;

  const endDateCmp = compareOptionalDate(a.end_date, b.end_date);
  if (endDateCmp !== 0) return endDateCmp;

  const updatedAtCmp = compareOptionalDate(b.updated_at, a.updated_at);
  if (updatedAtCmp !== 0) return updatedAtCmp;

  return String(a.title ?? "").localeCompare(String(b.title ?? ""));
}

type WbsUserTaskAssistMode = "breakdown" | "procedure";

function cleanAiJsonText(text: string): string {
  let cleaned = text.trim();
  if (cleaned.startsWith("```")) {
    cleaned = cleaned.replace(/^```(?:json)?\s*/i, "").replace(/```$/g, "")
      .trim();
  }
  const firstBrace = cleaned.indexOf("{");
  const lastBrace = cleaned.lastIndexOf("}");
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    return cleaned.slice(firstBrace, lastBrace + 1);
  }
  return cleaned;
}

function stringArrayFromUnknown(
  value: unknown,
  fallback: string[] = [],
): string[] {
  const values = Array.isArray(value)
    ? value
    : typeof value === "string"
    ? [value]
    : fallback;
  return values
    .map((item) => String(item ?? "").trim())
    .filter((item) => item.length > 0)
    .slice(0, 12);
}

function recordArrayFromUnknown(value: unknown): Record<string, unknown>[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => asRecord(item))
    .filter((item): item is Record<string, unknown> => item !== null);
}

function normalizeWbsUserTaskAssist(
  rawValue: unknown,
  fallback: Record<string, unknown>,
  mode: WbsUserTaskAssistMode,
  generatedBy: string,
): Record<string, unknown> {
  const raw = asRecord(rawValue) ?? {};
  const fallbackSubtasks = recordArrayFromUnknown(fallback.subtasks);
  const fallbackSteps = recordArrayFromUnknown(fallback.steps);
  const subtasks = recordArrayFromUnknown(raw.subtasks).slice(0, 8).map((
    item,
    index,
  ) => ({
    title: String(item.title ?? `小タスク ${index + 1}`).trim(),
    goal: String(item.goal ?? "").trim(),
    steps: stringArrayFromUnknown(item.steps).slice(0, 6),
    estimated_minutes: Number.isFinite(Number(item.estimated_minutes))
      ? Number(item.estimated_minutes)
      : null,
    done_when: String(item.done_when ?? "").trim(),
  })).filter((item) => item.title.length > 0);
  const steps = recordArrayFromUnknown(raw.steps).slice(0, 10).map((
    item,
    index,
  ) => ({
    title: String(item.title ?? `手順 ${index + 1}`).trim(),
    detail: String(item.detail ?? "").trim(),
    expected_result: String(item.expected_result ?? "").trim(),
    caution: String(item.caution ?? "").trim(),
  })).filter((item) => item.title.length > 0);

  return {
    summary: String(raw.summary ?? fallback.summary ?? "").trim().slice(0, 600),
    prerequisites: stringArrayFromUnknown(
      raw.prerequisites,
      stringArrayFromUnknown(fallback.prerequisites),
    ).slice(0, 8),
    subtasks: mode === "breakdown" && subtasks.length > 0
      ? subtasks
      : fallbackSubtasks,
    steps: mode === "procedure" && steps.length > 0 ? steps : fallbackSteps,
    blockers: stringArrayFromUnknown(
      raw.blockers,
      stringArrayFromUnknown(fallback.blockers),
    ).slice(0, 6),
    checklist: stringArrayFromUnknown(
      raw.checklist,
      stringArrayFromUnknown(fallback.checklist),
    ).slice(0, 8),
    generated_by: generatedBy,
  };
}

function fallbackWbsUserTaskAssist(
  task: Record<string, unknown>,
  mode: WbsUserTaskAssistMode,
  generatedBy: string,
): Record<string, unknown> {
  const title = String(task.title ?? "ユーザータスク").trim();
  const due = String(task.end_date ?? "").trim();
  const dueText = due
    ? `期限は ${due} です。`
    : "期限が未設定なら先に確認してください。";
  const commonPrerequisites = [
    "タスクの完了条件を1文で書き出す",
    "提出先・確認相手・必要書類を確認する",
    "不明点を1つに絞ってメモする",
  ];
  const commonChecklist = [
    "完了条件を満たした証跡を保存した",
    "次に待つ相手や期限が明確になっている",
    "WBSユーザータスク画面で状況報告を更新した",
  ];
  const subtasks = [
    {
      title: "完了条件を決める",
      goal: `${title}で何が終われば完了かを明確にする。${dueText}`,
      steps: ["関連メモとWBS説明を読む", "成果物・提出先・期限を1行で書く"],
      estimated_minutes: 10,
      done_when: "次に何を作る/送る/確認するかが1文で言える",
    },
    {
      title: "必要情報を集める",
      goal: "作業に必要な情報や書類をそろえる",
      steps: ["手元にある資料を確認する", "足りない情報をチェックリスト化する"],
      estimated_minutes: 20,
      done_when: "不足情報がゼロ、または問い合わせ先が決まっている",
    },
    {
      title: "最初の外部確認を送る",
      goal: "相手待ちで止まらないように確認依頼を出す",
      steps: ["質問を3点以内に絞る", "メール/Slack/フォームで送信する"],
      estimated_minutes: 15,
      done_when: "送信履歴と返信期限が残っている",
    },
    {
      title: "進捗をWBSに戻す",
      goal: "作業状況を共有して次の判断をしやすくする",
      steps: ["進捗率を更新する", "詰まり・次アクションを記録する"],
      estimated_minutes: 5,
      done_when: "WBSユーザータスクに最新状況が反映されている",
    },
  ];
  const steps = [
    {
      title: "目的と期限を確認する",
      detail:
        `${title}の説明、期限、関連メモを確認し、今日終える範囲を決めます。${dueText}`,
      expected_result: "今日の到達点が1つに絞られている",
      caution: "完璧な全体像を作る前に、最初の確認行動を決めてください",
    },
    {
      title: "必要な相手・資料を洗い出す",
      detail: "提出先、承認者、参考URL、必要書類を箇条書きにします。",
      expected_result: "不足している情報と問い合わせ先が分かる",
      caution: "個人情報や契約情報は公開チャネルに貼らないでください",
    },
    {
      title: "最小の実行単位で進める",
      detail: "15分で終わる確認、作成、送信のどれか1つを実施します。",
      expected_result: "作業が着手済みになり、次の待ち状態が明確になる",
      caution: "相手待ちが発生したら返信期限をメモしてください",
    },
    {
      title: "WBSへ状況報告する",
      detail:
        "進捗率、実施内容、詰まり、次アクションをユーザータスク画面から更新します。",
      expected_result: "他インスタンスが現在地を把握できる",
      caution: "完了していない場合は次アクションを必ず残してください",
    },
  ];

  return {
    summary: mode === "breakdown"
      ? `「${title}」を止めないため、15〜20分単位の小さな作業に分けました。`
      : `「${title}」を進めるための実施順です。迷ったら上から1つずつ処理してください。`,
    prerequisites: commonPrerequisites,
    subtasks,
    steps,
    blockers: [
      "完了条件が曖昧なまま作業を始める",
      "確認相手が決まらず相手待ちにできない",
      "証跡を残さず、後で進捗報告できない",
    ],
    checklist: commonChecklist,
    generated_by: generatedBy,
  };
}

async function generateWbsUserTaskAssistWithOpenAi(
  prompt: string,
  fallback: Record<string, unknown>,
  mode: WbsUserTaskAssistMode,
  task: Record<string, unknown>,
  fallbackReason: string,
): Promise<Record<string, unknown>> {
  const openAiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  if (!openAiKey) {
    return fallbackWbsUserTaskAssist(
      task,
      mode,
      `fallback:${fallbackReason}:no_openai_key`,
    );
  }

  try {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${openAiKey}`,
      },
      body: JSON.stringify({
        model: Deno.env.get("WBS_ASSIST_OPENAI_MODEL") ?? "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content:
              "あなたはWBSユーザータスクの実務支援AIです。必ずJSONのみで回答してください。",
          },
          { role: "user", content: prompt },
        ],
        response_format: { type: "json_object" },
        temperature: 0.2,
        max_tokens: 2200,
      }),
    });
    if (!res.ok) {
      return fallbackWbsUserTaskAssist(
        task,
        mode,
        `fallback:${fallbackReason}:openai_http_${res.status}`,
      );
    }
    const data = await res.json() as {
      choices?: Array<{ message?: { content?: string } }>;
    };
    const text = data.choices?.[0]?.message?.content ?? "";
    if (!text.trim()) {
      return fallbackWbsUserTaskAssist(
        task,
        mode,
        `fallback:${fallbackReason}:empty_openai_response`,
      );
    }
    const parsed = JSON.parse(cleanAiJsonText(text));
    return normalizeWbsUserTaskAssist(
      parsed,
      fallback,
      mode,
      Deno.env.get("WBS_ASSIST_OPENAI_MODEL") ?? "gpt-4o-mini",
    );
  } catch (err) {
    console.warn(
      `wbs.user_task_ai_assist OpenAI fallback failed: ${String(err)}`,
    );
    return fallbackWbsUserTaskAssist(
      task,
      mode,
      `fallback:${fallbackReason}:openai_error`,
    );
  }
}

async function generateWbsUserTaskAssist(
  task: Record<string, unknown>,
  mode: WbsUserTaskAssistMode,
): Promise<Record<string, unknown>> {
  const fallback = fallbackWbsUserTaskAssist(task, mode, "fallback");
  const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  const prompt = [
    "あなたはWBSユーザータスクの実務支援AIです。",
    "ユーザーが手を止めずに進められるよう、抽象的な助言ではなく、今日実行できる粒度で返してください。",
    mode === "breakdown"
      ? "目的: タスクを15〜30分で実行できる小さなサブタスクに分割する。"
      : "目的: 初心者でも迷わない詳細な実施手順を作る。",
    "必ずJSONのみで返してください。Markdownや説明文は不要です。",
    "JSON schema:",
    `{"summary":"string","prerequisites":["string"],"subtasks":[{"title":"string","goal":"string","steps":["string"],"estimated_minutes":15,"done_when":"string"}],"steps":[{"title":"string","detail":"string","expected_result":"string","caution":"string"}],"blockers":["string"],"checklist":["string"]}`,
    "対象タスク:",
    JSON.stringify({
      id: task.id,
      title: task.title,
      description: task.description,
      category: task.category,
      status: task.status,
      progress: task.progress,
      priority: task.priority,
      end_date: task.end_date,
      user_report_status: task.user_report_status,
      user_report_note: task.user_report_note,
      latest_report: task.latest_report ?? null,
    }),
  ].join("\n");

  if (!geminiKey) {
    return generateWbsUserTaskAssistWithOpenAi(
      prompt,
      fallback,
      mode,
      task,
      "no_gemini_key",
    );
  }

  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.25,
            maxOutputTokens: 2200,
            responseMimeType: "application/json",
          },
        }),
      },
    );
    if (!res.ok) {
      return generateWbsUserTaskAssistWithOpenAi(
        prompt,
        fallback,
        mode,
        task,
        `gemini_http_${res.status}`,
      );
    }
    const data = await res.json() as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    if (!text.trim()) {
      return generateWbsUserTaskAssistWithOpenAi(
        prompt,
        fallback,
        mode,
        task,
        "empty_gemini_response",
      );
    }
    const parsed = JSON.parse(cleanAiJsonText(text));
    return normalizeWbsUserTaskAssist(
      parsed,
      fallback,
      mode,
      "gemini-2.5-flash",
    );
  } catch (err) {
    console.warn(`wbs.user_task_ai_assist fallback: ${String(err)}`);
    return generateWbsUserTaskAssistWithOpenAi(
      prompt,
      fallback,
      mode,
      task,
      "gemini_error",
    );
  }
}

const WBS_INSTANCE_VALUES = [
  "codex", // OpenAI Codex CLI
  "gemini", // Google Gemini Code Assist
  "co-pilot", // GitHub Copilot Chat / Inline
  "vscode",
  "win",
  "ps1",
  "ps2",
  "ps3",
  "ps4",
  "ps5",
  "ps6",
  "web",
  "mobile",
  "schedule",
  "gha",
  "user", // ユーザー手動操作タスク (法人登記/銀行口座/外部面談等)
];

const WBS_ACTIVE_INSTANCE_VALUES = [
  "claude",
  "codex",
  "user",
  "automation",
];

const WBS_CODEX_LEGACY_INSTANCES = ["codex", "ps2", "ps5", "ps6"];
const WBS_AUTOMATION_LEGACY_INSTANCES = [
  "schedule",
  "gha",
  "gemini",
  "co-pilot",
];

const WBS_OPEN_STATUSES = ["pending", "in_progress", "blocked"];

function normalizeWbsInstance(value: unknown): string {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (
    normalized === "claude" ||
    normalized === "claude-code" ||
    normalized === "claude-code-1"
  ) return "win";
  if (normalized === "automation" || normalized === "auto") return "schedule";
  if (normalized === "windows") return "win";
  if (normalized === "ps") return "ps1";
  if (normalized === "copilot" || normalized === "github-copilot") {
    return "co-pilot";
  }
  return WBS_INSTANCE_VALUES.includes(normalized) ? normalized : "codex";
}

function normalizeWbsActiveInstance(value: unknown): string {
  const normalized = normalizeWbsInstance(value);
  if (WBS_CODEX_LEGACY_INSTANCES.includes(normalized)) return "codex";
  if (WBS_AUTOMATION_LEGACY_INSTANCES.includes(normalized)) return "automation";
  if (normalized === "user") return "user";
  return "claude";
}

function mcpArgsForAction(
  action: string,
  body: Record<string, unknown>,
): Record<string, unknown> {
  if (action === "mcp.tool.call") {
    const params = asRecord(body.params) ?? {};
    return asRecord(body.arguments) ?? asRecord(params.arguments) ?? {};
  }
  return body;
}

function isMcpJsonRpcRequest(body: Record<string, unknown>): boolean {
  return body.jsonrpc === "2.0" && typeof body.method === "string";
}

function mcpActionFromJsonRpc(body: Record<string, unknown>): string {
  if (!isMcpJsonRpcRequest(body)) return "";
  const method = String(body.method);
  if (method === "tools/list") return "mcp.tools.list";
  if (method === "tools/call") return "mcp.tool.call";
  return "";
}

function mcpJsonRpcId(body: Record<string, unknown>): unknown {
  return "id" in body ? body.id : null;
}

function mcpJsonRpcResult(
  body: Record<string, unknown>,
  result: Record<string, unknown>,
): Record<string, unknown> {
  return {
    jsonrpc: "2.0",
    id: mcpJsonRpcId(body),
    result,
  };
}

function mcpProtocolToolCatalog(): Array<Record<string, unknown>> {
  return buildMcpToolCatalog().map((tool) => ({
    name: tool.name,
    title: tool.title,
    description: tool.description,
    inputSchema: tool.input_schema,
    annotations: {
      requested_scopes: tool.requested_scopes,
      write_confirmation_required: tool.write_confirmation_required,
      invoke_action: tool.invoke_action,
    },
  }));
}

function mcpTextResult(summary: string): Array<Record<string, string>> {
  return [{ type: "text", text: summary }];
}

function mcpToolResponse(
  body: Record<string, unknown>,
  payload: Record<string, unknown>,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  if (!isMcpJsonRpcRequest(body)) {
    return json(payload, status, extraHeaders);
  }

  const isError = payload.success === false;
  const content = Array.isArray(payload.content)
    ? payload.content
    : mcpTextResult(String(payload.error ?? "MCP tool call failed."));
  return json(
    mcpJsonRpcResult(body, {
      content,
      structuredContent: payload.structuredContent ?? payload,
      isError,
    }),
    status,
    extraHeaders,
  );
}

function mcpAllowsToolScope(
  ctx: McpAuthContext,
  toolName: McpMyWebAppToolName,
): boolean {
  if (requireScope(ctx, toolName)) return true;
  const audAllows = ctx.aud.includes(toolResourceUrn(toolName)) ||
    ctx.aud.includes(toolResourceUrn("*"));
  if (!audAllows) return false;
  const requestedScopes = mcpRequestedScopes(toolName);
  return requestedScopes.every((scope) => ctx.scopes.includes(scope));
}

async function authorizeMcpTool(
  req: Request,
  toolName: McpMyWebAppToolName,
  args: Record<string, unknown>,
  body: Record<string, unknown>,
): Promise<{ ctx: McpAuthContext } | { response: Response }> {
  const ctx = await validateBearer(req);
  if (!ctx) {
    await logMcpInvocation(null, toolName, args, 401, req);
    return {
      response: mcpToolResponse(
        body,
        {
          success: false,
          error: "mcp_auth_required",
          tool: toolName,
        },
        401,
        {
          "WWW-Authenticate": `Bearer resource="${toolResourceUrn(toolName)}"`,
        },
      ),
    };
  }

  if (!mcpAllowsToolScope(ctx, toolName)) {
    await logMcpInvocation(ctx, toolName, args, 403, req);
    return {
      response: mcpToolResponse(body, {
        success: false,
        error: "mcp_scope_denied",
        tool: toolName,
        required_audience: toolResourceUrn(toolName),
        accepted_scopes: ["all", toolName, ...mcpRequestedScopes(toolName)],
      }, 403),
    };
  }

  return { ctx };
}

function isMcpClientRegistrationRequest(
  req: Request,
  action: string,
): boolean {
  if (action === "mcp.auth.register") return true;
  if (req.method !== "POST") return false;
  const { pathname } = new URL(req.url);
  return pathname.endsWith("/register") ||
    pathname.endsWith("/oauth/register");
}

async function handleMcpClientRegistration(
  req: Request,
  body: Record<string, unknown>,
  admin: SupabaseClient,
): Promise<Response> {
  const registration = await buildMcpClientRegistration(body, req);
  if (!registration.ok) {
    return json({
      success: false,
      error: registration.error,
    }, registration.status);
  }

  const { error } = await admin.from("mcp_oauth_clients")
    .insert(registration.row);
  if (error) throw new Error(error.message);

  return json(
    {
      success: true,
      ...registration.response,
    },
    201,
    {
      "Cache-Control": "no-store",
    },
  );
}

async function handleMcpFacade(
  req: Request,
  action: string,
  body: Record<string, unknown>,
  admin: SupabaseClient,
): Promise<Response | null> {
  if (action === "mcp.tools.list") {
    if (isMcpJsonRpcRequest(body)) {
      return json(mcpJsonRpcResult(body, { tools: mcpProtocolToolCatalog() }));
    }
    return json({
      success: true,
      tools: buildMcpToolCatalog(),
      invocation: {
        direct_actions: [
          "mcp.wbs.list",
          "mcp.feature_request.create",
          "mcp.user_tasks.list",
          "mcp.public_businesses.reference_list",
          "mcp.notes.list",
          "mcp.notes.create",
        ],
        generic_action: "mcp.tool.call",
        batch_action: "mcp.batch.call",
        generic_arguments_shape: {
          action: "mcp.tool.call",
          tool_name: "wbs.tasks.list",
          arguments: { instance: "codex", limit: 10 },
        },
        batch_arguments_shape: {
          action: "mcp.batch.call",
          calls: [
            { tool_name: "wbs.tasks.list", arguments: { limit: 5 } },
            { tool_name: "notes.list", arguments: { limit: 10 } },
          ],
        },
      },
    });
  }

  if (action === "mcp.batch.call") {
    return await handleMcpBatch(req, body, admin);
  }

  const toolName = mcpActionToToolName(action, body);
  if (!toolName) return null;

  const args = mcpArgsForAction(action, body);
  const auth = await authorizeMcpTool(req, toolName, args, body);
  if ("response" in auth) return auth.response;

  if (toolName === "wbs.tasks.list") {
    const rawInstance = String(args.instance ?? "codex").trim().toLowerCase();
    const instance = rawInstance === "all"
      ? "all"
      : normalizeWbsActiveInstance(rawInstance);
    const includeCompleted = parseBooleanish(args.include_completed, false);
    const status = String(args.status ?? "").trim();
    const validStatuses = ["pending", "in_progress", "blocked", "completed"];
    const limit = Math.min(Math.max(Number(args.limit ?? 10), 1), 50);
    let query = admin.from("wbs_tasks")
      .select(
        "id, category, title, description, instance, owner_instance, status, progress, end_date, priority, remaining_work, updated_at, github_issue_number, github_issue_url",
      );
    if (validStatuses.includes(status)) {
      query = query.eq("status", status);
    } else if (!includeCompleted) {
      query = query.in("status", WBS_OPEN_STATUSES);
    }

    const { data, error } = await query;
    if (error) throw new Error(error.message);

    const filtered = [...(data ?? [])].filter((task) =>
      wbsTaskMatchesInstanceFilter(task, rawInstance)
    );
    const tasks = filtered.sort(compareWbsTasks).slice(0, limit);
    await logMcpInvocation(auth.ctx, toolName, args, 200, req);
    return mcpToolResponse(body, {
      success: true,
      tool: toolName,
      structuredContent: {
        count: tasks.length,
        total: filtered.length,
        instance,
        tasks,
      },
      content: mcpTextResult(
        `Found ${tasks.length} WBS task(s) for instance=${instance}.`,
      ),
    });
  }

  if (toolName === "user_tasks.list") {
    const includeCompleted = parseBooleanish(args.include_completed, false);
    const limit = Math.min(Math.max(Number(args.limit ?? 10), 1), 50);
    const fetchLimit = Math.max(limit * 3, 50);
    const statusFilter = includeCompleted
      ? ["pending", "in_progress", "blocked", "completed"]
      : WBS_OPEN_STATUSES;
    const { data: tasks, error: tasksErr } = await admin
      .from("wbs_tasks")
      .select(
        "id, category, title, description, status, progress, priority, end_date, instance, owner_instance, user_report_status, user_report_note, user_reported_at, updated_at",
      )
      .or("instance.eq.user,owner_instance.eq.user")
      .in("status", statusFilter)
      .order("end_date", { ascending: true, nullsFirst: false })
      .limit(fetchLimit);
    if (tasksErr) throw new Error(tasksErr.message);

    const sortedTasks = [...(tasks ?? [])].sort(compareWbsTasks).slice(
      0,
      limit,
    );
    const taskIds = sortedTasks.map((task: Record<string, unknown>) => task.id);
    const latestReports: Record<string, Record<string, unknown>> = {};
    if (taskIds.length > 0) {
      const { data: reports, error: reportsErr } = await admin
        .from("wbs_user_task_reports")
        .select(
          "task_id, status, progress, report_text, next_action, blockers, created_at",
        )
        .in("task_id", taskIds)
        .order("created_at", { ascending: false })
        .limit(taskIds.length * 3);
      if (reportsErr) {
        console.warn(
          `mcp.user_tasks.list reports fetch skipped: ${reportsErr.message}`,
        );
      } else {
        for (const report of reports ?? []) {
          const row = report as Record<string, unknown>;
          const taskId = String(row.task_id);
          if (!latestReports[taskId]) latestReports[taskId] = row;
        }
      }
    }

    const enriched = sortedTasks.map((task: Record<string, unknown>) => ({
      ...task,
      latest_report: latestReports[String(task.id)] ?? null,
    }));
    await logMcpInvocation(auth.ctx, toolName, args, 200, req);
    return mcpToolResponse(body, {
      success: true,
      tool: toolName,
      structuredContent: {
        count: enriched.length,
        tasks: enriched,
      },
      content: mcpTextResult(`Found ${enriched.length} user task(s).`),
    });
  }

  if (toolName === "public_businesses.reference_list") {
    const targetId = String(args.target_id ?? "fuchu-honmachi-1").trim();
    if (targetId !== "fuchu-honmachi-1") {
      await logMcpInvocation(auth.ctx, toolName, args, 400, req);
      return mcpToolResponse(body, {
        success: false,
        tool: toolName,
        error: "unsupported_target",
      }, 400);
    }
    try {
      const payload = await fetchLocalBusinessReferences({
        limit: args.limit ?? 30,
      });
      await logMcpInvocation(auth.ctx, toolName, args, 200, req);
      return mcpToolResponse(body, {
        success: true,
        tool: toolName,
        structuredContent: payload,
        content: mcpTextResult(
          `Found ${payload.publicReference.count} public reference place(s). ` +
            "Ownership type is unknown and the list does not identify the census aggregate.",
        ),
      });
    } catch (error) {
      console.error("MCP public business reference failed", error);
      await logMcpInvocation(auth.ctx, toolName, args, 502, req);
      return mcpToolResponse(body, {
        success: false,
        tool: toolName,
        error: "public_reference_unavailable",
      }, 502);
    }
  }

  if (toolName === "feature_request.create") {
    const payloadResult = buildMcpFeatureRequestPayload(args);
    if (!payloadResult.ok) {
      await logMcpInvocation(
        auth.ctx,
        toolName,
        args,
        payloadResult.status,
        req,
      );
      return mcpToolResponse(body, {
        success: false,
        error: payloadResult.error,
        tool: toolName,
      }, payloadResult.status);
    }

    if (!hasMcpWriteConfirmation(toolName, args)) {
      const phrase = mcpConfirmationPhrase(toolName);
      await logMcpInvocation(
        auth.ctx,
        toolName,
        {
          ...args,
          proposed_task: payloadResult.payload,
        },
        409,
        req,
      );
      return mcpToolResponse(body, {
        success: false,
        error: "confirmation_required",
        tool: toolName,
        confirmation: {
          confirm: true,
          confirmation_phrase: phrase,
        },
        proposed_task: payloadResult.payload,
        content: mcpTextResult(
          `Confirmation required. Retry with confirm=true and confirmation_phrase=${phrase}.`,
        ),
      }, 409);
    }

    const payload = {
      ...payloadResult.payload,
      instance: normalizeWbsInstance(payloadResult.payload.instance),
      owner_instance: normalizeWbsInstance(
        payloadResult.payload.owner_instance,
      ),
    };
    const { data, error } = await admin.from("wbs_tasks")
      .insert(payload)
      .select(
        "id, title, instance, owner_instance, status, progress, priority, end_date",
      )
      .single();
    if (error) throw new Error(error.message);

    await logMcpInvocation(auth.ctx, toolName, args, 201, req);
    return mcpToolResponse(body, {
      success: true,
      tool: toolName,
      structuredContent: { task: data },
      content: mcpTextResult(`Created feature request WBS task: ${data.title}`),
    }, 201);
  }

  // ── notes.list (MCP) ─────────────────────────────────────────────────────
  if (toolName === "notes.list") {
    const limit = Math.min(Math.max(Number(args.limit ?? 20), 1), 50);
    const q = typeof args.q === "string" ? args.q.trim() : "";
    let query = admin
      .from("notes")
      .select("id, title, content, created_at, updated_at")
      .eq("user_id", auth.ctx.subject)
      .order("created_at", { ascending: false })
      .limit(limit);
    if (q !== "") {
      // Simple sanitize: strip PostgREST metacharacters before embedding in ilike
      const safe = q.replace(/[,()"'\\%_*]/g, " ").replace(/\s+/g, " ").trim()
        .slice(0, 100);
      if (safe !== "") {
        query = query.or(`title.ilike.%${safe}%,content.ilike.%${safe}%`);
      }
    }
    const { data: notes, error: notesErr } = await query;
    if (notesErr) throw new Error(notesErr.message);
    await logMcpInvocation(auth.ctx, toolName, args, 200, req);
    return mcpToolResponse(body, {
      success: true,
      tool: toolName,
      structuredContent: { count: (notes ?? []).length, notes: notes ?? [] },
      content: mcpTextResult(`Found ${(notes ?? []).length} note(s).`),
    });
  }

  // ── notes.create (MCP) ───────────────────────────────────────────────────
  if (toolName === "notes.create") {
    const payloadResult = buildMcpNotePayload(args);
    if (!payloadResult.ok) {
      await logMcpInvocation(
        auth.ctx,
        toolName,
        args,
        payloadResult.status,
        req,
      );
      return mcpToolResponse(body, {
        success: false,
        error: payloadResult.error,
        tool: toolName,
      }, payloadResult.status);
    }
    if (!hasMcpWriteConfirmation(toolName, args)) {
      const phrase = mcpConfirmationPhrase(toolName);
      await logMcpInvocation(auth.ctx, toolName, args, 409, req);
      return mcpToolResponse(body, {
        success: false,
        error: "confirmation_required",
        tool: toolName,
        confirmation: { confirm: true, confirmation_phrase: phrase },
        proposed_note: payloadResult.payload,
        content: mcpTextResult(
          `Confirmation required. Retry with confirm=true and confirmation_phrase=${phrase}.`,
        ),
      }, 409);
    }
    const { data: note, error: noteErr } = await admin
      .from("notes")
      .insert({ user_id: auth.ctx.subject, ...payloadResult.payload })
      .select("id, title, content, created_at, updated_at")
      .single();
    if (noteErr) throw new Error(noteErr.message);
    await logMcpInvocation(auth.ctx, toolName, args, 201, req);
    return mcpToolResponse(body, {
      success: true,
      tool: toolName,
      structuredContent: { note },
      content: mcpTextResult(`Created note: ${note.title}`),
    }, 201);
  }

  return null;
}

// ── MCP Batch (token最適化 / Notion MCP 91%削減 対抗) ────────────────────────
// 複数 MCP ツール呼び出しを 1 HTTP リクエストに束ねることで、往復オーバーヘッドと
// 認証ハンドシェイクを削減する。最大 5 呼び出しを並列処理。
async function handleMcpBatch(
  req: Request,
  body: Record<string, unknown>,
  admin: SupabaseClient,
): Promise<Response | null> {
  const rawCalls = Array.isArray(body.calls) ? body.calls : null;
  if (!rawCalls) {
    return json({
      error: "calls must be an array",
      example: [{ tool_name: "notes.list", arguments: { limit: 10 } }],
    }, 400);
  }
  const calls = rawCalls.slice(0, 5);
  if (calls.length === 0) {
    return json({ error: "calls must be a non-empty array (max 5)" }, 400);
  }
  const results = await Promise.all(
    calls.map(async (call: unknown, idx: number) => {
      if (call === null || typeof call !== "object" || Array.isArray(call)) {
        return { index: idx, success: false, error: "invalid call object" };
      }
      const c = call as Record<string, unknown>;
      const toolName = String(c.tool_name ?? "");
      const callArgs = (
          c.arguments !== null &&
          typeof c.arguments === "object" &&
          !Array.isArray(c.arguments)
        )
        ? c.arguments as Record<string, unknown>
        : {};
      const subBody: Record<string, unknown> = {
        tool_name: toolName,
        arguments: callArgs,
      };
      try {
        const res = await handleMcpFacade(req, "mcp.tool.call", subBody, admin);
        if (!res) {
          return {
            index: idx,
            tool: toolName,
            success: false,
            error: "unknown_tool",
          };
        }
        const data = await res.clone().json().catch(() => null);
        return { index: idx, tool: toolName, success: res.ok, data };
      } catch (err) {
        return {
          index: idx,
          tool: toolName,
          success: false,
          error: String(err).slice(0, 200),
        };
      }
    }),
  );
  return json({
    success: true,
    count: results.length,
    results,
  });
}

function parseGithubIssueNumber(value: unknown): number | null {
  const text = String(value ?? "");
  const match = text.match(
    /github\.com\/[^/\s]+\/[^/\s]+\/issues\/(\d+)|(?:^|[\s([])(?:github\s+)?issue\s*#\s*(\d+)\]?/i,
  );
  if (!match) return null;
  const issueNumber = Number(match.slice(1).find((group) => group) ?? 0);
  return Number.isFinite(issueNumber) && issueNumber > 0 ? issueNumber : null;
}

function explicitGithubIssueNumberFromTask(
  task: Record<string, unknown>,
): number | null {
  const explicit = Number(task.github_issue_number ?? 0);
  return Number.isFinite(explicit) && explicit > 0 ? explicit : null;
}

function githubIssueNumberFromTask(
  task: Record<string, unknown>,
): number | null {
  const titleIssueNumber = parseGithubIssueNumber(task.title);
  if (titleIssueNumber) return titleIssueNumber;
  const urlIssueNumber = parseGithubIssueNumber(task.github_issue_url);
  if (urlIssueNumber) return urlIssueNumber;
  const explicit = explicitGithubIssueNumberFromTask(task);
  if (explicit) return explicit;
  return parseGithubIssueNumber(task.description);
}

function normalizeDuplicateKey(value: unknown): string {
  return String(value ?? "")
    .replace(/^\s*\[Issue #\d+\]\s*/i, "")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

function isDuplicateWbsMirrorTask(task: Record<string, unknown>): boolean {
  const text = `${task.remaining_work ?? ""} ${task.recovery_plan ?? ""}`
    .toLowerCase();
  return text.includes("duplicate of wbs task") ||
    text.includes("duplicate github-origin wbs title") ||
    text.includes("duplicate wbs title") ||
    text.includes("duplicate_wbs_row") ||
    text.includes("duplicate_title") ||
    text.includes("duplicate_title_generic");
}

function compareWbsDuplicateTitleKeeper(
  a: Record<string, unknown>,
  b: Record<string, unknown>,
): number {
  return Number(isDuplicateWbsMirrorTask(a)) -
      Number(isDuplicateWbsMirrorTask(b)) ||
    Number(isCompletedWbsTask(a)) - Number(isCompletedWbsTask(b)) ||
    Number(b.progress ?? 0) - Number(a.progress ?? 0) ||
    compareOptionalDate(b.updated_at, a.updated_at) ||
    compareOptionalDate(a.created_at, b.created_at) ||
    String(a.id ?? "").localeCompare(String(b.id ?? ""));
}

function isWbsTitleInstanceUniqueConflict(
  error: { code?: string; message?: string; details?: string } | null,
): boolean {
  if (!error) return false;
  const text = `${error.message ?? ""} ${error.details ?? ""}`.toLowerCase();
  const isUniqueViolation = error.code === "23505" ||
    text.includes("duplicate key value violates unique constraint");
  return isUniqueViolation &&
    (text.includes("wbs_tasks_title_instance_unique") ||
      text.includes("key (title, instance)"));
}

function isWbsIssueInstanceActiveUniqueConflict(
  error: { code?: string; message?: string; details?: string } | null,
): boolean {
  if (!error) return false;
  const text = `${error.message ?? ""} ${error.details ?? ""}`.toLowerCase();
  const isUniqueViolation = error.code === "23505" ||
    text.includes("duplicate key value violates unique constraint");
  return isUniqueViolation &&
    (text.includes("wbs_tasks_issue_instance_active_unique") ||
      text.includes("key (github_issue_number, instance)"));
}

function isWbsGithubSyncUniqueConflict(
  error: { code?: string; message?: string; details?: string } | null,
): boolean {
  return isWbsTitleInstanceUniqueConflict(error) ||
    isWbsIssueInstanceActiveUniqueConflict(error);
}

function githubIssueLabelNames(issue: Record<string, unknown>): string[] {
  const labels = issue.labels;
  if (!Array.isArray(labels)) return [];
  return labels
    .map((label) => {
      if (typeof label === "string") return label;
      const record = asRecord(label);
      return record ? String(record.name ?? "").trim() : "";
    })
    .filter((label) => label.length > 0);
}

function githubIssueNumber(issue: Record<string, unknown>): number | null {
  const issueNumber = Number(issue.number ?? 0);
  return Number.isFinite(issueNumber) && issueNumber > 0 ? issueNumber : null;
}

function githubIssueState(issue: Record<string, unknown>): "OPEN" | "CLOSED" {
  const state = String(issue.state ?? "").trim().toUpperCase();
  return state === "CLOSED" || state === "CLOSE" ? "CLOSED" : "OPEN";
}

function normalizedMirroredGithubIssueState(value: unknown): string {
  const state = String(value ?? "").trim().toUpperCase();
  return state === "CLOSE" ? "CLOSED" : state;
}

function githubIssueTaskRepairReasons(
  task: Record<string, unknown>,
  issueNumber: number,
  issueState: string,
  canonicalTitle: string,
): string[] {
  const reasons = new Set<string>();
  const explicit = explicitGithubIssueNumberFromTask(task);
  if (!explicit) {
    reasons.add("github_issue_number_missing");
  } else if (explicit !== issueNumber) {
    reasons.add("github_issue_number_mismatch");
  }

  const titleIssueNumber = parseGithubIssueNumber(task.title);
  if (titleIssueNumber !== null && titleIssueNumber !== issueNumber) {
    reasons.add("title_issue_number_mismatch");
  }

  const urlIssueNumber = parseGithubIssueNumber(task.github_issue_url);
  if (urlIssueNumber !== null && urlIssueNumber !== issueNumber) {
    reasons.add("github_issue_url_mismatch");
  }

  const mirroredState = normalizedMirroredGithubIssueState(
    task.github_issue_state,
  );
  if (!mirroredState) {
    reasons.add("github_issue_state_missing");
  } else if (mirroredState !== issueState) {
    reasons.add("github_issue_state_stale");
  }

  if (String(task.title ?? "") !== canonicalTitle) {
    reasons.add("title_stale");
  }

  if (issueState === "CLOSED" && !isCompletedWbsTask(task)) {
    reasons.add("closed_issue_active_wbs");
  }

  return [...reasons];
}

async function fetchAllWbsTasks(
  admin: SupabaseClient,
  taskSelect: string,
): Promise<Array<Record<string, unknown>>> {
  const pageSize = 1000;
  const maxPages = 50;
  const tasks: Array<Record<string, unknown>> = [];

  for (let page = 0; page < maxPages; page += 1) {
    const from = page * pageSize;
    const to = from + pageSize - 1;
    const { data, error } = await admin.from("wbs_tasks")
      .select(taskSelect)
      .order("created_at", { ascending: true, nullsFirst: true })
      .order("id", { ascending: true })
      .range(from, to);
    if (error) throw new Error(error.message);

    const rows = (data ?? []) as unknown as Array<Record<string, unknown>>;
    tasks.push(...rows);
    if (rows.length < pageSize) return tasks;
  }

  throw new Error(
    `wbs.sync_github_issues scanned at least ${pageSize * maxPages} rows; ` +
      "increase the WBS pagination cap before syncing.",
  );
}

async function fetchWbsTasksForGithubIssues(
  admin: SupabaseClient,
  taskSelect: string,
  issueNumbers: number[],
): Promise<Array<Record<string, unknown>>> {
  const uniqueNumbers = [...new Set(issueNumbers)].filter((number) =>
    Number.isFinite(number)
  );
  if (uniqueNumbers.length === 0) return [];

  const chunkSize = 100;
  const tasks: Array<Record<string, unknown>> = [];
  for (let index = 0; index < uniqueNumbers.length; index += chunkSize) {
    const chunk = uniqueNumbers.slice(index, index + chunkSize);
    const { data, error } = await admin.from("wbs_tasks")
      .select(taskSelect)
      .in("github_issue_number", chunk)
      .order("created_at", { ascending: true, nullsFirst: true })
      .order("id", { ascending: true });
    if (error) throw new Error(error.message);
    tasks.push(...((data ?? []) as unknown as Array<Record<string, unknown>>));
  }
  return tasks;
}

function githubIssueOwnerInstance(labels: string[]): string {
  const normalized = labels.join(",").toLowerCase();
  if (
    /(workflow|github actions|gha|ci|deploy|cron|schedule)/.test(normalized)
  ) return "gha";
  if (/(mobile|ios|android|flutter)/.test(normalized)) return "mobile";
  if (/(notion|wbs|batch|sync)/.test(normalized)) return "schedule";
  return "codex";
}

function githubIssuePriority(labels: string[]): string {
  const normalized = labels.join(",").toLowerCase();
  if (/(critical|p0|urgent|high|p1|bug)/.test(normalized)) return "high";
  if (/(feature|enhancement|p2|request|追加要望)/.test(normalized)) {
    return "medium";
  }
  return "low";
}

function githubIssueDueDate(
  labels: string[],
  now: Date,
  title: unknown = "",
): string {
  if (isAdditionalRequestIssue(title, labels)) {
    return additionalRequestEndDate(now);
  }
  const normalized = labels.join(",").toLowerCase();
  const days = /(critical|p0|urgent|bug)/.test(normalized) ? 1 : 3;
  const due = new Date(now);
  due.setUTCDate(due.getUTCDate() + days);
  return due.toISOString().slice(0, 10);
}

function githubIssueCategory(labels: string[]): string {
  const normalized = labels.join(",").toLowerCase();
  if (/(bug|critical|p0)/.test(normalized)) return "GitHub Issue / Bug";
  if (/(feature|enhancement|request|追加要望)/.test(normalized)) {
    return "GitHub Issue / Feature Request";
  }
  return "GitHub Issue";
}

function githubIssueCategoryIcon(labels: string[]): string {
  const normalized = labels.join(",").toLowerCase();
  if (/(bug|critical|p0)/.test(normalized)) return "🐛";
  if (/(feature|enhancement|request|追加要望)/.test(normalized)) return "📝";
  return "🔗";
}

function isCompletedWbsTask(task: Record<string, unknown>): boolean {
  return String(task.status ?? "") === "completed" ||
    Number(task.progress ?? 0) >= 100;
}

function isClosedGithubIssueWbsTask(task: Record<string, unknown>): boolean {
  if (githubIssueNumberFromTask(task) === null) return false;
  return String(task.github_issue_state ?? "").trim().toUpperCase() ===
    "CLOSED";
}

function filterClosedGithubIssueWbsTasks(
  tasks: Array<Record<string, unknown>>,
): {
  activeTasks: Array<Record<string, unknown>>;
  excludedTasks: Array<Record<string, unknown>>;
} {
  const activeTasks: Array<Record<string, unknown>> = [];
  const excludedTasks: Array<Record<string, unknown>> = [];
  for (const task of tasks) {
    if (isClosedGithubIssueWbsTask(task)) {
      excludedTasks.push(task);
    } else {
      activeTasks.push(task);
    }
  }
  return { activeTasks, excludedTasks };
}

function isGithubIssueClosureReadyWbsTask(
  task: Record<string, unknown>,
): boolean {
  if (!isCompletedWbsTask(task)) return false;
  const reviewStatus = String(task.ai_review_status ?? "").trim().toLowerCase();
  return ["approved", "verified", "passed"].includes(reviewStatus);
}

function wbsStatusForOpenGithubIssue(
  task: Record<string, unknown> | null,
): string {
  const status = String(task?.status ?? "pending");
  return status === "completed" ? "in_progress" : status;
}

function wbsProgressForOpenGithubIssue(
  task: Record<string, unknown> | null,
): number {
  return Math.max(0, Math.min(99, Number(task?.progress ?? 0)));
}

function pickGithubIssueWbsKeeper(
  tasks: Array<Record<string, unknown>>,
): Record<string, unknown> | null {
  if (tasks.length === 0) return null;
  const sorted = [...tasks].sort((a, b) =>
    compareOptionalDate(a.created_at, b.created_at) ||
    compareOptionalDate(a.updated_at, b.updated_at) ||
    String(a.id ?? "").localeCompare(String(b.id ?? ""))
  );
  return sorted.find((task) => !isCompletedWbsTask(task)) ?? sorted[0];
}

function wbsTaskLane(task: Record<string, unknown>): string {
  return normalizeWbsActiveInstance(task.owner_instance ?? task.instance);
}

function wbsTaskMatchesInstanceFilter(
  task: Record<string, unknown>,
  rawInstance: unknown,
): boolean {
  const raw = String(rawInstance ?? "").trim().toLowerCase();
  if (!raw || raw === "all") return true;
  if (
    WBS_ACTIVE_INSTANCE_VALUES.includes(raw) ||
    raw === "claude-code" ||
    raw === "claude-code-1" ||
    raw === "automation" ||
    raw === "auto"
  ) {
    return wbsTaskLane(task) === normalizeWbsActiveInstance(raw);
  }
  const legacyInstance = normalizeWbsInstance(raw);
  return normalizeWbsInstance(task.instance) === legacyInstance ||
    normalizeWbsInstance(task.owner_instance ?? task.instance) ===
      legacyInstance;
}

function wbsDeadline(task: Record<string, unknown>): string {
  return String(task.planned_end_date ?? task.end_date ?? "");
}

function wbsOverdueDays(task: Record<string, unknown>, today: Date): number {
  const raw = wbsDeadline(task);
  if (!raw) return 0;
  const due = new Date(`${raw.slice(0, 10)}T00:00:00.000Z`);
  if (Number.isNaN(due.getTime()) || due >= today) return 0;
  return Math.ceil((today.getTime() - due.getTime()) / 86_400_000);
}

function wbsStaleDays(task: Record<string, unknown>, now: Date): number {
  const raw = String(task.updated_at ?? "");
  if (!raw) return 0;
  const updated = new Date(raw);
  if (Number.isNaN(updated.getTime()) || updated >= now) return 0;
  return Math.floor((now.getTime() - updated.getTime()) / 86_400_000);
}

function wbsRescueScore(task: Record<string, unknown>, now: Date): number {
  const today = new Date(now.toISOString().slice(0, 10));
  const status = String(task.status ?? "");
  const overdueDays = wbsOverdueDays(task, today);
  const staleDays = wbsStaleDays(task, now);
  return (status === "blocked" ? 500 : 0) +
    (overdueDays * 30) +
    (staleDays >= 3 ? staleDays * 12 : 0) +
    (wbsPriorityRank(task.priority) * 25) +
    (isFeatureRequestTask(task) ? 40 : 0) +
    (isGithubIssueLinkedTask(task) ? 25 : 0) +
    (status === "in_progress" ? 20 : 0);
}

function buildWbsWorkload(tasks: Array<Record<string, unknown>>, now: Date) {
  const today = new Date(now.toISOString().slice(0, 10));
  const workload = WBS_ACTIVE_INSTANCE_VALUES.map((instance) => {
    const laneTasks = tasks.filter((task) => wbsTaskLane(task) === instance);
    const openTasks = laneTasks.filter((task) =>
      WBS_OPEN_STATUSES.includes(String(task.status ?? ""))
    );
    const blockedTasks = openTasks.filter((task) =>
      task.status === "blocked"
    ).length;
    const overdueTasks =
      openTasks.filter((task) => wbsOverdueDays(task, today) > 0).length;
    const staleTasks =
      openTasks.filter((task) => wbsStaleDays(task, now) >= 3).length;
    const highPriorityTasks =
      openTasks.filter((task) => task.priority === "high").length;
    const rescueScore = openTasks.reduce(
      (sum, task) => sum + wbsRescueScore(task, now),
      0,
    );
    return {
      instance,
      open_tasks: openTasks.length,
      blocked_tasks: blockedTasks,
      overdue_tasks: overdueTasks,
      stale_tasks: staleTasks,
      high_priority_tasks: highPriorityTasks,
      rescue_score: rescueScore,
    };
  });
  return workload.sort((a, b) =>
    b.rescue_score - a.rescue_score || b.open_tasks - a.open_tasks
  );
}

function pickWbsRescueCandidate(
  tasks: Array<Record<string, unknown>>,
  targetInstance: string,
  now: Date,
): Record<string, unknown> | null {
  const candidates = tasks.filter((task) => {
    const lane = wbsTaskLane(task);
    const status = String(task.status ?? "");
    return lane !== targetInstance && WBS_OPEN_STATUSES.includes(status);
  });
  candidates.sort((a, b) => wbsRescueScore(b, now) - wbsRescueScore(a, now));
  return candidates.find((task) => wbsRescueScore(task, now) > 0) ??
    candidates[0] ?? null;
}

function buildWbsRebalanceSuggestions(
  tasks: Array<Record<string, unknown>>,
  now: Date,
): Array<Record<string, unknown>> {
  const workload = buildWbsWorkload(tasks, now);
  const idleInstances = workload.filter((lane) => lane.open_tasks === 0).map((
    lane,
  ) => lane.instance);
  const suggestions: Array<Record<string, unknown>> = [];
  for (const target of idleInstances) {
    const candidate = pickWbsRescueCandidate(tasks, target, now);
    if (!candidate) continue;
    suggestions.push({
      target_instance: target,
      from_instance: wbsTaskLane(candidate),
      task_id: candidate.id,
      title: candidate.title,
      reason: "target_idle_and_source_has_stalled_work",
      rescue_score: wbsRescueScore(candidate, now),
    });
  }
  return suggestions;
}

async function getUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return null;
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  return user?.id ?? null;
}

// Generic CRUD on hub_data by source
async function listItems(
  admin: SupabaseClient,
  source: string,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin.from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  meta: Record<string, unknown>,
) {
  const { data, error } = await admin.from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

async function latestHubMetadata(
  admin: SupabaseClient,
  source: string,
  userId: string,
): Promise<Record<string, unknown>> {
  const { data, error } = await admin.from("hub_data")
    .select("metadata")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return asRecord(data?.metadata) ?? {};
}

async function upsertLatestHubMetadata(
  admin: SupabaseClient,
  source: string,
  userId: string,
  meta: Record<string, unknown>,
) {
  const { data, error } = await admin.from("hub_data")
    .select("id, metadata")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(error.message);

  const metadata = {
    ...(asRecord(data?.metadata) ?? {}),
    ...meta,
    user_id: userId,
    updated_at: new Date().toISOString(),
  };
  if (data?.id) {
    const updated = await admin.from("hub_data")
      .update({ metadata })
      .eq("id", data.id)
      .select("id, metadata, created_at")
      .single();
    if (updated.error) throw new Error(updated.error.message);
    return updated.data;
  }
  return await addItem(admin, source, userId, metadata);
}

function publicSaasApprovalRequest(row: Record<string, unknown>) {
  const metadata = asRecord(row.metadata) ?? {};
  return {
    id: row.id,
    created_at: row.created_at,
    ...metadata,
  };
}

async function listSaasApprovalRequests(
  admin: SupabaseClient,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin.from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", SAAS_APPROVAL_REQUEST_SOURCE)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return (data ?? []).map((row: Record<string, unknown>) =>
    publicSaasApprovalRequest(row)
  );
}

async function getSaasApprovalSettings(
  admin: SupabaseClient,
  userId: string,
) {
  const metadata = await latestHubMetadata(
    admin,
    SAAS_APPROVAL_SETTINGS_SOURCE,
    userId,
  );
  return {
    team_id: normalizeText(metadata.team_id, "default"),
    approval_required: true,
    connector_enabled: normalizeSaasConnectorSettings(
      metadata.connector_enabled,
    ),
  };
}

function bodyRequestedScopes(body: Record<string, unknown>): string[] {
  if (Array.isArray(body.requested_scopes)) {
    return body.requested_scopes.map((item) => normalizeText(item)).filter(
      Boolean,
    );
  }
  return ["send", "external_share"];
}

async function createSaasApprovalRequest(
  admin: SupabaseClient,
  userId: string,
  input: {
    provider: string;
    actionKey: string;
    actionLabel: string;
    teamId: string;
    preview: Record<string, unknown>;
    payload: Record<string, unknown>;
    requestedScopes: string[];
    sourceAction: string;
  },
) {
  const now = new Date().toISOString();
  const item = await addItem(admin, SAAS_APPROVAL_REQUEST_SOURCE, userId, {
    provider: input.provider,
    action_key: input.actionKey,
    action_label: input.actionLabel,
    team_id: input.teamId || "default",
    status: "pending",
    preview: input.preview,
    payload: input.payload,
    requested_scopes: input.requestedScopes,
    source_action: input.sourceAction,
    created_by: userId,
    created_at: now,
    updated_at: now,
  });
  return publicSaasApprovalRequest(item as Record<string, unknown>);
}

async function addEvalAutomationItem(
  admin: SupabaseClient,
  userId: string,
  source: "team_task" | "calendar_event",
  metadata: Record<string, unknown>,
): Promise<boolean> {
  const { error } = await admin.from("hub_data").insert({
    source,
    metadata: { ...metadata, user_id: userId },
  });
  if (error?.code === "23505") return false;
  if (error) throw new Error(error.message);
  return true;
}

async function executeApprovedEvalAutomation(
  admin: SupabaseClient,
  userId: string,
  requestId: string,
  payload: Record<string, unknown>,
  selectedOptionId: string,
) {
  if (!requestId) {
    return {
      success: false,
      status: "failed",
      error: "approval request id is required for internal automation",
    };
  }
  return await executeEvalApprovalAutomation(payload, {
    createTask: async (task: EvalAutomationTask, itemKey: string) => {
      return await addEvalAutomationItem(admin, userId, "team_task", {
        title: task.title,
        description: task.description,
        assignee: task.assignee ?? userId,
        due_date: task.dueDate,
        status: "pending",
        priority: task.priority,
        source: "eval_approval",
        approval_request_id: requestId,
        automation_item_key: itemKey,
      });
    },
    createCalendarEvent: async (
      event: EvalAutomationCalendarEvent,
      itemKey: string,
    ) => {
      return await addEvalAutomationItem(admin, userId, "calendar_event", {
        title: event.title,
        description: event.description,
        start_at: event.startAt,
        end_at: event.endAt,
        all_day: event.allDay,
        color: event.color,
        reminder_min: event.reminderMinutes,
        calendar_id: event.calendarId,
        rrule: null,
        timezone: null,
        source: "eval_approval",
        approval_request_id: requestId,
        automation_item_key: itemKey,
      });
    },
  }, selectedOptionId);
}

async function executeApprovedSaasAction(
  admin: SupabaseClient,
  userId: string,
  metadata: Record<string, unknown>,
) {
  const provider = normalizeText(metadata.provider);
  const payload = asRecord(metadata.payload) ?? {};
  if (provider === "internal" || provider === "eval_automation") {
    return await executeApprovedEvalAutomation(
      admin,
      userId,
      normalizeText(metadata.request_id),
      payload,
      normalizeText(metadata.selected_option_id),
    );
  }
  if (provider !== "slack") {
    return {
      success: false,
      skipped: true,
      error: `unsupported provider: ${provider || "unknown"}`,
    };
  }

  const config = await latestHubMetadata(admin, "slack_config", userId);
  const webhookUrl = normalizeText(config.webhook_url);
  if (!webhookUrl) {
    return {
      success: false,
      error: "Slack webhook URL is not configured",
    };
  }

  const text = normalizeText(payload.text, "Slack approval test");
  const slackPayload: Record<string, unknown> = { text };
  const channel = normalizeText(payload.channel);
  const username = normalizeText(payload.username);
  if (channel) slackPayload.channel = channel;
  if (username) slackPayload.username = username;

  const response = await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(slackPayload),
  });
  const detail = await response.text();
  return {
    success: response.ok,
    status: response.status,
    detail: detail.slice(0, 500),
  };
}

async function decideSaasApprovalRequest(
  admin: SupabaseClient,
  userId: string,
  requestId: string,
  decision: SaasApprovalDecision,
  input: {
    reviewNote: string;
    revisedPayload: Record<string, unknown> | null;
    execute: boolean;
    selectedOptionId: string;
  },
) {
  const { data, error } = await admin.from("hub_data")
    .select("id, metadata, created_at")
    .eq("id", requestId)
    .eq("source", SAAS_APPROVAL_REQUEST_SOURCE)
    .filter("metadata->>user_id", "eq", userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) return null;

  const metadata = asRecord(data.metadata) ?? {};
  if (!isPendingSaasApprovalStatus(metadata.status)) {
    throw new ToolsHubRequestError(
      409,
      `approval request is already ${normalizeText(metadata.status)}`,
    );
  }
  const provider = normalizeText(metadata.provider);
  const payload = asRecord(input.revisedPayload ?? metadata.payload) ?? {};
  if (
    decision === "approved" && input.execute &&
    (provider === "internal" || provider === "eval_automation")
  ) {
    try {
      selectEvalApprovalAutomationPayload(payload, input.selectedOptionId);
    } catch (error) {
      throw new ToolsHubRequestError(
        400,
        error instanceof Error ? error.message : String(error),
      );
    }
  }
  const now = new Date().toISOString();
  const nextMetadata: Record<string, unknown> = {
    ...metadata,
    status: buildSaasApprovalStatus(decision),
    decision,
    decided_by: userId,
    decided_at: now,
    review_note: input.reviewNote,
    selected_option_id: input.selectedOptionId || null,
    updated_at: now,
    request_id: requestId,
  };
  if (decision === "revision_requested") {
    nextMetadata.status = "pending";
    nextMetadata.revision_requested_at = now;
  }
  if (input.revisedPayload) {
    nextMetadata.revised_payload = input.revisedPayload;
    nextMetadata.payload = input.revisedPayload;
  }

  if (decision === "approved" && input.execute) {
    const execution = await executeApprovedSaasAction(
      admin,
      userId,
      nextMetadata,
    );
    nextMetadata.execution = execution;
    nextMetadata.execution_status = execution.success
      ? normalizeText(execution.status, "sent")
      : "failed";
    nextMetadata.executed_at = now;
  }

  const updated = await admin.from("hub_data")
    .update({ metadata: nextMetadata })
    .eq("id", data.id)
    .select("id, metadata, created_at")
    .single();
  if (updated.error) throw new Error(updated.error.message);
  return publicSaasApprovalRequest(updated.data as Record<string, unknown>);
}

type RssFeedInput = {
  title: string;
  url: string;
  category: string;
};

type RssNewsItem = {
  title: string;
  url: string;
  source: string;
  category: string;
  published_at: string;
  summary: string;
};

type RankedNewsItem = RssNewsItem & {
  id: string;
  fetched_at: string;
  cluster_key: string;
  signal_score: number;
  confidence: "high" | "medium" | "low";
  why_it_matters: string;
  verification_warning: string;
};

type MarketIntelWatchItem = {
  name: string;
  keywords: string[];
};

type MarketIntelEvidence = {
  title: string;
  url: string;
  source: string;
  published_at: string;
  signal_score: number;
  confidence: string;
};

type MarketIntelSignal = {
  id: string;
  signal: string;
  headline: string;
  themes: string[];
  watchlist_matches: string[];
  evidence: MarketIntelEvidence[];
  evidence_count: number;
  source_count: number;
  confidence: "high" | "medium" | "low";
  uncertainty: string;
  risk_note: string;
  what_to_watch_next: string[];
  paper_decision_log: Record<string, unknown>;
};

function decodeXmlEntities(value: string): string {
  return value
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(
      /&#x([0-9a-fA-F]+);/g,
      (_, hex) => String.fromCharCode(parseInt(hex, 16)),
    )
    .replace(
      /&#([0-9]+);/g,
      (_, code) => String.fromCharCode(parseInt(code, 10)),
    )
    .trim();
}

function stripHtml(value: string): string {
  return decodeXmlEntities(value.replace(/<[^>]+>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
}

function extractXmlTag(xml: string, tag: string): string {
  const match = xml.match(
    new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, "i"),
  );
  return match ? decodeXmlEntities(match[1]) : "";
}

function parseRssItems(
  xml: string,
  feed: RssFeedInput,
  perFeedLimit: number,
): RssNewsItem[] {
  const blocks = xml.match(/<item[\s\S]*?<\/item>|<entry[\s\S]*?<\/entry>/gi) ??
    [];
  const items: RssNewsItem[] = [];
  for (const block of blocks.slice(0, perFeedLimit)) {
    const title = stripHtml(extractXmlTag(block, "title"));
    const linkMatch = block.match(/<link[^>]+href=["']([^"']+)["'][^>]*\/?>/i);
    const url = decodeXmlEntities(
      extractXmlTag(block, "link") || linkMatch?.[1] || "",
    );
    const published = extractXmlTag(block, "pubDate") ||
      extractXmlTag(block, "published") ||
      extractXmlTag(block, "updated");
    const summary = stripHtml(
      extractXmlTag(block, "description") ||
        extractXmlTag(block, "summary") ||
        extractXmlTag(block, "content"),
    );
    if (!title || !url) continue;
    items.push({
      title,
      url,
      source: feed.title,
      category: feed.category,
      published_at: published,
      summary: summary.length > 220 ? `${summary.slice(0, 220)}...` : summary,
    });
  }
  return items;
}

async function fetchRssNewsItems(
  feed: RssFeedInput,
  perFeedLimit: number,
): Promise<RssNewsItem[]> {
  const res = await fetch(feed.url, {
    headers: {
      "User-Agent":
        "my-web-app-news-reader/1.0 (+https://my-web-app-b67f4.web.app)",
    },
  }).catch(() => null);
  if (!res || !res.ok) return [];
  const xml = await res.text();
  return parseRssItems(xml, feed, perFeedLimit);
}

function normalizeRssFeedInputs(value: unknown): RssFeedInput[] {
  const rawFeeds = Array.isArray(value) ? value : [];
  const seen = new Set<string>();
  const feeds: RssFeedInput[] = [];
  for (const raw of rawFeeds) {
    const feed = asRecord(raw);
    if (!feed) continue;
    const url = String(feed.url ?? "").trim();
    if (!/^https?:\/\//i.test(url) || seen.has(url)) continue;
    seen.add(url);
    feeds.push({
      title: String(feed.title ?? feed.name ?? "RSS").trim() || "RSS",
      url,
      category: String(feed.category ?? "総合").trim() || "総合",
    });
  }
  return feeds.slice(0, 20);
}

function stableNewsHash(value: string): string {
  let hash = 0;
  for (let i = 0; i < value.length; i += 1) {
    hash = ((hash << 5) - hash + value.charCodeAt(i)) | 0;
  }
  return Math.abs(hash).toString(36);
}

function normalizePublishedAt(value: string): string {
  const parsed = Date.parse(value || "");
  return Number.isFinite(parsed) ? new Date(parsed).toISOString() : "";
}

function newsClusterKey(item: RssNewsItem): string {
  const normalizedTitle = item.title
    .toLowerCase()
    .replace(/[^\p{Letter}\p{Number}]+/gu, " ")
    .trim()
    .slice(0, 80);
  return `${item.source}:${normalizedTitle}`;
}

function sourceConfidence(source: string): number {
  const trustedSources = [
    "NHK",
    "ITmedia",
    "CNET",
    "Yahoo",
    "Reuters",
    "Bloomberg",
    "Nikkei",
    "日経",
  ];
  return trustedSources.some((name) => source.includes(name)) ? 1 : 0.72;
}

function keywordSignalScore(text: string): number {
  const keywords = [
    "AI",
    "生成AI",
    "Claude",
    "OpenAI",
    "Codex",
    "決算",
    "提携",
    "買収",
    "規制",
    "セキュリティ",
    "障害",
    "新機能",
    "発表",
    "速報",
    "価格",
    "投資",
    "市場",
    "選挙",
    "不正",
  ];
  return keywords.reduce(
    (score, keyword) =>
      text.toLowerCase().includes(keyword.toLowerCase()) ? score + 5 : score,
    0,
  );
}

function freshnessScore(publishedAt: string): number {
  const parsed = Date.parse(publishedAt || "");
  if (!Number.isFinite(parsed)) return 8;
  const ageHours = Math.max(0, (Date.now() - parsed) / 36e5);
  if (ageHours <= 6) return 28;
  if (ageHours <= 24) return 22;
  if (ageHours <= 72) return 14;
  return 6;
}

function newsWhyItMatters(text: string, category: string): string {
  const lower = text.toLowerCase();
  if (
    lower.includes("claude") || lower.includes("openai") || lower.includes("ai")
  ) {
    return "AI活用、プロダクト改善、ブログ下書き化の候補として優先確認";
  }
  if (text.includes("選挙") || text.includes("不正") || text.includes("規制")) {
    return "公共性が高く、一次情報確認と時系列整理が必要";
  }
  if (text.includes("決算") || text.includes("投資") || text.includes("市場")) {
    return "市場変化の兆候としてKPI/競合レポートに転用可能";
  }
  return `${category}カテゴリの更新として、要約と関連タスク化を検討`;
}

function rankNewsSignals(rawItems: unknown, limit = 30): RankedNewsItem[] {
  const values = Array.isArray(rawItems) ? rawItems : [];
  const deduped = new Map<string, RankedNewsItem>();
  for (const raw of values) {
    const item = asRecord(raw);
    if (!item) continue;
    const title = String(item.title ?? "").trim();
    const url = String(item.url ?? item.link ?? "").trim();
    if (!title || !url) continue;
    const source = String(item.source ?? "RSS").trim() || "RSS";
    const category = String(item.category ?? "総合").trim() || "総合";
    const publishedAt = normalizePublishedAt(String(item.published_at ?? ""));
    const summary = String(item.summary ?? item.description ?? "").trim();
    const base: RssNewsItem = {
      title,
      url,
      source,
      category,
      published_at: publishedAt,
      summary,
    };
    const text = `${title} ${summary}`;
    const clusterKey = newsClusterKey(base);
    const score = Math.round(
      sourceConfidence(source) * 34 + freshnessScore(publishedAt) +
        Math.min(28, keywordSignalScore(text)) +
        (summary.length > 80 ? 10 : 4),
    );
    const confidence = score >= 72 ? "high" : score >= 54 ? "medium" : "low";
    const ranked: RankedNewsItem = {
      ...base,
      id: `news_${stableNewsHash(`${source}|${url}|${title}`)}`,
      fetched_at: String(item.fetched_at ?? ""),
      cluster_key: clusterKey,
      signal_score: Math.min(100, score),
      confidence,
      why_it_matters: newsWhyItMatters(text, category),
      verification_warning: confidence === "low"
        ? "低信頼または鮮度不明のため、一次情報で確認してから配信"
        : "公開前に一次情報、日時、固有名詞を再確認",
    };
    const existing = deduped.get(clusterKey);
    if (!existing || ranked.signal_score > existing.signal_score) {
      deduped.set(clusterKey, ranked);
    }
  }
  return [...deduped.values()]
    .sort((a, b) => b.signal_score - a.signal_score)
    .slice(0, Math.max(1, Math.min(100, Number(limit) || 30)));
}

async function fetchLatestNewsItems(body: Record<string, unknown>): Promise<{
  fetched_at: string;
  source_count: number;
  items: RankedNewsItem[];
  errors: Array<{ source: string; url: string; error: string }>;
}> {
  const feeds = normalizeRssFeedInputs(body.feeds);
  const perFeedLimit = Math.min(
    Math.max(Number(body.per_feed_limit ?? 8) || 8, 1),
    30,
  );
  const totalLimit = Math.min(Math.max(Number(body.limit ?? 80) || 80, 1), 200);
  const fetchedAt = new Date().toISOString();
  const results = await Promise.allSettled(
    feeds.map(async (feed) => ({
      feed,
      items: await fetchRssNewsItems(feed, perFeedLimit),
    })),
  );
  const errors: Array<{ source: string; url: string; error: string }> = [];
  const items: RssNewsItem[] = [];
  for (const result of results) {
    if (result.status === "fulfilled") {
      items.push(...result.value.items);
    } else {
      errors.push({ source: "RSS", url: "", error: String(result.reason) });
    }
  }
  const normalizedItems = rankNewsSignals(
    items,
    Math.max(totalLimit, items.length),
  )
    .sort((a, b) => {
      const bTime = Date.parse(b.published_at || "") || 0;
      const aTime = Date.parse(a.published_at || "") || 0;
      return bTime - aTime;
    })
    .slice(0, totalLimit)
    .map((item) => ({ ...item, fetched_at: fetchedAt }));
  return {
    fetched_at: fetchedAt,
    source_count: feeds.length,
    items: normalizedItems,
    errors,
  };
}

const MARKET_INTEL_DISCLAIMER =
  "This is market research support, not investment advice. It never places trades, never recommends buy/sell orders, and requires human review before any decision.";

function defaultMarketIntelFeeds(): RssFeedInput[] {
  return [
    {
      title: "Google News: AI markets",
      url:
        "https://news.google.com/rss/search?q=AI%20market%20software%20startup&hl=en-US&gl=US&ceid=US:en",
      category: "AI",
    },
    {
      title: "Google News: fintech",
      url:
        "https://news.google.com/rss/search?q=fintech%20market%20intelligence%20software&hl=en-US&gl=US&ceid=US:en",
      category: "FinTech",
    },
    {
      title: "ITmedia AI+",
      url: "https://rss.itmedia.co.jp/rss/2.0/aiplus.xml",
      category: "AI",
    },
    {
      title: "CNET Japan",
      url: "http://feed.japan.cnet.com/rss/index.rdf",
      category: "Technology",
    },
  ];
}

function defaultMarketIntelWatchlist(): MarketIntelWatchItem[] {
  return [
    {
      name: "AI coding tools",
      keywords: [
        "Claude Code",
        "Codex",
        "Cursor",
        "Gemini Code Assist",
        "Devin",
      ],
    },
    {
      name: "AI infrastructure",
      keywords: ["OpenAI", "Anthropic", "Google", "Microsoft", "Nvidia"],
    },
    {
      name: "Financial terminals",
      keywords: ["Bloomberg", "FactSet", "Refinitiv", "Koyfin", "Sentieo"],
    },
  ];
}

function normalizeMarketIntelWatchlist(
  value: unknown,
): MarketIntelWatchItem[] {
  const rawItems = Array.isArray(value) ? value : [];
  const parsed: MarketIntelWatchItem[] = [];
  for (const raw of rawItems) {
    if (typeof raw === "string") {
      const name = raw.trim();
      if (name) parsed.push({ name, keywords: [name] });
      continue;
    }
    const item = asRecord(raw);
    if (!item) continue;
    const name = String(item.name ?? item.symbol ?? item.company ?? "").trim();
    if (!name) continue;
    const keywords = stringArrayFromUnknown(item.keywords, [name]);
    parsed.push({ name, keywords: keywords.length ? keywords : [name] });
  }
  return (parsed.length ? parsed : defaultMarketIntelWatchlist()).slice(0, 24);
}

function normalizeMarketIntelThemes(value: unknown): string[] {
  const themes = stringArrayFromUnknown(value, [
    "AI automation",
    "developer tooling",
    "fintech disruption",
    "pricing pressure",
    "enterprise adoption",
    "risk and regulation",
  ]);
  return themes.slice(0, 16);
}

function matchMarketIntelTerms(
  text: string,
  watchlist: MarketIntelWatchItem[],
): string[] {
  const lower = text.toLowerCase();
  return watchlist
    .filter((item) =>
      [item.name, ...item.keywords].some((keyword) =>
        lower.includes(keyword.toLowerCase())
      )
    )
    .map((item) => item.name);
}

function matchMarketIntelThemes(text: string, themes: string[]): string[] {
  const lower = text.toLowerCase();
  const matched = themes.filter((theme) =>
    theme.split(/\s+/).some((part) =>
      part.length >= 4 && lower.includes(part.toLowerCase())
    )
  );
  return matched.length ? matched : ["general market signal"];
}

function marketIntelClusterKey(item: RankedNewsItem): string {
  const words = item.title
    .toLowerCase()
    .replace(/[^\p{Letter}\p{Number}]+/gu, " ")
    .split(/\s+/)
    .filter((word) => word.length >= 4)
    .slice(0, 10);
  return words.join("-") || item.cluster_key;
}

function sourceHost(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return url;
  }
}

function marketIntelConfidence(
  score: number,
  sourceCount: number,
): "high" | "medium" | "low" {
  if (sourceCount >= 2 && score >= 76) return "high";
  if (sourceCount >= 2 || score >= 58) return "medium";
  return "low";
}

function buildMarketIntelSignal(
  clusterKey: string,
  items: RankedNewsItem[],
  watchlist: MarketIntelWatchItem[],
  themes: string[],
): MarketIntelSignal {
  const ranked = [...items].sort((a, b) => b.signal_score - a.signal_score);
  const lead = ranked[0];
  const text = ranked.map((item) => `${item.title} ${item.summary}`).join(" ");
  const evidence = ranked.slice(0, 6).map((item) => ({
    title: item.title,
    url: item.url,
    source: item.source,
    published_at: item.published_at,
    signal_score: item.signal_score,
    confidence: item.confidence,
  }));
  const sourceCount = new Set(
    evidence.map((item) => item.source || sourceHost(item.url)),
  ).size;
  const watchlistMatches = matchMarketIntelTerms(text, watchlist);
  const themeMatches = matchMarketIntelThemes(text, themes);
  const score = Math.min(
    100,
    lead.signal_score +
      Math.min(12, (sourceCount - 1) * 6) +
      Math.min(10, watchlistMatches.length * 4),
  );
  const confidence = marketIntelConfidence(score, sourceCount);
  const singleSource = sourceCount < 2;
  const uncertainty = singleSource
    ? "Single-source signal. Treat it as a research prompt until another independent source confirms it."
    : "Multiple sources are present, but timing, incentives, and market reaction still need human review.";
  const riskNote = [
    singleSource ? "single-source claim" : "multi-source but unverified claim",
    "no live price confirmation",
    "no automated trading action",
  ].join("; ");
  return {
    id: `market_${stableNewsHash(clusterKey)}`,
    signal: lead.title,
    headline: lead.title,
    themes: themeMatches,
    watchlist_matches: watchlistMatches,
    evidence,
    evidence_count: evidence.length,
    source_count: sourceCount,
    confidence,
    uncertainty,
    risk_note: riskNote,
    what_to_watch_next: [
      "Check official company or regulator source before acting.",
      "Compare the news timestamp with price, volume, and peer movement.",
      "Write a paper decision entry before any real-money decision.",
    ],
    paper_decision_log: {
      status: "research_only",
      action_allowed: "paper_decision_log",
      human_approval_required: true,
      auto_trade_allowed: false,
      invalidate_if: singleSource
        ? "No second source appears within the review window."
        : "Primary evidence conflicts with later official source.",
    },
  };
}

function buildMarketIntelSignals(
  items: RankedNewsItem[],
  watchlist: MarketIntelWatchItem[],
  themes: string[],
  limit: number,
): MarketIntelSignal[] {
  const groups = new Map<string, RankedNewsItem[]>();
  for (const item of items) {
    const key = marketIntelClusterKey(item);
    const current = groups.get(key) ?? [];
    current.push(item);
    groups.set(key, current);
  }
  return [...groups.entries()]
    .map(([key, group]) =>
      buildMarketIntelSignal(key, group, watchlist, themes)
    )
    .sort((a, b) => {
      const confidenceRank = { high: 3, medium: 2, low: 1 };
      const confidenceCmp = confidenceRank[b.confidence] -
        confidenceRank[a.confidence];
      if (confidenceCmp !== 0) return confidenceCmp;
      return b.source_count - a.source_count ||
        b.evidence[0].signal_score - a.evidence[0].signal_score;
    })
    .slice(0, Math.max(1, Math.min(50, limit)));
}

async function buildMarketIntelReport(
  body: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const watchlist = normalizeMarketIntelWatchlist(body.watchlist);
  const themes = normalizeMarketIntelThemes(body.themes);
  const signalLimit = Math.max(
    1,
    Math.min(30, Number(body.signal_limit ?? body.limit ?? 12) || 12),
  );
  const fetchedAt = new Date().toISOString();
  let items: RankedNewsItem[] = [];
  let sourceCount = 0;
  let errors: Array<{ source: string; url: string; error: string }> = [];

  if (Array.isArray(body.items) && body.items.length > 0) {
    items = rankNewsSignals(body.items, Math.max(100, signalLimit * 4));
    sourceCount = new Set(items.map((item) => item.source)).size;
  } else {
    const feeds = normalizeRssFeedInputs(body.feeds);
    const result = await fetchLatestNewsItems({
      ...body,
      feeds: feeds.length ? feeds : defaultMarketIntelFeeds(),
      per_feed_limit: Number(body.per_feed_limit ?? 10),
      limit: Number(body.news_limit ?? 120),
    });
    items = result.items;
    sourceCount = result.source_count;
    errors = result.errors;
  }

  const signals = buildMarketIntelSignals(
    items,
    watchlist,
    themes,
    signalLimit,
  );
  return {
    success: true,
    generated_at: fetchedAt,
    fetched_at: fetchedAt,
    disclaimer: MARKET_INTEL_DISCLAIMER,
    guardrails: {
      no_investment_advice: true,
      auto_trading_enabled: false,
      human_approval_required: true,
      strong_single_source_claims_blocked: true,
    },
    watchlist,
    themes,
    signals,
    audit: {
      generated_by: "tools-hub.market_intel.analyze",
      model: "market-intel-heuristic-v1",
      source_count: sourceCount,
      item_count: items.length,
      signal_count: signals.length,
      errors,
    },
  };
}

async function deleteItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  id: string,
) {
  const { error } = await admin.from("hub_data")
    .delete()
    .eq("id", id)
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

// ===== Horse Racing Multi-Provider Ensemble (Windows版#94) =====
// Quota/failure 時に自動 fallback + 複数プロバイダーで1レースの予想を蓄積
// して精度を向上させる。shared chat 基盤 (ai-hub) と独立させているのは
// horse racing 固有のプロンプト・JSON schema・コスト追跡が混ざらないため。

type HorseProviderConfig = {
  provider: string;
  model: string;
  apiKeyEnv: string;
  estimatedCostUsd: number;
  tier?: "base" | "premium";
  family?: string;
};

const HORSE_BASE_PROVIDER_CHAIN: HorseProviderConfig[] = [
  {
    provider: "google",
    model: "gemini-2.5-flash",
    apiKeyEnv: "GEMINI_API_KEY",
    estimatedCostUsd: 0.0005,
    tier: "base",
    family: "Gemini",
  },
  {
    provider: "openai",
    model: "gpt-4o-mini",
    apiKeyEnv: "OPENAI_API_KEY",
    estimatedCostUsd: 0.002,
    tier: "base",
    family: "GPT",
  },
  {
    provider: "anthropic",
    model: "claude-haiku-4-5-20251001",
    apiKeyEnv: "ANTHROPIC_API_KEY",
    estimatedCostUsd: 0.003,
    tier: "base",
    family: "Claude",
  },
  {
    provider: "xai",
    model: "grok-4-1-fast-non-reasoning",
    apiKeyEnv: "XAI_API_KEY",
    estimatedCostUsd: 0.002,
    tier: "base",
    family: "grok/xAI",
  },
  {
    provider: "openrouter",
    model: "deepseek/deepseek-chat-v3.1",
    apiKeyEnv: "OPENROUTER_API_KEY",
    estimatedCostUsd: 0.0015,
    tier: "base",
    family: "DeepSeek",
  },
];

const HORSE_PREMIUM_PROVIDER_CHAIN: HorseProviderConfig[] = [
  {
    provider: "anthropic",
    model: Deno.env.get("HORSE_ANTHROPIC_SONNET_MODEL") ?? "claude-sonnet-4-6",
    apiKeyEnv: "ANTHROPIC_API_KEY",
    estimatedCostUsd: 0.012,
    tier: "premium",
    family: "Sonnet",
  },
  {
    provider: "anthropic",
    model: Deno.env.get("HORSE_ANTHROPIC_OPUS_MODEL") ?? "claude-opus-4-7",
    apiKeyEnv: "ANTHROPIC_API_KEY",
    estimatedCostUsd: 0.03,
    tier: "premium",
    family: "Opus",
  },
  {
    provider: "openai",
    model: Deno.env.get("HORSE_OPENAI_PREMIUM_MODEL") ?? "gpt-4.1",
    apiKeyEnv: "OPENAI_API_KEY",
    estimatedCostUsd: 0.01,
    tier: "premium",
    family: "GPT",
  },
  {
    provider: "xai",
    model: Deno.env.get("HORSE_XAI_PREMIUM_MODEL") ?? "grok-4",
    apiKeyEnv: "XAI_API_KEY",
    estimatedCostUsd: 0.012,
    tier: "premium",
    family: "grok/xAI",
  },
  {
    provider: "openrouter",
    model: Deno.env.get("HORSE_DEEPSEEK_REASONER_MODEL") ??
      "deepseek/deepseek-r1",
    apiKeyEnv: "OPENROUTER_API_KEY",
    estimatedCostUsd: 0.006,
    tier: "premium",
    family: "DeepSeek",
  },
];

const NETKEIBA_NAR_VENUE_MAP: Record<string, string> = {
  // netkeiba NAR race_id codes. These differ from some NAR official venue codes.
  "30": "門別",
  "35": "盛岡",
  "36": "水沢",
  "42": "浦和",
  "43": "船橋",
  "44": "大井",
  "45": "川崎",
  "46": "金沢",
  "47": "笠松",
  "48": "名古屋",
  "50": "園田",
  "51": "姫路",
  "54": "高知",
  "55": "佐賀",
  "65": "帯広",
};

const NETKEIBA_NAR_ODDSPARK_TRACK_MAP: Record<string, string> = {
  "30": "06", // 門別
  "35": "10", // 盛岡
  "36": "11", // 水沢
  "42": "18", // 浦和
  "43": "19", // 船橋
  "44": "20", // 大井
  "45": "21", // 川崎
  "46": "22", // 金沢
  "47": "23", // 笠松
  "48": "24", // 名古屋
  "50": "27", // 園田
  "51": "28", // 姫路
  "54": "55", // 高知
  "55": "61", // 佐賀
  "65": "03", // 帯広
};

const NETKEIBA_JRA_VENUE_MAP: Record<string, string> = {
  "01": "札幌",
  "02": "函館",
  "03": "福島",
  "04": "新潟",
  "05": "東京",
  "06": "中山",
  "07": "中京",
  "08": "京都",
  "09": "阪神",
  "10": "小倉",
};

function inferHorseVenueFromRaceId(
  raceIdExt: unknown,
  source: unknown,
): string | null {
  const raceId = String(raceIdExt ?? "");
  const sourceKey = String(source ?? "").toLowerCase();
  if (!/^\d{12,}$/.test(raceId)) return null;
  const code = raceId.slice(4, 6);
  if (sourceKey === "nar") return NETKEIBA_NAR_VENUE_MAP[code] ?? null;
  if (sourceKey === "jra") return NETKEIBA_JRA_VENUE_MAP[code] ?? null;
  return null;
}

function normalizeHorseRaceVenue(race: Record<string, unknown>): string | null {
  const inferred = inferHorseVenueFromRaceId(race.race_id_ext, race.source);
  const current = String(race.venue ?? "").trim();
  if (inferred) return inferred;
  return current || null;
}

function decodeHtmlEntities(value: string): string {
  return value
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/g, "'")
    .replace(
      /&#x([0-9a-f]+);/gi,
      (_, hex: string) => String.fromCodePoint(parseInt(hex, 16)),
    )
    .replace(
      /&#(\d+);/g,
      (_, num: string) => String.fromCodePoint(parseInt(num, 10)),
    );
}

function cleanHorseHtmlText(value: string): string {
  return decodeHtmlEntities(value.replace(/<[^>]+>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
}

function isGenericHorseRaceName(value: unknown): boolean {
  const name = String(value ?? "").trim();
  if (!name) return true;
  return /地方競馬レース情報|レース情報\(JRA\)|レース情報|第?\d+レース|^\d+R?$|^レース\s*\d+/i
    .test(name);
}

function oddsParkTrackCodeFromRace(
  race: Record<string, unknown>,
): string | null {
  const raceId = String(race.race_id_ext ?? "");
  if (
    String(race.source ?? "").toLowerCase() !== "nar" ||
    !/^\d{12,}$/.test(raceId)
  ) return null;
  return NETKEIBA_NAR_ODDSPARK_TRACK_MAP[raceId.slice(4, 6)] ?? null;
}

function oddsParkRaceInfoUrl(race: Record<string, unknown>): string | null {
  const trackCode = oddsParkTrackCodeFromRace(race);
  const raceDate = String(race.race_date ?? "").replaceAll("-", "");
  const raceNumber = Number(
    race.race_number ?? String(race.race_id_ext ?? "").slice(-2),
  );
  if (
    !trackCode || !/^\d{8}$/.test(raceDate) || !Number.isFinite(raceNumber) ||
    raceNumber <= 0
  ) return null;
  return `https://www.oddspark.com/keiba/RaceList.do?opTrackCd=${trackCode}&raceDy=${raceDate}&raceNb=${raceNumber}&sponsorCd=04`;
}

function parseOddsParkRaceInfo(html: string, race: Record<string, unknown>) {
  const titleMatch = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  const title = titleMatch ? cleanHorseHtmlText(titleMatch[1]) : "";
  let raceName = title
    .replace(/^【?出走表】?/, "")
    .replace(/[｜|].*$/, "")
    .trim();
  if (raceName === title) {
    const h1Match = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
    raceName = h1Match
      ? cleanHorseHtmlText(h1Match[1]).replace(/^【?出走表】?/, "").trim()
      : raceName;
  }
  const text = cleanHorseHtmlText(html);
  const postTimeMatch = text.match(/発走(?:時間|時刻)?\s*(\d{1,2}:\d{2})/);
  const distanceMatch = text.match(/(\d{3,4})m/);
  const venue = normalizeHorseRaceVenue(race);
  return {
    race_name: raceName && !isGenericHorseRaceName(raceName) ? raceName : null,
    post_time: postTimeMatch?.[1] ?? null,
    distance: distanceMatch?.[1] ? Number(distanceMatch[1]) : null,
    course_type: venue === "帯広" ? "ばんえい" : null,
  };
}

async function fetchOddsParkRaceInfo(race: Record<string, unknown>) {
  const url = oddsParkRaceInfoUrl(race);
  if (!url) return null;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 4500);
  try {
    const res = await fetch(url, {
      headers: {
        "accept":
          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "accept-language": "ja,en;q=0.9",
        "user-agent": "Mozilla/5.0 (compatible; my-web-app horse-racing/1.0)",
      },
      signal: controller.signal,
    });
    if (!res.ok) return null;
    const html = await res.text();
    return parseOddsParkRaceInfo(html, race);
  } catch (error) {
    console.warn(`[horse-racing] OddsPark enrichment failed: ${url}`, error);
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

function shouldEnrichLocalRaceInfo(race: Record<string, unknown>): boolean {
  return String(race.source ?? "").toLowerCase() === "nar" &&
    oddsParkRaceInfoUrl(race) !== null &&
    (isGenericHorseRaceName(race.race_name) || !race.post_time ||
      !race.distance || normalizeHorseRaceVenue(race) === "帯広");
}

async function ensureLiveHorseRaceInfo(
  admin: SupabaseClient,
  race: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  if (!shouldEnrichLocalRaceInfo(race)) {
    return { ...race, venue: normalizeHorseRaceVenue(race) };
  }
  const live = await fetchOddsParkRaceInfo(race);
  if (!live) return { ...race, venue: normalizeHorseRaceVenue(race) };

  const update: Record<string, unknown> = {};
  if (
    live.race_name &&
    (isGenericHorseRaceName(race.race_name) ||
      live.race_name !== race.race_name)
  ) {
    update.race_name = live.race_name;
  }
  if (live.post_time && live.post_time !== race.post_time) {
    update.post_time = live.post_time;
  }
  if (live.distance && live.distance !== race.distance) {
    update.distance = live.distance;
  }
  if (live.course_type && live.course_type !== race.course_type) {
    update.course_type = live.course_type;
  }

  const enriched = {
    ...race,
    ...update,
    venue: normalizeHorseRaceVenue(race),
  };
  if (Object.keys(update).length > 0 && race.id) {
    const { error } = await admin.from("horse_races").update(update).eq(
      "id",
      race.id,
    );
    if (error) {
      console.warn(
        `[horse-racing] live race info update failed: ${error.message}`,
      );
    }
  }
  return enriched;
}

function horseProviderChain(includePremium = false): HorseProviderConfig[] {
  const premiumEnabled = includePremium ||
    /^true$/i.test(Deno.env.get("HORSE_USE_PREMIUM_MODELS") ?? "");
  const chain = premiumEnabled
    ? [...HORSE_BASE_PROVIDER_CHAIN, ...HORSE_PREMIUM_PROVIDER_CHAIN]
    : HORSE_BASE_PROVIDER_CHAIN;
  const seen = new Set<string>();
  return chain.filter((cfg) => {
    const key = `${cfg.provider}:${cfg.model}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function horseModelCandidates() {
  return [...HORSE_BASE_PROVIDER_CHAIN, ...HORSE_PREMIUM_PROVIDER_CHAIN].map((
    cfg,
  ) => ({
    provider: cfg.provider,
    model: cfg.model,
    family: cfg.family ?? cfg.provider,
    tier: cfg.tier ?? "base",
    api_key_env: cfg.apiKeyEnv,
  }));
}

type ProviderPredictionResult = {
  success: boolean;
  prediction?: {
    first: string;
    second: string;
    third: string;
    confidence: number;
    reasoning: string;
  };
  error?: {
    http_status?: number;
    reason: string;
    detail?: string;
    is_quota: boolean;
  };
  latency_ms: number;
};

type HorseBetSuggestion = {
  bet_type: string;
  combination: string;
  horses: string[];
  horse_numbers: number[];
  frames?: number[];
  risk: "low" | "medium" | "high";
  confidence: number;
  stake_units: number;
  recommended: boolean;
  priority: number;
  rationale: string;
  purchase_action?: "buy" | "skip";
  data_quality_score?: number;
  tickets?: Array<
    { combination: string; horses: string[]; horse_numbers: number[] }
  >;
};

function formatHorseEntryForPrompt(e: Record<string, unknown>): string {
  const parts = [
    `馬番${e.horse_number}`,
    String(e.horse_name ?? ""),
    `騎手:${e.jockey ?? "不明"}`,
    `調教師:${e.trainer ?? "不明"}`,
    e.stable ? `厩舎:${e.stable}` : null,
    e.age_sex ? `性齢:${e.age_sex}` : null,
    e.weight_kg ? `斤量:${e.weight_kg}` : null,
    e.horse_weight
      ? `馬体重:${e.horse_weight}${
        e.horse_weight_change !== undefined && e.horse_weight_change !== null
          ? `(${e.horse_weight_change})`
          : ""
      }`
      : null,
    e.win_odds ? `単勝:${e.win_odds}倍` : null,
    e.popularity ? `${e.popularity}番人気` : null,
    e.sire || e.dam || e.damsire
      ? `血統:${
        [
          e.sire ? `父${e.sire}` : null,
          e.dam ? `母${e.dam}` : null,
          e.damsire ? `母父${e.damsire}` : null,
        ].filter(Boolean).join("/")
      }`
      : null,
    e.prev_race_name || e.prev_finish || e.prev_time
      ? `前走:${
        [
          e.prev_race_date,
          e.prev_venue,
          e.prev_race_name,
          e.prev_finish ? `${e.prev_finish}着` : null,
          e.prev_margin ? `着差${e.prev_margin}` : null,
          e.prev_distance
            ? `${e.prev_course_type ?? ""}${e.prev_distance}m`
            : null,
          e.prev_time ? `時計${e.prev_time}` : null,
          e.prev_last_3f ? `上り${e.prev_last_3f}` : null,
          e.prev_days_ago ? `${e.prev_days_ago}日前` : null,
        ].filter(Boolean).join(" ")
      }`
      : null,
    e.best_time ? `持ち時計:${e.best_time}` : null,
  ].filter((part) => part !== null && String(part).trim().length > 0);
  return parts.join(" / ");
}

function buildHorseRacePrompt(
  race: Record<string, unknown>,
  entries: Record<string, unknown>[],
): string {
  const entryText = entries.map(formatHorseEntryForPrompt).join("\n");
  const dataQuality = horseRaceDataQualityScore(entries);
  return `競馬レース「${race.race_name}」(${race.venue ?? ""}/${
    race.course_type ?? "芝"
  }${race.distance ?? ""}m/${
    race.grade ?? ""
  }) の低リスク予想をしてください。\n必ず下記の出走馬リストに存在する馬名だけを選び、取消・非出走・リスト外の馬名は絶対に入れないでください。\n最優先は的中確率と資金保全です。単勝、複勝、枠連、馬連、ワイド、馬単、3連複、3連単をすべて検討し、低リスク順の買い方をreasoningに含めてください。\n血統、前走、持ち時計(best_time)、馬体重・馬体重変動(±kg)、騎手、調教師、厩舎、タイム、オッズ、人気を重視してください。特に「持ち時計」は過去ベストタイムで距離適性を示し、「馬体重変動」が大きい場合(±10kg超)は体調不良・過太りのリスク信号です。「馬体重(weight_kg)」が430kg未満の軽量馬はスタミナ/パワー不足リスク、560kg超の重量馬は機動力低下リスクがあります。「前走タイム(prev_time)」が「持ち時計(best_time)」より2秒以上遅い場合は調子落ちの可能性があります。「前走着差(着差フィールド)」が大差の場合は大きな評価ダウン、ハナ/クビ差なら健闘(僅差)と評価してください。「前走からの経過日数」が90日超の場合は休み明けリスク(仕上がり未知・レース勘の鈍り)を考慮してください。逆に前走から7日以内(連闘)または14日以内(中1週)の場合は疲労蓄積リスクがあります。「前走コース種別」が今回と異なる場合(例: 前走ダート→今回芝)はコース替わりリスクを評価してください。「前走距離」と今回距離の差が200m超の場合は距離適性リスク(短縮・延長)を考慮してください。「出走頭数」が13頭以上の場合は中型レース、16頭以上の大型レースは統計的に波乱率が高く予測精度が低下しやすいです。「1番人気と2番人気のオッズ差が5倍以上の場合は1強レースとして予測しやすく、差が小さい混戦レースは波乱リスクが高まります。」データ不足または信頼度が低い場合は「購入しない」選択もreasoningに明記してください。\nデータ充足度:${
    Math.round(dataQuality * 100)
  }%　出走頭数:${entries.length}頭${
    entries.length >= 16
      ? "（大型レース・高波乱リスク）"
      : entries.length >= 13
      ? "（中型レース・波乱注意）"
      : ""
  }\n出走馬:\n${entryText}\n\nJSON形式のみで回答 (前後に説明文を入れない): {"first":"予想馬名1","second":"予想馬名2","third":"予想馬名3","confidence":0.0,"reasoning":"根拠と券種別の低リスク買い目。購入しない判断が妥当ならその理由"}`;
}

function normalizeHorseNameForMatch(value: unknown): string {
  return String(value ?? "").trim().replace(/\s+/g, "").toLowerCase();
}

function lowRiskBetGuide(first: string, second: string, third: string): string {
  return [
    `低リスク本線: 複勝 ${first}`,
    `単勝: ${first}`,
    `ワイド: ${first}-${second} / ${first}-${third}`,
    `馬連: ${first}-${second}`,
    `枠連: ${first}-${second}の枠`,
    `馬単: ${first}→${second}`,
    `3連複: ${first}-${second}-${third}`,
    `3連単: ${first}→${second}→${third}は少額`,
  ].join(" / ");
}

function horseEntryLookup(entries: Record<string, unknown>[]) {
  const byName = new Map<string, Record<string, unknown>>();
  for (const entry of entries) {
    const name = String(entry.horse_name ?? "").trim();
    if (name) byName.set(normalizeHorseNameForMatch(name), entry);
  }
  return byName;
}

function horseNumberOf(entry?: Record<string, unknown>): number | null {
  const value = Number(entry?.horse_number ?? 0);
  return Number.isFinite(value) && value > 0 ? value : null;
}

function frameForHorseNumber(
  horseNumber: number | null,
  fieldSize: number,
): number | null {
  if (!horseNumber || fieldSize <= 0) return null;
  if (fieldSize <= 8) return horseNumber;
  const base = Math.floor(fieldSize / 8);
  const extra = fieldSize % 8;
  let start = 1;
  for (let frame = 1; frame <= 8; frame += 1) {
    const size = base + (frame > 8 - extra ? 1 : 0);
    const end = start + size - 1;
    if (horseNumber >= start && horseNumber <= end) return frame;
    start = end + 1;
  }
  return null;
}

function horseNumberLabel(entry?: Record<string, unknown>): string {
  const number = horseNumberOf(entry);
  return number
    ? String(number).padStart(2, "0")
    : String(entry?.horse_name ?? "");
}

function gradeMaxConfidence(grade: unknown): number {
  const g = String(grade ?? "").trim();
  if (/^(G1|GI|JpnI)$/i.test(g)) return 0.65; // top grade: hardest to predict
  if (/^(G2|GII|JpnII)$/i.test(g)) return 0.70;
  if (/^(G3|GIII|JpnIII)$/i.test(g)) return 0.75;
  return 0.80;
}

function tooFrequentRacePenalty(value: unknown): number {
  const days = numericOrFallback(value, 0);
  if (days <= 0) return 0; // データなし
  if (days <= 7) return 8; // 連闘 — 疲労リスク最大
  if (days <= 13) return 4; // 中1週 — 疲労リスク中程度
  return 0; // 中2週以上は正常
}

function prevTimeGapPenalty(prevTime: unknown, bestTime: unknown): number {
  const prev = timeToSecondsTS(prevTime);
  const best = timeToSecondsTS(bestTime);
  if (prev === null || best === null) return 0; // データなし — ペナルティなし
  const gap = prev - best; // 正数 = 前走タイムがbest_timeより遅い
  if (gap >= 3.0) return 6; // 3秒以上遅い — 大幅調子落ち
  if (gap >= 2.0) return 4;
  if (gap >= 1.0) return 2;
  return 0; // ±1秒以内は正常
}

function weightKgOutlierPenalty(value: unknown): number {
  const kg = numericOrFallback(value, 0);
  if (kg <= 0) return 2; // データなし
  if (kg < 430) return 5; // 軽量すぎ — スタミナ/パワー不足リスク
  if (kg > 560) return 4; // 重量すぎ — 機動力低下リスク
  return 0; // 適正範囲 430-560kg
}

function recentFormBonus(entries: Record<string, unknown>[]): number {
  if (entries.length === 0) return 0;
  const topHorse = entries.reduce((best, e) => {
    const odds = numericOrFallback(e.win_odds, 999);
    const bestOdds = numericOrFallback(best.win_odds, 999);
    return odds < bestOdds ? e : best;
  }, entries[0]);
  const finish = numericOrFallback(topHorse.prev_finish, 99);
  const days = numericOrFallback(topHorse.prev_days_ago, 999);
  if (finish <= 3 && days > 0 && days <= 30) return 0.03; // 1強が直近好走
  if (finish <= 3 && days > 0 && days <= 60) return 0.01;
  return 0;
}

function topTwoOddsGapBonus(entries: Record<string, unknown>[]): number {
  const sortedOdds = entries
    .map((e) => numericOrFallback(e.win_odds, 0))
    .filter((o) => o > 0)
    .sort((a, b) => a - b);
  if (sortedOdds.length < 2) return 0;
  const gap = sortedOdds[1] - sortedOdds[0];
  if (gap >= 5.0) return 0.05; // 1強レース — 予測しやすい
  if (gap >= 3.0) return 0.03;
  if (gap >= 1.5) return 0.01;
  return 0; // 混戦 — bonus なし
}

function tightOddsPenalty(entries: Record<string, unknown>[]): number {
  const sortedOdds = entries
    .map((e) => numericOrFallback(e.win_odds, 0))
    .filter((o) => o > 0)
    .sort((a, b) => a - b);
  if (sortedOdds.length < 3) return 0;
  const spread = sortedOdds[2] - sortedOdds[0]; // 3番人気オッズ - 1番人気オッズ
  if (spread < 1.0) return 0.06; // 超混戦 (3頭以内に1倍差) — 高ペナルティ
  if (spread < 2.0) return 0.03; // 混戦
  return 0;
}

function venueConfidenceBonus(venue: unknown): number {
  const v = String(venue ?? "").trim();
  if (["東京", "中山", "京都", "阪神"].includes(v)) return 0.03; // JRA主要4場: G1開催・投票量最大
  if (["札幌", "函館", "福島", "新潟", "中京", "小倉"].includes(v)) return 0.01; // その他JRA
  if (v === "帯広") return -0.04; // ばんえい: 完全別ルール
  if (
    [
      "門別",
      "盛岡",
      "水沢",
      "浦和",
      "船橋",
      "大井",
      "川崎",
      "金沢",
      "笠松",
      "名古屋",
      "園田",
      "姫路",
      "高知",
      "佐賀",
    ].includes(v)
  ) return -0.02; // NAR地方
  return 0; // 会場不明
}

function favOddsBonus(entries: Record<string, unknown>[]): number {
  const odds = entries
    .map((e) => numericOrFallback(e.win_odds, 0))
    .filter((o) => o > 0);
  if (odds.length === 0) return 0;
  const topOdds = Math.min(...odds);
  if (topOdds <= 1.5) return 0.05; // 圧倒的本命 (単勝1.5倍以下)
  if (topOdds <= 2.0) return 0.03; // 強い本命
  if (topOdds <= 3.0) return 0.01; // 本命
  return 0; // 混戦 or データなし
}

function bloodlineTopHorseBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const hasSire = topEntry.sire && String(topEntry.sire).trim() !== "";
  const hasDam = topEntry.dam && String(topEntry.dam).trim() !== "";
  const hasDamsire = topEntry.damsire && String(topEntry.damsire).trim() !== "";
  if (hasSire && hasDam && hasDamsire) return 0.02; // 血統3項目完全充足
  if (hasSire || hasDam) return 0.01; // 父 or 母のみ
  return 0;
}

function consensusBonus(topEntry: Record<string, unknown> | undefined): number {
  if (!topEntry) return 0;
  const popularity = numericOrFallback(topEntry.popularity, 99);
  const odds = numericOrFallback(topEntry.win_odds, 99);
  const prevFinish = numericOrFallback(topEntry.prev_finish, 99);
  const isTopPopularity = popularity === 1;
  const hasLowOdds = odds > 0 && odds <= 3.0;
  const hasGoodPrev = prevFinish >= 1 && prevFinish <= 3;
  if (isTopPopularity && hasLowOdds && hasGoodPrev) return 0.04; // 3指標全一致: 最強consensus
  if (isTopPopularity && (hasLowOdds || hasGoodPrev)) return 0.02; // 2指標一致
  return 0;
}

function distanceSpecificBonus(distance: unknown): number {
  const d = numericOrFallback(distance, 0);
  if (d <= 0) return 0; // データなし
  if (d <= 1200) return 0.02; // スプリント: 直線スピード主体/戦術少/予測容易
  if (d <= 1600) return 0.01; // マイル: やや容易
  if (d >= 2400) return -0.02; // 長距離: スタミナ不確実/展開要因増/予測困難
  if (d >= 2000) return -0.01; // 中長距離: やや困難
  return 0; // 1601-1999m: 標準
}

function jockeyWinRateBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const rate = numericOrFallback(topEntry.jockey_win_rate, 0);
  if (rate <= 0) return 0; // データなし
  if (rate >= 0.20) return 0.03; // 勝率20%以上: トップジョッキー
  if (rate >= 0.15) return 0.02; // 勝率15%以上: 好騎手
  if (rate >= 0.10) return 0.01; // 勝率10%以上: 安定騎手
  return 0;
}

function trainerWinRateBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const rate = numericOrFallback(topEntry.trainer_win_rate, 0);
  if (rate <= 0) return 0; // データなし
  if (rate >= 0.15) return 0.02; // 勝率15%以上: トップトレーナー
  if (rate >= 0.10) return 0.01; // 勝率10%以上: 好調教師
  return 0;
}

function gradeDifficultyPenalty(grade: unknown): number {
  const g = String(grade ?? "").toUpperCase();
  if (g === "G1") return -0.03; // 最高格: 超実力馬集結/展開不確実/予測困難
  if (g === "G2") return -0.02; // 重賞上位: やや困難
  if (g === "G3") return -0.01; // 重賞: やや不確実
  return 0; // OP/L/条件戦: 標準
}

function horseWeightStabilityBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  if (
    topEntry.horse_weight_change === null ||
    topEntry.horse_weight_change === undefined ||
    topEntry.horse_weight_change === ""
  ) {
    return 0;
  }
  const change = numericOrFallback(topEntry.horse_weight_change, 0);
  if (change === 0) return 0; // 前走同体重
  const abs = Math.abs(change);
  if (abs <= 2) return 0.01; // ±2kg以内: 体重安定管理/予測容易
  if (abs >= 8) return -0.01; // ±8kg以上: 大幅変動/調整乱れ/予測困難
  return 0; // 3〜7kg: 標準範囲
}

function ageOptimalBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const text = String(topEntry.age_sex ?? "").trim();
  if (!text) return 0;
  const match = text.match(/(\d+)/);
  if (!match) return 0;
  const age = parseInt(match[1]);
  if (age === 4) return 0.02; // 4歳: 多くの馬のピーク/予測しやすい
  if (age === 5) return 0.01; // 5歳: ピーク後半/安定
  if (age >= 6) return -0.01; // 6歳以上: 下降期/不確実
  return 0; // 3歳以下: 成長途上/標準
}

function raceIntervalBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const days = numericOrFallback(topEntry.prev_days_ago, 0);
  if (days <= 0) return 0; // データなし
  if (days <= 6) return -0.01; // 超短期連闘: 疲労懸念/不確実
  if (days <= 35) return 0.01; // 7〜35日: 最適間隔/仕上がり安定/予測容易
  if (days >= 91) return -0.01; // 91日以上: 長期休み明け/本来形不明
  return 0; // 36〜90日: 標準
}

function courseTypeMatchBonus(
  topEntry: Record<string, unknown> | undefined,
  currentCourseType: unknown,
): number {
  if (!topEntry) return 0;
  const prev = String(topEntry.prev_course_type ?? "").trim();
  const curr = String(currentCourseType ?? "").trim();
  if (!prev || !curr) return 0;
  if (prev === curr) return 0.02; // 同コース種別(芝→芝/ダート→ダート): 実績あり/予測容易
  return -0.02; // コース替わり(芝↔ダート): 適性未知/不確実
}

function popularityRankBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const pop = numericOrFallback(topEntry.popularity, 0);
  if (pop <= 0) return 0; // データなし
  if (pop === 1) return 0.01; // 1番人気: 市場最高評価/的中確率高め
  if (pop >= 7) return -0.01; // 7番人気以下: 低人気=高リスク
  return 0; // 2〜6番人気: 標準
}

function sexCategoryBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const text = String(topEntry.age_sex ?? "").trim();
  if (!text) return 0;
  if (text.includes("セン")) return 0.01; // セン馬(去勢): 気性安定/安定したパフォーマンス
  if (text.includes("牝")) return -0.01; // 牝馬: 牡馬混合レースでは統計的に不利
  return 0; // 牡馬: 基準
}

function weightChangeBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const raw = topEntry.horse_weight_change;
  if (raw === null || raw === undefined || String(raw).trim() === "") return 0;
  const change = numericOrFallback(raw, 999);
  if (change === 999) return 0; // 変換失敗
  if (change >= 2 && change <= 6) return 0.01; // 微増(+2〜+6kg): 好調充実/仕上がり良好
  if (change <= -8 || change >= 10) return -0.01; // 大変動(±8kg超): 体調不安定リスク
  return 0; // 小幅変動: 標準
}

function prevFinishBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const finish = numericOrFallback(topEntry.prev_finish, 0);
  if (finish <= 0) return 0; // データなし
  if (finish === 1) return 0.02; // 前走1着: 連勝期待/最高フォーム
  if (finish <= 3) return 0.01; // 前走2〜3着: 好走継続/安定上位
  if (finish >= 7) return -0.01; // 前走7着以下: 大敗/フォーム低下リスク
  return 0; // 前走4〜6着: 標準
}

function winningExperienceBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const wt = topEntry.winning_time;
  if (wt === null || wt === undefined || String(wt).trim() === "") return 0;
  return 0.01; // 勝利実績あり(winning_time存在): 勝ち方を知っている/精神的優位
}

function jockeyTrainerComboBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const jRate = numericOrFallback(topEntry.jockey_win_rate, 0);
  const tRate = numericOrFallback(topEntry.trainer_win_rate, 0);
  if (jRate <= 0 || tRate <= 0) return 0; // どちらかデータなし
  if (jRate >= 0.15 && tRate >= 0.15) return 0.02; // エリートコンビ: 最強シナジー
  if (jRate >= 0.10 && tRate >= 0.10) return 0.01; // 好コンビ: 両者安定/シナジー効果
  return 0; // 片方のみ好成績: 個別補正でカバー済み
}

function topHorseDataCompletenessBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const keyFields = [
    "jockey",
    "trainer",
    "win_odds",
    "popularity",
    "age_sex",
    "horse_weight",
    "weight_kg",
    "prev_finish",
    "prev_time",
    "prev_last_3f",
  ];
  const filled = keyFields.filter((f) => {
    const v = topEntry[f];
    return v !== null && v !== undefined && String(v).trim() !== "";
  }).length;
  if (filled >= 10) return 0.02; // 全10項目充足: 最高信頼度/評価材料完全
  if (filled >= 7) return 0.01; // 7〜9項目: 十分な評価材料
  return 0; // 6項目以下: 評価材料不足
}

function prevRaceContextTrifectaBonus(
  topEntry: Record<string, unknown> | undefined,
  raceVenue: unknown,
  raceDistance: unknown,
  raceCourseType: unknown,
): number {
  if (!topEntry) return 0;
  const prevVenue = String(topEntry.prev_venue ?? "").trim();
  const currVenue = String(raceVenue ?? "").trim();
  const venueMatch = prevVenue !== "" && prevVenue === currVenue;

  const prevDist = numericOrFallback(topEntry.prev_distance, 0);
  const currDist = numericOrFallback(raceDistance, 0);
  const distMatch = prevDist > 0 && currDist > 0 &&
    Math.abs(prevDist - currDist) <= 100;

  const prevCourse = String(topEntry.prev_course_type ?? "").trim();
  const currCourse = String(raceCourseType ?? "").trim();
  const courseMatch = prevCourse !== "" && currCourse !== "" &&
    prevCourse === currCourse;

  if (venueMatch && distMatch && courseMatch) return 0.02; // 三一致: 同レースを経験済み/最強親しみ
  return 0; // 部分一致: 個別補正でカバー済み
}

function bloodlineCourseTypeBonus(
  topEntry: Record<string, unknown> | undefined,
  raceCourseType: unknown,
): number {
  if (!topEntry) return 0;
  const sire = String(topEntry.sire ?? "").trim();
  const course = String(raceCourseType ?? "").trim();
  if (!sire || !course) return 0;
  const turfSires = [
    "ディープインパクト",
    "ハービンジャー",
    "エピファネイア",
    "キズナ",
    "ルーラーシップ",
    "オルフェーヴル",
    "ステイゴールド",
    "マンハッタンカフェ",
  ];
  const dirtSires = [
    "ゴールドアリュール",
    "パイロ",
    "ヘニーヒューズ",
    "シニスターミニスター",
    "スマートファルコン",
    "ホッコータルマエ",
    "コパノリッキー",
  ];
  const isTurf = course.includes("芝") || course.toLowerCase() === "turf";
  const isDirt = course.includes("ダート") || course.toLowerCase() === "dirt";
  if (isTurf && turfSires.some((s) => sire.includes(s))) return 0.01; // 芝適性種牡馬×芝: 実績適性一致
  if (isDirt && dirtSires.some((s) => sire.includes(s))) return 0.01; // ダート適性種牡馬×ダート: 適性一致
  if (isDirt && turfSires.some((s) => sire.includes(s))) return -0.01; // 芝系種牡馬がダート: 逆適性リスク
  if (isTurf && dirtSires.some((s) => sire.includes(s))) return -0.01; // ダート系種牡馬が芝: 逆適性リスク
  return 0;
}

function bestTimeFieldRankBonus(
  topEntry: Record<string, unknown> | undefined,
  allEntries: Record<string, unknown>[],
): number {
  if (!topEntry || allEntries.length < 2) return 0;
  const topTime = timeToSecondsTS(topEntry.best_time);
  if (topTime === null) return 0;
  const validTimes = allEntries
    .map((e) => timeToSecondsTS(e.best_time))
    .filter((t): t is number => t !== null);
  if (validTimes.length < 2) return 0;
  const minTime = Math.min(...validTimes);
  if (topTime === minTime) return 0.02; // フィールド最速ベスト: 実力No.1の証明
  if (topTime <= minTime + 0.5) return 0.01; // 0.5秒差以内: トップクラス
  if (topTime >= minTime + 2.0) return -0.01; // 2秒以上遅れ: 実力差大きい
  return 0;
}

function popularityPrevFinishConsistencyBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const pop = numericOrFallback(topEntry.popularity, 0);
  const finishText = String(topEntry.prev_finish ?? "").trim();
  const match = finishText.match(/\d+/);
  if (!match) return 0;
  const finish = parseInt(match[0]);
  if (!Number.isFinite(finish) || pop <= 0) return 0;
  if (pop === 1 && finish <= 3) return 0.02; // 1番人気×前走3着以内: 安定した実力馬
  if (pop <= 3 && finish === 1) return 0.01; // 上位人気×前走1着: 連勝気配
  if (pop === 1 && finish >= 6) return -0.02; // 1番人気×前走惨敗: 調子落ちリスク大
  if (pop <= 3 && finish >= 8) return -0.01; // 上位人気×前走大敗: 状態不安
  return 0;
}

function damSireLineBonus(
  topEntry: Record<string, unknown> | undefined,
  raceCourseType: unknown,
): number {
  if (!topEntry) return 0;
  const ds = String(topEntry.damsire ?? "").trim();
  const course = String(raceCourseType ?? "").trim();
  if (!ds || !course) return 0;
  const turfDamsires = [
    "サンデーサイレンス",
    "ダンスインザダーク",
    "フジキセキ",
    "スペシャルウィーク",
    "ネオユニヴァース",
    "マーベラスサンデー",
    "ノーザンダンサー",
    "ニジンスキー",
    "サドラーズウェルズ",
  ];
  const dirtDamsires = [
    "ブライアンズタイム",
    "フォーティーナイナー",
    "エンドスウィープ",
    "クロフネ",
    "ティンバーカントリー",
    "アフリート",
    "シェフリー",
  ];
  const isTurf = course.includes("芝") || course.toLowerCase() === "turf";
  const isDirt = course.includes("ダート") || course.toLowerCase() === "dirt";
  if (isTurf && turfDamsires.some((s) => ds.includes(s))) return 0.01; // 芝系母父×芝: 母系適性一致
  if (isDirt && dirtDamsires.some((s) => ds.includes(s))) return 0.01; // ダート系母父×ダート: 母系適性一致
  if (isDirt && turfDamsires.some((s) => ds.includes(s))) return -0.01; // 芝系母父×ダート: 逆適性懸念
  return 0;
}

function popularityOddsAlignBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const pop = numericOrFallback(topEntry.popularity, 0);
  const odds = numericOrFallback(topEntry.win_odds, 0);
  if (pop <= 0 || odds <= 0) return 0;
  if (pop === 1 && odds <= 2.0) return 0.01; // 1番人気×単勝2倍以下: 市場の強い合意/予測容易
  if (pop === 1 && odds > 5.0) return -0.01; // 1番人気×単勝5倍超: 人気と市場の乖離/不確実
  if (pop <= 3 && odds > 8.0) return -0.01; // 上位3番人気×単勝8倍超: 市場の過大評価懸念
  return 0;
}

function ageDistanceAffinityBonus(
  topEntry: Record<string, unknown> | undefined,
  raceDistance: unknown,
): number {
  if (!topEntry) return 0;
  const text = String(topEntry.age_sex ?? "").trim();
  const dist = numericOrFallback(raceDistance, 0);
  if (!text || dist <= 0) return 0;
  const match = text.match(/(\d+)/);
  if (!match) return 0;
  const age = parseInt(match[1]);
  if (age === 3 && dist >= 2400) return -0.01; // 3歳×長距離: 体力未成熟/スタミナ不確実
  if (age === 3 && dist <= 1200) return 0.01; // 3歳×スプリント: 若い脚力/距離負担軽/安定
  if (age >= 5 && dist >= 2000) return 0.01; // 古馬×中長距離: 経験豊富/スタミナ実証済み
  return 0;
}

function sireRankBonus(topEntry: Record<string, unknown> | undefined): number {
  if (!topEntry) return 0;
  const sire = String(topEntry.sire ?? "").trim();
  if (!sire) return 0;
  const topSires = [
    "ロードカナロア",
    "キタサンブラック",
    "エピファネイア",
    "ハービンジャー",
    "モーリス",
    "ルーラーシップ",
    "オルフェーヴル",
    "キズナ",
    "ドゥラメンテ",
    "リアルスティール",
  ];
  if (topSires.some((s) => sire.includes(s))) return 0.01; // トップ種牡馬産駒: 高連対率/市場信頼高/データ充実
  return 0;
}

function prevDistanceTrendBonus(
  topEntry: Record<string, unknown> | undefined,
  raceDistance: unknown,
): number {
  if (!topEntry) return 0;
  const prev = numericOrFallback(topEntry.prev_distance, 0);
  const curr = numericOrFallback(raceDistance, 0);
  if (!prev || !curr) return 0;
  const diff = curr - prev; // 正=距離延長 負=距離短縮
  if (diff <= -200) return 0.01; // 距離短縮(200m以上): スピード優位/余力残る/安定
  if (diff >= 500) return -0.01; // 大幅距離延長(500m以上): スタミナ未知/リスク高
  return 0;
}

function oddsFieldSpreadBonus(entries: Record<string, unknown>[]): number {
  const validOdds = entries.map((e) => numericOrFallback(e.win_odds, 0)).filter(
    (o) => o > 0,
  );
  if (validOdds.length < 3) return 0;
  const minOdds = Math.min(...validOdds);
  const maxOdds = Math.max(...validOdds);
  const spread = maxOdds - minOdds;
  if (spread >= 50) return 0.01; // 大きな分散(50倍以上): 明確な本命/予測容易
  if (spread <= 10) return -0.01; // 小さな分散(10倍以内): 混戦/予測困難
  return 0;
}

function prevWinMarginBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const finish = numericOrFallback(topEntry.prev_finish, 0);
  if (finish !== 1) return 0; // 前走1着以外: 対象外
  const text = String(topEntry.prev_margin ?? "").trim();
  if (!text) return 0;
  if (text === "大差") return 0.02; // 大差勝ち: 圧倒的実力/最強シグナル
  const numeric = parseFloat(text);
  if (Number.isFinite(numeric) && numeric >= 3) return 0.01; // 3馬身以上: 快勝/実力上位
  if (Number.isFinite(numeric) && numeric <= 0.1) return 0; // ハナ差勝ち: 際どい勝利/普通
  return 0;
}

function horseNumberFieldRatioBonus(
  topEntry: Record<string, unknown> | undefined,
  fieldSize: number,
): number {
  if (!topEntry || fieldSize <= 0) return 0;
  const num = numericOrFallback(topEntry.horse_number, 0);
  if (!num) return 0;
  const ratio = num / fieldSize; // 0=最内枠 1=最外枠相当
  if (ratio <= 0.2) return 0.01; // フィールド上位20%の内枠: 有利ポジション
  if (ratio >= 0.85) return -0.01; // フィールド上位15%の外枠: 距離ロスリスク
  return 0;
}

function multipleTopSignalBonus(
  topEntry: Record<string, unknown> | undefined,
  _entries: Record<string, unknown>[],
  _raceCourseType: unknown,
): number {
  if (!topEntry) return 0;
  let positiveCount = 0;
  const pop = numericOrFallback(topEntry.popularity, 99);
  const odds = numericOrFallback(topEntry.win_odds, 99);
  const finish = numericOrFallback(topEntry.prev_finish, 99);
  const jRate = numericOrFallback(topEntry.jockey_win_rate, 0);
  const tRate = numericOrFallback(topEntry.trainer_win_rate, 0);
  if (pop === 1) positiveCount++; // 1番人気
  if (odds > 0 && odds <= 3.0) positiveCount++; // 低オッズ
  if (finish >= 1 && finish <= 3) positiveCount++; // 前走好走
  if (jRate >= 0.15) positiveCount++; // トップジョッキー
  if (tRate >= 0.10) positiveCount++; // 好調教師
  if (positiveCount >= 4) return 0.02; // 4+シグナル: 複数指標が同時支持/最強合意
  if (positiveCount >= 3) return 0.01; // 3シグナル: 強い合意
  return 0;
}

function trackConditionAdaptBonus(
  topEntry: Record<string, unknown> | undefined,
  raceTrackCondition: unknown,
): number {
  if (!topEntry) return 0;
  const wetConditions = ["重", "不良"];
  const prevCond = String(topEntry.prev_track_condition ?? "").trim();
  const currCond = String(raceTrackCondition ?? "").trim();
  if (!prevCond || !currCond) return 0;
  const prevWet = wetConditions.includes(prevCond);
  const currWet = wetConditions.includes(currCond);
  if (prevWet && currWet) return 0.01;
  if (!prevWet && !currWet) return 0;
  return -0.01;
}

function runningStyleDistanceBonus(
  topEntry: Record<string, unknown> | undefined,
  raceDistance: unknown,
): number {
  if (!topEntry) return 0;
  const style = String(topEntry.running_style ?? "").trim();
  if (!style) return 0;
  const dist = numericOrFallback(raceDistance, 1600);
  if ((style === "逃" || style === "先") && dist <= 1400) return 0.01;
  if ((style === "差" || style === "追") && dist >= 2000) return 0.01;
  if ((style === "逃" || style === "先") && dist >= 2400) return -0.01;
  return 0;
}

function prev2FinishConsistencyBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const f1 = numericOrFallback(topEntry.prev_finish, 0);
  const f2 = numericOrFallback(topEntry.prev2_finish, 0);
  if (!f1 || !f2) return 0;
  if (f1 <= 3 && f2 <= 3) return 0.02;
  if (f1 >= 7 && f2 >= 7) return -0.01;
  return 0;
}

function raceClassStepBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const curr = numericOrFallback(topEntry.race_class_rank, 0);
  const prev = numericOrFallback(topEntry.prev_race_class_rank, 0);
  if (!curr || !prev) return 0;
  if (curr < prev) return 0.01; // 降格: 格下条件で有利
  if (curr > prev) return -0.01; // 昇格: 格上条件で不利
  return 0;
}

function favoriteConsistencyBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const currPop = numericOrFallback(topEntry.popularity, 99);
  const prevPop = numericOrFallback(topEntry.prev_popularity, 99);
  if (currPop !== 1) return 0;
  if (prevPop === 1) return 0.01; // 前走も1番人気=安定した支持
  if (prevPop >= 5) return -0.01; // 前走低人気から急1番人気=不安定
  return 0;
}

function jockeyTopCourseBonus(
  topEntry: Record<string, unknown> | undefined,
  raceCourse: unknown,
): number {
  if (!topEntry) return 0;
  const topCourse = String(topEntry.jockey_top_course ?? "").trim();
  const course = String(raceCourse ?? "").trim();
  if (!topCourse || !course) return 0;
  if (topCourse === course) return 0.01; // 騎手の得意コース
  return 0;
}

function trainerTopCourseBonus(
  topEntry: Record<string, unknown> | undefined,
  raceCourse: unknown,
): number {
  if (!topEntry) return 0;
  const topCourse = String(topEntry.trainer_top_course ?? "").trim();
  const course = String(raceCourse ?? "").trim();
  if (!topCourse || !course) return 0;
  if (topCourse === course) return 0.01; // 調教師の得意コース
  return 0;
}

function prev3FormTrendBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const f1 = numericOrFallback(topEntry.prev_finish, 0);
  const f2 = numericOrFallback(topEntry.prev2_finish, 0);
  const f3 = numericOrFallback(topEntry.prev3_finish, 0);
  if (!f1 || !f2 || !f3) return 0;
  if (f1 < f2 && f2 < f3) return 0.01; // 3走連続着順改善トレンド
  if (f1 > f2 && f2 > f3) return -0.01; // 3走連続着順悪化トレンド
  return 0;
}

function jockeyChangeBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const currJockey = String(topEntry.jockey_name ?? "").trim();
  const prevJockey = String(topEntry.prev_jockey ?? "").trim();
  if (!currJockey || !prevJockey || currJockey === prevJockey) return 0;
  const winRate = numericOrFallback(topEntry.jockey_win_rate, 0);
  if (winRate >= 0.15) return 0.01; // 高勝率騎手に交代 = 陣営強化シグナル
  if (winRate < 0.05) return -0.01; // 低勝率騎手に交代 = 陣営弱化シグナル
  return 0;
}

function prevPopularityBounceBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const prevPop = numericOrFallback(topEntry.prev_popularity, 0);
  const prevFin = numericOrFallback(topEntry.prev_finish, 0);
  if (!prevPop || !prevFin) return 0;
  if (prevPop <= 2 && prevFin >= 4) return 0.01; // 前走1-2番人気→4着以下敗退 = 巻き返し期待
  if (prevPop >= 6 && prevFin <= 3) return 0.01; // 前走6番人気以下→3着以内好走 = 人気薄好走実績
  return 0;
}

function weightChangeCourseSuitBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const change = numericOrFallback(topEntry.horse_weight_change, 0);
  const courseType = String(topEntry.prev_course_type ?? "").trim();
  if (!change || !courseType) return 0;
  if (courseType === "ダート" && change >= 10) return 0.01; // ダート+10kg以上増 = パワーアップ
  if (courseType === "芝" && change >= 20) return -0.01; // 芝+20kg以上増 = 重め仕上げ注意
  return 0;
}

function prev3AvgFinishBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const f1 = numericOrFallback(topEntry.prev_finish, 0);
  const f2 = numericOrFallback(topEntry.prev2_finish, 0);
  const f3 = numericOrFallback(topEntry.prev3_finish, 0);
  if (!f1 || !f2 || !f3) return 0;
  const avg = (f1 + f2 + f3) / 3;
  if (avg <= 2.0) return 0.01; // 前3走平均2着以内 = 圧倒的安定感
  if (avg >= 7.0) return -0.01; // 前3走平均7着以下 = 不安定な戦績
  return 0;
}

function largeFieldPerformerBonus(
  topEntry: Record<string, unknown> | undefined,
  fieldSize: number,
): number {
  if (!topEntry || fieldSize < 14) return 0;
  const f1 = numericOrFallback(topEntry.prev_finish, 0);
  if (!f1) return 0;
  if (f1 <= 3) return 0.01; // 大頭数(14頭以上)で前走3着以内 = 混戦耐性実証済み
  if (f1 >= 10) return -0.01; // 大頭数(14頭以上)で前走10着以下 = 大頭数苦手シグナル
  return 0;
}

function jockeyHorseReunionBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const curr = String(topEntry.jockey_name ?? "").trim();
  const prev = String(topEntry.prev_jockey ?? "").trim();
  if (!curr || !prev || curr !== prev) return 0; // 乗り替わりはjockeyChangeBonusが対応
  const f1 = numericOrFallback(topEntry.prev_finish, 0);
  if (!f1) return 0;
  if (f1 <= 3) return 0.01; // 同騎手で前走3着以内 = 成功コンビ再結成
  if (f1 >= 8) return -0.01; // 同騎手で前走8着以下 = 失敗コンビ継続懸念
  return 0;
}

function formValueBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const f1 = numericOrFallback(topEntry.prev_finish, 0);
  const pop = numericOrFallback(topEntry.popularity, 0);
  if (!f1 || !pop) return 0;
  if (f1 <= 2 && pop >= 5) return 0.01; // 好フォーム(前走2着以内)×低人気(5番人気以下) = 市場が見逃した価値馬
  if (f1 >= 8 && pop <= 3) return -0.01; // 不調(前走8着以下)×高人気(3番人気以内) = 市場の過大評価リスク
  return 0;
}

function runningStyleFieldSizeBonus(
  topEntry: Record<string, unknown> | undefined,
  fieldSize: number,
): number {
  if (!topEntry) return 0;
  const style = String(topEntry.running_style ?? "").trim();
  if (!style) return 0;
  const isFront = style === "逃" || style === "先";
  const isCloser = style === "差" || style === "追";
  if (fieldSize >= 14) {
    if (isFront) return -0.01; // 大頭数ペース激化→逃げ先行は消耗戦リスク
    if (isCloser) return 0.01; // 大頭数で外差し有効→差し追い込みに捌きスペース
  }
  if (fieldSize <= 8) {
    if (isFront) return 0.01; // 少頭数でペース落ち着く→逃げ先行が能力発揮
  }
  return 0;
}

function horseBodyCarryRatioBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const body = numericOrFallback(topEntry.horse_weight, 0);
  const carry = numericOrFallback(topEntry.weight_kg, 0);
  if (body <= 0 || carry <= 0) return 0;
  const ratio = carry / body;
  if (ratio >= 0.13) return -0.01; // 高負担比率(斤量/馬体重≥13%): 体力消耗リスク
  if (ratio <= 0.10) return 0.01; // 低負担比率(斤量/馬体重≤10%): 体格対比軽斤量優位
  return 0;
}

function sireDistanceAffinityBonus(
  topEntry: Record<string, unknown> | undefined,
  raceDistance: unknown,
): number {
  if (!topEntry) return 0;
  const sire = String(topEntry.sire ?? "").trim();
  const dist = numericOrFallback(raceDistance, 0);
  if (!sire || !dist) return 0;
  const sprintSires = [
    "ロードカナロア",
    "サクラバクシンオー",
    "タイキシャトル",
    "ビッグアーサー",
  ];
  const stayerSires = [
    "ハービンジャー",
    "マンハッタンカフェ",
    "ゴールドシップ",
    "ジャングルポケット",
  ];
  const isSprint = dist <= 1400;
  const isRoute = dist >= 2000;
  if (isSprint && sprintSires.some((s) => sire.includes(s))) return 0.01; // スプリント血統×短距離: 適性一致
  if (isRoute && stayerSires.some((s) => sire.includes(s))) return 0.01; // スタミナ血統×長距離: 適性一致
  if (isSprint && stayerSires.some((s) => sire.includes(s))) return -0.01; // スタミナ血統×短距離: 逆適性リスク
  if (isRoute && sprintSires.some((s) => sire.includes(s))) return -0.01; // スプリント血統×長距離: スタミナ不安
  return 0;
}

// S169: ageGradeInteractionBonus — 馬齢×グレード難易度複合補正
function ageGradeInteractionBonus(
  topEntry: Record<string, unknown> | undefined,
  raceGrade: unknown,
): number {
  if (!topEntry) return 0;
  const ageSex = String(topEntry.age_sex ?? "").trim();
  const grade = String(raceGrade ?? "").trim();
  if (!ageSex || !grade) return 0;
  const ageMatch = ageSex.match(/(\d+)/);
  if (!ageMatch) return 0;
  const age = parseInt(ageMatch[1], 10);
  const isTopGrade = /^(G1|GI|JpnI|G2|GII|JpnII)$/i.test(grade);
  const isG1 = /^(G1|GI|JpnI)$/i.test(grade);
  if (age >= 4 && age <= 5 && isTopGrade) return 0.01; // ピーク期×準最高峰以上: 能力最大化ステージ
  if (age === 3 && isG1) return -0.01; // 発展途上×最高峰G1: 古馬一線級との実力差
  if (age >= 7 && isTopGrade) return -0.01; // ピーク超え古馬×高難度グレード: 体力限界近い
  return 0;
}

// S170: jockeyGradeCompatibilityBonus — 騎手勝率×グレード難易度適性補正
function jockeyGradeCompatibilityBonus(
  topEntry: Record<string, unknown> | undefined,
  raceGrade: unknown,
): number {
  if (!topEntry) return 0;
  const jRate = numericOrFallback(topEntry.jockey_win_rate, 0);
  const grade = String(raceGrade ?? "").trim();
  if (!grade) return 0;
  const isTopGrade = /^(G1|GI|JpnI|G2|GII|JpnII)$/i.test(grade);
  if (!isTopGrade) return 0;
  if (jRate >= 0.18) return 0.01; // トップジョッキー×G1/G2: 大舞台での実績・対応力
  if (jRate < 0.07) return -0.01; // 低勝率騎手×G1/G2: 最高峰では力量不一致
  return 0;
}

// S171: prevWinVenueReturnsBonus — 前走勝利×同一会場再訪補正
function prevWinVenueReturnsBonus(
  topEntry: Record<string, unknown> | undefined,
  raceVenue: unknown,
): number {
  if (!topEntry) return 0;
  const prev = String(topEntry.prev_venue ?? "").trim();
  const curr = String(raceVenue ?? "").trim();
  if (!prev || !curr || prev !== curr) return 0;
  const prevFin = numericOrFallback(topEntry.prev_finish, 0);
  if (!prevFin) return 0;
  if (prevFin === 1) return 0.01; // 同一会場前走勝利馬の再訪: コース得意の最強証明
  if (prevFin >= 9) return -0.01; // 同一会場で大敗経験: コース苦手シグナル
  return 0;
}

function consecutiveTopThreeBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const f1 = numericOrFallback(topEntry.prev_finish, 0);
  const f2 = numericOrFallback(topEntry.prev2_finish, 0);
  const f3 = numericOrFallback(topEntry.prev3_finish, 0);
  if (!f1 || !f2 || !f3) return 0;
  if (f1 <= 3 && f2 <= 3 && f3 <= 3) return 0.01; // 前3走全て3着以内 = 安定した馬券圏内
  if (f1 >= 4 && f2 >= 4 && f3 >= 4) return -0.01; // 前3走全て4着以下 = 一貫して圏外
  return 0;
}

function popularityShiftBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const curr = numericOrFallback(topEntry.popularity, 0);
  const prev = numericOrFallback(topEntry.prev_popularity, 0);
  if (!curr || !prev) return 0;
  const shift = prev - curr; // positive = popularity improved (lower rank = more popular)
  if (shift >= 3) return 0.01; // 3ランク以上人気急上昇 = 市場の急速な評価上昇
  if (shift <= -3) return -0.01; // 3ランク以上人気急落下 = 市場の急速な評価下落
  return 0;
}

function prev3WinRateBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const f1 = numericOrFallback(topEntry.prev_finish, 0);
  const f2 = numericOrFallback(topEntry.prev2_finish, 0);
  const f3 = numericOrFallback(topEntry.prev3_finish, 0);
  if (!f1 || !f2 || !f3) return 0;
  const wins = [f1, f2, f3].filter((f) => f === 1).length;
  if (wins >= 2) return 0.01; // 前3走2勝以上 = 近走圧倒的勝負強さ
  if (wins === 0 && f1 >= 5 && f2 >= 5 && f3 >= 5) return -0.01; // 前3走無勝利かつ全て5着以下
  return 0;
}

function prev2FormGapBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const f1 = numericOrFallback(topEntry.prev_finish, 0);
  const f2 = numericOrFallback(topEntry.prev2_finish, 0);
  if (!f1 || !f2) return 0;
  const gap = f2 - f1; // positive = improvement (lower number = better finish)
  if (gap >= 3) return 0.01; // 3着以上急改善 = 直近上昇加速シグナル
  if (gap <= -3) return -0.01; // 3着以上急悪化 = 直近下降加速シグナル
  return 0;
}

function courseSurfaceMatchBonus(
  topEntry: Record<string, unknown> | undefined,
  currentCourseType: string,
): number {
  if (!topEntry || !currentCourseType) return 0;
  const prev = String(topEntry.prev_course_type ?? "").trim();
  if (!prev) return 0;
  if (prev === currentCourseType) return 0.01; // 前走同じ馬場種別 = 実績の舞台で安心感
  return -0.01; // 馬場種別変更 = 未知の適性リスク
}

function fieldWeightRankBonus(
  topEntry: Record<string, unknown> | undefined,
  entries: Record<string, unknown>[],
): number {
  if (!topEntry || entries.length < 3) return 0;
  const w = numericOrFallback(topEntry.weight_kg, 0);
  if (!w) return 0;
  const weights = entries
    .map((e) => numericOrFallback(e.weight_kg, 0))
    .filter((x) => x > 0);
  if (weights.length < 3) return 0;
  const min = Math.min(...weights);
  const max = Math.max(...weights);
  if (w === min) return 0.01; // フィールド最軽量 = 斤量面の相対的有利
  if (w === max) return -0.01; // フィールド最重量 = 斤量面の相対的不利
  return 0;
}

function prevTimeGapBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const prev = timeToSecondsTS(topEntry.prev_time);
  const best = timeToSecondsTS(topEntry.best_time);
  if (prev === null || best === null) return 0; // データなし
  const gap = prev - best; // 正数 = 前走がベストより遅い
  if (gap >= 2.0) return -0.01; // 2秒以上遅い: 調子落ちリスク
  if (gap <= 0.3) return 0.01; // ベスト近い(0.3秒以内): 好調維持
  return 0;
}

function horseBodyWeightBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const w = numericOrFallback(topEntry.horse_weight, 0);
  if (w <= 0) return 0; // データなし
  if (w <= 430) return -0.01; // 軽量馬: スタミナ/パワー不足リスク
  if (w >= 560) return -0.01; // 重量馬: 機動力低下リスク
  if (w >= 450 && w <= 510) return 0.01; // 理想体重帯: 均整取れた馬体
  return 0;
}

function prevMarginBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const text = String(topEntry.prev_margin ?? "").trim();
  if (!text) return 0;
  if (text === "大差") return -0.02; // 大敗: 大きく評価ダウン
  if (text === "ハナ" || text === "アタマ" || text === "クビ") return 0.01; // 僅差: 健闘
  const frac = text.match(/^(\d+)\/(\d+)$/);
  if (frac) {
    const lengths = Number(frac[1]) / Number(frac[2]);
    if (lengths <= 0.5) return 0.01; // 半馬身以内
    if (lengths >= 5) return -0.01; // 5馬身以上
    return 0;
  }
  const numeric = parseFloat(text);
  if (Number.isFinite(numeric) && numeric >= 0) {
    if (numeric <= 0.5) return 0.01; // 半馬身以内
    if (numeric >= 5) return -0.01; // 5馬身以上
  }
  return 0;
}

function weightKgBonus(topEntry: Record<string, unknown> | undefined): number {
  if (!topEntry) return 0;
  const w = numericOrFallback(topEntry.weight_kg, 0);
  if (w <= 0) return 0; // データなし
  if (w <= 53) return 0.01; // 軽斤量(≤53kg): 有利
  if (w >= 57) return -0.01; // 重斤量(≥57kg): 不利
  return 0; // 54〜56kg: 標準
}

function prevLast3fBonus(
  topEntry: Record<string, unknown> | undefined,
): number {
  if (!topEntry) return 0;
  const t = numericOrFallback(topEntry.prev_last_3f, 0);
  if (t <= 0) return 0; // データなし
  if (t <= 34.0) return 0.02; // 優秀な末脚(34秒台以下): スパート能力高
  if (t <= 35.5) return 0.01; // 良好な末脚(35秒台前半)
  if (t >= 37.0) return -0.01; // 遅い末脚: 末脚不足リスク
  return 0;
}

function prevDistanceMatchBonus(
  topEntry: Record<string, unknown> | undefined,
  raceDistance: unknown,
): number {
  if (!topEntry) return 0;
  const prev = Number(topEntry.prev_distance ?? 0);
  const curr = Number(raceDistance ?? 0);
  if (!prev || !curr) return 0;
  const diff = Math.abs(prev - curr);
  if (diff <= 100) return 0.01; // 前走±100m以内: 距離経験・適性実証
  if (diff >= 300) return -0.01; // 前走±300m超: 距離大幅変更リスク
  return 0;
}

function prevVenueMatchBonus(
  topEntry: Record<string, unknown> | undefined,
  raceVenue: unknown,
): number {
  if (!topEntry) return 0;
  const prev = String(topEntry.prev_venue ?? "").trim();
  const curr = String(raceVenue ?? "").trim();
  if (!prev || !curr) return 0;
  return prev === curr ? 0.01 : 0; // 前走同会場: コース経験・適性実証あり +1%
}

function barrierPositionBonus(
  topEntry: Record<string, unknown> | undefined,
  fieldSize: number,
): number {
  if (!topEntry) return 0;
  const horseNum = Number(topEntry.horse_number ?? 0);
  if (!horseNum || fieldSize <= 0) return 0;
  const frame = frameForHorseNumber(horseNum, fieldSize);
  if (frame === null) return 0;
  if (frame <= 2) return 0.01; // 内枠(1〜2枠): 日本競馬では一般的に有利
  if (frame >= 7) return -0.01; // 外枠(7〜8枠): 距離ロス・包まれリスクで不利
  return 0; // 中枠(3〜6枠): 中立
}

function smallFieldBonus(fieldSize: number): number {
  if (fieldSize <= 4) return 0.04; // 最小頭数 — 候補絞られ予測容易
  if (fieldSize <= 6) return 0.02; // 小頭数
  if (fieldSize <= 8) return 0.01; // やや少頭数
  return 0; // 9頭以上: fieldSizeConfidencePenaltyがカバー
}

function fieldSizeConfidencePenalty(fieldSize: number): number {
  if (fieldSize >= 16) return 0.07; // 大型レース — 高分散
  if (fieldSize >= 13) return 0.04;
  if (fieldSize >= 9) return 0.02;
  return 0.00; // ≤8頭: 小頭数
}

function clampConfidence(value: number): number {
  if (!Number.isFinite(value)) return 0.5;
  return Math.max(0.05, Math.min(0.95, Math.round(value * 1000) / 1000));
}

function horseRaceDataQualityScore(entries: Record<string, unknown>[]): number {
  if (entries.length === 0) return 0;
  const fields = [
    "jockey",
    "trainer",
    "win_odds",
    "popularity",
    "age_sex",
    "horse_weight",
    "weight_kg",
    "prev_finish",
    "prev_time",
    "prev_last_3f",
    "horse_weight_change",
    "sire",
    "dam",
    "damsire",
    "stable",
    "prev_margin",
    "prev_days_ago",
    "best_time",
  ];
  let filled = 0;
  for (const entry of entries) {
    for (const field of fields) {
      const value = entry[field];
      if (
        value !== null && value !== undefined && String(value).trim() !== ""
      ) filled += 1;
    }
  }
  return Math.round((filled / (entries.length * fields.length)) * 1000) / 1000;
}

function numericOrFallback(value: unknown, fallback: number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function recentFinishScore(value: unknown): number {
  const text = String(value ?? "");
  const match = text.match(/\d+/);
  if (!match) return 99;
  const place = Number(match[0]);
  return Number.isFinite(place) ? place : 99;
}

function timeToSecondsTS(value: unknown): number | null {
  const text = String(value ?? "").trim();
  if (!text) return null;
  const mmss = text.match(/^(\d+):(\d+(?:\.\d+)?)$/);
  if (mmss) return parseInt(mmss[1]) * 60 + parseFloat(mmss[2]);
  const ss = text.match(/^(\d+(?:\.\d+)?)$/);
  if (ss) return parseFloat(ss[1]);
  return null;
}

function weightChangeScore(value: unknown): number {
  const change = numericOrFallback(value, 0);
  // Stable range (-2 to +4 kg) = 0 penalty; large swings = proportional penalty
  const abs = Math.abs(change);
  if (abs <= 4) return 0;
  if (abs >= 12) return 50;
  return (abs - 4) * 5;
}

function freshnessPenaltyScore(value: unknown): number {
  const days = numericOrFallback(value, 0);
  if (days <= 0) return 5; // unknown interval = slight penalty
  if (days <= 60) return 0; // normal interval
  if (days <= 89) return 3; // slightly long break
  if (days <= 179) return 10; // 休み明け
  return 20; // 超長期休養明け (180日+)
}

function agePenaltyScore(value: unknown): number {
  const text = String(value ?? "").trim();
  if (!text) return 5; // unknown age = slight uncertainty
  const match = text.match(/(\d+)/);
  if (!match) return 5;
  const age = parseInt(match[1]);
  if (age <= 2) return 5; // still developing, higher variance
  if (age <= 5) return 0; // prime years (3–5 years)
  if (age === 6) return 3;
  if (age === 7) return 8;
  return 15; // 8+ years: significant decline risk
}

function marginPenaltyScore(value: unknown): number {
  const text = String(value ?? "").trim();
  if (!text) return 0;
  if (text === "大差") return 30;
  if (text === "ハナ" || text === "アタマ") return 1;
  if (text === "クビ") return 2;
  // Fractional: "1/2", "3/4" (horse lengths)
  const frac = text.match(/^(\d+)\/(\d+)$/);
  if (frac) {
    return Math.min(Math.round((Number(frac[1]) / Number(frac[2])) * 4), 20);
  }
  const numeric = parseFloat(text);
  if (Number.isFinite(numeric) && numeric >= 0) {
    return Math.min(Math.round(numeric * 4), 30);
  }
  return 0;
}

function courseDistancePenaltyScore(
  entry: Record<string, unknown>,
  raceContext?: { courseType?: string; distance?: number },
): number {
  let penalty = 0;
  if (raceContext?.courseType) {
    const prev = String(entry.prev_course_type ?? "").trim();
    const cur = raceContext.courseType.trim();
    if (prev && cur && prev !== cur) penalty += 10; // コース種別替わり (芝↔ダート)
  }
  if (raceContext?.distance) {
    const prevDist = numericOrFallback(entry.prev_distance, 0);
    const raceDist = raceContext.distance;
    if (prevDist > 0 && raceDist > 0) {
      const delta = Math.abs(prevDist - raceDist);
      if (delta >= 400) penalty += 8; // 大幅距離変化
      else if (delta >= 200) penalty += 4; // 中程度距離変化
    }
  }
  return penalty;
}

function prevLast3FSlowPenalty(value: unknown): number {
  const t = numericOrFallback(value, 0);
  if (t <= 0) return 2; // データなし — やや不利
  if (t >= 37.0) return 6; // 非常に遅いラスト3F
  if (t >= 36.0) return 4;
  if (t >= 35.0) return 2;
  return 0; // 34秒台以下は速い
}

function popularitySortScore(value: unknown): number {
  const p = numericOrFallback(value, 99);
  if (p <= 0) return 5; // データなし
  if (p <= 3) return 0; // 1-3番人気
  if (p <= 6) return 2; // 4-6番人気
  if (p <= 9) return 4; // 7-9番人気
  return 6; // 10番人気以下
}

function weightKgPenaltyScore(value: unknown): number {
  const w = numericOrFallback(value, 0);
  if (w <= 0) return 0; // データなし — neutral
  if (w <= 53) return -1; // 軽斤量 (≤53kg 有利)
  if (w <= 55) return 0; // 標準
  if (w < 57) return 1; // やや重い斤量
  return 2; // 重斤量 (≥57kg 不利)
}

function prevVenueMatchScore(
  entry: Record<string, unknown>,
  raceVenue: string | undefined,
): number {
  if (!raceVenue) return 0;
  const prev = String(entry.prev_venue ?? "").trim();
  if (!prev) return 0;
  return prev === raceVenue ? -2 : 0; // 前走同会場 = 有利 (ascending, 低い方が上位)
}

function sortHorseEntriesForLearning(
  entries: Record<string, unknown>[],
  raceContext?: { courseType?: string; distance?: number; venue?: string },
): Record<string, unknown>[] {
  return [...entries].sort((a, b) => {
    // 1. popularity (ascending — lower rank = more popular)
    const popularity = numericOrFallback(a.popularity, 999) -
      numericOrFallback(b.popularity, 999);
    if (popularity !== 0) return popularity;
    // 2. win_odds (ascending — lower = cheaper = more likely per market)
    const odds = numericOrFallback(a.win_odds, 999) -
      numericOrFallback(b.win_odds, 999);
    if (odds !== 0) return odds;
    // 3. prev_finish (ascending — lower place = better)
    const recent = recentFinishScore(a.prev_finish) -
      recentFinishScore(b.prev_finish);
    if (recent !== 0) return recent;
    // 4. prev_margin penalty (ascending — larger loss margin = ranked lower)
    const margin = marginPenaltyScore(a.prev_margin) -
      marginPenaltyScore(b.prev_margin);
    if (margin !== 0) return margin;
    // 5. best_time (ascending — faster career record = better; null = unknown, sorted last)
    const btA = timeToSecondsTS(a.best_time);
    const btB = timeToSecondsTS(b.best_time);
    if (btA !== null && btB !== null && btA !== btB) return btA - btB;
    if (btA !== null && btB === null) return -1;
    if (btA === null && btB !== null) return 1;
    // 6. prev_last_3f (ascending — faster finish sprint)
    const last3f = numericOrFallback(a.prev_last_3f, 99) -
      numericOrFallback(b.prev_last_3f, 99);
    if (last3f !== 0) return last3f;
    // 7. freshness penalty (ascending — long absence / 休み明け = higher penalty)
    const freshness = freshnessPenaltyScore(a.prev_days_ago) -
      freshnessPenaltyScore(b.prev_days_ago);
    if (freshness !== 0) return freshness;
    // 8. age penalty (ascending — older horse beyond prime = higher penalty)
    const age = agePenaltyScore(a.age_sex) - agePenaltyScore(b.age_sex);
    if (age !== 0) return age;
    // 9. weight change penalty (ascending — large swings = higher penalty = ranked lower)
    const wc = weightChangeScore(a.horse_weight_change) -
      weightChangeScore(b.horse_weight_change);
    if (wc !== 0) return wc;
    // 10. data_quality_score (descending — more data = more confidence)
    const quality = numericOrFallback(b.data_quality_score, 0) -
      numericOrFallback(a.data_quality_score, 0);
    if (quality !== 0) return quality;
    // 11. course/distance fit (ascending — コース替わり/大幅距離変化 = higher penalty)
    const cd = courseDistancePenaltyScore(a, raceContext) -
      courseDistancePenaltyScore(b, raceContext);
    if (cd !== 0) return cd;
    // 12. weight_kg outlier (ascending — 軽量/重量すぎ = higher penalty)
    const wkg = weightKgOutlierPenalty(a.weight_kg) -
      weightKgOutlierPenalty(b.weight_kg);
    if (wkg !== 0) return wkg;
    // 13. prev_time vs best_time gap (ascending — 前走がbest_timeより大幅遅い = 調子不良)
    const ptg = prevTimeGapPenalty(a.prev_time, a.best_time) -
      prevTimeGapPenalty(b.prev_time, b.best_time);
    if (ptg !== 0) return ptg;
    // 14. too-frequent race penalty (ascending — 連闘/中1週 = 疲労リスク)
    const tfr = tooFrequentRacePenalty(a.prev_days_ago) -
      tooFrequentRacePenalty(b.prev_days_ago);
    if (tfr !== 0) return tfr;
    // 15. prev_last_3f slow penalty (ascending — ラスト3F遅い馬は末脚不足リスク)
    const l3f = prevLast3FSlowPenalty(a.prev_last_3f) -
      prevLast3FSlowPenalty(b.prev_last_3f);
    if (l3f !== 0) return l3f;
    // 16. popularity sort score (ascending — 人気上位馬を優先)
    const pop = popularitySortScore(a.popularity) -
      popularitySortScore(b.popularity);
    if (pop !== 0) return pop;
    // 17. weight_kg penalty (ascending — 重斤量は不利)
    const wkgPenalty = weightKgPenaltyScore(a.weight_kg) -
      weightKgPenaltyScore(b.weight_kg);
    if (wkgPenalty !== 0) return wkgPenalty;
    // 19. prev venue match (ascending — 前走同会場は有利)
    const venueMatch = prevVenueMatchScore(a, raceContext?.venue) -
      prevVenueMatchScore(b, raceContext?.venue);
    if (venueMatch !== 0) return venueMatch;
    // 20. horse_number (ascending — tiebreaker)
    return numericOrFallback(a.horse_number, 999) -
      numericOrFallback(b.horse_number, 999);
  });
}

function buildHistoricalBaselinePrediction(
  race: Record<string, unknown>,
  entries: Record<string, unknown>[],
): ProviderPredictionResult {
  const raceCtx = {
    courseType: String(race.course_type ?? "").trim() || undefined,
    distance: Number(race.distance ?? 0) || undefined,
    venue: String(race.venue ?? "").trim() || undefined,
  };
  const ranked = sortHorseEntriesForLearning(entries, raceCtx);
  const [first, second, third] = ranked;
  const dataQuality = horseRaceDataQualityScore(entries);
  const oddsCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.win_odds !== null && entry.win_odds !== undefined
    ).length / entries.length
    : 0;
  const historyCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.prev_finish || entry.prev_time || entry.best_time
    ).length / entries.length
    : 0;
  const bestTimeCoverage = entries.length > 0
    ? entries.filter((entry) => entry.best_time).length / entries.length
    : 0;
  const prevMarginCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.prev_margin !== null && entry.prev_margin !== undefined &&
      String(entry.prev_margin).trim() !== ""
    ).length / entries.length
    : 0;
  const jockeyCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.jockey && String(entry.jockey).trim() !== ""
    ).length / entries.length
    : 0;
  const trainerCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.trainer && String(entry.trainer).trim() !== ""
    ).length / entries.length
    : 0;
  const bloodlineCoverage = entries.length > 0
    ? entries.filter((entry) => entry.sire && String(entry.sire).trim() !== "")
      .length / entries.length
    : 0;
  const last3FCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.prev_last_3f !== null && entry.prev_last_3f !== undefined &&
      String(entry.prev_last_3f).trim() !== ""
    ).length / entries.length
    : 0;
  const winningTimeCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.winning_time !== null && entry.winning_time !== undefined &&
      String(entry.winning_time).trim() !== ""
    ).length / entries.length
    : 0;
  const weightChangeCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.weight_change !== null && entry.weight_change !== undefined &&
      String(entry.weight_change).trim() !== ""
    ).length / entries.length
    : 0;
  const ageCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.horse_age !== null && entry.horse_age !== undefined &&
      String(entry.horse_age).trim() !== ""
    ).length / entries.length
    : 0;
  const sexCoverage = entries.length > 0
    ? entries.filter((entry) => entry.sex && String(entry.sex).trim() !== "")
      .length / entries.length
    : 0;
  const horseWeightCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.horse_weight !== null && entry.horse_weight !== undefined &&
      String(entry.horse_weight).trim() !== ""
    ).length / entries.length
    : 0;
  const stableCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.stable && String(entry.stable).trim() !== ""
    ).length / entries.length
    : 0;
  const damCoverage = entries.length > 0
    ? entries.filter((entry) => entry.dam && String(entry.dam).trim() !== "")
      .length / entries.length
    : 0;
  const damsireCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.damsire && String(entry.damsire).trim() !== ""
    ).length / entries.length
    : 0;
  const popularityCoverage = entries.length > 0
    ? entries.filter((entry) =>
      entry.popularity !== null && entry.popularity !== undefined &&
      String(entry.popularity).trim() !== ""
    ).length / entries.length
    : 0;
  const maxConf = gradeMaxConfidence(race.grade);
  const fieldPenalty = fieldSizeConfidencePenalty(entries.length);
  const oddsGapBonus = topTwoOddsGapBonus(entries);
  const recentForm = recentFormBonus(entries);
  const tightOdds = tightOddsPenalty(entries);
  const venueBonus = venueConfidenceBonus(race.venue);
  const favBonus = favOddsBonus(entries);
  const smallField = smallFieldBonus(entries.length);
  const bloodlineBonus = bloodlineTopHorseBonus(first);
  const distanceBonus = distanceSpecificBonus(race.distance);
  const consensus = consensusBonus(first);
  const jockeyWinRate = jockeyWinRateBonus(first);
  const trainerWinRate = trainerWinRateBonus(first);
  const gradePenalty = gradeDifficultyPenalty(race.grade);
  const weightStability = horseWeightStabilityBonus(first);
  const ageOptimal = ageOptimalBonus(first);
  const intervalBonus = raceIntervalBonus(first);
  const courseTypeMatch = courseTypeMatchBonus(first, race.course_type);
  const barrierPosition = barrierPositionBonus(first, entries.length);
  const prevVenueMatch = prevVenueMatchBonus(first, race.venue);
  const prevDistanceMatch = prevDistanceMatchBonus(first, race.distance);
  const last3fBonus = prevLast3fBonus(first);
  const weightKg = weightKgBonus(first);
  const prevMargin = prevMarginBonus(first);
  const bodyWeight = horseBodyWeightBonus(first);
  const prevTimeGap = prevTimeGapBonus(first);
  const sexCategory = sexCategoryBonus(first);
  const popularityRank = popularityRankBonus(first);
  const weightChange = weightChangeBonus(first);
  const prevFinish = prevFinishBonus(first);
  const winExp = winningExperienceBonus(first);
  const jtCombo = jockeyTrainerComboBonus(first);
  const dataComplete = topHorseDataCompletenessBonus(first);
  const trifecta = prevRaceContextTrifectaBonus(
    first,
    race.venue,
    race.distance,
    race.course_type,
  );
  const bloodlineCourseType = bloodlineCourseTypeBonus(first, race.course_type);
  const bestTimeRank = bestTimeFieldRankBonus(first, entries);
  const popPrevFinishConsist = popularityPrevFinishConsistencyBonus(first);
  const damSireLine = damSireLineBonus(first, race.course_type);
  const popOddsAlign = popularityOddsAlignBonus(first);
  const ageDistAffinity = ageDistanceAffinityBonus(first, race.distance);
  const sireRank = sireRankBonus(first);
  const prevDistTrend = prevDistanceTrendBonus(first, race.distance);
  const oddsSpread = oddsFieldSpreadBonus(entries);
  const prevWinMargin = prevWinMarginBonus(first);
  const horseNumRatio = horseNumberFieldRatioBonus(first, entries.length);
  const multiSignal = multipleTopSignalBonus(first, entries, race.course_type);
  const trackCondAdapt = trackConditionAdaptBonus(first, race.track_condition);
  const runStyleDist = runningStyleDistanceBonus(first, race.distance);
  const prev2Consist = prev2FinishConsistencyBonus(first);
  const classStep = raceClassStepBonus(first);
  const favConsist = favoriteConsistencyBonus(first);
  const jockeyTopCourse = jockeyTopCourseBonus(first, race.venue);
  const trainerTopCourse = trainerTopCourseBonus(first, race.venue);
  const prev3FormTrend = prev3FormTrendBonus(first);
  const jockeyChange = jockeyChangeBonus(first);
  const prevPopBounce = prevPopularityBounceBonus(first);
  const wtChangeCourse = weightChangeCourseSuitBonus(first);
  const prev3AvgFinish = prev3AvgFinishBonus(first);
  const prev2FormGap = prev2FormGapBonus(first);
  const courseSurfaceMatch = courseSurfaceMatchBonus(
    first,
    raceCtx.courseType ?? "",
  );
  const fieldWeightRank = fieldWeightRankBonus(first, entries);
  const consec3Top = consecutiveTopThreeBonus(first);
  const popShift = popularityShiftBonus(first);
  const prev3WinRate = prev3WinRateBonus(first);
  const largeFieldPerf = largeFieldPerformerBonus(first, entries.length);
  const jockeyReunion = jockeyHorseReunionBonus(first);
  const formValue = formValueBonus(first);
  const runStyleFieldSize = runningStyleFieldSizeBonus(first, entries.length);
  const bodyCarryRatio = horseBodyCarryRatioBonus(first);
  const sireDistAffinity = sireDistanceAffinityBonus(first, race.distance);
  const ageGradeInteract = ageGradeInteractionBonus(first, race.grade);
  const jockeyGradeCompat = jockeyGradeCompatibilityBonus(first, race.grade);
  const prevWinVenueReturn = prevWinVenueReturnsBonus(first, race.venue);
  const confidence = Math.min(
    clampConfidence(
      0.31 + dataQuality * 0.22 + oddsCoverage * 0.12 + historyCoverage * 0.07 +
        bestTimeCoverage * 0.05 + prevMarginCoverage * 0.03 +
        jockeyCoverage * 0.02 + trainerCoverage * 0.01 +
        bloodlineCoverage * 0.01 + last3FCoverage * 0.01 +
        winningTimeCoverage * 0.01 + weightChangeCoverage * 0.01 +
        ageCoverage * 0.01 + sexCoverage * 0.01 + horseWeightCoverage * 0.01 +
        stableCoverage * 0.01 + damCoverage * 0.01 + damsireCoverage * 0.01 +
        popularityCoverage * 0.01 - fieldPenalty - tightOdds + oddsGapBonus +
        recentForm + venueBonus + favBonus + smallField + bloodlineBonus +
        distanceBonus + consensus + jockeyWinRate + trainerWinRate +
        gradePenalty + weightStability + ageOptimal + intervalBonus +
        courseTypeMatch + barrierPosition + prevVenueMatch + prevDistanceMatch +
        last3fBonus + weightKg + prevMargin + bodyWeight + prevTimeGap +
        sexCategory + popularityRank + weightChange + prevFinish + winExp +
        jtCombo + dataComplete + trifecta + bloodlineCourseType + bestTimeRank +
        popPrevFinishConsist + damSireLine + popOddsAlign + ageDistAffinity +
        sireRank + prevDistTrend + oddsSpread + prevWinMargin + horseNumRatio +
        multiSignal + trackCondAdapt + runStyleDist + prev2Consist + classStep +
        favConsist + jockeyTopCourse + trainerTopCourse + prev3FormTrend +
        jockeyChange + prevPopBounce + wtChangeCourse + prev3AvgFinish +
        prev2FormGap + courseSurfaceMatch + fieldWeightRank +
        consec3Top + popShift + prev3WinRate +
        largeFieldPerf + jockeyReunion + formValue +
        runStyleFieldSize + bodyCarryRatio + sireDistAffinity +
        ageGradeInteract + jockeyGradeCompat + prevWinVenueReturn,
    ),
    maxConf,
  );
  return {
    success: true,
    prediction: {
      first: String(first?.horse_name ?? ""),
      second: String(second?.horse_name ?? ""),
      third: String(third?.horse_name ?? ""),
      confidence,
      reasoning: [
        "過去レース学習用の低リスク基準予想。",
        "レース結果は参照せず、人気・単勝オッズ・前走・着差・持ち時計・馬体重変動・馬体/騎手/調教師/血統など取得済み特徴量から順位付け。",
        `対象:${race.race_date ?? ""} ${race.venue ?? ""}${
          race.race_number ?? ""
        }R ${race.race_name ?? ""}`,
        `信頼度:${Math.round(confidence * 100)}% (データ充足${
          Math.round(dataQuality * 100)
        }% オッズ${Math.round(oddsCoverage * 100)}% 上がり3F${
          Math.round(last3FCoverage * 100)
        }% 血統${Math.round(bloodlineCoverage * 100)}% 騎手${
          Math.round(jockeyCoverage * 100)
        }% 馬体重${Math.round(horseWeightCoverage * 100)}% 厩舎${
          Math.round(stableCoverage * 100)
        }% 人気${
          Math.round(popularityCoverage * 100)
        }% 頭数${entries.length}頭 グレード:${
          race.grade ?? "OP以下"
        } 会場補正:${venueBonus >= 0 ? "+" : ""}${
          Math.round(venueBonus * 100)
        }% 本命補正:+${Math.round(favBonus * 100)}% 少頭数補正:+${
          Math.round(smallField * 100)
        }% 血統充足:+${Math.round(bloodlineBonus * 100)}% 距離補正:${
          distanceBonus >= 0 ? "+" : ""
        }${Math.round(distanceBonus * 100)}% 合意補正:+${
          Math.round(consensus * 100)
        }% 騎手勝率補正:+${Math.round(jockeyWinRate * 100)}% 調教師勝率補正:+${
          Math.round(trainerWinRate * 100)
        }% グレード補正:${gradePenalty >= 0 ? "+" : ""}${
          Math.round(gradePenalty * 100)
        }% 体重安定:${weightStability >= 0 ? "+" : ""}${
          Math.round(weightStability * 100)
        }% 年齢補正:${ageOptimal >= 0 ? "+" : ""}${
          Math.round(ageOptimal * 100)
        }% 間隔補正:${intervalBonus >= 0 ? "+" : ""}${
          Math.round(intervalBonus * 100)
        }% コース種別補正:${courseTypeMatch >= 0 ? "+" : ""}${
          Math.round(courseTypeMatch * 100)
        }% 枠番補正:${barrierPosition >= 0 ? "+" : ""}${
          Math.round(barrierPosition * 100)
        }% 前走同会場:${prevVenueMatch >= 0 ? "+" : ""}${
          Math.round(prevVenueMatch * 100)
        }% 前走距離適合:${prevDistanceMatch >= 0 ? "+" : ""}${
          Math.round(prevDistanceMatch * 100)
        }% 上り3F:${last3fBonus >= 0 ? "+" : ""}${
          Math.round(last3fBonus * 100)
        }% 斤量:${weightKg >= 0 ? "+" : ""}${
          Math.round(weightKg * 100)
        }% 前走着差:${prevMargin >= 0 ? "+" : ""}${
          Math.round(prevMargin * 100)
        }% 馬体重:${bodyWeight >= 0 ? "+" : ""}${
          Math.round(bodyWeight * 100)
        }% 前走タイム差:${prevTimeGap >= 0 ? "+" : ""}${
          Math.round(prevTimeGap * 100)
        }% 性別:${sexCategory >= 0 ? "+" : ""}${
          Math.round(sexCategory * 100)
        }% 人気ランク:${popularityRank >= 0 ? "+" : ""}${
          Math.round(popularityRank * 100)
        }% 体重変動:${weightChange >= 0 ? "+" : ""}${
          Math.round(weightChange * 100)
        }% 前走着順:${prevFinish >= 0 ? "+" : ""}${
          Math.round(prevFinish * 100)
        }% 勝利実績:+${Math.round(winExp * 100)}% JTコンビ:+${
          Math.round(jtCombo * 100)
        }% データ完全:${dataComplete >= 0 ? "+" : ""}${
          Math.round(dataComplete * 100)
        }% 三一致:+${Math.round(trifecta * 100)}% 血統コース:${
          bloodlineCourseType >= 0 ? "+" : ""
        }${Math.round(bloodlineCourseType * 100)}% ベストタイム順位:${
          bestTimeRank >= 0 ? "+" : ""
        }${Math.round(bestTimeRank * 100)}% 人気前走整合:${
          popPrevFinishConsist >= 0 ? "+" : ""
        }${Math.round(popPrevFinishConsist * 100)}% 母父系統:${
          damSireLine >= 0 ? "+" : ""
        }${Math.round(damSireLine * 100)}% 人気オッズ整合:${
          popOddsAlign >= 0 ? "+" : ""
        }${Math.round(popOddsAlign * 100)}% 年齢距離親和:${
          ageDistAffinity >= 0 ? "+" : ""
        }${Math.round(ageDistAffinity * 100)}% 種牡馬ランク:+${
          Math.round(sireRank * 100)
        }% 前走距離傾向:${prevDistTrend >= 0 ? "+" : ""}${
          Math.round(prevDistTrend * 100)
        }% オッズ分散:${oddsSpread >= 0 ? "+" : ""}${
          Math.round(oddsSpread * 100)
        }% 前走圧勝:${prevWinMargin >= 0 ? "+" : ""}${
          Math.round(prevWinMargin * 100)
        }% 馬番比率:${horseNumRatio >= 0 ? "+" : ""}${
          Math.round(horseNumRatio * 100)
        }% 複合シグナル:+${Math.round(multiSignal * 100)}% 馬場適性:${
          trackCondAdapt >= 0 ? "+" : ""
        }${Math.round(trackCondAdapt * 100)}% 脚質距離:${
          runStyleDist >= 0 ? "+" : ""
        }${Math.round(runStyleDist * 100)}% 2走一貫:${
          prev2Consist >= 0 ? "+" : ""
        }${Math.round(prev2Consist * 100)}% クラス昇降:${
          classStep >= 0 ? "+" : ""
        }${Math.round(classStep * 100)}% 本命継続:${
          favConsist >= 0 ? "+" : ""
        }${Math.round(favConsist * 100)}% 騎手得意コース:+${
          Math.round(jockeyTopCourse * 100)
        }% 調教師得意コース:+${
          Math.round(trainerTopCourse * 100)
        }% 3走トレンド:${prev3FormTrend >= 0 ? "+" : ""}${
          Math.round(prev3FormTrend * 100)
        }% 騎乗交代:${jockeyChange >= 0 ? "+" : ""}${
          Math.round(jockeyChange * 100)
        }% 人気リバウンド:${prevPopBounce >= 0 ? "+" : ""}${
          Math.round(prevPopBounce * 100)
        }% 体重増減コース:${wtChangeCourse >= 0 ? "+" : ""}${
          Math.round(wtChangeCourse * 100)
        }% 前3走平均:${prev3AvgFinish >= 0 ? "+" : ""}${
          Math.round(prev3AvgFinish * 100)
        }%)`,
      ].join(" "),
    },
    latency_ms: 0,
  };
}

function horsePurchaseDecision(
  confidence: number,
  entries: Record<string, unknown>[],
) {
  const base = clampConfidence(confidence);
  const dataQuality = horseRaceDataQualityScore(entries);
  const hasOdds =
    entries.filter((entry) =>
      entry.win_odds !== null && entry.win_odds !== undefined
    ).length >= Math.max(3, Math.ceil(entries.length * 0.6));
  const skipRecommended = base < 0.42 || dataQuality < 0.28 || !hasOdds;
  const reason = skipRecommended
    ? `信頼度${Math.round(base * 100)}%・データ充足度${
      Math.round(dataQuality * 100)
    }%のため、資金保全を優先して購入見送りを推奨。`
    : `信頼度${Math.round(base * 100)}%・データ充足度${
      Math.round(dataQuality * 100)
    }%。低リスク券種に限定する前提で購入検討可。`;
  return {
    skipRecommended,
    reason,
    dataQuality,
    confidence: clampConfidence(
      skipRecommended ? Math.max(1 - base, 0.58) : Math.max(0.12, 1 - base),
    ),
  };
}

function buildHorseBetSuggestions(
  first: string,
  second: string,
  third: string,
  entries: Record<string, unknown>[],
  confidence: number,
): {
  bet_suggestions: HorseBetSuggestion[];
  recommended_tickets: HorseBetSuggestion[];
} {
  const lookup = horseEntryLookup(entries);
  const fieldSize = entries.length || 18;
  const firstEntry = lookup.get(normalizeHorseNameForMatch(first));
  const secondEntry = lookup.get(normalizeHorseNameForMatch(second));
  const thirdEntry = lookup.get(normalizeHorseNameForMatch(third));
  const n1 = horseNumberOf(firstEntry);
  const n2 = horseNumberOf(secondEntry);
  const n3 = horseNumberOf(thirdEntry);
  const f1 = frameForHorseNumber(n1, fieldSize);
  const f2 = frameForHorseNumber(n2, fieldSize);
  const l1 = horseNumberLabel(firstEntry);
  const l2 = horseNumberLabel(secondEntry);
  const l3 = horseNumberLabel(thirdEntry);
  const purchaseDecision = horsePurchaseDecision(confidence, entries);
  const shouldRecommendBuy = !purchaseDecision.skipRecommended;
  const wideTickets = [
    {
      combination: `${l1}-${l2}`,
      horses: [first, second],
      horse_numbers: [n1, n2].filter((n): n is number => n !== null),
    },
    {
      combination: `${l1}-${l3}`,
      horses: [first, third],
      horse_numbers: [n1, n3].filter((n): n is number => n !== null),
    },
    {
      combination: `${l2}-${l3}`,
      horses: [second, third],
      horse_numbers: [n2, n3].filter((n): n is number => n !== null),
    },
  ];
  const base = clampConfidence(confidence);
  const suggestion = (
    betType: string,
    combination: string,
    horses: string[],
    horseNumbers: Array<number | null>,
    risk: "low" | "medium" | "high",
    confidenceDelta: number,
    stakeUnits: number,
    recommended: boolean,
    priority: number,
    rationale: string,
    frames?: Array<number | null>,
    tickets?: HorseBetSuggestion["tickets"],
    purchaseAction: "buy" | "skip" = "buy",
  ): HorseBetSuggestion => ({
    bet_type: betType,
    combination,
    horses,
    horse_numbers: horseNumbers.filter((n): n is number => n !== null),
    frames: frames?.filter((n): n is number => n !== null),
    risk,
    confidence: clampConfidence(base + confidenceDelta),
    stake_units: stakeUnits,
    recommended,
    priority,
    rationale,
    purchase_action: purchaseAction,
    data_quality_score: purchaseDecision.dataQuality,
    tickets,
  });
  const betSuggestions: HorseBetSuggestion[] = [
    suggestion(
      "購入しない",
      "見送り",
      [first, second, third],
      [n1, n2, n3],
      "low",
      purchaseDecision.confidence - base,
      0,
      purchaseDecision.skipRecommended,
      purchaseDecision.skipRecommended ? 0 : 9,
      purchaseDecision.reason,
      undefined,
      undefined,
      "skip",
    ),
    suggestion(
      "複勝",
      l1,
      [first],
      [n1],
      "low",
      0.14,
      3,
      shouldRecommendBuy,
      1,
      "本命馬が3着以内に入る前提の最小リスク本線。",
    ),
    suggestion(
      "ワイド",
      `${l1}-${l2} / ${l1}-${l3}`,
      [first, second, third],
      [n1, n2, n3],
      "low",
      0.08,
      2,
      shouldRecommendBuy,
      2,
      "本命から相手2頭へ分散し、3着内の組み合わせを狙う。",
      undefined,
      wideTickets,
    ),
    suggestion(
      "単勝",
      l1,
      [first],
      [n1],
      "medium",
      0.02,
      1,
      false,
      3,
      "本命の勝ち切りを狙うが、複勝よりブレが大きい。",
    ),
    suggestion(
      "馬連",
      `${l1}-${l2}`,
      [first, second],
      [n1, n2],
      "medium",
      -0.02,
      1,
      false,
      4,
      "1・2着の順不同。上位2頭の能力差が小さい時の相手本線。",
    ),
    suggestion(
      "枠連",
      f1 && f2 ? `${f1}-${f2}` : `${l1}-${l2}の枠`,
      [first, second],
      [n1, n2],
      "medium",
      -0.03,
      1,
      false,
      5,
      "枠番ベースで上位2頭を押さえる。",
      [f1, f2],
    ),
    suggestion(
      "馬単",
      `${l1}→${l2}`,
      [first, second],
      [n1, n2],
      "high",
      -0.08,
      1,
      false,
      6,
      "本命1着固定。リターンは増えるが順序リスクが高い。",
    ),
    suggestion(
      "3連複",
      `${l1}-${l2}-${l3}`,
      [first, second, third],
      [n1, n2, n3],
      "high",
      -0.12,
      1,
      false,
      7,
      "上位3頭の順不同。少額で妙味を見る券種。",
    ),
    suggestion(
      "3連単",
      `${l1}→${l2}→${l3}`,
      [first, second, third],
      [n1, n2, n3],
      "high",
      -0.18,
      1,
      false,
      8,
      "着順完全固定。最も荒れるため記録・検証用の少額向け。",
    ),
  ];
  return {
    bet_suggestions: betSuggestions,
    recommended_tickets: betSuggestions.filter((bet) => bet.recommended),
  };
}

function sanitizeHorsePrediction(
  pred: {
    first: string;
    second: string;
    third: string;
    confidence: number;
    reasoning: string;
  },
  entries: Record<string, unknown>[],
) {
  const names = entries
    .map((entry) => String(entry.horse_name ?? "").trim())
    .filter((name) => name.length > 0);
  const nameByNormalized = new Map(
    names.map((name) => [normalizeHorseNameForMatch(name), name]),
  );
  const picked: string[] = [];
  let corrected = false;
  for (const raw of [pred.first, pred.second, pred.third]) {
    const normalized = normalizeHorseNameForMatch(raw);
    const validName = nameByNormalized.get(normalized);
    if (validName && !picked.includes(validName)) {
      picked.push(validName);
    } else {
      corrected = true;
    }
  }
  for (const name of names) {
    if (picked.length >= 3) break;
    if (!picked.includes(name)) picked.push(name);
    corrected = true;
  }
  const [first, second, third] = [
    picked[0] ?? names[0] ?? "",
    picked[1] ?? names[1] ?? "",
    picked[2] ?? names[2] ?? "",
  ];
  const guide = lowRiskBetGuide(first, second, third);
  const confidence = corrected
    ? Math.min(Number(pred.confidence ?? 0.5), 0.55)
    : Number(pred.confidence ?? 0.5);
  const bets = buildHorseBetSuggestions(
    first,
    second,
    third,
    entries,
    confidence,
  );
  return {
    first,
    second,
    third,
    confidence,
    reasoning: `${
      corrected
        ? "出走馬リスト外の候補を除外して補正済み。 "
        : "出走馬リスト照合済み。 "
    }${String(pred.reasoning ?? "")} ${guide}`,
    ...bets,
  };
}

function enrichHorsePredictionForClient(
  pred: Record<string, unknown>,
  entries: Record<string, unknown>[],
): Record<string, unknown> {
  const sanitized = sanitizeHorsePrediction({
    first: String(pred.first_pick ?? ""),
    second: String(pred.second_pick ?? ""),
    third: String(pred.third_pick ?? ""),
    confidence: Number(pred.confidence ?? 0.5),
    reasoning: String(pred.ai_reasoning ?? pred.reasoning ?? ""),
  }, entries);
  return {
    ...pred,
    bet_suggestions: sanitized.bet_suggestions,
    recommended_tickets: sanitized.recommended_tickets,
  };
}

function hasExistingHorsePrediction(predictions: unknown): boolean {
  if (Array.isArray(predictions)) return predictions.length > 0;
  return Boolean(predictions && typeof predictions === "object");
}

function enrichHorseRaceForClient(
  race: Record<string, unknown>,
): Record<string, unknown> {
  const normalizedRace = {
    ...race,
    venue: normalizeHorseRaceVenue(race),
  };
  const entriesRaw = race.horse_entries;
  const entries = Array.isArray(entriesRaw)
    ? entriesRaw as Record<string, unknown>[]
    : [];
  const predRaw = race.horse_predictions;
  if (Array.isArray(predRaw)) {
    return {
      ...normalizedRace,
      horse_predictions: predRaw.map((pred) =>
        enrichHorsePredictionForClient(pred as Record<string, unknown>, entries)
      ),
    };
  }
  if (predRaw && typeof predRaw === "object") {
    return {
      ...normalizedRace,
      horse_predictions: enrichHorsePredictionForClient(
        predRaw as Record<string, unknown>,
        entries,
      ),
    };
  }
  return normalizedRace;
}

function sortedPair(values: string[]): string {
  return values.map((v) => normalizeHorseNameForMatch(v)).sort().join("|");
}

function hitMapForHorsePrediction(
  pred: Record<string, unknown>,
  result: Record<string, unknown>,
  entries: Record<string, unknown>[],
) {
  const first = String(pred.first_pick ?? "").trim();
  const second = String(pred.second_pick ?? "").trim();
  const third = String(pred.third_pick ?? "").trim();
  const actualFirst = String(result.first_place ?? "").trim();
  const actualSecond = String(result.second_place ?? "").trim();
  const actualThird = String(result.third_place ?? "").trim();
  const actualTop3 = [actualFirst, actualSecond, actualThird].filter(Boolean);
  const lookup = horseEntryLookup(entries);
  const fieldSize = entries.length || 18;
  const predFrame1 = frameForHorseNumber(
    horseNumberOf(lookup.get(normalizeHorseNameForMatch(first))),
    fieldSize,
  );
  const predFrame2 = frameForHorseNumber(
    horseNumberOf(lookup.get(normalizeHorseNameForMatch(second))),
    fieldSize,
  );
  const actualFrame1 = frameForHorseNumber(
    horseNumberOf(lookup.get(normalizeHorseNameForMatch(actualFirst))),
    fieldSize,
  );
  const actualFrame2 = frameForHorseNumber(
    horseNumberOf(lookup.get(normalizeHorseNameForMatch(actualSecond))),
    fieldSize,
  );
  const predictedPair = sortedPair([first, second]);
  const actualPair = sortedPair([actualFirst, actualSecond]);
  const predictedTriple = sortedPair([first, second, third]);
  const actualTriple = sortedPair(actualTop3);
  const widePairs = [
    sortedPair([first, second]),
    sortedPair([first, third]),
    sortedPair([second, third]),
  ];
  const actualWidePairs = new Set([
    sortedPair([actualFirst, actualSecond]),
    sortedPair([actualFirst, actualThird]),
    sortedPair([actualSecond, actualThird]),
  ]);
  const frameHit = predFrame1 !== null && predFrame2 !== null &&
    actualFrame1 !== null && actualFrame2 !== null &&
    sortedPair([String(predFrame1), String(predFrame2)]) ===
      sortedPair([String(actualFrame1), String(actualFrame2)]);
  const winHit = normalizeHorseNameForMatch(first) ===
    normalizeHorseNameForMatch(actualFirst);
  const placeHit = actualTop3.map(normalizeHorseNameForMatch).includes(
    normalizeHorseNameForMatch(first),
  );
  const quinellaHit = predictedPair === actualPair;
  const wideHit = widePairs.some((pair) => actualWidePairs.has(pair));
  const exactaHit = normalizeHorseNameForMatch(first) ===
      normalizeHorseNameForMatch(actualFirst) &&
    normalizeHorseNameForMatch(second) ===
      normalizeHorseNameForMatch(actualSecond);
  const trioHit = predictedTriple === actualTriple;
  const trifectaHit = exactaHit &&
    normalizeHorseNameForMatch(third) ===
      normalizeHorseNameForMatch(actualThird);
  const noBetCorrect = !placeHit && !wideHit;
  return {
    hits: {
      "購入しない": noBetCorrect,
      "単勝": winHit,
      "複勝": placeHit,
      "枠連": frameHit,
      "馬連": quinellaHit,
      "ワイド": wideHit,
      "馬単": exactaHit,
      "3連複": trioHit,
      "3連単": trifectaHit,
    },
    suggestions: buildHorseBetSuggestions(
      first,
      second,
      third,
      entries,
      Number(pred.confidence ?? 0.5),
    ).bet_suggestions,
  };
}

async function evaluateHorsePredictionAccuracy(
  admin: SupabaseClient,
  options: { raceId?: string | null; limit?: number } = {},
) {
  const raceId = options.raceId ? String(options.raceId) : null;
  const limit = Math.max(1, Math.min(500, Number(options.limit ?? 50)));
  const resultsQuery = admin.from("horse_results")
    .select("race_id, first_place, second_place, third_place");
  const { data: resultsRows, error: resErr } = raceId
    ? await resultsQuery.eq("race_id", raceId)
    : await resultsQuery.order("created_at", { ascending: false }).limit(limit);
  if (resErr) throw new Error(resErr.message);
  if (!resultsRows || resultsRows.length === 0) {
    return {
      success: true,
      evaluated: 0,
      races_processed: 0,
      message: "no finalized results",
    };
  }

  // Batch-fetch entries and predictions to avoid N+1 queries
  const raceIds = (resultsRows as Array<Record<string, unknown>>).map((r) =>
    String(r.race_id)
  );
  const [{ data: allEntriesRows }, { data: allPredsRows }] = await Promise.all([
    admin.from("horse_entries").select("*").in("race_id", raceIds),
    admin.from("horse_race_predictions_ensemble")
      .select(
        "race_id, provider, model, first_pick, second_pick, third_pick, confidence",
      )
      .in("race_id", raceIds),
  ]);
  const entriesByRace = new Map<string, Array<Record<string, unknown>>>();
  for (const e of (allEntriesRows ?? []) as Array<Record<string, unknown>>) {
    const k = String(e.race_id);
    if (!entriesByRace.has(k)) entriesByRace.set(k, []);
    entriesByRace.get(k)!.push(e);
  }
  const predsByRace = new Map<string, Array<Record<string, unknown>>>();
  for (const p of (allPredsRows ?? []) as Array<Record<string, unknown>>) {
    const k = String(p.race_id);
    if (!predsByRace.has(k)) predsByRace.set(k, []);
    predsByRace.get(k)!.push(p);
  }

  let evaluated = 0;
  for (const r of resultsRows as Array<Record<string, unknown>>) {
    const rid = String(r.race_id);
    const entries = entriesByRace.get(rid) ?? [];
    const preds = predsByRace.get(rid) ?? [];
    for (const p of preds as Array<Record<string, unknown>>) {
      const firstCorrect = String(p.first_pick ?? "").trim() ===
        String(r.first_place ?? "").trim();
      const trifectaCorrect = firstCorrect &&
        String(p.second_pick ?? "").trim() ===
          String(r.second_place ?? "").trim() &&
        String(p.third_pick ?? "").trim() ===
          String(r.third_place ?? "").trim();
      const typeEval = hitMapForHorsePrediction(p, r, entries);
      const hits = typeEval.hits as Record<string, boolean>;
      const suggestions = typeEval.suggestions as HorseBetSuggestion[];
      const skipRecommended = suggestions.some((s) =>
        s.bet_type === "購入しない" && s.recommended
      );
      const weightedScore = (skipRecommended && hits["購入しない"] ? 0.22 : 0) +
        (hits["複勝"] ? 0.28 : 0) +
        (hits["ワイド"] ? 0.22 : 0) +
        (hits["単勝"] ? 0.16 : 0) +
        (hits["馬連"] ? 0.11 : 0) +
        (hits["枠連"] ? 0.08 : 0) +
        (hits["馬単"] ? 0.07 : 0) +
        (hits["3連複"] ? 0.05 : 0) +
        (hits["3連単"] ? 0.03 : 0);
      const payload = {
        race_id: rid,
        provider: p.provider,
        model: p.model,
        predicted_first: p.first_pick,
        predicted_second: p.second_pick,
        predicted_third: p.third_pick,
        actual_first: r.first_place,
        actual_second: r.second_place,
        actual_third: r.third_place,
        first_correct: firstCorrect,
        trifecta_correct: trifectaCorrect,
        bet_type_hits: hits,
        recommended_hits: {
          low_risk_core: Boolean(hits["複勝"] || hits["ワイド"]),
          skip_purchase: skipRecommended ? Boolean(hits["購入しない"]) : null,
          recommended_bet_types: ["複勝", "ワイド"].filter((type) =>
            hits[type]
          ),
        },
        bet_type_predictions: suggestions,
        skip_recommendation_correct: skipRecommended
          ? Boolean(hits["購入しない"])
          : null,
        evaluated_features: {
          data_quality_score: horseRaceDataQualityScore(entries),
          entry_count: entries.length,
          features: [
            "血統",
            "前走",
            "馬体重",
            "騎手",
            "調教師",
            "厩舎",
            "タイム",
            "オッズ",
            "人気",
            "持ち時計",
            "馬体重変動",
            "前走着差",
          ],
        },
        learning_score: Math.round(weightedScore * 1000) / 1000,
      };
      const { error: accErr } = await admin.from("horse_prediction_accuracy")
        .upsert(
          payload,
          { onConflict: "race_id,provider,model" },
        );
      if (accErr) {
        console.warn(
          "horse_prediction_accuracy extended upsert failed; retrying legacy payload",
          accErr.message,
        );
        const legacyPayload = { ...payload } as Record<string, unknown>;
        delete legacyPayload.bet_type_hits;
        delete legacyPayload.recommended_hits;
        delete legacyPayload.bet_type_predictions;
        delete legacyPayload.skip_recommendation_correct;
        delete legacyPayload.evaluated_features;
        delete legacyPayload.learning_score;
        await admin.from("horse_prediction_accuracy").upsert(
          legacyPayload,
          { onConflict: "race_id,provider,model" },
        );
      }
      evaluated += 1;
    }
  }

  return { success: true, evaluated, races_processed: resultsRows.length };
}

async function callProviderForHorsePrediction(
  cfg: HorseProviderConfig,
  prompt: string,
): Promise<ProviderPredictionResult> {
  const apiKey = Deno.env.get(cfg.apiKeyEnv) ?? "";
  if (!apiKey) {
    return {
      success: false,
      error: { reason: `${cfg.apiKeyEnv} not configured`, is_quota: false },
      latency_ms: 0,
    };
  }
  const startMs = Date.now();
  try {
    let res: Response;
    let rawText = "";

    if (cfg.provider === "google") {
      res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${cfg.model}:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
        },
      );
      if (res.ok) {
        const data = await res.json() as {
          candidates?: Array<{ content: { parts: Array<{ text: string }> } }>;
        };
        rawText = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
      }
    } else if (
      cfg.provider === "openai" || cfg.provider === "xai" ||
      cfg.provider === "openrouter"
    ) {
      const url = cfg.provider === "openai"
        ? "https://api.openai.com/v1/chat/completions"
        : cfg.provider === "xai"
        ? "https://api.x.ai/v1/chat/completions"
        : "https://openrouter.ai/api/v1/chat/completions";
      res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
          ...(cfg.provider === "openrouter"
            ? {
              "HTTP-Referer": "https://my-web-app-b67f4.web.app",
              "X-Title": "my_web_app horse racing AI",
            }
            : {}),
        },
        body: JSON.stringify({
          model: cfg.model,
          messages: [
            {
              role: "system",
              content:
                "あなたは競馬予想AIです。必ずJSONのみで回答してください。",
            },
            { role: "user", content: prompt },
          ],
          temperature: 0.3,
          response_format: { type: "json_object" },
        }),
      });
      if (res.ok) {
        const data = await res.json() as {
          choices?: Array<{ message: { content: string } }>;
        };
        rawText = data.choices?.[0]?.message?.content ?? "";
      }
    } else if (cfg.provider === "anthropic") {
      res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: cfg.model,
          max_tokens: 1024,
          messages: [{ role: "user", content: prompt }],
        }),
      });
      if (res.ok) {
        const data = await res.json() as { content?: Array<{ text: string }> };
        rawText = data.content?.[0]?.text ?? "";
      }
    } else {
      return {
        success: false,
        error: { reason: `unknown provider: ${cfg.provider}`, is_quota: false },
        latency_ms: Date.now() - startMs,
      };
    }

    if (!res.ok) {
      const errText = await res.text().catch(() => "");
      const isQuota = res.status === 429 ||
        /quota|rate.?limit|RESOURCE_EXHAUSTED|insufficient_quota/i.test(
          errText,
        );
      return {
        success: false,
        error: {
          http_status: res.status,
          reason: `${cfg.provider} HTTP ${res.status}`,
          detail: errText.slice(0, 200),
          is_quota: isQuota,
        },
        latency_ms: Date.now() - startMs,
      };
    }

    let pred: Record<string, unknown>;
    try {
      pred = JSON.parse(rawText.replace(/```json\n?|\n?```/g, "").trim());
    } catch (parseErr) {
      return {
        success: false,
        error: {
          reason: `JSON.parse failed: ${parseErr}`,
          detail: rawText.slice(0, 200),
          is_quota: false,
        },
        latency_ms: Date.now() - startMs,
      };
    }

    return {
      success: true,
      prediction: {
        first: String(pred.first ?? ""),
        second: String(pred.second ?? ""),
        third: String(pred.third ?? ""),
        confidence: Number(pred.confidence ?? 0.5),
        reasoning: String(pred.reasoning ?? ""),
      },
      latency_ms: Date.now() - startMs,
    };
  } catch (err) {
    return {
      success: false,
      error: {
        reason: `exception: ${String(err).slice(0, 200)}`,
        is_quota: false,
      },
      latency_ms: Date.now() - startMs,
    };
  }
}

async function persistEnsemblePrediction(
  admin: SupabaseClient,
  raceId: string,
  cfg: HorseProviderConfig,
  result: ProviderPredictionResult,
  entries: Record<string, unknown>[],
): Promise<void> {
  if (!result.success || !result.prediction) return;
  const pred = sanitizeHorsePrediction(result.prediction, entries);
  await admin.from("horse_race_predictions_ensemble").upsert({
    race_id: raceId,
    provider: cfg.provider,
    model: cfg.model,
    first_pick: pred.first,
    second_pick: pred.second,
    third_pick: pred.third,
    confidence: pred.confidence,
    reasoning: pred.reasoning,
    prediction_json: pred,
    estimated_cost_usd: cfg.estimatedCostUsd,
    latency_ms: result.latency_ms,
  }, { onConflict: "race_id,provider,model" });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (isOAuthProtectedResourceMetadataRequest(req)) {
    return json(
      buildOAuthProtectedResourceMetadata(req.url, "tools-hub", [
        "wbs.tasks.list",
        "feature_request.create",
        "user_tasks.list",
        "read",
        "create",
      ]),
    );
  }

  try {
    const url = new URL(req.url);
    const body: Record<string, unknown> = req.method === "POST"
      ? await req.json().catch(() => ({}))
      : {};
    const action = String(body.action ?? "").trim() ||
      mcpActionFromJsonRpc(body) ||
      url.searchParams.get("action") ||
      "";
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (isMcpClientRegistrationRequest(req, action)) {
      return await handleMcpClientRegistration(req, body, admin);
    }

    const mcpResponse = await handleMcpFacade(req, action, body, admin);
    if (mcpResponse) return mcpResponse;

    // Public, read-only business references used by the regional map. Keep this
    // in tools-hub so the browser and authenticated MCP tool share one fetcher
    // without consuming another production Edge Function slot.
    if (action === "public_businesses.reference_list") {
      const result = await dispatchLocalBusinessReferenceAction(body);
      return json(result.body, result.status);
    }

    // ── 自分API (Notion Developer Platform 対抗 / 2026-07-12 WEB版) ─────────
    // jibunapi.* = 管理系 (Supabase JWT) / api.* = 外部公開系 (jibun_sk_ キー)。
    // GET 呼び出し (AI エージェント / curl) 向けに query params も body へマージする。
    if (action.startsWith("jibunapi.") || action.startsWith("api.")) {
      const merged: Record<string, unknown> = {
        ...Object.fromEntries(url.searchParams),
        ...body,
      };
      const jibunResponse = await handleJibunApiAction({
        req,
        action,
        body: merged,
        store: createSupabaseJibunApiStore(admin),
        getUserId: () => getUserId(req),
      });
      if (jibunResponse) return jibunResponse;
    }

    // ── Stateless utilities (no auth needed) ────────────────────────────────
    if (action === "generate_password") {
      const length = Number(body.length ?? 16);
      const chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*-_";
      const arr = new Uint8Array(length);
      crypto.getRandomValues(arr);
      const password = Array.from(arr, (b) => chars[b % chars.length]).join("");
      return json({ success: true, password });
    }

    if (action === "generate_qr") {
      const text = String(body.text ?? "");
      const size = Number(body.size ?? 200);
      const qrUrl =
        `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${
          encodeURIComponent(text)
        }`;
      return json({ success: true, qr_url: qrUrl, text });
    }

    if (action === "convert_currency") {
      const from = String(body.from ?? "USD").toUpperCase();
      const to = String(body.to ?? "JPY").toUpperCase();
      const amount = Number(body.amount ?? 1);
      const res = await fetch(`https://open.er-api.com/v6/latest/${from}`)
        .catch(() => null);
      if (!res || !res.ok) {
        return json({ error: "Exchange rate API unavailable" }, 502);
      }
      const rates =
        (await res.json() as { rates: Record<string, number> }).rates;
      const rate = rates[to];
      if (!rate) return json({ error: `Unknown currency: ${to}` }, 400);
      return json({
        success: true,
        from,
        to,
        amount,
        rate,
        result: amount * rate,
      });
    }

    if (action === "get_weather") {
      const city = String(body.city ?? "Tokyo");
      const res = await fetch(
        `https://wttr.in/${encodeURIComponent(city)}?format=j1`,
      ).catch(() => null);
      if (!res || !res.ok) {
        return json({ error: "Weather API unavailable" }, 502);
      }
      const data = await res.json() as Record<string, unknown>;
      return json({ success: true, city, weather: data });
    }

    if (action === "render_markdown") {
      // Client-side rendering preferred; return raw markdown with metadata
      const markdown = String(body.markdown ?? "");
      return json({ success: true, markdown, length: markdown.length });
    }

    if (action === "translate") {
      const text = String(body.text ?? "");
      const target = String(body.target ?? "ja");
      const source = String(body.source ?? "auto");
      const res = await fetch(
        `https://api.mymemory.translated.net/get?q=${
          encodeURIComponent(text)
        }&langpair=${source}|${target}`,
      ).catch(() => null);
      if (!res || !res.ok) {
        return json({ error: "Translation API unavailable" }, 502);
      }
      const result = await res.json() as {
        responseData?: { translatedText?: string };
      };
      return json({
        success: true,
        original: text,
        translated: result.responseData?.translatedText ?? text,
        target,
      });
    }

    // ── Horse Racing + WBS 自動化パイプライン (auth不要 — GitHub Actions / 全インスタンス hook対応) ─────────
    // PS#6 S22 (2026-04-20): wbs.* は SERVICE_ROLE_KEY で admin 操作 (全インスタンスの session hook / wrap-up 更新経路)
    if (action.startsWith("horseracing.") || action.startsWith("wbs.")) {
      switch (action) {
        case "horseracing.today": {
          const targetDate = String(
            body.date ?? new Date().toISOString().split("T")[0],
          );
          const type = String(body.type ?? "all");
          let query = admin
            .from("horse_races")
            .select(
              "*, horse_entries(*), horse_predictions(*), horse_results(*)",
            )
            .eq("race_date", targetDate);

          if (type === "jra") query = query.eq("source", "jra");
          else if (type === "nar") query = query.eq("source", "nar");
          else if (type === "overseas") query = query.eq("source", "overseas");

          const { data: races, error: re } = await query.order("post_time", {
            ascending: true,
          });
          if (re) throw new Error(re.message);
          const raceRows = (races ?? []) as Record<string, unknown>[];
          const liveEnriched = new Map<string, Record<string, unknown>>();
          await Promise.allSettled(
            raceRows
              .filter((race) => shouldEnrichLocalRaceInfo(race))
              .slice(0, 48)
              .map(async (race) => {
                const enriched = await ensureLiveHorseRaceInfo(admin, race);
                liveEnriched.set(
                  String(race.id ?? race.race_id_ext ?? ""),
                  enriched,
                );
              }),
          );
          const enrichedRaces = raceRows.map((race) => {
            const key = String(race.id ?? race.race_id_ext ?? "");
            return enrichHorseRaceForClient(liveEnriched.get(key) ?? race);
          });
          return json({
            success: true,
            races: enrichedRaces,
            date: targetDate,
          });
        }
        case "horseracing.list_races": {
          const { data: races, error: re } = await admin
            .from("horse_races")
            .select(
              "*, horse_predictions(id,first_pick,second_pick,third_pick,confidence), horse_results(first_place,second_place,third_place,is_prediction_correct,trifecta_paid)",
            )
            .order("race_date", { ascending: false })
            .limit(50);
          if (re) throw new Error(re.message);
          return json({ success: true, races: races ?? [] });
        }
        case "horseracing.predict_all": {
          // Windows版#94: quota fallback chain 対応
          // 1) レース毎に HORSE_PROVIDER_CHAIN を順に試行 (quota時は次プロバイダー)
          // 2) 成功した予想を horse_predictions (互換維持) + horse_race_predictions_ensemble に両方記録
          // 3) 全プロバイダーquota時のみ残りレースを早期skip
          const targetDate = String(
            body.date ?? new Date().toISOString().split("T")[0],
          );
          const type = String(body.type ?? body.source ?? "all");
          const raceId = body.race_id ? String(body.race_id) : null;
          const force = Boolean(body.force ?? false);
          const providerChain = horseProviderChain(
            parseBooleanish(
              body.use_premium_models ?? body.premium_models,
              false,
            ),
          );
          let raceQuery = admin.from("horse_races")
            .select("*, horse_entries(*), horse_predictions(id)")
            .eq("race_date", targetDate).eq("status", "scheduled");
          if (type === "jra") raceQuery = raceQuery.eq("source", "jra");
          else if (type === "nar") raceQuery = raceQuery.eq("source", "nar");
          else if (type === "overseas") {
            raceQuery = raceQuery.eq("source", "overseas");
          }
          if (raceId) raceQuery = raceQuery.eq("id", raceId);
          const { data: races } = await raceQuery;
          if (!races || races.length === 0) {
            return json({
              success: true,
              predictions: [],
              message: "本日のレースなし",
            });
          }
          const allUnpredicted = force
            ? races
            : races.filter((r) =>
              !hasExistingHorsePrediction(
                (r as { horse_predictions?: unknown }).horse_predictions,
              )
            );
          if (allUnpredicted.length === 0) {
            return json({
              success: true,
              predictions: [],
              message: "全レース予想済",
            });
          }
          // Windows版#94b: EF 150s timeout 対策として 1 回あたり最大 limit 件まで処理
          // (4 providers × 長レースで 120s urllib timeout に到達するため)
          const maxBatch = Math.max(1, Math.min(50, Number(body.limit ?? 20)));
          const unpredicted = allUnpredicted.slice(0, maxBatch);
          const remaining = Math.max(
            0,
            allUnpredicted.length - unpredicted.length,
          );
          const results: Array<Record<string, unknown>> = [];
          const failures: Array<Record<string, unknown>> = [];
          const providerStats: Record<
            string,
            { attempts: number; hits: number; quotas: number }
          > = {};
          for (const cfg of providerChain) {
            providerStats[cfg.provider] = { attempts: 0, hits: 0, quotas: 0 };
          }
          const exhaustedProviders = new Set<string>();

          for (const rawRace of unpredicted) {
            const race = await ensureLiveHorseRaceInfo(
              admin,
              rawRace as Record<string, unknown>,
            );
            const currentRaceId = String(race.id ?? "");
            if (exhaustedProviders.size >= providerChain.length) {
              failures.push({
                race_id: currentRaceId,
                race_name: race.race_name,
                reason: "skipped: all providers exhausted (quota)",
              });
              continue;
            }
            // deno-lint-ignore no-explicit-any
            const entries = (race.horse_entries as any[]) ?? [];
            if (entries.length < 3) {
              failures.push({
                race_id: currentRaceId,
                race_name: race.race_name,
                reason: `entries < 3 (${entries.length}頭)`,
              });
              continue;
            }
            const prompt = buildHorseRacePrompt(race, entries);
            let succeededCfg: HorseProviderConfig | null = null;
            let succeededResult: ProviderPredictionResult | null = null;
            const perRaceFailures: Array<Record<string, unknown>> = [];

            for (const cfg of providerChain) {
              if (exhaustedProviders.has(cfg.provider)) continue;
              providerStats[cfg.provider].attempts += 1;
              const result = await callProviderForHorsePrediction(cfg, prompt);
              if (result.success) {
                providerStats[cfg.provider].hits += 1;
                succeededCfg = cfg;
                succeededResult = result;
                break;
              }
              perRaceFailures.push({
                provider: cfg.provider,
                model: cfg.model,
                reason: result.error?.reason,
                http_status: result.error?.http_status,
                is_quota: result.error?.is_quota ?? false,
              });
              if (result.error?.is_quota) {
                providerStats[cfg.provider].quotas += 1;
                exhaustedProviders.add(cfg.provider);
                console.warn(
                  `[predict_all] ${cfg.provider} quota exceeded — fallback to next provider.`,
                );
              }
            }

            if (
              !succeededCfg || !succeededResult || !succeededResult.prediction
            ) {
              failures.push({
                race_id: currentRaceId,
                race_name: race.race_name,
                reason: "all providers failed",
                provider_failures: perRaceFailures,
              });
              continue;
            }

            // 1) ensemble table に記録 (プロバイダー別蓄積)
            await persistEnsemblePrediction(
              admin,
              currentRaceId,
              succeededCfg,
              succeededResult,
              entries,
            );

            // 2) 互換維持: horse_predictions (代表1件) に最初の成功プロバイダー結果を入れる
            const pred = sanitizeHorsePrediction(
              succeededResult.prediction,
              entries,
            );
            await admin.from("horse_predictions").delete().eq(
              "race_id",
              currentRaceId,
            );
            const { error: ie } = await admin.from("horse_predictions").insert({
              race_id: currentRaceId,
              first_pick: pred.first || entries[0].horse_name,
              second_pick: pred.second || entries[1].horse_name,
              third_pick: pred.third || entries[2].horse_name,
              confidence: pred.confidence,
              ai_reasoning: pred.reasoning,
              ai_model: `${succeededCfg.provider}:${succeededCfg.model}`,
            });
            if (ie) {
              failures.push({
                race_id: currentRaceId,
                race_name: race.race_name,
                reason: `horse_predictions insert failed: ${ie.message}`,
              });
            } else {
              results.push({
                race_id: currentRaceId,
                race_name: race.race_name,
                provider: succeededCfg.provider,
                model: succeededCfg.model,
                ...pred,
              });
            }
          }
          return json({
            success: true,
            predictions: results,
            count: results.length,
            failures,
            failure_count: failures.length,
            provider_stats: providerStats,
            exhausted_providers: Array.from(exhaustedProviders),
            remaining,
            batch_size: unpredicted.length,
            total_unpredicted: allUnpredicted.length,
            model_chain: providerChain.map((cfg) =>
              `${cfg.provider}:${cfg.model}`
            ),
          });
        }
        case "horseracing.predict_ensemble": {
          // 1レースに対し全プロバイダーで並列予想 → ensemble table に記録
          // body: { race_id, providers?: string[], force?: boolean }
          const raceId = String(body.race_id ?? "");
          if (!raceId) return json({ error: "race_id required" }, 400);
          const whitelist: string[] | null = Array.isArray(body.providers)
            ? body.providers.map(String)
            : null;
          const force = Boolean(body.force ?? false);
          const providerChain = horseProviderChain(
            parseBooleanish(
              body.use_premium_models ?? body.premium_models,
              false,
            ),
          );
          const { data: race, error: re } = await admin.from("horse_races")
            .select("*, horse_entries(*)")
            .eq("id", raceId)
            .maybeSingle();
          if (re) throw new Error(re.message);
          if (!race) return json({ error: "race not found" }, 404);
          const liveRace = await ensureLiveHorseRaceInfo(
            admin,
            race as Record<string, unknown>,
          );
          // deno-lint-ignore no-explicit-any
          const entries = ((liveRace as any).horse_entries as any[]) ?? [];
          if (entries.length < 3) {
            return json({ error: `entries < 3 (${entries.length})` }, 400);
          }

          const targetCfgs = whitelist
            ? providerChain.filter((c) =>
              whitelist.includes(c.provider) ||
              whitelist.includes(`${c.provider}:${c.model}`)
            )
            : providerChain;
          if (targetCfgs.length === 0) {
            return json({ error: "no providers selected" }, 400);
          }

          // 既に予想済みの provider は skip (force=true でやり直し)
          let existing: Set<string> = new Set();
          if (!force) {
            const { data: ex } = await admin.from(
              "horse_race_predictions_ensemble",
            )
              .select("provider, model")
              .eq("race_id", raceId);
            existing = new Set(
              (ex ?? []).map((r: Record<string, unknown>) =>
                `${r.provider}:${r.model}`
              ),
            );
          }

          const prompt = buildHorseRacePrompt(liveRace, entries);
          const jobs = targetCfgs
            .filter((cfg) => !existing.has(`${cfg.provider}:${cfg.model}`))
            .map(async (cfg) => {
              const result = await callProviderForHorsePrediction(cfg, prompt);
              if (result.success) {
                await persistEnsemblePrediction(
                  admin,
                  raceId,
                  cfg,
                  result,
                  entries,
                );
              }
              return { cfg, result };
            });
          const settled = await Promise.all(jobs);
          const succeeded = settled.filter((s) => s.result.success);
          const failed = settled.filter((s) => !s.result.success);
          return json({
            success: true,
            race_id: raceId,
            attempted: settled.length,
            succeeded: succeeded.map((s) => ({
              provider: s.cfg.provider,
              model: s.cfg.model,
              prediction: s.result.prediction,
              latency_ms: s.result.latency_ms,
            })),
            failed: failed.map((s) => ({
              provider: s.cfg.provider,
              model: s.cfg.model,
              reason: s.result.error?.reason,
              is_quota: s.result.error?.is_quota ?? false,
            })),
            skipped_already_predicted: targetCfgs.length - settled.length,
          });
        }
        case "horseracing.consensus": {
          // 1レースの全予想をプロバイダー横断で集計しコンセンサスを返す
          // body: { race_id }
          const raceId = String(body.race_id ?? "");
          if (!raceId) return json({ error: "race_id required" }, 400);
          const { data: preds, error: pe } = await admin.from(
            "horse_race_predictions_ensemble",
          )
            .select(
              "provider, model, first_pick, second_pick, third_pick, confidence, reasoning, predicted_at",
            )
            .eq("race_id", raceId)
            .order("predicted_at", { ascending: true });
          if (pe) throw new Error(pe.message);
          const rows = preds ?? [];
          if (rows.length === 0) {
            return json({
              success: true,
              race_id: raceId,
              consensus: null,
              predictions: [],
            });
          }
          // 1着票数 + 信頼度加重集計
          const firstVotes: Record<
            string,
            { votes: number; weighted: number; providers: string[] }
          > = {};
          // 複勝コンセンサス: 1着(×1.0) + 2着(×0.7) + 3着(×0.5) の加重合算
          const placeVotes: Record<
            string,
            {
              votes: number;
              weighted: number;
              as_first: number;
              providers: string[];
            }
          > = {};
          for (const p of rows) {
            const conf = Number(p.confidence ?? 0.5);
            const provKey = `${p.provider}:${p.model}`;
            // 1着集計
            const first = String(p.first_pick ?? "").trim();
            if (first) {
              if (!firstVotes[first]) {
                firstVotes[first] = { votes: 0, weighted: 0, providers: [] };
              }
              firstVotes[first].votes += 1;
              firstVotes[first].weighted += conf;
              firstVotes[first].providers.push(provKey);
            }
            // 複勝集計 (1着=1.0 / 2着=0.7 / 3着=0.5)
            const picks: [unknown, number][] = [[p.first_pick, 1.0], [
              p.second_pick,
              0.7,
            ], [p.third_pick, 0.5]];
            const seen = new Set<string>();
            for (const [pick, decay] of picks) {
              const horse = String(pick ?? "").trim();
              if (!horse || seen.has(horse)) continue;
              seen.add(horse);
              if (!placeVotes[horse]) {
                placeVotes[horse] = {
                  votes: 0,
                  weighted: 0,
                  as_first: 0,
                  providers: [],
                };
              }
              placeVotes[horse].votes += 1;
              placeVotes[horse].weighted += conf * decay;
              if (pick === p.first_pick) placeVotes[horse].as_first += 1;
              placeVotes[horse].providers.push(provKey);
            }
          }
          const sortedFirst = Object.entries(firstVotes)
            .sort((a, b) => b[1].weighted - a[1].weighted);
          const sortedPlace = Object.entries(placeVotes)
            .sort((a, b) => b[1].weighted - a[1].weighted);
          const top = sortedFirst[0];
          const topPlace = sortedPlace[0];
          const agreementRate = top ? top[1].votes / rows.length : 0;
          return json({
            success: true,
            race_id: raceId,
            predictions: rows,
            total_providers: rows.length,
            consensus: top
              ? {
                first_pick: top[0],
                votes: top[1].votes,
                weighted_score: Math.round(top[1].weighted * 1000) / 1000,
                providers: top[1].providers,
                agreement_rate: Math.round(agreementRate * 1000) / 1000,
              }
              : null,
            place_consensus: topPlace
              ? {
                horse: topPlace[0],
                place_votes: topPlace[1].votes,
                place_weighted_score: Math.round(topPlace[1].weighted * 1000) /
                  1000,
                as_first_count: topPlace[1].as_first,
                providers: topPlace[1].providers,
                place_agreement_rate:
                  Math.round(topPlace[1].votes / rows.length * 1000) / 1000,
              }
              : null,
            first_pick_distribution: sortedFirst.map(([horse, v]) => ({
              horse,
              votes: v.votes,
              weighted: Math.round(v.weighted * 1000) / 1000,
              providers: v.providers,
            })),
            place_distribution: sortedPlace.map(([horse, v]) => ({
              horse,
              place_votes: v.votes,
              place_weighted: Math.round(v.weighted * 1000) / 1000,
              as_first: v.as_first,
              providers: v.providers,
            })),
          });
        }
        case "horseracing.provider_leaderboard": {
          const { data, error: le } = await admin.from(
            "horse_provider_leaderboard",
          )
            .select("*");
          if (le) throw new Error(le.message);
          const lb = data ?? [];
          // Attach best bet type per provider/model from horse_bet_type_provider_accuracy
          const { data: btRows } = await admin.from(
            "horse_bet_type_provider_accuracy",
          )
            .select(
              "provider, model, bet_type, hit_rate_pct, total_predictions",
            )
            .neq("bet_type", "購入しない");
          const btMap = new Map<
            string,
            { bet_type: string; hit_rate_pct: number }
          >();
          for (const row of (btRows ?? []) as Array<Record<string, unknown>>) {
            const key = `${row.provider}|${row.model}`;
            if (!btMap.has(key)) {
              btMap.set(key, {
                bet_type: String(row.bet_type ?? ""),
                hit_rate_pct: Number(row.hit_rate_pct ?? 0),
              });
            }
          }
          const enriched = lb.map((row: Record<string, unknown>) => {
            const key = `${row.provider}|${row.model}`;
            const best = btMap.get(key);
            return {
              ...row,
              best_bet_type: best?.bet_type ?? null,
              best_bet_hit_rate: best?.hit_rate_pct ?? null,
            };
          });
          return json({ success: true, leaderboard: enriched });
        }
        case "horseracing.evaluate_accuracy": {
          // 結果確定済みレースの ensemble 予想を全てスコアリング
          // body: { race_id? } (指定時は1レース、省略時は最新50レース)
          const raceId = body.race_id ? String(body.race_id) : null;
          const limit = Math.max(1, Math.min(500, Number(body.limit ?? 50)));
          return json(
            await evaluateHorsePredictionAccuracy(admin, { raceId, limit }),
          );
        }
        case "horseracing.backfill_learning_data": {
          // 過去レースの出走表から「結果を見ない」低リスク基準予想を作り、
          // 既に取得済みの結果と照合して学習データを増やす。
          const targetDate = String(
            body.date_to ?? body.date ?? new Date().toISOString().split("T")[0],
          );
          const days = Math.max(1, Math.min(180, Number(body.days ?? 21)));
          const dateFromMs = Date.parse(`${targetDate}T00:00:00.000Z`) -
            (days - 1) * 86_400_000;
          const dateFrom = String(
            body.date_from ?? new Date(dateFromMs).toISOString().split("T")[0],
          );
          const force = Boolean(body.force ?? false);
          // force=true 時は 150s EF タイムアウト内で完結するよう limit を 60 に制限
          const defaultLimit = force ? 60 : 160;
          const limit = Math.max(
            1,
            Math.min(force ? 60 : 500, Number(body.limit ?? defaultLimit)),
          );
          const type = String(body.type ?? body.source ?? "all");
          const baselineCfg: HorseProviderConfig = {
            provider: "baseline",
            model: "low-risk-ranker-v1",
            apiKeyEnv: "",
            estimatedCostUsd: 0,
            tier: "base",
            family: "HistoricalBaseline",
          };

          let raceQuery = admin.from("horse_races")
            .select(
              "*, horse_entries(*), horse_predictions(id), horse_results(race_id,first_place,second_place,third_place)",
            )
            .gte("race_date", dateFrom)
            .lte("race_date", targetDate)
            .order("race_date", { ascending: false })
            .limit(limit);
          if (type === "jra") raceQuery = raceQuery.eq("source", "jra");
          else if (type === "nar") raceQuery = raceQuery.eq("source", "nar");
          else if (type === "overseas") {
            raceQuery = raceQuery.eq("source", "overseas");
          }

          const { data: races, error: raceErr } = await raceQuery;
          if (raceErr) throw new Error(raceErr.message);
          const raceRows = (races ?? []) as Array<Record<string, unknown>>;
          const raceIds = raceRows.map((race) => String(race.id ?? "")).filter(
            Boolean,
          );
          const existingBaseline = new Set<string>();
          if (raceIds.length > 0) {
            const { data: existing } = await admin.from(
              "horse_race_predictions_ensemble",
            )
              .select("race_id")
              .in("race_id", raceIds)
              .eq("provider", baselineCfg.provider)
              .eq("model", baselineCfg.model);
            for (
              const row of (existing ?? []) as Array<Record<string, unknown>>
            ) {
              existingBaseline.add(String(row.race_id));
            }
          }

          let backfilled = 0;
          let representativeInserted = 0;
          let skipped = 0;
          let withResults = 0;
          const samples: Array<Record<string, unknown>> = [];

          for (const rawRace of raceRows) {
            const race = await ensureLiveHorseRaceInfo(admin, rawRace);
            const raceId = String(race.id ?? "");
            if (!raceId) {
              skipped += 1;
              continue;
            }
            const entries = Array.isArray(race.horse_entries)
              ? (race.horse_entries as Array<Record<string, unknown>>)
              : [];
            if (entries.length < 3) {
              skipped += 1;
              continue;
            }
            const hasResult = Array.isArray(race.horse_results) &&
              race.horse_results.length > 0;
            if (hasResult) withResults += 1;
            if (!force && existingBaseline.has(raceId)) {
              skipped += 1;
              continue;
            }

            const baseline = buildHistoricalBaselinePrediction(race, entries);
            await persistEnsemblePrediction(
              admin,
              raceId,
              baselineCfg,
              baseline,
              entries,
            );
            backfilled += 1;

            const representative = Array.isArray(race.horse_predictions)
              ? race.horse_predictions
              : [];
            if (representative.length === 0 && baseline.prediction) {
              const pred = sanitizeHorsePrediction(
                baseline.prediction,
                entries,
              );
              const { error: insertErr } = await admin.from("horse_predictions")
                .insert({
                  race_id: raceId,
                  first_pick: pred.first,
                  second_pick: pred.second,
                  third_pick: pred.third,
                  confidence: pred.confidence,
                  ai_reasoning:
                    `${pred.reasoning} / historical backfill baseline`,
                  ai_model: `${baselineCfg.provider}:${baselineCfg.model}`,
                });
              if (!insertErr) representativeInserted += 1;
            }

            if (samples.length < 8 && baseline.prediction) {
              samples.push({
                race_id: raceId,
                race_date: race.race_date,
                race_name: race.race_name,
                venue: race.venue,
                first: baseline.prediction.first,
                second: baseline.prediction.second,
                third: baseline.prediction.third,
                confidence: baseline.prediction.confidence,
                has_result: hasResult,
              });
            }
          }

          const evaluation = await evaluateHorsePredictionAccuracy(admin, {
            limit: Math.max(limit, 100),
          });
          return json({
            success: true,
            date_from: dateFrom,
            date_to: targetDate,
            scanned: raceRows.length,
            backfilled,
            representative_inserted: representativeInserted,
            skipped,
            races_with_results: withResults,
            evaluation,
            samples,
          });
        }
        case "horseracing.predictions": {
          const { data: preds, error: pe } = await admin.from(
            "horse_predictions",
          )
            .select(
              "*, horse_races(race_name,race_date,venue,grade,course_type,distance)",
            )
            .order("created_at", { ascending: false }).limit(
              Number(body.limit ?? 50),
            );
          if (pe) throw new Error(pe.message);
          const raceIds = (preds ?? []).map((p: Record<string, unknown>) =>
            p.race_id as string
          ).filter(Boolean);
          const resultsMap: Record<string, unknown> = {};
          const entriesMap: Record<string, Record<string, unknown>[]> = {};
          if (raceIds.length > 0) {
            const { data: hrs } = await admin.from("horse_results")
              .select(
                "race_id,first_place,second_place,third_place,trifecta_paid,is_prediction_correct",
              )
              .in("race_id", raceIds);
            (hrs ?? []).forEach((r: Record<string, unknown>) => {
              resultsMap[r.race_id as string] = r;
            });
            const { data: entries } = await admin.from("horse_entries")
              .select("*")
              .in("race_id", raceIds);
            for (
              const entry of (entries ?? []) as Array<Record<string, unknown>>
            ) {
              const rid = String(entry.race_id ?? "");
              if (!entriesMap[rid]) entriesMap[rid] = [];
              entriesMap[rid].push(entry);
            }
          }
          const enriched = (preds ?? []).map((p: Record<string, unknown>) => ({
            ...enrichHorsePredictionForClient(
              p,
              entriesMap[p.race_id as string] ?? [],
            ),
            horse_results: resultsMap[p.race_id as string] ?? null,
          }));
          return json({ success: true, predictions: enriched });
        }
        case "horseracing.store_results": {
          const raceId = String(body.race_id ?? "");
          if (!raceId) return json({ error: "race_id required" }, 400);
          const pred = await admin.from("horse_predictions").select(
            "first_pick,second_pick,third_pick",
          ).eq("race_id", raceId).maybeSingle();
          const isCorrect = pred.data
            ? (pred.data.first_pick === body.first_place &&
              pred.data.second_pick === body.second_place &&
              pred.data.third_pick === body.third_place)
            : null;
          const { error: re } = await admin.from("horse_results").upsert({
            race_id: raceId,
            first_place: body.first_place,
            second_place: body.second_place,
            third_place: body.third_place,
            trifecta_paid: body.trifecta_paid ?? null,
            winner_odds: body.winner_odds ?? null,
            is_prediction_correct: isCorrect,
            payouts: body.payouts ?? {},
          }, { onConflict: "race_id" });
          await admin.from("horse_races").update({ status: "completed" }).eq(
            "id",
            raceId,
          );
          if (re) throw new Error(re.message);
          const evaluation = await evaluateHorsePredictionAccuracy(admin, {
            raceId,
            limit: 1,
          });
          return json({ success: true, is_correct: isCorrect, evaluation });
        }
        case "horseracing.accuracy": {
          const { data: stats } = await admin.from("horse_accuracy_stats")
            .select("*").maybeSingle();
          const { data: recentHits } = await admin.from("horse_results")
            .select(
              "race_id, is_prediction_correct, trifecta_paid, horse_races(race_name, race_date)",
            )
            .eq("is_prediction_correct", true).order("fetched_at", {
              ascending: false,
            }).limit(5);
          const { data: betTypeRows, error: betTypeError } = await admin.from(
            "horse_bet_type_accuracy",
          )
            .select("*");
          if (betTypeError) {
            console.warn(
              "horse_bet_type_accuracy unavailable",
              betTypeError.message,
            );
          }
          const rankedBetTypes = [...(betTypeRows ?? [])].sort((
            a: Record<string, unknown>,
            b: Record<string, unknown>,
          ) => Number(b.hit_rate_pct ?? 0) - Number(a.hit_rate_pct ?? 0));
          const { data: dailyLearning, error: dailyLearningError } = await admin
            .from("horse_learning_daily_accuracy")
            .select("*")
            .order("race_date", { ascending: false })
            .limit(14);
          if (dailyLearningError) {
            console.warn(
              "horse_learning_daily_accuracy unavailable",
              dailyLearningError.message,
            );
          }
          const { data: backfillStatus, error: backfillStatusError } =
            await admin.from("horse_learning_backfill_status")
              .select("*")
              .order("race_date", { ascending: false })
              .limit(21);
          if (backfillStatusError) {
            console.warn(
              "horse_learning_backfill_status unavailable",
              backfillStatusError.message,
            );
          }
          const activeChain = horseProviderChain(false);
          return json({
            success: true,
            stats: stats ?? {},
            recent_hits: recentHits ?? [],
            bet_type_accuracy: betTypeRows ?? [],
            learning: {
              best_low_risk_bet_type: rankedBetTypes[0]?.bet_type ?? null,
              best_purchase_decision:
                rankedBetTypes.find((row: Record<string, unknown>) =>
                  row.bet_type === "購入しない"
                ) ?? null,
              daily_accuracy: dailyLearning ?? [],
              backfill_status: backfillStatus ?? [],
              evaluated_bet_types: rankedBetTypes.length,
              feedback_loop:
                "レース結果取得後に horseracing.evaluate_accuracy が券種別と購入見送り判断を照合し、horseracing.backfill_learning_data で過去レースも低リスク基準予想として蓄積します。",
              backfill_action: "horseracing.backfill_learning_data",
              model_chain: activeChain.map((cfg) =>
                `${cfg.provider}:${cfg.model}`
              ),
              model_candidates: horseModelCandidates(),
              feature_set: [
                "血統",
                "前走",
                "馬体重",
                "騎手",
                "調教師",
                "厩舎",
                "タイム",
                "オッズ",
                "人気",
              ],
            },
          });
        }
        // ─── WBS (Work Breakdown Structure) actions (Win版#128) ─────────
        case "wbs.list_tasks": {
          // インスタンス + status でフィルタしてタスク一覧取得
          // body: { instance?: 'all'|'claude'|'codex'|'user'|'automation' (legacy lanes are still accepted),
          //        status?: 'pending'|'in_progress'|'completed'|'blocked',
          //        updated_since?: 'YYYY-MM-DDTHH:MM:SSZ' (ISO-8601),
          //        limit?: 50, offset?: 0 }
          const inst = body.instance as string | undefined;
          const status = body.status as string | undefined;
          const updatedSince = body.updated_since as string | undefined;
          const pagination = normalizeWbsListPagination(body);
          const taskSelect =
            "id, category, category_icon, category_order, title, description, instance, owner_instance, status, progress, start_date, end_date, planned_start_date, planned_end_date, milestone_code, priority, remaining_work, updated_at, github_issue_number, github_issue_url, github_issue_state, github_issue_labels, github_issue_synced_at";
          const pageSize = 1000;
          const allTasks: Array<Record<string, unknown>> = [];
          for (let offset = 0;; offset += pageSize) {
            let q = admin.from("wbs_tasks").select(taskSelect);
            if (status) q = q.eq("status", status);
            if (updatedSince) q = q.gte("updated_at", updatedSince);
            const { data, error } = await q
              .order("id", { ascending: true })
              .range(offset, offset + pageSize - 1);
            if (error) throw new Error(error.message);
            const rows = (data ?? []) as unknown as Array<
              Record<string, unknown>
            >;
            allTasks.push(...rows);
            if (rows.length < pageSize) break;
          }
          const dedupedTasks = dedupeWbsTasksById(allTasks);
          const filteredTasks = dedupedTasks.tasks.filter((task) =>
            wbsTaskMatchesInstanceFilter(
              task,
              inst ?? "all",
            )
          );
          const sortedTasks = filteredTasks.sort(compareWbsTasks);
          const pagedTasks = paginateWbsTasks(sortedTasks, pagination);
          // milestone 情報も同時取得
          const { data: milestones } = await admin.from("wbs_milestones")
            .select("code, name, target_date, goal_users, color");
          return json({
            success: true,
            tasks: pagedTasks,
            milestones: milestones ?? [],
            total: filteredTasks.length,
            limit: pagination.limit,
            offset: pagination.offset,
            returned: pagedTasks.length,
            duplicate_rows_removed: dedupedTasks.duplicateRowsRemoved,
          });
        }
        case "wbs.update_progress": {
          // body: { id, progress?: 0-100, status?: 'in_progress'|'completed'|'blocked',
          //        recovery_plan?: string, end_date?: 'YYYY-MM-DD' (リスケ用),
          //        planned_start_date?: 'YYYY-MM-DD', planned_end_date?: 'YYYY-MM-DD', note?: string }
          // Win版#131 part 10: 遅延時 recovery_plan 必須化
          // Win版#131 part 14 / T2-Win: defense-in-depth EF validation
          //   DB trigger `wbs_enforce_recovery_plan_trg` も同仕様を block
          const id = String(body.id ?? "");
          if (!id) return json({ error: "id required" }, 400);
          const update: Record<string, unknown> = {};
          if (body.progress !== undefined) {
            const p = Math.max(0, Math.min(100, Number(body.progress)));
            update.progress = p;
            if (p === 100 && !body.status) update.status = "completed";
          }
          if (body.status) update.status = String(body.status);
          if (body.recovery_plan !== undefined) {
            update.recovery_plan = String(body.recovery_plan);
            update.recovery_planned_at = new Date().toISOString();
          }
          if (body.end_date !== undefined) {
            update.end_date = String(body.end_date);
            const { data: cur } = await admin.from("wbs_tasks")
              .select("rescheduled_count").eq("id", id).single();
            update.rescheduled_count =
              ((cur?.rescheduled_count as number) ?? 0) + 1;
          }
          if (body.planned_start_date !== undefined) {
            update.planned_start_date = String(body.planned_start_date);
          }
          if (body.planned_end_date !== undefined) {
            update.planned_end_date = String(body.planned_end_date);
          }
          if (Object.keys(update).length === 0) {
            return json({
              error:
                "progress, status, recovery_plan, end_date, planned_start_date, or planned_end_date required",
            }, 400);
          }

          // Win版#131 part 14 / T2-Win:
          // 遅延判定 = COALESCE(planned_end_date, end_date) < CURRENT_DATE AND status != 'completed'
          // 遅延中 + recovery_plan 空のまま保存しようとしたら EF level で 400 block
          // (DB trigger も同仕様を CHECK 違反として投げるが UX として事前検出)
          const willStatus = (update.status ?? null) as string | null;
          if (willStatus !== "completed") {
            const { data: cur } = await admin.from("wbs_tasks")
              .select("planned_end_date, end_date, recovery_plan, status")
              .eq("id", id).maybeSingle();
            if (cur) {
              const deadlineRaw =
                (update.planned_end_date as string | undefined) ??
                  (cur.planned_end_date as string | null) ??
                  (update.end_date as string | undefined) ??
                  (cur.end_date as string | null);
              const recoveryPlanFinal =
                (update.recovery_plan as string | undefined) ??
                  (cur.recovery_plan as string | null) ??
                  "";
              const mergedStatus = willStatus ?? (cur.status as string | null);
              if (
                mergedStatus !== "completed" &&
                deadlineRaw &&
                new Date(deadlineRaw) <
                  new Date(new Date().toISOString().split("T")[0]) &&
                recoveryPlanFinal.trim().length === 0
              ) {
                return json({
                  error: "遅延タスクには recovery_plan 必須 (deadline=" +
                    deadlineRaw + ")",
                  hint:
                    'recovery_plan 例: "Win版に並行で UI 着手", "scope 縮小: 5社→3社"',
                  code: "RECOVERY_PLAN_REQUIRED",
                }, 400);
              }
            }
          }

          const { data, error } = await admin.from("wbs_tasks")
            .update(update).eq("id", id)
            .select(
              "id, title, status, progress, recovery_plan, end_date, planned_start_date, planned_end_date, rescheduled_count",
            )
            .single();
          if (error) {
            // DB trigger (wbs_enforce_recovery_plan_trg) が投げた場合は 400 に格上げ
            if (error.code === "23514" || /recovery_plan/.test(error.message)) {
              return json({
                error: error.message,
                code: "RECOVERY_PLAN_REQUIRED",
              }, 400);
            }
            throw new Error(error.message);
          }
          return json({ success: true, task: data });
        }
        case "wbs.delayed_tasks": {
          // Win版#131 part 10: 遅延中タスク一覧 (recovery_status: on_track / has_recovery_plan / delay_no_plan)
          const { data, error } = await admin.from("wbs_delayed_tasks_view")
            .select("*")
            .order("delay_days", { ascending: false });
          if (error) throw new Error(error.message);
          return json({ success: true, tasks: data ?? [] });
        }
        case "wbs.milestone_risk": {
          // Win版#131 part 14 / T9-Win: マイルストーン risk 一覧
          // (VSCode版 T9-VSCode で badge 表示に使用)
          // view `wbs_milestone_risk_view` 既存 (part 13 `20260420140000`)
          // defensive: view 未 deploy / 0 rows でも 200 返す
          try {
            const { data, error } = await admin
              .from("wbs_milestone_risk_view")
              .select("*");
            if (error) {
              return json({
                success: false,
                milestones: [],
                error: error.message,
              }, 200);
            }
            return json({ success: true, milestones: data ?? [] });
          } catch (e) {
            return json({
              success: false,
              milestones: [],
              error: String(e),
            }, 200);
          }
        }
        case "wbs.project_overview": {
          // Win版#131 part 20: プロジェクト全体概観 (AI 報告用)
          // Win版#131 part 23: defensive — view 未 deploy / 0 rows でも 200 返す
          try {
            const { data, error } = await admin
              .from("wbs_project_overview_view")
              .select("*").maybeSingle();
            if (error) {
              return json({
                success: false,
                overview: null,
                error: error.message,
              }, 200);
            }
            return json({ success: true, overview: data });
          } catch (e) {
            return json(
              { success: false, overview: null, error: String(e) },
              200,
            );
          }
        }
        case "wbs.auto_repair_dependencies": {
          // Win版#131 part 20: 依存関係スケジュール自動修復
          // Win版#131 part 23: defensive — RPC 未 deploy でも 200 返す
          try {
            const { data, error } = await admin.rpc(
              "wbs_auto_repair_dependencies",
            );
            if (error) {
              return json(
                { success: false, repairs: [], error: error.message },
                200,
              );
            }
            return json({ success: true, repairs: data ?? [] });
          } catch (e) {
            return json({ success: false, repairs: [], error: String(e) }, 200);
          }
        }
        case "wbs.ai_status_report": {
          // Win版#131 part 20: AI による WBS 概観レポート生成
          // Win版#131 part 23: defensive — view/RPC 失敗でも 200 返す
          // 1) overview view から health snapshot 取得
          // 2) ai-hub:provider.chat (groq) に prompt 投げる
          const currentDate = new Date().toISOString().split("T")[0];
          let fallbackSnapshot: {
            overview: Record<string, unknown>;
            delayed: Array<Record<string, unknown>>;
          } | null = null;
          const dateOnly = (value: unknown): string | null => {
            if (typeof value !== "string" || value.length < 10) return null;
            return value.slice(0, 10);
          };
          const delayDays = (deadline: string): number => {
            const todayMs = Date.parse(`${currentDate}T00:00:00Z`);
            const deadlineMs = Date.parse(`${deadline}T00:00:00Z`);
            if (Number.isNaN(todayMs) || Number.isNaN(deadlineMs)) return 0;
            return Math.max(0, Math.ceil((todayMs - deadlineMs) / 86400000));
          };
          const buildFallbackSnapshot = async () => {
            if (fallbackSnapshot !== null) return fallbackSnapshot;
            const { data: tasks, error: taskErr } = await admin
              .from("wbs_tasks")
              .select("title,status,progress,instance,end_date,recovery_plan");
            if (taskErr) throw new Error(taskErr.message);

            const rows = (tasks ?? []) as Array<Record<string, unknown>>;
            const byInstance: Record<string, number> = {};
            const activeInstances = new Set<string>();
            let doneTasks = 0;
            let inProgressTasks = 0;
            let pendingTasks = 0;
            let blockedTasks = 0;
            let overdueTasks = 0;
            let overdueNoRecovery = 0;
            let inProgressProgressTotal = 0;
            let inProgressProgressCount = 0;
            const delayedRows: Array<Record<string, unknown>> = [];

            for (const row of rows) {
              const status = String(row.status ?? "pending");
              const instance = String(row.instance ?? "unassigned");
              byInstance[instance] = (byInstance[instance] ?? 0) + 1;
              if (instance !== "all") activeInstances.add(instance);

              if (status === "completed") doneTasks++;
              if (status === "in_progress") {
                inProgressTasks++;
                const progress = Number(row.progress ?? 0);
                if (!Number.isNaN(progress)) {
                  inProgressProgressTotal += progress;
                  inProgressProgressCount++;
                }
              }
              if (status === "pending") pendingTasks++;
              if (status === "blocked") blockedTasks++;

              const deadline = dateOnly(row.end_date);
              const recoveryPlan = String(row.recovery_plan ?? "");
              const isOverdue = status !== "completed" &&
                deadline !== null &&
                deadline < currentDate;
              if (isOverdue) {
                overdueTasks++;
                if (recoveryPlan.trim().length === 0) overdueNoRecovery++;
                delayedRows.push({
                  title: row.title,
                  instance,
                  delay_days: delayDays(deadline),
                  recovery_plan: recoveryPlan,
                  recovery_status: recoveryPlan.trim().length === 0
                    ? "delay_no_plan"
                    : "has_recovery_plan",
                });
              }
            }

            delayedRows.sort((a, b) =>
              Number(b.delay_days ?? 0) - Number(a.delay_days ?? 0)
            );
            fallbackSnapshot = {
              overview: {
                total_tasks: rows.length,
                done_tasks: doneTasks,
                in_progress_tasks: inProgressTasks,
                pending_tasks: pendingTasks,
                blocked_tasks: blockedTasks,
                overdue_tasks: overdueTasks,
                overdue_no_recovery: overdueNoRecovery,
                active_instances: activeInstances.size,
                avg_in_progress_pct: inProgressProgressCount > 0
                  ? Math.round(
                    inProgressProgressTotal / inProgressProgressCount,
                  )
                  : null,
                by_instance: byInstance,
                source: "wbs_tasks_fallback",
              },
              delayed: delayedRows.slice(0, 10),
            };
            return fallbackSnapshot;
          };

          let overviewSource = "wbs_project_overview_view";
          let overviewError = "";
          const { data: overview, error: oErr } = await admin
            .from("wbs_project_overview_view").select("*").maybeSingle();
          let overviewForReport: Record<string, unknown> | null =
            (overview ?? null) as Record<string, unknown> | null;
          if (oErr) {
            overviewError = oErr.message;
            const fallback = await buildFallbackSnapshot();
            overviewForReport = fallback.overview;
            overviewSource = "wbs_tasks_fallback";
          }
          let delayedSource = "wbs_delayed_tasks_view";
          let delayedError = "";
          const { data: delayedViewRows, error: delayedErr } = await admin
            .from("wbs_delayed_tasks_view")
            .select(
              "title, instance, delay_days, recovery_plan, recovery_status",
            )
            .order("delay_days", { ascending: false })
            .limit(10);
          let delayed = (delayedViewRows ?? []) as Array<
            Record<string, unknown>
          >;
          if (delayedErr) {
            delayedError = delayedErr.message;
            const fallback = await buildFallbackSnapshot();
            delayed = fallback.delayed;
            delayedSource = "wbs_tasks_fallback";
          }
          let riskSource = "wbs_milestone_risk_view";
          let riskError = "";
          const { data: riskViewRows, error: risksErr } = await admin
            .from("wbs_milestone_risk_view").select("*");
          let risks = (riskViewRows ?? []) as Array<Record<string, unknown>>;
          if (risksErr) {
            riskError = risksErr.message;
            risks = [];
            riskSource = "unavailable";
          }
          const prompt = `自分株式会社 WBS プロジェクト健全性 snapshot:\n\n` +
            `データソース: overview=${overviewSource}, delayed=${delayedSource}, risk=${riskSource}\n` +
            `総タスク: ${overviewForReport?.total_tasks} (完了 ${overviewForReport?.done_tasks} / ` +
            `進行中 ${overviewForReport?.in_progress_tasks} / 未着手 ${overviewForReport?.pending_tasks} / ` +
            `ブロック ${overviewForReport?.blocked_tasks})\n` +
            `遅延: ${overviewForReport?.overdue_tasks} (うちリカバリー案未記入 ${overviewForReport?.overdue_no_recovery})\n` +
            `担当 instance 数: ${overviewForReport?.active_instances}\n` +
            `進行中タスクの平均進捗: ${overviewForReport?.avg_in_progress_pct}%\n` +
            `担当別: ${
              JSON.stringify(overviewForReport?.by_instance ?? {})
            }\n\n` +
            `遅延 TOP10:\n${
              (delayed ?? []).map((t: Record<string, unknown>, i: number) =>
                `${
                  i + 1
                }. [${t.instance}] ${t.title} - ${t.delay_days}日遅延 - ${t.recovery_status}`
              ).join("\n")
            }\n\n` +
            `マイルストーン risk:\n${
              (risks ?? []).map((m: Record<string, unknown>) =>
                `- ${m.code}: ${m.risk_status} (残${m.days_left}日 / 工数${m.remaining_hours}h / 利用可能${m.available_hours}h)`
              ).join("\n")
            }\n\n` +
            `この snapshot を 300 字以内で経営者向けに「健康状態 / 即対処 / 提案」の 3 セクションで報告してください。`;
          try {
            const aiResp = await fetch(
              `${SUPABASE_URL}/functions/v1/ai-hub`,
              {
                method: "POST",
                headers: {
                  Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({
                  action: "provider.chat",
                  provider: "groq",
                  message: prompt,
                }),
              },
            );
            const aiData = await aiResp.json() as Record<string, unknown>;
            return json({
              success: true,
              report: aiData.success === true
                ? String(aiData.text ?? "")
                : "AI レポート取得失敗 (Groq 未設定の可能性)",
              snapshot: {
                overview: overviewForReport,
                delayed,
                risks,
                sources: {
                  overview: overviewSource,
                  delayed: delayedSource,
                  risks: riskSource,
                },
                errors: {
                  overview: overviewError,
                  delayed: delayedError,
                  risks: riskError,
                },
              },
            });
          } catch (e) {
            return json({
              success: false,
              report: "AI レポート生成エラー",
              error: String(e),
              snapshot: {
                overview: overviewForReport,
                delayed,
                risks,
                sources: {
                  overview: overviewSource,
                  delayed: delayedSource,
                  risks: riskSource,
                },
                errors: {
                  overview: overviewError,
                  delayed: delayedError,
                  risks: riskError,
                },
              },
            }, 200);
          }
        }
        case "wbs.reschedule_realistic": {
          // Win版#132 part 157 (2026-05-06):
          // 全 open タスクの start_date / end_date を priority tier ベースで
          // 「実際に着手可能な日付」へ再配置する。
          //
          // body:
          //   dry_run?: boolean (default true)
          //   priority_offset_days?: { high: number, medium: number, low: number }
          //     (default {high: 7, medium: 30, low: 90})
          //   duration_days?: { high: number, medium: number, low: number }
          //     (default {high: 3, medium: 7, low: 14})
          //   parallel_capacity?: { high: number, medium: number, low: number }
          //     priority tier 内での並列着手可能数 (default {high: 4, medium: 8, low: 12})
          //     スケジュール stagger は floor(queue_index / parallel_capacity) 日 ずらして配置
          //
          // 対象: status != 'completed' AND github_issue_state != 'CLOSED'
          // skip: 上記完了系
          const dryRun = body.dry_run !== false; // default true

          // 全 open タスクを取得 (完了系 skip / Supabase 1000 row cap 回避にページネーション)
          const selectCols =
            "id, category, title, instance, owner_instance, priority, status, " +
            "description, start_date, end_date, github_issue_number, github_issue_url, " +
            "github_issue_state, category_order";
          const pageSize = 1000;
          const maxPages = 50;
          const all: Array<Record<string, unknown>> = [];
          for (let page = 0; page < maxPages; page += 1) {
            const from = page * pageSize;
            const to = from + pageSize - 1;
            const { data: pageRows, error: fetchErr } = await admin
              .from("wbs_tasks")
              .select(selectCols)
              .neq("status", "completed")
              .order("category_order", { ascending: true, nullsFirst: false })
              .order("id", { ascending: true })
              .range(from, to);
            if (fetchErr) {
              return json({ success: false, error: fetchErr.message }, 200);
            }
            const rows = (pageRows ?? []) as unknown as Array<
              Record<string, unknown>
            >;
            all.push(...rows);
            if (rows.length < pageSize) break;
            if (page === maxPages - 1) {
              return json(
                {
                  success: false,
                  error:
                    `wbs.reschedule_realistic scanned >= ${
                      pageSize * maxPages
                    } ` +
                    "rows; increase pagination cap.",
                },
                200,
              );
            }
          }
          const plan = buildWbsReschedulePlan(
            all,
            body as Record<string, unknown>,
            new Date(),
          );
          const updates = plan.updates;

          if (dryRun) {
            return json({
              success: true,
              dry_run: true,
              total_open: plan.totalOpen,
              total_skipped_completed: plan.totalSkippedCompleted,
              would_update: updates.length,
              by_priority: plan.byPriority,
              sample: plan.sample,
              today: plan.today,
              params: plan.params,
            });
          }

          // apply: Supabase JS は bulk update (行ごと異なる値) が無いので chunk
          // 並列化 (concurrency=10 で 1144 row ≒ 6 sec / curl 240s 内に収まる)
          let updated = 0;
          const errors: Array<{ id: string; error: string }> = [];
          const concurrency = 10;
          for (let i = 0; i < updates.length; i += concurrency) {
            const batch = updates.slice(i, i + concurrency);
            const results = await Promise.all(batch.map(async (u) => {
              const { error } = await admin
                .from("wbs_tasks")
                .update({
                  start_date: u.start_date,
                  end_date: u.end_date,
                  planned_start_date: u.start_date,
                  planned_end_date: u.end_date,
                })
                .eq("id", u.id);
              return { id: u.id, error: error?.message };
            }));
            for (const r of results) {
              if (r.error) {
                errors.push({ id: r.id, error: r.error });
              } else {
                updated += 1;
              }
            }
          }

          // monitoring_events に記録 (= scheduled task / GHA cron 監査用)
          try {
            await admin.from("monitoring_events").insert({
              event_type: "wbs.reschedule_realistic",
              severity: errors.length > 0 ? "warning" : "info",
              metadata: {
                total_open: plan.totalOpen,
                updated,
                errors: errors.length,
                by_priority: plan.byPriority,
                params: plan.params,
                today: plan.today,
              },
            });
          } catch (_) {
            // monitoring_events 未存在時は無視
          }

          return json({
            success: errors.length === 0,
            dry_run: false,
            total_open: plan.totalOpen,
            updated,
            errors_count: errors.length,
            errors: errors.slice(0, 10),
            by_priority: plan.byPriority,
            sample: plan.sample,
            today: plan.today,
            params: plan.params,
          });
        }
        case "wbs.bulk_update": {
          // body: { updates: [{id, progress?, status?}, ...] }
          const updates = (body.updates as Array<Record<string, unknown>>) ??
            [];
          if (updates.length === 0) {
            return json({ error: "updates required" }, 400);
          }
          const results: Array<Record<string, unknown>> = [];
          for (const u of updates) {
            const id = String(u.id ?? "");
            if (!id) {
              results.push({ error: "id required", input: u });
              continue;
            }
            const upd: Record<string, unknown> = {};
            if (u.progress !== undefined) {
              const p = Math.max(0, Math.min(100, Number(u.progress)));
              upd.progress = p;
              if (p === 100 && !u.status) upd.status = "completed";
            }
            if (u.status) upd.status = String(u.status);
            if (Object.keys(upd).length === 0) {
              results.push({ id, skipped: "no fields" });
              continue;
            }
            const { error } = await admin.from("wbs_tasks").update(upd).eq(
              "id",
              id,
            );
            results.push({ id, success: !error, error: error?.message });
          }
          const ok = results.filter((r) => r.success).length;
          return json({
            success: true,
            updated: ok,
            total: results.length,
            results,
          });
        }
        case "wbs.add_task": {
          // body: { category, title, instance, owner_instance?, description?,
          //        priority?, end_date?, planned_start_date?, planned_end_date?, milestone_code?,
          //        github_issue_number?, github_issue_url?, github_issue_state?,
          //        github_issue_labels? }
          // PS#6 S23 (2026-04-21): instance を required 化 (ALL leak 防止)
          // 2026-04-25: 'all' を廃止し、codex を正式な instance として追加。
          const category = String(body.category ?? "");
          const title = String(body.title ?? "");
          const instance = normalizeWbsInstance(body.instance);
          const validInstances = WBS_INSTANCE_VALUES;
          const validOwnerInstances = validInstances;
          if (!category || !title) {
            return json({ error: "category and title required" }, 400);
          }
          if (!instance || !validInstances.includes(instance)) {
            return json({
              error: `instance required (one of: ${validInstances.join(", ")})`,
            }, 400);
          }
          const ownerInstance = body.owner_instance !== undefined
            ? normalizeWbsInstance(body.owner_instance)
            : instance;
          if (!ownerInstance || !validOwnerInstances.includes(ownerInstance)) {
            return json({
              error: `owner_instance required (one of: ${
                validOwnerInstances.join(", ")
              })`,
            }, 400);
          }
          const labels = Array.isArray(body.github_issue_labels)
            ? body.github_issue_labels.map((label) => String(label)).filter((
              label,
            ) => label.length > 0)
            : String(body.github_issue_labels ?? "")
              .split(",")
              .map((label) => label.trim())
              .filter((label) => label.length > 0);
          const issueNumber = body.github_issue_number !== undefined
            ? Number(body.github_issue_number)
            : parseGithubIssueNumber(`${title} ${body.description ?? ""}`);
          const normalizedIssueNumber =
            issueNumber !== null && Number.isFinite(issueNumber) &&
              issueNumber > 0
              ? issueNumber
              : null;
          const issueLinkedNow = new Date();
          const issueLinkedStartDate = normalizedIssueNumber
            ? githubIssueStartDate(issueLinkedNow)
            : null;
          const issueLinkedEndDate = normalizedIssueNumber
            ? githubIssueDueDate(labels, issueLinkedNow, title)
            : null;
          const status = body.status !== undefined
            ? String(body.status)
            : "pending";
          const progress = body.progress !== undefined
            ? Math.max(0, Math.min(100, Number(body.progress)))
            : 0;
          const payload: Record<string, unknown> = {
            category,
            category_icon: String(body.category_icon ?? "📋"),
            category_order: Number(
              body.category_order ?? (normalizedIssueNumber ? 1 : 99),
            ),
            title,
            description: body.description ?? null,
            instance,
            owner_instance: ownerInstance,
            status,
            progress,
            priority: String(body.priority ?? "medium"),
            start_date: body.start_date ?? issueLinkedStartDate,
            end_date: body.end_date ?? issueLinkedEndDate,
            planned_start_date: body.planned_start_date ?? body.start_date ??
              issueLinkedStartDate,
            planned_end_date: body.planned_end_date ?? body.end_date ??
              issueLinkedEndDate,
            remaining_work: body.remaining_work ?? null,
            milestone_code: body.milestone_code ?? null,
          };
          if (normalizedIssueNumber) {
            payload.github_issue_number = normalizedIssueNumber;
            payload.github_issue_url = body.github_issue_url ??
              `https://github.com/kanta13jp1/my_web_app/issues/${normalizedIssueNumber}`;
            payload.github_issue_state = String(
              body.github_issue_state ?? "OPEN",
            ).toUpperCase();
            payload.github_issue_labels = labels;
            payload.github_issue_synced_at = new Date().toISOString();

            const { data: existing, error: findError } = await admin.from(
              "wbs_tasks",
            )
              .select("id")
              .eq("github_issue_number", normalizedIssueNumber)
              .order("created_at", { ascending: true })
              .limit(1);
            if (findError) throw new Error(findError.message);
            if ((existing ?? []).length > 0) {
              const id = String(existing![0].id);
              const { data, error } = await admin.from("wbs_tasks")
                .update(payload)
                .eq("id", id)
                .select(
                  "id, title, owner_instance, github_issue_number, github_issue_url",
                )
                .single();
              if (error) throw new Error(error.message);
              return json({
                success: true,
                task: data,
                updated_existing: true,
              });
            }
          }

          const { data, error } = await admin.from("wbs_tasks")
            .insert(payload)
            .select(
              "id, title, owner_instance, github_issue_number, github_issue_url",
            )
            .single();
          if (error) {
            if (error.code === "23505") {
              const { data: existing, error: findError } = await admin.from(
                "wbs_tasks",
              )
                .select("id")
                .eq("title", title)
                .eq("instance", instance)
                .limit(1);
              if (findError) throw new Error(findError.message);
              if ((existing ?? []).length > 0) {
                const id = String(existing![0].id);
                const { data: updated, error: updateError } = await admin.from(
                  "wbs_tasks",
                )
                  .update(payload)
                  .eq("id", id)
                  .select(
                    "id, title, owner_instance, github_issue_number, github_issue_url",
                  )
                  .single();
                if (updateError) throw new Error(updateError.message);
                return json({
                  success: true,
                  task: updated,
                  updated_existing: true,
                });
              }
            }
            throw new Error(error.message);
          }
          return json({ success: true, task: data, created: true });
        }
        case "wbs.sync_github_issues": {
          // body: { repo?: "owner/name", issues: GitHub issue JSON[] }
          // Scheduled source of truth:
          // - every GitHub Issue exists in WBS
          // - closed GitHub Issues complete the linked WBS task
          // - completed WBS tasks for open GitHub Issues are returned for Issue closing
          // - duplicate WBS rows for the same Issue are completed, keeping one canonical row
          const repo = String(body.repo ?? "kanta13jp1/my_web_app");
          const issueRecords = (Array.isArray(body.issues) ? body.issues : [])
            .map((issue) => asRecord(issue))
            .filter((issue): issue is Record<string, unknown> => issue !== null)
            .filter((issue) => githubIssueNumber(issue) !== null);
          if (issueRecords.length === 0) {
            return json({ error: "issues array required" }, 400);
          }

          const issuesByNumber = new Map<number, Record<string, unknown>>();
          for (const issue of issueRecords) {
            const issueNumber = githubIssueNumber(issue);
            if (!issueNumber) continue;
            issuesByNumber.set(issueNumber, issue);
          }
          const issueNumbers = [...issuesByNumber.keys()];
          const runGlobalRepairs = parseBooleanish(
            body.global_repairs ?? body.globalRepairs,
            false,
          );

          const now = new Date();
          const nowIso = now.toISOString();
          const taskSelect =
            "id, category, category_icon, category_order, title, description, instance, owner_instance, status, progress, start_date, end_date, planned_start_date, planned_end_date, milestone_code, priority, remaining_work, recovery_plan, ai_review_status, created_at, updated_at, github_issue_number, github_issue_url, github_issue_state, github_issue_labels, github_issue_synced_at";
          const allTasks = runGlobalRepairs
            ? await fetchAllWbsTasks(admin, taskSelect)
            : await fetchWbsTasksForGithubIssues(
              admin,
              taskSelect,
              issueNumbers,
            );
          const tasksByIssue = new Map<
            number,
            Array<Record<string, unknown>>
          >();
          for (const task of allTasks) {
            const issueNumber = githubIssueNumberFromTask(task);
            if (!issueNumber) continue;
            const tasks = tasksByIssue.get(issueNumber) ?? [];
            tasks.push(task);
            tasksByIssue.set(issueNumber, tasks);
          }

          const stats = {
            created: 0,
            updated: 0,
            completed_from_closed_issues: 0,
            duplicate_wbs_closed: 0,
            stale_wbs_repaired: 0,
            skipped: 0,
          };
          const issuesToClose: Array<Record<string, unknown>> = [];
          const closedIssueNumbers = new Set<number>();
          const duplicateWbsTasks: Array<Record<string, unknown>> = [];
          const repairedWbsTasks: Array<Record<string, unknown>> = [];
          const repairedWbsTaskIds = new Set<string>();
          const recordWbsRepair = (
            task: Record<string, unknown>,
            issueNumber: number,
            reasons: string[],
            context: string,
          ) => {
            const id = String(task.id ?? "");
            if (!id || reasons.length === 0 || repairedWbsTaskIds.has(id)) {
              return;
            }
            repairedWbsTaskIds.add(id);
            repairedWbsTasks.push({
              id,
              issue_number: issueNumber,
              reasons,
              context,
            });
            stats.stale_wbs_repaired += 1;
          };
          const completeDuplicateWbsTask = async ({
            duplicate,
            keptId,
            issueNumber,
            issueUrl,
            state,
            labels,
            canonicalTitle,
            note,
            reason,
            context,
          }: {
            duplicate: Record<string, unknown>;
            keptId: unknown;
            issueNumber: number;
            issueUrl: string;
            state: string;
            labels: string[];
            canonicalTitle: string;
            note: string;
            reason: string;
            context: string;
          }) => {
            const duplicateId = String(duplicate.id ?? "");
            if (!duplicateId) return;
            const duplicateRepairReasons = githubIssueTaskRepairReasons(
              duplicate,
              issueNumber,
              state,
              canonicalTitle,
            );
            duplicateRepairReasons.push(reason);
            const statusPatch = {
              status: "completed",
              progress: 100,
              ai_review_status: "manual_override",
              remaining_work: note,
            };
            const metadataPatch = {
              github_issue_number: issueNumber,
              github_issue_url: issueUrl ||
                String(duplicate.github_issue_url ?? "") ||
                null,
              github_issue_state: state,
              github_issue_labels: labels.length
                ? labels
                : (duplicate.github_issue_labels ?? []),
              github_issue_synced_at: nowIso,
            };
            const { error: statusError } = await admin.from("wbs_tasks")
              .update(statusPatch)
              .eq("id", duplicateId);
            if (statusError) throw new Error(statusError.message);
            const { error: metadataError } = await admin.from("wbs_tasks")
              .update(metadataPatch)
              .eq("id", duplicateId);
            if (metadataError) throw new Error(metadataError.message);
            Object.assign(duplicate, statusPatch, metadataPatch);
            recordWbsRepair(
              duplicate,
              issueNumber,
              duplicateRepairReasons,
              context,
            );
            duplicateWbsTasks.push({
              id: duplicateId,
              kept_id: keptId,
              issue_number: issueNumber,
              reason,
            });
            stats.duplicate_wbs_closed += 1;
          };
          const completeActiveIssueInstanceConflicts = async ({
            issueNumber,
            lane,
            keepId,
            issueUrl,
            state,
            labels,
            canonicalTitle,
          }: {
            issueNumber: number;
            lane: string;
            keepId: string;
            issueUrl: string;
            state: string;
            labels: string[];
            canonicalTitle: string;
          }) => {
            const { data: activeTasks, error: activeTasksError } = await admin
              .from("wbs_tasks")
              .select(taskSelect)
              .eq("github_issue_number", issueNumber)
              .eq("instance", lane)
              .neq("status", "completed")
              .order("created_at", { ascending: true, nullsFirst: true })
              .order("id", { ascending: true });
            if (activeTasksError) throw new Error(activeTasksError.message);
            for (
              const activeTask of (activeTasks ?? []) as Array<
                Record<string, unknown>
              >
            ) {
              const activeTaskId = String(activeTask.id ?? "");
              if (!activeTaskId || activeTaskId === keepId) continue;
              const inMemoryTask = allTasks.find((task) =>
                String(task.id ?? "") === activeTaskId
              ) ?? activeTask;
              await completeDuplicateWbsTask({
                duplicate: inMemoryTask,
                keptId: keepId || "pending-canonical",
                issueNumber,
                issueUrl,
                state,
                labels,
                canonicalTitle,
                note:
                  `Duplicate active WBS task for GitHub Issue #${issueNumber} and instance ${lane}; kept WBS task ${
                    keepId || "pending canonical"
                  } as canonical.`,
                reason: "duplicate_issue_instance",
                context: "issue_instance_preflight",
              });
            }
          };

          for (const [issueNumber, issue] of issuesByNumber.entries()) {
            try {
              const issueTitle = String(issue.title ?? `Issue #${issueNumber}`)
                .trim();
              const issueUrl = String(
                issue.url ?? issue.html_url ??
                  `https://github.com/${repo}/issues/${issueNumber}`,
              );
              const labels = githubIssueLabelNames(issue);
              const state = githubIssueState(issue);
              const isClosed = state === "CLOSED";
              const prioritizeAdditionalRequest = isAdditionalRequestIssue(
                issueTitle,
                labels,
              );
              const prioritizeIssueSchedule = !isClosed;
              const existing = tasksByIssue.get(issueNumber) ?? [];
              const keeper = pickGithubIssueWbsKeeper(existing);
              const lane = normalizeWbsInstance(
                keeper?.owner_instance ?? keeper?.instance ??
                  githubIssueOwnerInstance(labels),
              );
              const authorRecord = asRecord(issue.author) ??
                asRecord(issue.user);
              const author = authorRecord
                ? String(authorRecord.login ?? "")
                : "";
              const issueUpdatedAt = String(
                issue.updatedAt ?? issue.updated_at ?? "",
              );
              const description = [
                `GitHub Issue: ${issueUrl}`,
                author ? `Author: ${author}` : null,
                labels.length ? `Labels: ${labels.join(", ")}` : null,
                issueUpdatedAt ? `GitHub updated: ${issueUpdatedAt}` : null,
              ].filter((line) => line !== null).join(" / ");
              const currentCompleted = keeper
                ? isCompletedWbsTask(keeper)
                : false;
              const closureReady = keeper
                ? isGithubIssueClosureReadyWbsTask(keeper)
                : false;
              const nextStatus = isClosed
                ? "completed"
                : closureReady
                ? "completed"
                : wbsStatusForOpenGithubIssue(keeper);
              const nextProgress = isClosed
                ? 100
                : closureReady
                ? 100
                : wbsProgressForOpenGithubIssue(keeper);
              const syncedStartDate = prioritizeAdditionalRequest
                ? additionalRequestStartDate(now)
                : githubIssueStartDate(now);
              const syncedEndDate = githubIssueDueDate(labels, now, issueTitle);
              const pinnedSchedule =
                ASSET_MANAGEMENT_PINNED_ISSUE_SCHEDULE[issueNumber];
              const issueScheduleStartDate = pinnedSchedule?.start_date ??
                syncedStartDate;
              const issueScheduleEndDate = pinnedSchedule?.end_date ??
                syncedEndDate;
              const payload: Record<string, unknown> = {
                category: githubIssueCategory(labels),
                category_icon: githubIssueCategoryIcon(labels),
                category_order: 1,
                title: `[Issue #${issueNumber}] ${issueTitle}`,
                description,
                instance: lane,
                owner_instance: lane,
                status: nextStatus,
                progress: nextProgress,
                priority: githubIssuePriority(labels),
                start_date: prioritizeIssueSchedule
                  ? issueScheduleStartDate
                  : keeper?.start_date ?? syncedStartDate,
                end_date: prioritizeIssueSchedule
                  ? issueScheduleEndDate
                  : keeper?.end_date ?? syncedEndDate,
                planned_start_date: prioritizeIssueSchedule
                  ? issueScheduleStartDate
                  : keeper?.planned_start_date ?? keeper?.start_date ??
                    syncedStartDate,
                planned_end_date: prioritizeIssueSchedule
                  ? issueScheduleEndDate
                  : keeper?.planned_end_date ?? keeper?.end_date ??
                    syncedEndDate,
                remaining_work: isClosed
                  ? "GitHub Issue is closed; WBS mirrored as completed."
                  : (keeper?.remaining_work ??
                    "GitHub Issue source of truth. Sync keeps WBS and Issues aligned."),
                milestone_code: keeper?.milestone_code ?? null,
                github_issue_number: issueNumber,
                github_issue_url: issueUrl,
                github_issue_state: state,
                github_issue_labels: labels,
                github_issue_synced_at: nowIso,
              };
              const canonicalTitle = String(payload.title ?? "");
              const activeIssueInstanceRows = await admin.from("wbs_tasks")
                .select("id")
                .eq("github_issue_number", issueNumber)
                .eq("instance", lane)
                .neq("status", "completed")
                .order("created_at", { ascending: true, nullsFirst: true })
                .order("id", { ascending: true });
              if (activeIssueInstanceRows.error) {
                throw new Error(activeIssueInstanceRows.error.message);
              }
              const activeIssueInstanceKeepId = keeper?.id
                ? String(keeper.id)
                : String(activeIssueInstanceRows.data?.[0]?.id ?? "");
              await completeActiveIssueInstanceConflicts({
                issueNumber,
                lane,
                keepId: activeIssueInstanceKeepId,
                issueUrl,
                state,
                labels,
                canonicalTitle,
              });
              if (!isClosed && currentCompleted && !closureReady) {
                payload.remaining_work =
                  "GitHub Issue is still open; WBS completion must pass AI review before the issue can be closed.";
              }

              if (!keeper) {
                const { data: created, error: createError } = await admin.from(
                  "wbs_tasks",
                )
                  .insert(payload)
                  .select(taskSelect)
                  .single();
                if (createError) {
                  if (!isWbsGithubSyncUniqueConflict(createError)) {
                    throw new Error(createError.message);
                  }
                  const conflictQuery = isWbsIssueInstanceActiveUniqueConflict(
                      createError,
                    )
                    ? admin.from("wbs_tasks")
                      .select(taskSelect)
                      .eq("github_issue_number", issueNumber)
                      .eq("instance", lane)
                      .neq("status", "completed")
                      .order("created_at", { ascending: true })
                      .limit(1)
                    : admin.from("wbs_tasks")
                      .select(taskSelect)
                      .eq("title", String(payload.title ?? ""))
                      .eq("instance", lane)
                      .order("created_at", { ascending: true })
                      .limit(1);
                  const { data: conflictingTasks, error: conflictFindError } =
                    await conflictQuery;
                  if (conflictFindError) {
                    throw new Error(conflictFindError.message);
                  }
                  const conflictingTask = (conflictingTasks ?? [])[0] as
                    | Record<string, unknown>
                    | undefined;
                  if (!conflictingTask?.id) {
                    throw new Error(createError.message);
                  }
                  const conflictRepairReasons = githubIssueTaskRepairReasons(
                    conflictingTask,
                    issueNumber,
                    state,
                    canonicalTitle,
                  );

                  const { data: recovered, error: recoveryError } = await admin
                    .from("wbs_tasks")
                    .update(payload)
                    .eq("id", String(conflictingTask.id))
                    .select(taskSelect)
                    .single();
                  if (recoveryError) throw new Error(recoveryError.message);
                  const recoveredTask = recovered as Record<string, unknown>;
                  tasksByIssue.set(issueNumber, [recoveredTask]);
                  const existingIndex = allTasks.findIndex((task) =>
                    String(task.id ?? "") === String(recoveredTask.id ?? "")
                  );
                  if (existingIndex >= 0) {
                    allTasks[existingIndex] = recoveredTask;
                  } else {
                    allTasks.push(recoveredTask);
                  }
                  recordWbsRepair(
                    conflictingTask,
                    issueNumber,
                    conflictRepairReasons.length
                      ? conflictRepairReasons
                      : ["title_instance_conflict_recovered"],
                    "insert_conflict_recovery",
                  );
                  stats.updated += 1;
                  if (isClosed) stats.completed_from_closed_issues += 1;
                  continue;
                }
                const createdTask = created as Record<string, unknown>;
                tasksByIssue.set(issueNumber, [createdTask]);
                allTasks.push(createdTask);
                stats.created += 1;
                continue;
              }

              const activeDuplicateTasksBeforeUpdate = existing.filter((task) =>
                String(task.id ?? "") !== String(keeper.id ?? "") &&
                !isCompletedWbsTask(task)
              );
              for (const duplicate of activeDuplicateTasksBeforeUpdate) {
                await completeDuplicateWbsTask({
                  duplicate,
                  keptId: keeper.id,
                  issueNumber,
                  issueUrl,
                  state,
                  labels,
                  canonicalTitle,
                  note:
                    `Duplicate of WBS task ${keeper.id}; GitHub Issue #${issueNumber} is kept on one canonical WBS row.`,
                  reason: "duplicate_wbs_row",
                  context: "issue_duplicate_pre_update",
                });
              }

              const { data: updated, error: updateError } = await admin.from(
                "wbs_tasks",
              )
                .update(payload)
                .eq("id", String(keeper.id))
                .select(taskSelect)
                .single();
              let updatedKeeper = updated as Record<string, unknown> | null;
              const keeperRepairReasons = githubIssueTaskRepairReasons(
                keeper,
                issueNumber,
                state,
                canonicalTitle,
              );
              let conflictRepairTask: Record<string, unknown> | null = null;
              let conflictRepairReasons: string[] = [];
              if (updateError) {
                if (!isWbsGithubSyncUniqueConflict(updateError)) {
                  throw new Error(updateError.message);
                }
                const conflictQuery = isWbsIssueInstanceActiveUniqueConflict(
                    updateError,
                  )
                  ? admin.from("wbs_tasks")
                    .select(taskSelect)
                    .eq("github_issue_number", issueNumber)
                    .eq("instance", lane)
                    .neq("id", String(keeper.id))
                    .neq("status", "completed")
                    .order("created_at", { ascending: true })
                    .limit(1)
                  : admin.from("wbs_tasks")
                    .select(taskSelect)
                    .eq("title", String(payload.title ?? ""))
                    .eq("instance", lane)
                    .neq("id", String(keeper.id))
                    .order("created_at", { ascending: true })
                    .limit(1);
                const { data: conflictingTasks, error: conflictFindError } =
                  await conflictQuery;
                if (conflictFindError) {
                  throw new Error(conflictFindError.message);
                }
                const conflictingTask = (conflictingTasks ?? [])[0] as
                  | Record<string, unknown>
                  | undefined;
                if (!conflictingTask?.id) throw new Error(updateError.message);
                conflictRepairTask = conflictingTask;
                conflictRepairReasons = githubIssueTaskRepairReasons(
                  conflictingTask,
                  issueNumber,
                  state,
                  canonicalTitle,
                );

                const { data: recovered, error: recoveryError } = await admin
                  .from("wbs_tasks")
                  .update(payload)
                  .eq("id", String(conflictingTask.id))
                  .select(taskSelect)
                  .single();
                if (recoveryError) throw new Error(recoveryError.message);
                updatedKeeper = recovered as Record<string, unknown>;
              }
              if (!updatedKeeper?.id) {
                throw new Error(
                  "WBS task update did not return a canonical row.",
                );
              }
              stats.updated += 1;
              if (isClosed) stats.completed_from_closed_issues += 1;
              recordWbsRepair(
                keeper,
                issueNumber,
                keeperRepairReasons,
                "canonical_update",
              );
              if (conflictRepairTask) {
                recordWbsRepair(
                  conflictRepairTask,
                  issueNumber,
                  conflictRepairReasons.length
                    ? conflictRepairReasons
                    : ["title_instance_conflict_recovered"],
                  "update_conflict_recovery",
                );
              }
              if (
                !isClosed && closureReady &&
                !closedIssueNumbers.has(issueNumber)
              ) {
                issuesToClose.push({
                  number: issueNumber,
                  task_id: updatedKeeper.id,
                  reason: "linked WBS task is completed and AI review approved",
                });
                closedIssueNumbers.add(issueNumber);
              }

              const updatedIndex = allTasks.findIndex((task) =>
                String(task.id ?? "") === String(updatedKeeper.id ?? "")
              );
              if (updatedIndex >= 0) {
                allTasks[updatedIndex] = updatedKeeper;
              } else {
                allTasks.push(updatedKeeper);
              }
              const duplicateTasks = existing.filter((task) =>
                String(task.id ?? "") !== String(updatedKeeper.id ?? "") &&
                !isCompletedWbsTask(task)
              );
              for (const duplicate of duplicateTasks) {
                await completeDuplicateWbsTask({
                  duplicate,
                  keptId: updatedKeeper.id,
                  issueNumber,
                  issueUrl,
                  state,
                  labels,
                  canonicalTitle,
                  note:
                    `Duplicate of WBS task ${updatedKeeper.id}; GitHub Issue #${issueNumber} is kept on one canonical WBS row.`,
                  reason: "duplicate_wbs_row",
                  context: "issue_duplicate_update",
                });
              }
            } catch (error) {
              const message = error instanceof Error
                ? error.message
                : String(error);
              if (isWbsGithubSyncUniqueConflict({ message })) {
                console.warn(
                  `wbs.sync_github_issues skipped Issue #${issueNumber} after unique-conflict recovery failed: ${message}`,
                );
                stats.skipped += 1;
                continue;
              }
              throw error;
            }
          }

          for (const task of allTasks) {
            const issueNumber = githubIssueNumberFromTask(task);
            if (!issueNumber || closedIssueNumbers.has(issueNumber)) continue;
            const issue = issuesByNumber.get(issueNumber);
            if (!issue || githubIssueState(issue) !== "OPEN") continue;
            if (isGithubIssueClosureReadyWbsTask(task)) {
              issuesToClose.push({
                number: issueNumber,
                task_id: task.id,
                reason:
                  "WBS task was completed and AI review approved before scheduled sync",
              });
              closedIssueNumbers.add(issueNumber);
            }
          }

          const duplicateTaskIds = new Set(
            duplicateWbsTasks.map((task) => String(task.id ?? "")),
          );
          const titleGroups = new Map<string, Array<Record<string, unknown>>>();
          for (const task of allTasks) {
            const issueNumber = githubIssueNumberFromTask(task);
            if (!issueNumber || !issuesByNumber.has(issueNumber)) continue;
            const titleKey = normalizeDuplicateKey(task.title);
            if (!titleKey) continue;
            const key = `${issueNumber}:${titleKey}`;
            const tasks = titleGroups.get(key) ?? [];
            tasks.push(task);
            titleGroups.set(key, tasks);
          }
          for (const tasks of titleGroups.values()) {
            if (tasks.length < 2) continue;
            const sorted = [...tasks].sort((a, b) =>
              Number(isCompletedWbsTask(a)) - Number(isCompletedWbsTask(b)) ||
              compareOptionalDate(a.created_at, b.created_at) ||
              String(a.id ?? "").localeCompare(String(b.id ?? ""))
            );
            const keeper = sorted.find((task) => {
              const issueNumber = githubIssueNumberFromTask(task);
              const issue = issueNumber
                ? issuesByNumber.get(issueNumber)
                : null;
              return issue !== null && issue !== undefined &&
                githubIssueState(issue) === "OPEN" &&
                !isCompletedWbsTask(task);
            }) ?? sorted.find((task) => !isCompletedWbsTask(task)) ?? sorted[0];
            for (const duplicate of sorted) {
              const duplicateId = String(duplicate.id ?? "");
              if (
                !duplicateId || duplicateId === String(keeper.id ?? "") ||
                duplicateTaskIds.has(duplicateId)
              ) {
                continue;
              }
              const issueNumber = githubIssueNumberFromTask(duplicate);
              if (!issueNumber) continue;
              const issue = issueNumber
                ? issuesByNumber.get(issueNumber)
                : null;
              const issueUrl = issue
                ? String(
                  issue.url ?? issue.html_url ??
                    `https://github.com/${repo}/issues/${issueNumber}`,
                )
                : String(duplicate.github_issue_url ?? "");
              const labels = issue ? githubIssueLabelNames(issue) : [];
              const state = issue
                ? githubIssueState(issue)
                : (normalizedMirroredGithubIssueState(
                  duplicate.github_issue_state,
                ) || "OPEN");
              const canonicalTitle = issue
                ? `[Issue #${issueNumber}] ${
                  String(issue.title ?? `Issue #${issueNumber}`).trim()
                }`
                : String(keeper.title ?? duplicate.title ?? "");
              await completeDuplicateWbsTask({
                duplicate,
                issueNumber,
                issueUrl,
                state,
                labels,
                canonicalTitle,
                keptId: keeper.id,
                note:
                  `Duplicate GitHub-origin WBS title; kept WBS task ${keeper.id} as canonical.`,
                reason: "duplicate_title",
                context: "title_duplicate_update",
              });
              duplicateTaskIds.add(duplicateId);
            }
          }

          const genericTitleGroups = new Map<
            string,
            Array<Record<string, unknown>>
          >();
          for (const task of allTasks) {
            const taskId = String(task.id ?? "");
            if (!taskId || duplicateTaskIds.has(taskId)) continue;
            if (githubIssueNumberFromTask(task)) continue;
            const titleKey = normalizeDuplicateKey(task.title);
            if (!titleKey) continue;
            const tasks = genericTitleGroups.get(titleKey) ?? [];
            tasks.push(task);
            genericTitleGroups.set(titleKey, tasks);
          }
          for (const tasks of genericTitleGroups.values()) {
            if (tasks.length < 2) continue;
            const sorted = [...tasks].sort(compareWbsDuplicateTitleKeeper);
            const keeper = sorted.find((task) => !isCompletedWbsTask(task)) ??
              sorted[0];
            const keeperId = String(keeper.id ?? "");
            if (!keeperId) continue;
            for (const duplicate of sorted) {
              const duplicateId = String(duplicate.id ?? "");
              if (
                !duplicateId || duplicateId === keeperId ||
                duplicateTaskIds.has(duplicateId)
              ) {
                continue;
              }
              const duplicateNote =
                `Duplicate WBS title; kept WBS task ${keeperId} as canonical.`;
              const duplicateUpdate: Record<string, unknown> = {
                status: "completed",
                progress: 100,
                ai_review_status: "manual_override",
                remaining_work: duplicateNote,
              };
              if (!String(duplicate.recovery_plan ?? "").trim()) {
                duplicateUpdate.recovery_plan =
                  "Completed as a duplicate WBS title by wbs.sync_github_issues.";
              }
              if (!String(duplicate.recovery_planned_at ?? "").trim()) {
                duplicateUpdate.recovery_planned_at = nowIso;
              }
              const { error: duplicateError } = await admin.from("wbs_tasks")
                .update(duplicateUpdate)
                .eq("id", duplicateId);
              if (duplicateError) throw new Error(duplicateError.message);
              Object.assign(duplicate, duplicateUpdate);
              duplicateTaskIds.add(duplicateId);
              duplicateWbsTasks.push({
                id: duplicateId,
                kept_id: keeperId,
                reason: "duplicate_title_generic",
              });
              stats.duplicate_wbs_closed += 1;
            }
          }

          return json({
            success: true,
            repo,
            issue_count: issueRecords.length,
            wbs_task_scan_count: allTasks.length,
            global_repairs: runGlobalRepairs,
            ...stats,
            issues_to_close: issuesToClose,
            duplicate_wbs_tasks: duplicateWbsTasks,
            repaired_wbs_tasks: repairedWbsTasks,
          });
        }
        case "wbs.priority_for_instance": {
          // 指定インスタンスの優先タスク TOP 5 を返す (session-start-check 用)
          // 担当なしの場合は他 instance の滞留タスクを自担当へ救援 reassign する。
          // body: { instance: 'claude'|'codex'|'user'|'automation' (legacy lanes are still accepted),
          //         auto_reassign?: true, limit?: 5 }
          const rawInstance = String(body.instance ?? "").trim();
          if (!rawInstance) return json({ error: "instance required" }, 400);
          const rawInstanceLower = rawInstance.toLowerCase();
          if (
            !WBS_INSTANCE_VALUES.includes(rawInstanceLower) &&
            !WBS_ACTIVE_INSTANCE_VALUES.includes(rawInstanceLower) &&
            ![
              "windows",
              "ps",
              "copilot",
              "github-copilot",
              "claude-code",
              "claude-code-1",
              "automation",
              "auto",
            ].includes(rawInstanceLower)
          ) {
            return json({
              error: `instance must be one of: ${
                WBS_ACTIVE_INSTANCE_VALUES.join(", ")
              }`,
            }, 400);
          }
          const inst = normalizeWbsActiveInstance(rawInstance);
          const limit = Math.min(Math.max(Number(body.limit ?? 5), 1), 20);
          const autoReassign = parseBooleanish(
            body.auto_reassign ?? body.autoReassign,
            true,
          );
          const taskSelect =
            "id, category, category_order, title, status, progress, priority, end_date, planned_start_date, planned_end_date, updated_at, instance, owner_instance, recovery_plan, github_issue_number, github_issue_url, github_issue_state, github_issue_synced_at";
          const { data, error } = await admin.from("wbs_tasks")
            .select(taskSelect)
            .in("status", ["pending", "in_progress", "blocked"]);
          if (error) {
            throw new Error(error.message);
          }
          const ownTaskFilter = filterClosedGithubIssueWbsTasks(
            [...(data ?? [])].filter((task) =>
              wbsTaskMatchesInstanceFilter(
                task as Record<string, unknown>,
                rawInstance,
              )
            ) as Array<Record<string, unknown>>,
          );
          let topTasks = ownTaskFilter.activeTasks
            .sort(compareWbsTasks)
            .slice(0, limit);

          const { data: allOpen, error: allErr } = await admin.from("wbs_tasks")
            .select(taskSelect)
            .in("status", ["pending", "in_progress", "blocked"]);
          if (allErr) throw new Error(allErr.message);
          const now = new Date();
          const allTaskFilter = filterClosedGithubIssueWbsTasks(
            [...(allOpen ?? [])] as Array<Record<string, unknown>>,
          );
          const openTasks = allTaskFilter.activeTasks;
          const workload = buildWbsWorkload(openTasks, now);
          const rebalanceSuggestions = buildWbsRebalanceSuggestions(
            openTasks,
            now,
          );
          let reassignedTask: Record<string, unknown> | null = null;

          if (topTasks.length === 0 && autoReassign && inst !== "automation") {
            const candidate = pickWbsRescueCandidate(openTasks, inst, now);
            if (candidate) {
              const legacyTarget = normalizeWbsInstance(rawInstance);
              const update: Record<string, unknown> = {
                instance: legacyTarget,
                owner_instance: legacyTarget,
              };
              const needsRecoveryPlan = wbsOverdueDays(
                    candidate,
                    new Date(now.toISOString().slice(0, 10)),
                  ) > 0 &&
                String(candidate.recovery_plan ?? "").trim().length === 0;
              if (needsRecoveryPlan) {
                update.recovery_plan =
                  `担当作業が空いた ${inst} が救援として引き取り、次セッションで最小単位に分割して進める。`;
                update.recovery_planned_at = now.toISOString();
              }
              const { data: updated, error: updateErr } = await admin.from(
                "wbs_tasks",
              )
                .update(update)
                .eq("id", String(candidate.id))
                .select(taskSelect)
                .single();
              if (updateErr) throw new Error(updateErr.message);
              reassignedTask = updated as Record<string, unknown>;
              topTasks = [reassignedTask];
            }
          }

          // user タスク (手動操作が必要なタスク) も合わせて返す + Slack 通知
          const { data: userTasksRaw } = await admin.from("wbs_tasks")
            .select(
              "id, title, category, status, progress, priority, end_date, user_report_status, user_report_note, user_reported_at",
            )
            .or("instance.eq.user,owner_instance.eq.user")
            .in("status", ["pending", "in_progress", "blocked"])
            .order("end_date", { ascending: true, nullsFirst: false })
            .limit(10);
          const userTasks = userTasksRaw ?? [];

          // Slack 通知: user タスクがある場合 (セッション開始時)
          if (userTasks.length > 0 && body.notify_slack !== false) {
            const webhookUrl = Deno.env.get("SLACK_WEBHOOK_URL") ?? "";
            if (webhookUrl) {
              const icon = (p: string) =>
                p === "high" ? "🔴" : p === "low" ? "🟢" : "🟡";
              const lines = [
                `🙋 *[WBS] ユーザー手動タスク ${userTasks.length} 件* (要対応)`,
                "",
                ...userTasks.slice(0, 5).map((t, i) => {
                  const due = t.end_date ? ` | 期限 ${t.end_date}` : "";
                  const report = t.user_report_status
                    ? ` | 報告 ${t.user_report_status}`
                    : "";
                  return `${i + 1}. ${
                    icon(String(t.priority ?? "medium"))
                  } *${t.title}* — ${t.category}${due}${report}`;
                }),
                userTasks.length > 5 ? `…他 ${userTasks.length - 5} 件` : "",
                "",
                `🔗 https://my-web-app-b67f4.web.app/user-tasks`,
              ].filter((l) => l !== "");
              await fetch(webhookUrl, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ text: lines.join("\n"), mrkdwn: true }),
              }).catch(() => {/* fire-and-forget */});
            }
          }

          return json({
            success: true,
            instance: inst,
            top_tasks: topTasks,
            user_tasks: userTasks,
            user_tasks_count: userTasks.length,
            workload,
            rebalance_suggestions: rebalanceSuggestions,
            closed_issue_exclusions: {
              own_count: ownTaskFilter.excludedTasks.length,
              total_count: allTaskFilter.excludedTasks.length,
              own_tasks: ownTaskFilter.excludedTasks.slice(0, 10).map((
                task,
              ) => ({
                id: task.id,
                title: task.title,
                github_issue_number: githubIssueNumberFromTask(task),
                github_issue_url: task.github_issue_url ?? null,
                github_issue_state: task.github_issue_state ?? null,
                github_issue_synced_at: task.github_issue_synced_at ?? null,
              })),
            },
            auto_reassign: autoReassign,
            reassigned_task: reassignedTask,
          });
        }
        case "wbs.instance_workload": {
          // body: { instance?: string } 任意。全 instance の負荷と救援候補を返す。
          const taskSelect =
            "id, category, category_order, title, status, progress, priority, end_date, planned_start_date, planned_end_date, updated_at, instance, owner_instance, recovery_plan, github_issue_number, github_issue_url, github_issue_state, github_issue_synced_at";
          const { data, error } = await admin.from("wbs_tasks")
            .select(taskSelect)
            .in("status", ["pending", "in_progress", "blocked"]);
          if (error) throw new Error(error.message);
          const now = new Date();
          const taskFilter = filterClosedGithubIssueWbsTasks(
            [...(data ?? [])] as Array<Record<string, unknown>>,
          );
          const openTasks = taskFilter.activeTasks;
          return json({
            success: true,
            instance: body.instance
              ? normalizeWbsActiveInstance(body.instance)
              : null,
            workload: buildWbsWorkload(openTasks, now),
            rebalance_suggestions: buildWbsRebalanceSuggestions(openTasks, now),
            closed_issue_exclusions: {
              total_count: taskFilter.excludedTasks.length,
            },
          });
        }

        // ─── WBS Rebalance (Win版#132 part 17) ────────────────────────────
        // 自 instance に task が無い時、他 instance の滞留 task を suggest。
        // 設計: docs/WBS_REBALANCE.md
        case "wbs.rebalance_suggest": {
          const myInstance = String(body.my_instance ?? "");
          const limitN = Math.min(Number(body.limit ?? 5), 20);
          if (!myInstance) return json({ error: "my_instance required" }, 400);
          const myActiveInstance = normalizeWbsActiveInstance(myInstance);

          // 1. 自 instance の active task 数 fetch
          const { data: myActiveRaw, error: myActiveErr } = await admin.from(
            "wbs_tasks",
          )
            .select("id, instance, owner_instance")
            .in("status", ["pending", "in_progress", "blocked"]);
          if (myActiveErr) throw new Error(myActiveErr.message);
          const myActiveCount = [...(myActiveRaw ?? [])].filter((task) =>
            wbsTaskMatchesInstanceFilter(
              task as Record<string, unknown>,
              myActiveInstance,
            )
          ).length;

          // 2. 他 instance の active task 取得 (rebalance 候補)
          const { data: otherTasks, error } = await admin.from("wbs_tasks")
            .select(
              "id, category, title, instance, owner_instance, status, progress, priority, end_date, updated_at, last_rebalanced_at, github_issue_number, github_issue_url, github_issue_state, github_issue_synced_at",
            )
            .in("status", ["pending", "in_progress", "blocked"])
            .neq("priority", "completed")
            .limit(200);
          if (error) {
            throw new Error(error.message);
          }
          const otherTaskFilter = filterClosedGithubIssueWbsTasks(
            [...(otherTasks ?? [])].filter((task) =>
              !wbsTaskMatchesInstanceFilter(
                task as Record<string, unknown>,
                myActiveInstance,
              )
            ) as Array<Record<string, unknown>>,
          );

          // 3. 抑制ルール: PS 専任 / IPO 専決 / 期限直前は除外
          const NOW = Date.now();
          const HOUR = 3600 * 1000;
          const filtered = otherTaskFilter.activeTasks.filter((t) => {
            const cat = String(t.category ?? "");
            const title = String(t.title ?? "");
            // PS#1 専任 (Rule17)
            if (cat.startsWith("rule17-")) {
              return false;
            }
            // PS#2 専任 (T-1 dispatch)
            if (cat.startsWith("blog-") || title.includes("T-1")) {
              return false;
            }
            // PS#5 専任 (urgent on-call)
            if (t.priority === "high" && cat === "bug") {
              return false;
            }
            // IPO 専決 (CEO 固定)
            if (cat === "business-ipo") {
              return false;
            }
            // 期限直前 (1 日切ってる) は元担当継続
            if (t.end_date) {
              const dueMs = new Date(String(t.end_date)).getTime();
              if (dueMs - NOW < 24 * HOUR && t.priority === "high") {
                return false;
              }
            }
            // 7 日以内に rebalance 済 = loop 防止
            if (t.last_rebalanced_at) {
              const lastMs = new Date(String(t.last_rebalanced_at)).getTime();
              if (NOW - lastMs < 7 * 24 * HOUR) {
                return false;
              }
            }
            return true;
          });

          // 4. stale_score 計算
          const scored = filtered.map((t) => {
            let score = 0;
            const reasons: string[] = [];
            const dueMs = t.end_date
              ? new Date(String(t.end_date)).getTime()
              : null;
            const updMs = t.updated_at
              ? new Date(String(t.updated_at)).getTime()
              : null;

            // 期限ペナルティ
            if (dueMs !== null) {
              if (dueMs < NOW) {
                score += 50;
                reasons.push("期限超過");
              } else if (dueMs - NOW < 3 * 24 * HOUR) {
                score += 30;
                reasons.push("期限間近 (3 日以内)");
              } else if (dueMs - NOW < 7 * 24 * HOUR) {
                score += 15;
                reasons.push("期限間近 (7 日以内)");
              }
            }
            // 進捗停滞ペナルティ
            if (updMs !== null) {
              const hoursSince = (NOW - updMs) / HOUR;
              if (hoursSince > 168) {
                score += 30;
                reasons.push("7 日停滞");
              } else if (hoursSince > 72) {
                score += 20;
                reasons.push("3 日停滞");
              } else if (hoursSince > 24) {
                score += 10;
                reasons.push("1 日停滞");
              }
              // half-way 50-90% で 48h 以上 stuck
              const progress = Number(t.progress ?? 0);
              if (progress >= 50 && progress < 90 && hoursSince > 48) {
                score += 25;
                reasons.push("half-way stuck (50-90%)");
              }
            }
            // priority bonus
            if (t.priority === "high") {
              score += 20;
              reasons.push("priority=high");
            } else if (t.priority === "medium") {
              score += 10;
            }

            return {
              id: t.id,
              title: t.title,
              category: t.category,
              current_instance: t.instance,
              current_owner: t.owner_instance,
              progress: t.progress,
              priority: t.priority,
              end_date: t.end_date,
              updated_at: t.updated_at,
              stale_score: score,
              stale_reasons: reasons,
            };
          });

          // 5. score 高い順 sort + limit
          const candidates = scored
            .filter((s) =>
              s.stale_score > 0
            )
            .sort((a, b) => b.stale_score - a.stale_score)
            .slice(0, limitN);

          return json({
            success: true,
            my_instance: myInstance,
            my_active_instance: myActiveInstance,
            my_active_count: myActiveCount,
            candidates,
            closed_issue_exclusions: {
              total_count: otherTaskFilter.excludedTasks.length,
            },
          });
        }

        case "wbs.notify_user_tasks": {
          const sendSlack = body.send_slack !== false;
          const limitN = Math.min(Math.max(Number(body.limit ?? 10), 1), 50);
          const { data: userTasks, error: queryErr } = await admin
            .from("wbs_tasks")
            .select(
              "id, category, title, description, status, progress, priority, end_date, instance, owner_instance, user_report_status, user_report_note, user_reported_at",
            )
            .or("instance.eq.user,owner_instance.eq.user")
            .in("status", ["pending", "in_progress", "blocked"])
            .order("priority", { ascending: false })
            .order("end_date", { ascending: true, nullsFirst: false })
            .limit(limitN);
          if (queryErr) throw new Error(queryErr.message);

          const tasks = userTasks ?? [];
          const today = new Date();
          const urgentTasks = tasks.filter((t: Record<string, unknown>) => {
            if (!t.end_date) return false;
            const due = new Date(String(t.end_date));
            if (Number.isNaN(due.getTime())) return false;
            return Math.ceil((due.getTime() - today.getTime()) / 86_400_000) <=
              7;
          });

          let slackPosted = false;
          let slackError: string | null = null;
          if (sendSlack && tasks.length > 0) {
            const webhookUrl = Deno.env.get("SLACK_WEBHOOK_URL") ?? "";
            if (!webhookUrl) {
              slackError = "SLACK_WEBHOOK_URL not configured";
            } else {
              const priorityIcon = (p: string) =>
                p === "high" ? "🔴" : p === "low" ? "🟢" : "🟡";
              const lines = [
                `📋 *自分株式会社 WBS - ユーザー手動タスク*`,
                `合計 *${tasks.length}件* / 期限7日以内 *${urgentTasks.length}件*`,
                "",
                ...tasks.slice(0, 10).map(
                  (t: Record<string, unknown>, i: number) => {
                    const due = t.end_date ? ` / 期限 ${t.end_date}` : "";
                    const progress = ` / ${t.progress ?? 0}%`;
                    const report = t.user_report_status
                      ? ` / 報告 ${t.user_report_status}`
                      : "";
                    return `${i + 1}. ${
                      priorityIcon(String(t.priority ?? "medium"))
                    } *${t.title}* - ${t.category}${progress}${due}${report}`;
                  },
                ),
                tasks.length > 10 ? `...他 ${tasks.length - 10} 件` : "",
                "",
                `報告UI: https://my-web-app-b67f4.web.app/user-tasks`,
                `WBS: https://my-web-app-b67f4.web.app/project-gantt`,
              ].filter((line) => line !== "");
              try {
                const resp = await fetch(webhookUrl, {
                  method: "POST",
                  headers: { "Content-Type": "application/json" },
                  body: JSON.stringify({
                    text: lines.join("\n"),
                    username: "自分株式会社 WBS Bot",
                    icon_emoji: ":clipboard:",
                  }),
                });
                slackPosted = resp.ok;
                if (!resp.ok) slackError = `HTTP ${resp.status}`;
              } catch (err) {
                slackError = String(err);
              }
            }
          }

          return json({
            success: true,
            count: tasks.length,
            urgent_count: urgentTasks.length,
            user_tasks_count: tasks.length,
            slack_posted: slackPosted,
            slack_error: slackError,
            tasks,
          });
        }

        case "wbs.update_user_task_report": {
          const taskId = String(body.task_id ?? body.id ?? "").trim();
          if (!taskId) return json({ error: "task_id required" }, 400);
          const reportStatus = String(
            body.user_report_status ?? body.report_status ?? "in_progress",
          ).trim();
          const allowedReportStatuses = [
            "not_reported",
            "in_progress",
            "waiting",
            "completed",
            "blocked",
          ];
          if (!allowedReportStatuses.includes(reportStatus)) {
            return json({
              error: `invalid user_report_status: ${reportStatus}`,
            }, 400);
          }

          const nowIso = new Date().toISOString();
          const update: Record<string, unknown> = {
            user_report_status: reportStatus,
            user_report_note: String(body.note ?? body.user_report_note ?? "")
              .trim(),
            user_reported_at: nowIso,
            updated_at: nowIso,
          };
          if (body.progress !== undefined) {
            update.progress = Math.min(Math.max(Number(body.progress), 0), 100);
          }
          if (body.status !== undefined) {
            const status = String(body.status);
            if (
              !["pending", "in_progress", "blocked", "completed"].includes(
                status,
              )
            ) {
              return json({ error: `invalid status: ${status}` }, 400);
            }
            update.status = status;
          } else if (reportStatus === "completed") {
            update.status = "completed";
            update.progress = 100;
          } else if (reportStatus === "blocked") {
            update.status = "blocked";
          } else if (reportStatus === "in_progress") {
            update.status = "in_progress";
            if (update.progress === undefined) update.progress = 10;
          }

          const { data: updated, error: updateErr } = await admin
            .from("wbs_tasks")
            .update(update)
            .eq("id", taskId)
            .or("instance.eq.user,owner_instance.eq.user")
            .select(
              "id, title, category, status, progress, priority, end_date, user_report_status, user_report_note, user_reported_at",
            )
            .maybeSingle();
          if (updateErr) throw new Error(updateErr.message);
          if (!updated) return json({ error: "user task not found" }, 404);

          try {
            await admin.from("wbs_user_task_reports").insert({
              task_id: taskId,
              reporter: "user",
              progress: updated.progress ?? update.progress ?? null,
              status: updated.status ?? update.status ?? null,
              report_text: update.user_report_note || null,
              metadata: { source: "wbs.update_user_task_report" },
            });
          } catch (err) {
            console.warn(
              `wbs_user_task_reports insert skipped: ${String(err)}`,
            );
          }

          return json({ success: true, task: updated });
        }

        // ─── WBS User Task Report (Win版#132 part 19) ─────────────────────
        // user instance task の進捗報告 + NotebookLM 蓄積用 history 保存。
        // body: {task_id, progress?, status?, report_text?, blockers?, next_action?}
        case "wbs.user_task_report": {
          const taskId = String(body.task_id ?? "");
          if (!taskId) return json({ error: "task_id required" }, 400);

          // 1. task fetch + instance='user' guard
          const { data: task, error: fetchErr } = await admin
            .from("wbs_tasks")
            .select("id, instance, owner_instance, title, progress, status")
            .eq("id", taskId)
            .maybeSingle();
          if (fetchErr) throw new Error(fetchErr.message);
          if (!task) return json({ error: "task not found" }, 404);
          if (task.instance !== "user" && task.owner_instance !== "user") {
            return json({
              error: "instance != 'user' / report 不可",
              reason: "non_user_task",
            }, 403);
          }

          // 2. wbs_tasks 更新 (progress / status のみ更新可 / 他は不変)
          const updates: Record<string, unknown> = {
            updated_at: new Date().toISOString(),
          };
          const newProgress = body.progress !== undefined
            ? Number(body.progress)
            : null;
          const newStatus = body.status !== undefined
            ? String(body.status)
            : null;
          if (newProgress !== null && newProgress >= 0 && newProgress <= 100) {
            updates.progress = newProgress;
            // 100% で auto-completed
            if (newProgress === 100 && task.status !== "completed") {
              updates.status = "completed";
            }
          }
          if (
            newStatus &&
            ["pending", "in_progress", "completed", "blocked"].includes(
              newStatus,
            )
          ) {
            updates.status = newStatus;
          }
          updates.user_report_status = updates.status === "completed"
            ? "completed"
            : updates.status === "blocked"
            ? "blocked"
            : updates.status === "in_progress"
            ? "in_progress"
            : "in_progress";
          updates.user_report_note = body.report_text
            ? String(body.report_text).slice(0, 4000)
            : "";
          updates.user_reported_at = new Date().toISOString();
          if (Object.keys(updates).length > 1) {
            // updated_at 以外に変更ある場合のみ UPDATE
            await admin.from("wbs_tasks").update(updates).eq("id", taskId);
          }

          // 3. wbs_user_task_reports に履歴 INSERT
          const { data: report, error: insertErr } = await admin
            .from("wbs_user_task_reports")
            .insert({
              task_id: taskId,
              reporter: String(body.reporter ?? "user"),
              progress: newProgress ?? task.progress,
              status: (updates.status as string) ?? task.status,
              report_text: body.report_text
                ? String(body.report_text).slice(0, 4000)
                : null,
              blockers: body.blockers
                ? String(body.blockers).slice(0, 2000)
                : null,
              next_action: body.next_action
                ? String(body.next_action).slice(0, 1000)
                : null,
              metadata: body.metadata ?? {},
            })
            .select("id, created_at")
            .single();
          if (insertErr) throw new Error(insertErr.message);

          return json({
            success: true,
            task_id: taskId,
            task_title: task.title,
            new_progress: updates.progress ?? task.progress,
            new_status: updates.status ?? task.status,
            report_id: report?.id,
            reported_at: report?.created_at,
          });
        }

        // ─── WBS Export User Tasks (NotebookLM 用 markdown) ───────────────
        // user instance の active task + 直近 report を markdown で返却。
        // GHA cron が docs/user-tasks-snapshot.md として commit → NotebookLM source 候補。
        // body: {include_completed: bool=false, recent_reports: int=3}
        case "wbs.export_user_tasks_md": {
          const includeCompleted = body.include_completed === true;
          const recentReports = Math.min(Number(body.recent_reports ?? 3), 10);

          const statusFilter = includeCompleted
            ? ["pending", "in_progress", "completed", "blocked"]
            : ["pending", "in_progress", "blocked"];

          const { data: userTasks, error: fetchErr } = await admin
            .from("wbs_tasks")
            .select(
              "id, title, description, category, status, progress, end_date, priority, created_at, updated_at",
            )
            .or("instance.eq.user,owner_instance.eq.user")
            .in("status", statusFilter)
            .order("priority", { ascending: false })
            .order("end_date", { ascending: true, nullsFirst: false })
            .limit(100);
          if (fetchErr) throw new Error(fetchErr.message);

          const tasks = userTasks ?? [];
          const taskIds = tasks.map((t) => t.id);

          // 各 task の直近 report も fetch
          const reportsByTask = new Map<string, Record<string, unknown>[]>();
          if (taskIds.length > 0 && recentReports > 0) {
            const { data: allReports } = await admin
              .from("wbs_user_task_reports")
              .select(
                "task_id, progress, status, report_text, blockers, next_action, created_at",
              )
              .in("task_id", taskIds)
              .order("created_at", { ascending: false });
            for (const r of allReports ?? []) {
              const tid = r.task_id as string;
              const arr = reportsByTask.get(tid) ?? [];
              if (arr.length < recentReports) {
                arr.push(r);
                reportsByTask.set(tid, arr);
              }
            }
          }

          // markdown 生成
          const todayJst = new Date().toLocaleDateString("ja-JP", {
            timeZone: "Asia/Tokyo",
          });
          const lines = [
            `# 自分株式会社 — User Tasks Snapshot`,
            ``,
            `_Generated: ${todayJst} (JST)_`,
            `_Active user tasks: ${tasks.length}_`,
            ``,
            `## 概要`,
            ``,
            `このドキュメントは \`instance='user'\` (ユーザー手動操作タスク) の最新スナップショットです。`,
            `NotebookLM に source として追加し、「具体的手順」「詰まりポイントの解消手順」を分析させる前提で生成されています。`,
            ``,
            `カテゴリ別の手動タスクが含まれます: 法人登記 / 商標 / Notion 設定 / Slack Webhook / 監査法人選定 / 上場審査 等。`,
            ``,
            `## タスク一覧`,
            ``,
          ];

          for (const t of tasks) {
            const priIcon = t.priority === "high"
              ? "🔴"
              : t.priority === "low"
              ? "🟢"
              : "🟡";
            const stIcon = t.status === "completed"
              ? "✅"
              : t.status === "blocked"
              ? "🚧"
              : t.status === "in_progress"
              ? "🔧"
              : "⏳";
            lines.push(`### ${priIcon} ${stIcon} ${t.title}`);
            lines.push(``);
            lines.push(`- **id**: \`${t.id}\``);
            lines.push(`- **category**: ${t.category}`);
            lines.push(`- **progress**: ${t.progress ?? 0}%`);
            lines.push(`- **status**: ${t.status}`);
            lines.push(`- **priority**: ${t.priority ?? "medium"}`);
            if (t.end_date) lines.push(`- **deadline**: ${t.end_date}`);
            if (t.description) {
              lines.push(``);
              lines.push(`**説明**:`);
              lines.push(``);
              lines.push(`${t.description}`);
            }

            const reports = reportsByTask.get(t.id as string) ?? [];
            if (reports.length > 0) {
              lines.push(``);
              lines.push(`**直近 ${reports.length} 報告**:`);
              lines.push(``);
              for (const r of reports) {
                const ts = r.created_at
                  ? new Date(String(r.created_at)).toLocaleString("ja-JP", {
                    timeZone: "Asia/Tokyo",
                  })
                  : "-";
                lines.push(
                  `- _${ts}_ — progress=${
                    r.progress ?? "?"
                  }% status=${r.status}`,
                );
                if (r.report_text) lines.push(`  - 📝 ${r.report_text}`);
                if (r.blockers) lines.push(`  - 🚧 詰まり: ${r.blockers}`);
                if (r.next_action) lines.push(`  - ➡️ 次: ${r.next_action}`);
              }
            }
            lines.push(``);
            lines.push(`---`);
            lines.push(``);
          }

          lines.push(`## NotebookLM への質問例`);
          lines.push(``);
          lines.push(
            `- 「商標出願の具体的手順を弁理士選定から登録完了まで step-by-step で」`,
          );
          lines.push(
            `- 「\`blockers\` で「料金が不明」とあるタスクの最新相場を調査して」`,
          );
          lines.push(
            `- 「期限が 30 日以内のタスクを priority 順に並べて、それぞれの最短ルートを提示」`,
          );
          lines.push(
            `- 「進捗が 1 週間動いていないタスクの典型的な詰まりパターンを 3 つ抽出」`,
          );
          lines.push(``);

          const md = lines.join("\n");

          return json({
            success: true,
            task_count: tasks.length,
            report_count: Array.from(reportsByTask.values()).reduce(
              (acc, arr) => acc + arr.length,
              0,
            ),
            markdown: md,
            generated_at: new Date().toISOString(),
          });
        }

        // ─── WBS Claim Task (Win版#132 part 17) ───────────────────────────
        // 他 instance の task を自担当に変更。audit log + cooldown + guard。
        case "wbs.claim_task": {
          const taskId = String(body.task_id ?? "");
          const myInstance = String(body.my_instance ?? "");
          const reason = String(body.reason ?? "manual_review");
          const triggeredBy = String(body.triggered_by ?? "user");

          if (!taskId) return json({ error: "task_id required" }, 400);
          if (!myInstance) return json({ error: "my_instance required" }, 400);

          // 1. task fetch
          const { data: task, error: fetchErr } = await admin
            .from("wbs_tasks")
            .select(
              "id, instance, owner_instance, status, category, title, last_rebalanced_at",
            )
            .eq("id", taskId)
            .maybeSingle();
          if (fetchErr) throw new Error(fetchErr.message);
          if (!task) return json({ error: "task not found" }, 404);

          // 2. guard checks
          if (task.status === "completed") {
            return json({
              error: "completed task cannot be claimed",
              reason: "completed_protect",
            }, 409);
          }
          if (task.instance === myInstance) {
            return json({
              success: false,
              reason: "already_owner",
              task_id: taskId,
            });
          }
          if (task.category === "business-ipo") {
            return json({
              error: "business-ipo は CEO 専決 / claim 不可",
              reason: "ipo_protect",
            }, 403);
          }
          // 7 日 cooldown
          if (task.last_rebalanced_at) {
            const lastMs = new Date(task.last_rebalanced_at).getTime();
            if (Date.now() - lastMs < 7 * 24 * 3600 * 1000) {
              return json({
                error: "7 日以内に既に rebalance 済 / cooldown 中",
                reason: "cooldown",
              }, 429);
            }
          }

          // 3. update wbs_tasks
          const fromInstance = String(task.instance ?? "");
          const fromOwner = String(task.owner_instance ?? "");
          const nowIso = new Date().toISOString();

          const { error: updErr } = await admin
            .from("wbs_tasks")
            .update({
              instance: myInstance,
              owner_instance: myInstance,
              status: task.status === "blocked" || task.status === "pending"
                ? "in_progress"
                : task.status,
              last_rebalanced_at: nowIso,
              updated_at: nowIso,
            })
            .eq("id", taskId);
          if (updErr) {
            return json({ error: `update_failed: ${updErr.message}` }, 500);
          }

          // increment rebalance_count (best-effort)
          try {
            const { error: countErr } = await admin.rpc(
              "increment_wbs_rebalance_count",
              {
                p_task_id: taskId,
              },
            );
            if (countErr) {
              console.warn(
                `increment_wbs_rebalance_count failed: ${countErr.message}`,
              );
            }
          } catch (err) {
            console.warn(`increment_wbs_rebalance_count threw: ${String(err)}`);
          }

          // 4. audit log INSERT
          const { error: logErr } = await admin
            .from("wbs_rebalance_log")
            .insert({
              task_id: taskId,
              from_instance: fromInstance,
              to_instance: myInstance,
              from_owner: fromOwner,
              to_owner: myInstance,
              reason,
              triggered_by: triggeredBy,
              metadata: {
                task_title: task.title,
                task_category: task.category,
              },
            });
          if (logErr) {
            // log failure は non-fatal
            console.warn(`rebalance_log insert failed: ${logErr.message}`);
          }

          return json({
            success: true,
            task_id: taskId,
            from_instance: fromInstance,
            to_instance: myInstance,
            status: "in_progress",
          });
        }

        // ── WBS User Task AI Assist (UI向け) ───────────────────────────────
        // user instance task を、AIで「小タスク化」または「詳細手順化」する。
        // body: {task_id, mode: "breakdown" | "procedure"}
        case "wbs.user_task_ai_assist": {
          const taskId = String(body.task_id ?? body.id ?? "").trim();
          const requestedMode = String(body.mode ?? "breakdown").trim();
          const mode: WbsUserTaskAssistMode = requestedMode === "procedure"
            ? "procedure"
            : "breakdown";
          if (!taskId) return json({ error: "task_id required" }, 400);

          const { data: task, error: taskErr } = await admin
            .from("wbs_tasks")
            .select(
              "id, category, title, description, status, progress, priority, end_date, instance, owner_instance, user_report_status, user_report_note, user_reported_at, updated_at",
            )
            .eq("id", taskId)
            .maybeSingle();
          if (taskErr) throw new Error(taskErr.message);
          if (!task) return json({ error: "user task not found" }, 404);
          if (task.instance !== "user" && task.owner_instance !== "user") {
            return json({
              error: "instance != 'user' / AI assist 不可",
              reason: "non_user_task",
            }, 403);
          }

          const { data: reports, error: reportErr } = await admin
            .from("wbs_user_task_reports")
            .select(
              "status, progress, report_text, blockers, next_action, created_at",
            )
            .eq("task_id", taskId)
            .order("created_at", { ascending: false })
            .limit(1);
          if (reportErr) {
            console.warn(
              `wbs_user_task_reports latest fetch skipped: ${reportErr.message}`,
            );
          }

          const taskWithReport = {
            ...(task as Record<string, unknown>),
            latest_report: reports?.[0] ?? null,
          };
          const guidance = await generateWbsUserTaskAssist(
            taskWithReport,
            mode,
          );

          return json({
            success: true,
            mode,
            task_id: taskId,
            task_title: task.title,
            generated_by: guidance.generated_by ?? null,
            guidance,
          });
        }

        // ── WBS Get User Tasks (UI向け) ──────────────────────────────────────
        case "wbs.get_user_tasks": {
          // UI から呼ぶユーザータスク一覧 (pending/in_progress/blocked + completed 直近10件)
          const includeCompleted = body.include_completed === true;
          const limitN = Math.min(Number(body.limit ?? 50), 100);

          const statusFilter = includeCompleted
            ? ["pending", "in_progress", "blocked", "completed"]
            : ["pending", "in_progress", "blocked"];

          const { data: tasks, error: tasksErr } = await admin
            .from("wbs_tasks")
            .select(
              "id, category, title, description, status, progress, priority, end_date, instance, owner_instance, user_report_status, user_report_note, user_reported_at, updated_at",
            )
            .or("instance.eq.user,owner_instance.eq.user")
            .in("status", statusFilter)
            .order("priority", { ascending: false })
            .order("end_date", { ascending: true, nullsFirst: false })
            .limit(limitN);
          if (tasksErr) throw new Error(tasksErr.message);

          // 最新レポート取得
          const taskIds = (tasks ?? []).map((t: Record<string, unknown>) =>
            t.id
          );
          const latestReports: Record<string, Record<string, unknown>> = {};
          if (taskIds.length > 0) {
            const { data: reports, error: reportsErr } = await admin
              .from("wbs_user_task_reports")
              .select(
                "task_id, status, progress, report_text, next_action, blockers, created_at",
              )
              .in("task_id", taskIds)
              .order("created_at", { ascending: false })
              .limit(taskIds.length * 3);
            if (reportsErr) {
              console.warn(
                `wbs_user_task_reports fetch skipped: ${reportsErr.message}`,
              );
            } else {
              for (const r of reports ?? []) {
                const rep = r as Record<string, unknown>;
                if (!latestReports[String(rep.task_id)]) {
                  latestReports[String(rep.task_id)] = rep;
                }
              }
            }
          }

          const enriched = (tasks ?? []).map((t: Record<string, unknown>) => ({
            ...t,
            latest_report: latestReports[String(t.id)] ?? null,
          }));

          return json({
            success: true,
            count: enriched.length,
            tasks: enriched,
          });
        }

        // ── WBS Submit User Task Report ───────────────────────────────────────
        case "wbs.submit_user_task_report": {
          // UI からタスク進捗報告。user_task_reports に INSERT + wbs_tasks.progress を更新。
          const taskId = String(body.task_id ?? "");
          const status = String(body.status ?? "in_progress");
          const progress = Math.max(
            0,
            Math.min(100, Number(body.progress ?? 0)),
          );
          const reportText = String(body.report_text ?? "");
          const nextAction = String(body.next_action ?? "");
          const blockers = String(body.blockers ?? "");

          if (!taskId) return json({ error: "task_id required" }, 400);
          const validStatuses = [
            "not_started",
            "in_progress",
            "completed",
            "blocked",
            "delegated",
          ];
          if (!validStatuses.includes(status)) {
            return json({
              error: `status must be one of: ${validStatuses.join(", ")}`,
            }, 400);
          }

          // 1. Insert report
          const { data: report, error: insertErr } = await admin
            .from("user_task_reports")
            .insert({
              task_id: taskId,
              status,
              progress,
              report_text: reportText || null,
              next_action: nextAction || null,
              blockers: blockers || null,
              reported_by: "user",
            })
            .select("id")
            .single();
          if (insertErr) throw new Error(insertErr.message);

          // 2. Update wbs_tasks progress (and status if completed)
          const taskUpdate: Record<string, unknown> = {
            progress,
            updated_at: new Date().toISOString(),
          };
          if (status === "completed" && progress === 100) {
            taskUpdate.status = "completed";
          } else if (status === "in_progress") {
            taskUpdate.status = "in_progress";
          } else if (status === "blocked") {
            taskUpdate.status = "blocked";
          }
          await admin.from("wbs_tasks").update(taskUpdate).eq("id", taskId);

          // 3. Slack notification on completion
          if (status === "completed") {
            const { data: task } = await admin
              .from("wbs_tasks")
              .select("title, category")
              .eq("id", taskId)
              .maybeSingle();
            const webhookUrl = Deno.env.get("SLACK_WEBHOOK_URL") ?? "";
            if (webhookUrl && task) {
              try {
                await fetch(webhookUrl, {
                  method: "POST",
                  headers: { "Content-Type": "application/json" },
                  body: JSON.stringify({
                    text: `✅ *ユーザータスク完了*
[${task.category}] ${task.title}
${reportText ? `> ${reportText}` : ""}`,
                    username: "自分株式会社 WBS Bot",
                    icon_emoji: ":white_check_mark:",
                  }),
                });
              } catch (_) { /* non-fatal */ }
            }
          }

          return json({
            success: true,
            report_id: report?.id,
            task_id: taskId,
            status,
            progress,
          });
        }

        case "horseracing.register_race": {
          const { data: r, error: re } = await admin.from("horse_races").insert(
            {
              source: "manual",
              race_name: String(body.name ?? ""),
              race_date: String(
                body.date ?? new Date().toISOString().split("T")[0],
              ),
              venue: body.venue ?? null,
              course_type: body.race_type ?? "芝",
              grade: body.grade ?? "未勝利",
              distance: body.distance ?? null,
              status: "scheduled",
            },
          ).select("id").single();
          if (re) throw new Error(re.message);
          return json({ success: true, race_id: r?.id });
        }
        case "horseracing.stats": {
          const { data: stats } = await admin.from("horse_accuracy_stats")
            .select("*").maybeSingle();
          // Enrich with new learning metrics from the learning loop views
          const days = Math.max(1, Math.min(30, Number(body.days ?? 7)));
          const fromDate =
            new Date(Date.now() - (days - 1) * 86_400_000).toISOString().split(
              "T",
            )[0];
          const [dailyRes, betTypeRes, allBetTypeRes] = await Promise.all([
            admin.from("horse_learning_daily_accuracy")
              .select(
                "race_date,evaluated_predictions,evaluated_races,avg_learning_score,first_hit_rate_pct,skip_accuracy_pct,place_hit_rate_pct,wide_hit_rate_pct",
              )
              .gte("race_date", fromDate)
              .order("race_date", { ascending: false })
              .limit(days),
            admin.from("horse_bet_type_accuracy")
              .select("bet_type,total_predictions,hit_rate_pct")
              .neq("bet_type", "購入しない")
              .order("hit_rate_pct", { ascending: false })
              .limit(5),
            admin.from("horse_bet_type_accuracy")
              .select("bet_type,total_predictions,hits,hit_rate_pct")
              .in("bet_type", ["複勝", "購入しない", "単勝", "ワイド"]),
          ]);
          const dailyRows = dailyRes.data ?? [];
          const betTypeRows = betTypeRes.data ?? [];
          const allBtRows = (allBetTypeRes.data ?? []) as Array<
            Record<string, unknown>
          >;
          const latestDay = dailyRows[0] as Record<string, unknown> | undefined;
          // all-time aggregate from horse_bet_type_accuracy (複勝 total_predictions ≒ total evaluated)
          const placeBt = allBtRows.find((r) => r.bet_type === "複勝");
          const skipBt = allBtRows.find((r) => r.bet_type === "購入しない");
          const tansoBt = allBtRows.find((r) => r.bet_type === "単勝");
          const wideBt = allBtRows.find((r) => r.bet_type === "ワイド");
          return json({
            success: true,
            stats: {
              totalBets: stats?.total_predictions ?? 0,
              wins: stats?.correct_count ?? 0,
              winRate: stats?.hit_rate_pct ?? 0,
              totalPayout: stats?.total_payout ?? 0,
              maxPayout: stats?.max_payout ?? 0,
            },
            aggregate: {
              total_evaluated: Number(placeBt?.total_predictions ?? 0),
              place_hit_rate_pct: Number(placeBt?.hit_rate_pct ?? 0),
              tansho_hit_rate_pct: Number(tansoBt?.hit_rate_pct ?? 0),
              wide_hit_rate_pct: Number(wideBt?.hit_rate_pct ?? 0),
              skip_accuracy_pct: Number(skipBt?.hit_rate_pct ?? 0),
            },
            learning: {
              days_queried: days,
              latest_avg_learning_score: latestDay
                ? Number(latestDay.avg_learning_score ?? 0)
                : null,
              latest_skip_accuracy_pct: latestDay
                ? Number(latestDay.skip_accuracy_pct ?? 0)
                : null,
              latest_first_hit_rate_pct: latestDay
                ? Number(latestDay.first_hit_rate_pct ?? 0)
                : null,
              daily_trend: dailyRows,
              top_bet_types: betTypeRows,
            },
          });
        }
        default:
          return json(
            { error: `Unknown horseracing/wbs action: ${action}` },
            400,
          );
      }
    }

    if (action === "rss.fetch_latest") {
      const result = await fetchLatestNewsItems(body);
      const signalLimit = Math.max(
        1,
        Math.min(30, Number(body.signal_limit ?? 20) || 20),
      );
      return json({
        success: true,
        ...result,
        signals: rankNewsSignals(result.items, signalLimit),
        signal_action: "news.signal_rank",
      });
    }

    if (action === "news.signal_rank") {
      const limit = Math.max(1, Math.min(100, Number(body.limit ?? 30)));
      return json({
        success: true,
        signals: rankNewsSignals(body.items, limit),
      });
    }

    if (action === "market_intel.analyze") {
      return json(await buildMarketIntelReport(body));
    }

    // ── Authenticated CRUD operations ────────────────────────────────────────
    const userId = await getUserId(req);
    if (!userId) return json({ error: "Unauthorized" }, 401);

    switch (action) {
      case "mcp_file.connectors": {
        const connectors = connectorsAvailableToUser(
          configuredMcpFileConnectors(),
          userId,
        ).map(publicMcpFileConnector);
        return json({
          success: true,
          connectors: connectors.map((connector) => ({
            id: connector.id,
            name: connector.name,
            search_tool: connector.searchTool,
            can_attach_context: connector.canAttachContext,
          })),
        });
      }
      case "mcp_file.search": {
        const query = String(body.query ?? "").trim();
        if (!query) {
          throw new ToolsHubRequestError(400, "query is required");
        }
        const connector = mcpFileConnectorForUser(
          userId,
          body.connector_id,
        );
        const requestedLimit = Number(body.limit ?? 20);
        const limit = Number.isFinite(requestedLimit)
          ? Math.min(Math.max(Math.trunc(requestedLimit), 1), 20)
          : 20;
        let status = 502;
        try {
          const toolResult = await callExternalMcpTool(
            connector,
            connector.searchTool,
            { query: query.slice(0, 500), limit, user_id: userId },
          );
          const normalized = normalizeExternalFileSearchResults(
            toolResult,
            connector,
            userId,
          );
          status = 200;
          return json({
            success: true,
            connector: publicMcpFileConnector(connector),
            results: normalized.results.map((item) => ({
              id: item.id,
              title: item.title,
              uri: item.uri,
              mime_type: item.mimeType,
              snippet: item.snippet,
              modified_at: item.modifiedAt,
              score: item.score,
              connector_id: item.connectorId,
              connector_name: item.connectorName,
              context_eligible: item.contextEligible,
            })),
            denied_count: normalized.deniedCount,
            unsafe_count: normalized.unsafeCount,
          });
        } catch (error) {
          console.warn("MCP file search failed", {
            connector: connector.id,
            error: String(error),
          });
          throw new ToolsHubRequestError(502, "mcp_file_search_failed");
        } finally {
          await logMcpInvocation(
            externalMcpAuditContext(userId),
            `external.${connector.searchTool}`,
            { connector_id: connector.id, query: query.slice(0, 500), limit },
            status,
            req,
          );
        }
      }
      case "mcp_file.attach_context": {
        const connector = mcpFileConnectorForUser(
          userId,
          body.connector_id,
        );
        const expectedId = String(body.file_id ?? body.id ?? "").trim().slice(
          0,
          512,
        );
        const expectedUri = String(body.uri ?? "").trim().slice(0, 2048);
        if (!expectedId || !expectedUri) {
          throw new ToolsHubRequestError(400, "file_id and uri are required");
        }
        let status = 502;
        try {
          const toolResult = await callExternalMcpTool(
            connector,
            connector.fetchTool,
            {
              id: expectedId,
              file_id: expectedId,
              uri: expectedUri,
              user_id: userId,
            },
          );
          const file = normalizeExternalFileContent(
            toolResult,
            connector,
            userId,
            expectedId,
            expectedUri,
          );
          const item = await addItem(admin, MCP_FILE_CONTEXT_SOURCE, userId, {
            connector_id: connector.id,
            connector_name: connector.name,
            external_file_id: file.id,
            title: file.title,
            uri: file.uri,
            mime_type: file.mimeType,
            content: file.content,
            content_sha256: await sha256Hex(file.content),
            truncated: file.truncated,
            security_status: "allowed",
            attached_at: new Date().toISOString(),
          });
          status = 201;
          return json({
            success: true,
            context: {
              id: item.id,
              title: file.title,
              uri: file.uri,
              connector_id: connector.id,
              connector_name: connector.name,
              truncated: file.truncated,
            },
          }, 201);
        } catch (error) {
          const message = String(error);
          if (message.includes("external_file_access_denied")) {
            status = 403;
            throw new ToolsHubRequestError(403, "external_file_access_denied");
          }
          if (message.includes("external_file_not_found")) {
            status = 404;
            throw new ToolsHubRequestError(404, "external_file_not_found");
          }
          if (message.includes("external_file_content_unsafe")) {
            status = 422;
            throw new ToolsHubRequestError(422, "external_file_content_unsafe");
          }
          console.warn("MCP file context attach failed", {
            connector: connector.id,
            error: message,
          });
          throw new ToolsHubRequestError(502, "mcp_file_context_failed");
        } finally {
          await logMcpInvocation(
            externalMcpAuditContext(userId),
            `external.${connector.fetchTool}`,
            {
              connector_id: connector.id,
              file_id: expectedId,
              uri: expectedUri,
            },
            status,
            req,
          );
        }
      }
      // ── Bookmarks ───────────────────────────────────────────────────────────
      case "bookmark.list":
        return json({
          success: true,
          bookmarks: await listItems(admin, "bookmark", userId),
        });
      case "bookmark.add": {
        const item = await addItem(admin, "bookmark", userId, {
          url: body.url,
          title: body.title,
          tags: body.tags ?? [],
        });
        return json({ success: true, bookmark: item });
      }
      case "bookmark.delete": {
        await deleteItem(admin, "bookmark", userId, String(body.id ?? ""));
        return json({ success: true });
      }
      case "bookmark.mark_read": {
        const { data: bm } = await admin.from("hub_data")
          .select("metadata").eq("id", String(body.id ?? "")).eq(
            "source",
            "bookmark",
          ).maybeSingle();
        if (!bm) return json({ success: false, error: "not found" }, 404);
        const { error } = await admin.from("hub_data")
          .update({
            metadata: {
              ...(bm.metadata as Record<string, unknown>),
              read: true,
            },
          })
          .eq("id", String(body.id ?? "")).eq("source", "bookmark");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "bookmark.sync": {
        const bookmarks = body.bookmarks as unknown[] ?? [];
        for (const bm of bookmarks) {
          await addItem(
            admin,
            "bookmark_sync",
            userId,
            bm as Record<string, unknown>,
          );
        }
        return json({ success: true, synced: bookmarks.length });
      }

      // ── Quick Notes ─────────────────────────────────────────────────────────
      case "note.list":
        return json({
          success: true,
          notes: await listItems(admin, "quick_note", userId),
        });
      case "note.add": {
        const item = await addItem(admin, "quick_note", userId, {
          content: body.content,
          title: body.title ?? "",
          tags: body.tags ?? [],
        });
        return json({ success: true, note: item });
      }
      case "note.delete": {
        await deleteItem(admin, "quick_note", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Goals ───────────────────────────────────────────────────────────────
      case "goal.list":
        return json({
          success: true,
          goals: await listItems(admin, "goal", userId),
        });
      case "goal.add": {
        const item = await addItem(admin, "goal", userId, {
          title: body.title,
          description: body.description,
          deadline: body.deadline,
          timeframe: body.timeframe ?? "short",
          status: "active",
          milestones: body.milestones ?? [],
        });
        return json({ success: true, goal: item });
      }
      case "goal.update": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { ...body, user_id: userId } })
          .eq("id", String(body.id ?? "")).eq("source", "goal");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "goal.delete": {
        await deleteItem(admin, "goal", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Contacts ────────────────────────────────────────────────────────────
      case "career_kpi.list":
        return json({
          success: true,
          items: await listItems(admin, "career_monthly_kpi", userId, 100),
        });
      case "career_kpi.add": {
        const item = await addItem(
          admin,
          "career_monthly_kpi",
          userId,
          buildCareerKpiPayload(body),
        );
        return json({ success: true, item });
      }
      case "career_kpi.update": {
        const id = String(body.id ?? "").trim();
        if (!id) return json({ error: "Missing KPI id" }, 400);
        const { error } = await admin.from("hub_data")
          .update({
            metadata: { ...buildCareerKpiPayload(body), user_id: userId },
          })
          .eq("id", id)
          .eq("source", "career_monthly_kpi")
          .filter("metadata->>user_id", "eq", userId);
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "career_kpi.delete": {
        await deleteItem(
          admin,
          "career_monthly_kpi",
          userId,
          String(body.id ?? ""),
        );
        return json({ success: true });
      }
      case "contact.list":
        return json({
          success: true,
          contacts: await listItems(admin, "contact", userId),
        });
      case "contact.add": {
        const item = await addItem(admin, "contact", userId, {
          name: body.name,
          email: body.email,
          phone: body.phone,
          company: body.company,
          notes: body.notes,
        });
        return json({ success: true, contact: item });
      }
      case "contact.delete": {
        await deleteItem(admin, "contact", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Reading List ────────────────────────────────────────────────────────
      case "reading.list":
        return json({
          success: true,
          items: await listItems(admin, "reading", userId),
        });
      case "reading.add": {
        const item = await addItem(admin, "reading", userId, {
          url: body.url,
          title: body.title,
          author: body.author ?? "",
          status: "unread",
        });
        return json({ success: true, item });
      }
      case "reading.mark_read": {
        const { error } = await admin.from("hub_data")
          .update({
            metadata: {
              user_id: userId,
              status: "read",
              read_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id ?? "")).eq("source", "reading");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Tags ────────────────────────────────────────────────────────────────
      case "tag.list":
        return json({
          success: true,
          tags: await listItems(admin, "tag", userId),
        });
      case "tag.create": {
        const item = await addItem(admin, "tag", userId, {
          name: body.name,
          color: body.color,
        });
        return json({ success: true, tag: item });
      }
      case "tag.delete": {
        await deleteItem(admin, "tag", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Templates ───────────────────────────────────────────────────────────
      case "template.list":
        return json({
          success: true,
          templates: await listItems(admin, "template", userId),
        });
      case "template.create": {
        const item = await addItem(admin, "template", userId, {
          name: body.name,
          content: body.content,
          category: body.category,
        });
        return json({ success: true, template: item });
      }
      case "template.use": {
        const templates = await listItems(admin, "template", userId);
        const found = templates.find((t) =>
          (t.metadata as Record<string, unknown>)?.id === body.id
        );
        return json({
          success: true,
          content: (found?.metadata as Record<string, unknown>)?.content ?? "",
        });
      }
      case "template.delete": {
        await deleteItem(admin, "template", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Address Book ─────────────────────────────────────────────────────────
      case "address.list":
        return json({
          success: true,
          addresses: await listItems(admin, "address", userId),
        });
      case "address.add": {
        const item = await addItem(admin, "address", userId, {
          name: body.name,
          street: body.street,
          city: body.city,
          country: body.country,
          type: body.type ?? "home",
        });
        return json({ success: true, address: item });
      }
      case "address.delete": {
        await deleteItem(admin, "address", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Emergency Contacts ──────────────────────────────────────────────────
      case "emergency.list":
        return json({
          success: true,
          contacts: await listItems(admin, "emergency_contact", userId),
        });
      case "emergency.add": {
        const item = await addItem(admin, "emergency_contact", userId, {
          name: body.name,
          phone: body.phone,
          relation: body.relation,
        });
        return json({ success: true, contact: item });
      }
      case "emergency.delete": {
        await deleteItem(
          admin,
          "emergency_contact",
          userId,
          String(body.id ?? ""),
        );
        return json({ success: true });
      }

      // ── Habits ──────────────────────────────────────────────────────────────
      case "habit.list":
        return json({
          success: true,
          habits: await listItems(admin, "habit_definition", userId),
        });
      case "habit.create": {
        const item = await addItem(admin, "habit_definition", userId, {
          name: body.name,
          frequency: body.frequency ?? "daily",
          target: body.target ?? 1,
          points: body.points ?? 10,
        });
        return json({ success: true, habit: item });
      }
      case "habit.checkin": {
        const item = await addItem(admin, "habit_checkin", userId, {
          habit_id: body.habit_id,
          note: body.note ?? "",
          date: new Date().toISOString().slice(0, 10),
        });
        return json({ success: true, checkin: item });
      }
      case "habit.stats": {
        const checkins = await listItems(admin, "habit_checkin", userId, 200);
        return json({
          success: true,
          total_checkins: checkins.length,
          checkins: checkins.slice(0, 30),
        });
      }

      // ── Habit Gamification (merged from habit-gamification EF) ───────────────
      case "habit.gamification.profile": {
        const habits = await listItems(admin, "habit_definition", userId, 20);
        const checkins = await listItems(admin, "habit_checkin", userId, 200);
        const points = checkins.length * 10;
        const level = Math.floor(points / 100) + 1;
        return json({
          success: true,
          profile: {
            user_id: userId,
            points,
            level,
            habit_count: habits.length,
            checkin_count: checkins.length,
          },
        });
      }
      case "habit.gamification.badges": {
        const badges = await listItems(admin, "habit_badge", userId);
        return json({ success: true, badges });
      }
      case "habit.gamification.challenges": {
        const challenges = await listItems(
          admin,
          "habit_challenge",
          userId,
          10,
        );
        return json({ success: true, challenges });
      }
      case "habit.leaderboard":
      case "habit.gamification.leaderboard": {
        const { data, error: lbErr } = await admin.from("hub_data")
          .select("metadata")
          .eq("source", "habit_checkin")
          .order("created_at", { ascending: false })
          .limit(100);
        if (lbErr) throw new Error(lbErr.message);
        const counts: Record<string, number> = {};
        for (const row of data ?? []) {
          const uid = (row.metadata as Record<string, unknown>)
            ?.user_id as string;
          if (uid) counts[uid] = (counts[uid] ?? 0) + 1;
        }
        const leaderboard = Object.entries(counts)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 20)
          .map(([uid, count], i) => ({
            rank: i + 1,
            user_id: uid,
            checkins: count,
          }));
        return json({ success: true, leaderboard });
      }
      case "habit.gamification.award": {
        const badge = await addItem(admin, "habit_badge", userId, {
          badge_type: body.badge_type ?? "streak",
          title: body.title ?? "バッジ",
          earned_at: new Date().toISOString(),
        });
        return json({ success: true, badge });
      }

      // ── Pomodoro / Focus Timer ───────────────────────────────────────────────
      case "pomodoro.start": {
        const item = await addItem(admin, "pomodoro", userId, {
          duration_min: body.duration_min ?? 25,
          started_at: new Date().toISOString(),
          status: "running",
        });
        return json({ success: true, session: item });
      }
      case "pomodoro.complete": {
        const item = await addItem(admin, "pomodoro", userId, {
          duration_min: body.duration_min ?? 25,
          completed_at: new Date().toISOString(),
          status: "done",
        });
        return json({ success: true, session: item });
      }
      case "pomodoro.history":
        return json({
          success: true,
          sessions: await listItems(admin, "pomodoro", userId),
        });

      case "focus.start": {
        const item = await addItem(admin, "focus_timer", userId, {
          task: body.task_label ?? body.task ?? "",
          duration_minutes: body.duration_minutes ?? 25,
          started_at: new Date().toISOString(),
          status: "active",
        });
        return json({ success: true, session: item });
      }
      case "focus.complete": {
        const { data: fm } = await admin.from("hub_data")
          .select("metadata").eq("id", String(body.session_id ?? "")).eq(
            "source",
            "focus_timer",
          ).maybeSingle();
        if (fm) {
          await admin.from("hub_data")
            .update({
              metadata: {
                ...(fm.metadata as Record<string, unknown>),
                status: "completed",
                completed_at: new Date().toISOString(),
              },
            })
            .eq("id", String(body.session_id ?? "")).eq(
              "source",
              "focus_timer",
            );
        }
        return json({ success: true });
      }
      case "focus.cancel": {
        const { data: fc } = await admin.from("hub_data")
          .select("metadata").eq("id", String(body.session_id ?? "")).eq(
            "source",
            "focus_timer",
          ).maybeSingle();
        if (fc) {
          await admin.from("hub_data")
            .update({
              metadata: {
                ...(fc.metadata as Record<string, unknown>),
                status: "cancelled",
              },
            })
            .eq("id", String(body.session_id ?? "")).eq(
              "source",
              "focus_timer",
            );
        }
        return json({ success: true });
      }
      case "focus.stats": {
        const days = parseInt(String(body.days ?? "30"), 10);
        const since = new Date(Date.now() - days * 86400000).toISOString();
        const [focusItems, legacyPomodoroItems] = await Promise.all([
          listItems(admin, "focus_timer", userId, 200),
          listItems(admin, "pomodoro", userId, 200),
        ]);
        const normalizedFocus = focusItems.map(
          (item: Record<string, unknown>) => ({
            ...(item.metadata as Record<string, unknown>),
            id: item.id,
            created_at: item.created_at,
          }),
        );
        // 旧 `/pomodoro-timer` は `source=pomodoro` に保存していた。
        // 統合後の集中タイマーで過去実績を失わないよう、新形式へ読み替える。
        const normalizedLegacy = legacyPomodoroItems.map(
          (item: Record<string, unknown>) => {
            const metadata = (item.metadata ?? {}) as Record<string, unknown>;
            const completedAt = String(
              metadata.completed_at ?? item.created_at ?? "",
            );
            return {
              id: item.id,
              task_label: metadata.task_name ?? "ポモドーロ",
              duration_minutes: metadata.duration_minutes ??
                metadata.duration_min ?? 25,
              status: metadata.status === "done"
                ? "completed"
                : metadata.status ?? "completed",
              started_at: metadata.started_at ?? completedAt,
              completed_at: completedAt,
              created_at: item.created_at,
              legacy_source: "pomodoro",
            };
          },
        );
        const recent = [...normalizedFocus, ...normalizedLegacy]
          .filter((item: Record<string, unknown>) =>
            String(item.started_at ?? item.created_at ?? "") >= since
          )
          .sort((a: Record<string, unknown>, b: Record<string, unknown>) =>
            String(b.started_at ?? b.created_at ?? "").localeCompare(
              String(a.started_at ?? a.created_at ?? ""),
            )
          );
        const completed = recent.filter((i: Record<string, unknown>) =>
          i.status === "completed"
        );
        const totalMinutes = completed.reduce(
          (s: number, i: Record<string, unknown>) =>
            s + (Number(i.duration_minutes) || 25),
          0,
        );
        const completedDays = new Set(
          completed.map((item: Record<string, unknown>) =>
            String(
              item.completed_at ?? item.started_at ?? item.created_at ?? "",
            )
              .slice(0, 10)
          ),
        );
        const cursor = new Date();
        cursor.setUTCHours(0, 0, 0, 0);
        if (!completedDays.has(cursor.toISOString().slice(0, 10))) {
          cursor.setUTCDate(cursor.getUTCDate() - 1);
        }
        let streakDays = 0;
        while (completedDays.has(cursor.toISOString().slice(0, 10))) {
          streakDays += 1;
          cursor.setUTCDate(cursor.getUTCDate() - 1);
        }
        const focusScore = Math.min(100, Math.round(completed.length * 10));
        return json({
          success: true,
          sessions: recent,
          stats: {
            total_sessions: recent.length,
            completed_sessions: completed.length,
            total_minutes: totalMinutes,
            streak_days: streakDays,
            focus_score: focusScore,
          },
        });
      }

      // ── Clipboard History ────────────────────────────────────────────────────
      case "clipboard.list":
        return json({
          success: true,
          items: await listItems(admin, "clipboard", userId, 30),
        });
      case "clipboard.add": {
        const item = await addItem(admin, "clipboard", userId, {
          text: body.text,
          source: body.source ?? "manual",
        });
        return json({ success: true, item });
      }
      case "clipboard.clear": {
        await admin.from("hub_data")
          .delete().eq("source", "clipboard").filter(
            "metadata->>user_id",
            "eq",
            userId,
          );
        return json({ success: true });
      }

      // ── News / RSS ───────────────────────────────────────────────────────────
      case "rss.list_feeds":
        return json({
          success: true,
          feeds: await listItems(admin, "rss_feed", userId),
        });
      case "rss.add_feed": {
        const item = await addItem(admin, "rss_feed", userId, {
          url: body.url,
          title: body.title,
          category: body.category ?? "購読",
        });
        return json({ success: true, feed: item });
      }
      case "rss.fetch": {
        const feedUrl = String(body.url ?? "");
        const res = await fetch(feedUrl).catch(() => null);
        if (!res || !res.ok) return json({ error: "Cannot fetch feed" }, 502);
        const text = await res.text();
        return json({ success: true, content: text.slice(0, 5000) });
      }

      // ── Changelog ────────────────────────────────────────────────────────────
      case "changelog.list":
        return json({
          success: true,
          entries: await listItems(admin, "changelog", userId),
        });
      case "changelog.create": {
        const item = await addItem(admin, "changelog", userId, {
          version: body.version,
          title: body.title,
          changes: body.changes ?? [],
        });
        return json({ success: true, entry: item });
      }

      // ── Mindmap ──────────────────────────────────────────────────────────────
      case "mindmap.list":
        return json({
          success: true,
          maps: await listItems(admin, "mindmap", userId),
        });
      case "mindmap.create": {
        const item = await addItem(admin, "mindmap", userId, {
          title: body.title,
          nodes: body.nodes ?? [],
          edges: body.edges ?? [],
        });
        return json({ success: true, map: item });
      }
      case "mindmap.update": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { ...body, user_id: userId } })
          .eq("id", String(body.id ?? "")).eq("source", "mindmap");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "mindmap.delete": {
        await deleteItem(admin, "mindmap", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Polls & Forms ────────────────────────────────────────────────────────
      case "poll.list":
        return json({
          success: true,
          polls: await listItems(admin, "poll", userId, 100),
        });
      case "poll.create": {
        const item = await addItem(admin, "poll", userId, {
          question: body.question,
          options: body.options ?? [],
          votes: {},
        });
        return json({ success: true, poll: item });
      }
      case "poll.vote": {
        const polls = await listItems(admin, "poll", userId, 100);
        const poll = polls.find((p) => p.id === body.poll_id);
        if (!poll) return json({ error: "Poll not found" }, 404);
        const meta = poll.metadata as Record<string, unknown>;
        const votes = (meta.votes as Record<string, number>) ?? {};
        votes[String(body.option ?? "")] =
          (votes[String(body.option ?? "")] ?? 0) + 1;
        await admin.from("hub_data").update({ metadata: { ...meta, votes } })
          .eq("id", poll.id);
        return json({ success: true, votes });
      }
      case "form.list":
        return json({
          success: true,
          forms: await listItems(admin, "form", userId),
        });
      case "form.create": {
        const item = await addItem(admin, "form", userId, {
          title: body.title,
          fields: body.fields ?? [],
          responses: [],
        });
        return json({ success: true, form: item });
      }
      case "form.submit": {
        const item = await addItem(admin, "form_response", userId, {
          form_id: body.form_id,
          responses: body.responses ?? {},
        });
        return json({ success: true, response: item });
      }

      // ── Note Sharing ─────────────────────────────────────────────────────────
      case "note_share.create": {
        const shareId = crypto.randomUUID();
        const item = await addItem(admin, "note_share", userId, {
          share_id: shareId,
          content: body.content,
          title: body.title,
          expires_at: body.expires_at,
          is_public: body.is_public ?? true,
        });
        return json({ success: true, share_id: shareId, share: item });
      }
      case "note_share.get": {
        const { data } = await admin.from("hub_data")
          .select("metadata, created_at")
          .eq("source", "note_share")
          .filter("metadata->>share_id", "eq", String(body.share_id ?? ""))
          .single();
        return json({ success: true, note: data });
      }

      // ── Content Versioning ───────────────────────────────────────────────────
      case "version.list":
        return json({
          success: true,
          versions: await listItems(admin, "content_version", userId),
        });
      case "version.create": {
        const item = await addItem(admin, "content_version", userId, {
          document_id: body.document_id,
          content: body.content,
          version: body.version ?? 1,
        });
        return json({ success: true, version: item });
      }

      // ── Password Vault ───────────────────────────────────────────────────────
      case "vault.list":
        return json({
          success: true,
          entries: await listItems(admin, "password_vault", userId),
        });
      case "vault.add": {
        const item = await addItem(admin, "password_vault", userId, {
          site: body.site,
          username: body.username,
          encrypted_password: body.encrypted_password,
          notes: body.notes,
        });
        return json({ success: true, entry: item });
      }
      case "vault.delete": {
        await deleteItem(
          admin,
          "password_vault",
          userId,
          String(body.id ?? ""),
        );
        return json({ success: true });
      }

      // ── Virtual Pet ──────────────────────────────────────────────────────────
      case "pet.status": {
        const pets = await listItems(admin, "virtual_pet", userId, 1);
        if (pets.length === 0) {
          const pet = await addItem(admin, "virtual_pet", userId, {
            name: "たま",
            hunger: 50,
            happiness: 50,
            age_days: 0,
            last_fed: new Date().toISOString(),
          });
          return json({ success: true, pet });
        }
        return json({ success: true, pet: pets[0] });
      }
      case "pet.feed": {
        const { data: latest } = await admin.from("hub_data")
          .select("id, metadata").eq("source", "virtual_pet")
          .filter("metadata->>user_id", "eq", userId).order("created_at", {
            ascending: false,
          }).limit(1).single();
        if (!latest) return json({ error: "No pet found" }, 404);
        const meta = latest.metadata as Record<string, unknown>;
        await admin.from("hub_data").update({
          metadata: {
            ...meta,
            hunger: Math.min(100, Number(meta.hunger ?? 50) + 20),
            last_fed: new Date().toISOString(),
          },
        }).eq("id", latest.id);
        return json({ success: true, message: "Pet fed!" });
      }

      // ── Slack Integration ─────────────────────────────────────────────────────
      case "slack.post": {
        const settings = await getSaasApprovalSettings(admin, userId);
        const text = normalizeText(body.text);
        if (!text) return json({ error: "text is required" }, 400);

        const gateReason = externalSaasGateReason({
          connectorEnabled: settings.connector_enabled.slack,
          humanApprovalRequired: settings.approval_required,
          actorType: String(body.actor_type ?? "user"),
          requestedScopes: bodyRequestedScopes(body),
        });
        if (gateReason === "connector_disabled") {
          return json({
            success: false,
            error: "Slack connector is disabled for this team",
            connector: "slack",
          }, 403);
        }
        if (gateReason === "approval_required") {
          const payload: Record<string, unknown> = { text };
          if (body.channel) payload.channel = body.channel;
          if (body.username) payload.username = body.username;
          const approval = await createSaasApprovalRequest(admin, userId, {
            provider: "slack",
            actionKey: "slack.post",
            actionLabel: "Post Slack message",
            teamId: settings.team_id,
            preview: {
              text,
              channel: body.channel ?? "webhook default",
              username: body.username ?? null,
            },
            payload,
            requestedScopes: bodyRequestedScopes(body),
            sourceAction: "slack.post",
          });
          return json({
            success: false,
            approval_required: true,
            status: "pending",
            approval,
          }, 202);
        }

        const execution = await executeApprovedSaasAction(admin, userId, {
          provider: "slack",
          payload: { text, channel: body.channel, username: body.username },
        });
        return json(
          { success: execution.success, execution },
          execution.success ? 200 : 502,
        );
      }

      case "slack.search": {
        const token = Deno.env.get("SLACK_BOT_TOKEN") ?? "";
        if (!token) {
          return json({ error: "SLACK_BOT_TOKEN not configured" }, 503);
        }
        const query = String(body.query ?? "");
        if (!query) return json({ error: "query is required" }, 400);
        const count = Math.min(Number(body.count ?? 10), 50);
        const params = new URLSearchParams({ query, count: String(count) });
        const resp = await fetch(
          `https://slack.com/api/search.messages?${params}`,
          {
            headers: { Authorization: `Bearer ${token}` },
          },
        );
        if (!resp.ok) {
          return json({ error: `Slack API error: ${resp.status}` }, 502);
        }
        const data = await resp.json() as Record<string, unknown>;
        if (!data.ok) {
          return json({ error: String(data.error ?? "Slack API error") }, 502);
        }
        const msgData = data.messages as Record<string, unknown> | undefined;
        const matches =
          (msgData?.matches as Record<string, unknown>[] | undefined) ?? [];
        const messages = matches.map((m) => ({
          text: m.text,
          user: m.username,
          channel: (m.channel as Record<string, unknown> | undefined)?.name,
          ts: m.ts,
        }));
        return json({ success: true, total: msgData?.total ?? 0, messages });
      }
      case "slack.get_config": {
        const cfg = await latestHubMetadata(admin, "slack_config", userId);
        const settings = await getSaasApprovalSettings(admin, userId);
        const approvals = await listSaasApprovalRequests(admin, userId, 50);
        return json({
          success: true,
          webhook_url: cfg.webhook_url ?? "",
          triggers: cfg.triggers ?? [],
          team_id: cfg.team_id ?? settings.team_id,
          approval_required: settings.approval_required,
          connector_enabled: settings.connector_enabled,
          approvals,
        });
      }
      case "slack.configure": {
        const settings = await getSaasApprovalSettings(admin, userId);
        const connectorEnabled = normalizeSaasConnectorSettings(
          body.connector_enabled ?? settings.connector_enabled,
        );
        const teamId = normalizeText(body.team_id, settings.team_id);
        await upsertLatestHubMetadata(admin, "slack_config", userId, {
          webhook_url: body.webhook_url,
          triggers: body.triggers ?? [],
          team_id: teamId,
        });
        await upsertLatestHubMetadata(
          admin,
          SAAS_APPROVAL_SETTINGS_SOURCE,
          userId,
          {
            team_id: teamId,
            approval_required: true,
            connector_enabled: connectorEnabled,
          },
        );
        return json({
          success: true,
          team_id: teamId,
          approval_required: true,
          connector_enabled: connectorEnabled,
        });
      }
      case "slack.test": {
        const settings = await getSaasApprovalSettings(admin, userId);
        if (!settings.connector_enabled.slack) {
          return json({
            success: false,
            error: "Slack connector is disabled for this team",
            connector: "slack",
          }, 403);
        }
        const text = normalizeText(
          body.text,
          "Slack approval test from my_web_app",
        );
        const gateReason = externalSaasGateReason({
          connectorEnabled: true,
          humanApprovalRequired: settings.approval_required,
          actorType: String(body.actor_type ?? "user"),
          requestedScopes: ["send", "external_share"],
        });
        if (gateReason === "approval_required") {
          const approval = await createSaasApprovalRequest(admin, userId, {
            provider: "slack",
            actionKey: "slack.test",
            actionLabel: "Send Slack test notification",
            teamId: settings.team_id,
            preview: { text, channel: "webhook default" },
            payload: { text },
            requestedScopes: ["send", "external_share"],
            sourceAction: "slack.test",
          });
          return json({
            success: false,
            approval_required: true,
            status: "pending",
            message: "Slack test notification queued for approval",
            approval,
          }, 202);
        }

        const execution = await executeApprovedSaasAction(admin, userId, {
          provider: "slack",
          payload: { text },
        });
        return json({
          success: execution.success,
          message: execution.success
            ? "Slack test notification sent"
            : "Slack test notification failed",
          execution,
        }, execution.success ? 200 : 502);
      }
      case "saas_approval.list": {
        const settings = await getSaasApprovalSettings(admin, userId);
        const approvals = await listSaasApprovalRequests(
          admin,
          userId,
          Math.min(Number(body.limit ?? 50), 100),
        );
        return json({ success: true, settings, approvals });
      }

      case "saas_approval.create": {
        const provider = normalizeText(body.provider, "slack");
        const settings = await getSaasApprovalSettings(admin, userId);
        const connectorEnabled = normalizeSaasConnectorSettings(
          settings.connector_enabled,
        );
        if (provider === "slack" && !connectorEnabled.slack) {
          return json({
            success: false,
            error: "Slack connector is disabled for this team",
          }, 403);
        }
        const approval = await createSaasApprovalRequest(admin, userId, {
          provider,
          actionKey: normalizeText(body.action_key, `${provider}.custom`),
          actionLabel: normalizeText(body.action_label, "External SaaS action"),
          teamId: normalizeText(body.team_id, settings.team_id),
          preview: asRecord(body.preview) ?? {},
          payload: asRecord(body.payload) ?? {},
          requestedScopes: bodyRequestedScopes(body),
          sourceAction: normalizeText(
            body.source_action,
            "saas_approval.create",
          ),
        });
        return json({
          success: false,
          approval_required: true,
          status: "pending",
          approval,
        }, 202);
      }

      case "saas_approval.decide": {
        const requestId = normalizeText(body.request_id ?? body.id);
        if (!requestId) return json({ error: "request_id is required" }, 400);
        const decision = normalizeSaasApprovalDecision(body.decision);
        if (!decision) return json({ error: "invalid decision" }, 400);
        const approval = await decideSaasApprovalRequest(
          admin,
          userId,
          requestId,
          decision,
          {
            reviewNote: normalizeText(body.review_note),
            revisedPayload: asRecord(body.revised_payload),
            execute: body.execute === true,
            selectedOptionId: normalizeText(body.selected_option_id),
          },
        );
        if (!approval) {
          return json({ error: "approval request not found" }, 404);
        }
        return json({ success: true, approval });
      }

      case "legal.harvey.complete":
      case "legal-assistant.harvey.complete":
      case "legal-assistant.review": {
        const result = await callHarveyCompletion(body);
        if (!result.ok) {
          return json({
            success: false,
            provider: "harvey",
            error: result.error,
            details: result.details ?? null,
          }, result.status);
        }
        return json({
          success: true,
          ...result.data,
        });
      }

      default:
        return json({
          error: `Unknown action: ${action}`,
          available_actions: [
            "generate_password",
            "generate_qr",
            "convert_currency",
            "get_weather",
            "render_markdown",
            "translate",
            "bookmark.list",
            "bookmark.add",
            "bookmark.delete",
            "bookmark.sync",
            "note.list",
            "note.add",
            "note.delete",
            "goal.list",
            "goal.add",
            "goal.update",
            "goal.delete",
            "career_kpi.list",
            "career_kpi.add",
            "career_kpi.update",
            "career_kpi.delete",
            "contact.list",
            "contact.add",
            "contact.delete",
            "reading.list",
            "reading.add",
            "reading.mark_read",
            "tag.list",
            "tag.create",
            "tag.delete",
            "template.list",
            "template.create",
            "template.use",
            "template.delete",
            "address.list",
            "address.add",
            "address.delete",
            "emergency.list",
            "emergency.add",
            "emergency.delete",
            "habit.list",
            "habit.create",
            "habit.checkin",
            "habit.stats",
            "pomodoro.start",
            "pomodoro.complete",
            "pomodoro.history",
            "focus.start",
            "clipboard.list",
            "clipboard.add",
            "clipboard.clear",
            "rss.list_feeds",
            "rss.add_feed",
            "rss.fetch",
            "rss.fetch_latest",
            "news.signal_rank",
            "market_intel.analyze",
            "changelog.list",
            "changelog.create",
            "mindmap.list",
            "mindmap.create",
            "mindmap.update",
            "mindmap.delete",
            "poll.list",
            "poll.create",
            "poll.vote",
            "form.create",
            "form.submit",
            "note_share.create",
            "note_share.get",
            "version.list",
            "version.create",
            "vault.list",
            "vault.add",
            "vault.delete",
            "pet.status",
            "pet.feed",
            "horseracing.today",
            "horseracing.list_races",
            "horseracing.predict_all",
            "horseracing.predict_ensemble",
            "horseracing.consensus",
            "horseracing.provider_leaderboard",
            "horseracing.evaluate_accuracy",
            "horseracing.backfill_learning_data",
            "horseracing.predictions",
            "horseracing.store_results",
            "horseracing.accuracy",
            "horseracing.register_race",
            "horseracing.stats",
            "slack.post",
            "slack.search",
            "wbs.list_tasks",
            "wbs.add_task",
            "wbs.update_progress",
            "wbs.sync_github_issues",
            "wbs.notify_user_tasks",
            "wbs.update_user_task_report",
            "wbs.user_task_report",
            "wbs.export_user_tasks_md",
            "wbs.user_task_ai_assist",
            "wbs.get_user_tasks",
            "wbs.submit_user_task_report",
            "mcp.tools.list",
            "mcp.tool.call",
            "mcp.batch.call",
            "mcp.auth.register",
            "mcp.wbs.list",
            "mcp.feature_request.create",
            "mcp.user_tasks.list",
            "mcp.public_businesses.reference_list",
            "mcp.notes.list",
            "mcp.notes.create",
            "mcp_file.connectors",
            "mcp_file.search",
            "mcp_file.attach_context",
            "legal.harvey.complete",
            "legal-assistant.harvey.complete",
            "legal-assistant.review",
          ],
        }, 400);
    }
  } catch (e) {
    if (e instanceof ToolsHubRequestError) {
      return json({ error: e.message }, e.status);
    }
    return json({ error: String(e) }, 500);
  }
});
