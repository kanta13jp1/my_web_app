// core-hub — コアUI・メモ・通知・ユーザー管理統合EF
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  type CoreHubAction,
  coreHubActionDefinition,
} from "./action_registry.ts";
import {
  createSupabaseMemoReactionStore,
  handleMemoReactionAction,
  type MemoReactionAction,
} from "./memo_reactions.ts";
import {
  sendDiscordWebhook,
  wantsDiscordSecondary,
} from "./notification_channels.ts";
import {
  externalSaasGateReason,
  SAAS_APPROVAL_REQUEST_SOURCE,
} from "../_shared/saas_human_approval.ts";
import {
  type ExistingFeatureRequestIssue,
  type FeatureRequestCandidate,
  featureRequestCandidateKey,
  type FeatureRequestIssueLike,
  matchExistingFeatureRequestIssues,
} from "./feature_request_dedupe.ts";
import { buildFeedbackIssue } from "./feedback_issue.ts";
import {
  clampPublicMemoLimit,
  normalizePublicMemoSearchQuery,
  PUBLIC_MEMO_SEARCH_MAX_QUERY_LENGTH,
  PUBLIC_MEMO_SEARCH_MIN_QUERY_LENGTH,
  PUBLIC_MEMO_VIEW_COLUMNS,
  publicMemoToPayload,
  type PublicMemoViewRow,
  renderPublicMemoHtml,
  renderPublicMemoListHtml,
  renderPublicMemoListMarkdown,
  renderPublicMemoMarkdown,
  renderPublicMemoNotFoundHtml,
  resolvePublicMemoViewFormat,
  searchParamsToActionBody,
} from "./public_memo_view.ts";
import {
  BLOG_VIEW_COLUMNS,
  type BlogPostRow,
  blogPostToPayload,
  renderBlogHtml,
  renderBlogListHtml,
  renderBlogListMarkdown,
  renderBlogMarkdown,
  renderBlogNotFoundHtml,
} from "./blog_view.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

function json(data: unknown, status = 200): Response {
  const responseData = status >= 500 && data !== null &&
      typeof data === "object" && "error" in data
    ? { ...data, error: "Internal server error" }
    : data;
  return new Response(JSON.stringify(responseData), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function publicText(body: string, contentType: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": contentType,
      "Cache-Control": "public, max-age=300",
    },
  });
}

async function getUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return null;
  const c = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const {
    data: { user },
  } = await c.auth.getUser();
  return user?.id ?? null;
}

async function listItems(
  admin: SupabaseClient,
  source: string,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin
    .from("hub_data")
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
  const { data, error } = await admin
    .from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at")
    .single();
  if (error) throw new Error(error.message);
  return data;
}

async function deleteItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  id: string,
) {
  const { error } = await admin
    .from("hub_data")
    .delete()
    .eq("id", id)
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

function textValue(value: unknown, maxLength = 4000): string {
  return String(value ?? "").trim().slice(0, maxLength);
}

function coreRequestedScopes(body: Record<string, unknown>): string[] {
  if (Array.isArray(body.requested_scopes)) {
    return body.requested_scopes.map((item) => textValue(item, 80)).filter(
      Boolean,
    );
  }
  return ["send", "external_share"];
}

async function enqueueCoreSaasApprovalRequest(
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
  },
) {
  const now = new Date().toISOString();
  return await addItem(admin, SAAS_APPROVAL_REQUEST_SOURCE, userId, {
    provider: input.provider,
    action_key: input.actionKey,
    action_label: input.actionLabel,
    team_id: input.teamId || "default",
    status: "pending",
    preview: input.preview,
    payload: input.payload,
    requested_scopes: input.requestedScopes,
    source_action: input.actionKey,
    created_by: "core-hub",
    created_at: now,
    updated_at: now,
  });
}

function normalizePriority(value: unknown): "high" | "medium" | "low" {
  const priority = textValue(value, 20).toLowerCase();
  return priority === "high" || priority === "low" ? priority : "medium";
}

function estimateFeatureRequestHours(
  priority: "high" | "medium" | "low",
): number {
  if (priority === "high") return 6;
  if (priority === "low") return 2;
  return 4;
}

async function getUserEmail(
  admin: SupabaseClient,
  userId: string,
): Promise<string> {
  try {
    const { data } = await admin.auth.admin.getUserById(userId);
    return data.user?.email ?? "";
  } catch {
    return "";
  }
}

type FeatureRequestAttachmentAnalysis = {
  title: string;
  category: string;
  priority: "high" | "medium" | "low";
  observation: string;
  inferred_problem: string;
  proposal: string;
  reproduction_steps: string;
  acceptance_criteria: string;
  expected_outcome: string;
  confidence: "low" | "medium" | "high";
  generated_by: string;
};

function cleanJsonText(text: string): string {
  let cleaned = text.trim();
  if (cleaned.startsWith("```")) {
    cleaned = cleaned.split("\n").slice(1, -1).join("\n").trim();
  }
  const match = cleaned.match(/\{[\s\S]*\}/);
  return match?.[0] ?? cleaned;
}

function stringField(value: unknown, fallback = "", maxLength = 800): string {
  return textValue(value ?? fallback, maxLength);
}

function normalizeFeatureRequestAnalysis(
  raw: Record<string, unknown>,
  fallback: FeatureRequestAttachmentAnalysis,
): FeatureRequestAttachmentAnalysis {
  const priority = normalizePriority(raw.priority ?? fallback.priority);
  const confidenceRaw = textValue(raw.confidence ?? fallback.confidence, 20)
    .toLowerCase();
  const confidence = confidenceRaw === "high" || confidenceRaw === "low"
    ? confidenceRaw
    : "medium";
  return {
    title: stringField(raw.title, fallback.title, 120),
    category: stringField(raw.category, fallback.category, 80),
    priority,
    observation: stringField(raw.observation, fallback.observation, 1200),
    inferred_problem: stringField(
      raw.inferred_problem,
      fallback.inferred_problem,
      1200,
    ),
    proposal: stringField(raw.proposal, fallback.proposal, 1200),
    reproduction_steps: stringField(
      raw.reproduction_steps,
      fallback.reproduction_steps,
      1200,
    ),
    acceptance_criteria: stringField(
      raw.acceptance_criteria,
      fallback.acceptance_criteria,
      1200,
    ),
    expected_outcome: stringField(
      raw.expected_outcome,
      fallback.expected_outcome,
      800,
    ),
    confidence,
    generated_by: stringField(raw.generated_by, fallback.generated_by, 80),
  };
}

function fallbackFeatureRequestAttachmentAnalysis(params: {
  fileName: string;
  currentTitle: string;
  currentDescription: string;
  currentExpectedOutcome: string;
  category: string;
  priority: "high" | "medium" | "low";
  reason: string;
}): FeatureRequestAttachmentAnalysis {
  return {
    title: params.currentTitle || "スクリーンショットからの改善要望",
    category: params.category || "UX改善",
    priority: params.priority,
    observation:
      `添付画像 ${params.fileName} を受け取りました。${params.reason}`,
    inferred_problem: params.currentDescription ||
      "画像で示された画面や操作に、ユーザーが迷う・失敗する・手戻りする要因がある可能性があります。",
    proposal:
      "画面上の該当箇所を確認し、ユーザーが次に取るべき行動が分かるUI・導線・状態表示へ改善します。",
    reproduction_steps:
      "1. 対象画面を開く\n2. 添付画像と同じ状態にする\n3. 迷い・エラー・不足している案内を確認する",
    acceptance_criteria:
      "添付画像の課題がIssue本文に残り、WBSタスクとして改善作業へ引き継げること。",
    expected_outcome: params.currentExpectedOutcome ||
      "ユーザーが状況を説明しなくても、画像から改善要望を登録できるようになる。",
    confidence: "low",
    generated_by: "fallback",
  };
}

async function analyzeFeatureRequestAttachment(params: {
  fileName: string;
  mimeType: string;
  imageBase64: string;
  currentTitle: string;
  currentDescription: string;
  currentExpectedOutcome: string;
  category: string;
  priority: "high" | "medium" | "low";
}): Promise<FeatureRequestAttachmentAnalysis> {
  const fallback = fallbackFeatureRequestAttachmentAnalysis({
    fileName: params.fileName,
    currentTitle: params.currentTitle,
    currentDescription: params.currentDescription,
    currentExpectedOutcome: params.currentExpectedOutcome,
    category: params.category,
    priority: params.priority,
    reason: "Gemini画像診断が利用できない場合の暫定診断です。",
  });
  const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  if (!geminiKey) {
    return { ...fallback, generated_by: "fallback:no_gemini_key" };
  }

  const prompt =
    `あなたはWebアプリのUX改善担当です。添付画像を観察し、Home画面の追加要望フォームからGitHub Issue/WBSへ登録するための下書きをJSONだけで返してください。

前提:
- 画像はスクリーンショットまたは写真です。
- ユーザーが長文入力しなくても、課題・改善案・受入条件が伝わることを重視します。
- 推測は推測と分かるように書き、個人情報が写っている可能性がある場合は本文に転記しないでください。

現在入力されている文脈:
- title: ${params.currentTitle || "未入力"}
- description: ${params.currentDescription || "未入力"}
- expected_outcome: ${params.currentExpectedOutcome || "未入力"}
- category: ${params.category}
- priority: ${params.priority}

出力JSON:
{
  "title": "120字以内のIssueタイトル",
  "category": "機能追加|UX改善|不具合|AI連携|データ連携|その他",
  "priority": "high|medium|low",
  "observation": "画像から確認できる事実",
  "inferred_problem": "課題仮説",
  "proposal": "改善案",
  "reproduction_steps": "再現手順または確認手順",
  "acceptance_criteria": "受入条件",
  "expected_outcome": "期待する成果",
  "confidence": "low|medium|high"
}`;

  try {
    const resp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: prompt },
              {
                inlineData: {
                  mimeType: params.mimeType,
                  data: params.imageBase64,
                },
              },
            ],
          }],
          generationConfig: {
            temperature: 0.25,
            maxOutputTokens: 1200,
          },
        }),
      },
    );
    if (!resp.ok) {
      return {
        ...fallback,
        observation:
          `${fallback.observation} Gemini API status: ${resp.status}`,
        generated_by: "fallback:gemini_error",
      };
    }
    const data = await resp.json();
    const text = String(
      data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "",
    );
    const parsed = JSON.parse(cleanJsonText(text)) as Record<string, unknown>;
    return normalizeFeatureRequestAnalysis(parsed, {
      ...fallback,
      confidence: "medium",
      generated_by: "gemini-2.5-flash",
    });
  } catch (e) {
    return {
      ...fallback,
      observation: `${fallback.observation} AI診断例外: ${String(e)}`,
      generated_by: "fallback:exception",
    };
  }
}

type ProactiveFinding = {
  id: string;
  area: "WBS" | "GitHub Issues" | "Actions" | "Supabase";
  severity: "critical" | "warning" | "info";
  title: string;
  detail: string;
  next_action: string;
  user_task: boolean;
  count?: number;
};

function proactiveSeverityWeight(severity: ProactiveFinding["severity"]) {
  if (severity === "critical") return 0;
  if (severity === "warning") return 1;
  return 2;
}

function proactiveFallbackReview(input: {
  score: number;
  findings: ProactiveFinding[];
}): Record<string, unknown> {
  const topFindings = [...input.findings].sort((a, b) =>
    proactiveSeverityWeight(a.severity) - proactiveSeverityWeight(b.severity)
  ).slice(0, 3);
  const summary = input.score >= 90
    ? "自動化基盤は概ね安定しています。小さなズレを定期的に潰せば、このまま開発速度を維持できます。"
    : input.score >= 70
    ? "運用は継続可能ですが、放置すると手戻りになりやすい警告があります。上位の警告から順に処理してください。"
    : "WBS、Issue、定期実行のどこかに詰まりがあり、先に運用の詰まりを解消する必要があります。";
  return {
    summary,
    root_cause: topFindings.length === 0
      ? "重大な異常は検出されていません。"
      : "未完了タスク、同期状態、定期実行ログのズレが複合して運用負荷を上げています。",
    next_actions: topFindings.map((finding) => finding.next_action),
    generated_by: "heuristic",
  };
}

async function buildProactiveAiReview(input: {
  score: number;
  stats: Record<string, unknown>;
  findings: ProactiveFinding[];
}): Promise<Record<string, unknown>> {
  const fallback = proactiveFallbackReview(input);
  const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  if (!geminiKey || input.findings.length === 0) {
    return fallback;
  }

  const prompt =
    `あなたは自分株式会社のSRE兼プロダクトマネージャーです。以下の運用診断データから、ユーザーが次に取るべき対応を短く具体化してください。

ルール:
- 日本語で返す
- 重大度の高いものを優先する
- 「自動修正できるもの」と「ユーザー手動確認が必要なもの」を区別する
- JSONだけで返す

診断スコア: ${input.score}
統計: ${JSON.stringify(input.stats)}
検出事項: ${JSON.stringify(input.findings.slice(0, 10))}

出力JSON:
{
  "summary": "全体状況を1-2文で要約",
  "root_cause": "主な原因仮説",
  "next_actions": ["次の一手1", "次の一手2", "次の一手3"],
  "generated_by": "gemini-2.5-flash"
}`;

  try {
    const resp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 900,
          },
        }),
      },
    );
    if (!resp.ok) {
      return { ...fallback, generated_by: "heuristic:gemini_error" };
    }
    const data = await resp.json();
    const text = String(
      data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "",
    );
    const parsed = JSON.parse(cleanJsonText(text)) as Record<string, unknown>;
    const nextActions = Array.isArray(parsed.next_actions)
      ? parsed.next_actions.map((item) => textValue(item, 180)).filter(Boolean)
      : (fallback.next_actions as string[]);
    return {
      summary: stringField(parsed.summary, String(fallback.summary), 500),
      root_cause: stringField(
        parsed.root_cause,
        String(fallback.root_cause),
        500,
      ),
      next_actions: nextActions.slice(0, 4),
      generated_by: "gemini-2.5-flash",
    };
  } catch {
    return { ...fallback, generated_by: "heuristic:exception" };
  }
}

function buildFeatureRequestBody(params: {
  title: string;
  description: string;
  expectedOutcome: string;
  category: string;
  priority: string;
  /** 擬似匿名の user_id。公開 Issue にメール等の PII は載せない。 */
  userId: string;
  createdAt: string;
  attachmentFileName?: string;
  attachmentAnalysis?: FeatureRequestAttachmentAnalysis | null;
}): string {
  const lines = [
    "Home画面の追加要望フォームから登録されました。",
    "",
    "## 要望",
    params.description,
    "",
    "## 期待する成果",
    params.expectedOutcome || "未入力",
    "",
    "## 分類",
    `- カテゴリ: ${params.category}`,
    `- 優先度: ${params.priority}`,
    // PII 保護: メールは公開 Issue 本文に載せず、識別は擬似匿名の user_id のみ。
    `- 登録者ID: ${params.userId}`,
    `- 登録日時: ${params.createdAt}`,
  ];
  if (params.attachmentAnalysis) {
    lines.push(
      "",
      "## 添付画像AI診断",
      `- ファイル: ${params.attachmentFileName || "未保存"}`,
      `- 診断生成: ${params.attachmentAnalysis.generated_by}`,
      `- 信頼度: ${params.attachmentAnalysis.confidence}`,
      "",
      "### 観察事実",
      params.attachmentAnalysis.observation || "未入力",
      "",
      "### 課題仮説",
      params.attachmentAnalysis.inferred_problem || "未入力",
      "",
      "### 改善案",
      params.attachmentAnalysis.proposal || "未入力",
      "",
      "### 確認手順",
      params.attachmentAnalysis.reproduction_steps || "未入力",
      "",
      "### 受入条件",
      params.attachmentAnalysis.acceptance_criteria || "未入力",
    );
  }
  lines.push(
    "",
    "## WBS連携",
    "このIssue作成後、同じ内容をWBSのユーザー要望タスクとして登録します。",
  );
  return lines.join("\n");
}

async function createGitHubIssue(params: {
  title: string;
  body: string;
  /** タイトル接頭辞。既定は追加要望フォーム互換の "[追加要望] "。 */
  titlePrefix?: string;
  /** Issue ラベル。既定は追加要望フォーム互換。 */
  labels?: string[];
}): Promise<Record<string, unknown>> {
  const token = Deno.env.get("GITHUB_PAT") ??
    Deno.env.get("GITHUB_TOKEN") ??
    Deno.env.get("GH_TOKEN") ??
    "";
  const repo = Deno.env.get("GITHUB_REPO") ??
    Deno.env.get("GITHUB_REPOSITORY") ??
    "kanta13jp1/my_web_app";

  if (token === "" || repo === "") {
    return {
      skipped: true,
      error: "GitHub token or repository is not configured",
    };
  }

  const titlePrefix = params.titlePrefix ?? "[追加要望] ";
  const labels = params.labels ?? ["enhancement", "追加要望", "wbs"];

  const res = await fetch(`https://api.github.com/repos/${repo}/issues`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "jibun-app-feature-request-form",
    },
    body: JSON.stringify({
      title: `${titlePrefix}${params.title}`,
      body: params.body,
      labels,
    }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    return {
      skipped: false,
      status: res.status,
      error: String(
        (data as Record<string, unknown>).message ?? "GitHub API error",
      ),
    };
  }
  const issue = data as Record<string, unknown>;
  return {
    number: issue.number,
    html_url: issue.html_url,
    title: issue.title,
  };
}

function githubAuthHeaders(): Record<string, string> {
  const token = Deno.env.get("GITHUB_PAT") ??
    Deno.env.get("GITHUB_TOKEN") ??
    Deno.env.get("GH_TOKEN") ??
    "";
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "jibun-app-feature-request-dedupe",
  };
  if (token !== "") {
    headers.Authorization = `Bearer ${token}`;
  }
  return headers;
}

function githubRepoName(): string {
  return Deno.env.get("GITHUB_REPO") ??
    Deno.env.get("GITHUB_REPOSITORY") ??
    "kanta13jp1/my_web_app";
}

function normalizeFeatureRequestCandidates(
  rawCandidates: unknown,
  source: string,
): FeatureRequestCandidate[] {
  if (!Array.isArray(rawCandidates)) return [];
  return rawCandidates.slice(0, 20).map((raw, index) => {
    const item = raw && typeof raw === "object"
      ? raw as Record<string, unknown>
      : {};
    const title = textValue(item.title, 180);
    const description = textValue(item.description, 800);
    const key = textValue(item.key, 240) ||
      featureRequestCandidateKey(title, description, source) ||
      `candidate-${index}`;
    return { key, title, description };
  }).filter((candidate) => candidate.title.length >= 3);
}

async function fetchGitHubIssuesByTitle(
  repo: string,
  title: string,
): Promise<FeatureRequestIssueLike[]> {
  const query = `repo:${repo} is:issue in:title "${
    title.replaceAll('"', " ")
  }"`;
  const url = new URL("https://api.github.com/search/issues");
  url.searchParams.set("q", query);
  url.searchParams.set("per_page", "10");
  const response = await fetch(url, { headers: githubAuthHeaders() });
  if (!response.ok) return [];
  const data = await response.json().catch(() => ({}));
  const items = (data as { items?: unknown }).items;
  return Array.isArray(items) ? items as FeatureRequestIssueLike[] : [];
}

async function findGitHubFeatureRequestIssues(
  candidates: FeatureRequestCandidate[],
): Promise<ExistingFeatureRequestIssue[]> {
  const repo = githubRepoName();
  const matched = new Map<string, ExistingFeatureRequestIssue>();
  for (const candidate of candidates) {
    if (matched.has(candidate.key)) continue;
    const issues = await fetchGitHubIssuesByTitle(repo, candidate.title);
    const [match] = matchExistingFeatureRequestIssues(
      [candidate],
      issues,
      "github_title",
    );
    if (match) {
      matched.set(candidate.key, match);
    }
  }
  return [...matched.values()];
}

async function findLocalFeatureRequestIssues(
  admin: SupabaseClient,
  candidates: FeatureRequestCandidate[],
  source: string,
): Promise<ExistingFeatureRequestIssue[]> {
  const { data, error } = await admin
    .from("hub_data")
    .select("metadata, created_at")
    .eq("source", "feature_request_user")
    .filter("metadata->>source", "eq", source)
    .order("created_at", { ascending: false })
    .limit(200);
  if (error) return [];
  const issues: FeatureRequestIssueLike[] = [];
  for (const row of data ?? []) {
    const metadata = (row.metadata ?? {}) as Record<string, unknown>;
    const githubIssue = (metadata.github_issue ?? {}) as Record<
      string,
      unknown
    >;
    const title = textValue(metadata.title, 200) ||
      textValue(githubIssue.title, 200);
    if (!title) continue;
    issues.push({
      number: githubIssue.number,
      title,
      html_url: githubIssue.html_url,
      state: "registered",
    });
  }
  return matchExistingFeatureRequestIssues(
    candidates,
    issues,
    "local_record",
  );
}

async function findExistingFeatureRequestIssues(
  admin: SupabaseClient,
  candidates: FeatureRequestCandidate[],
  source: string,
): Promise<ExistingFeatureRequestIssue[]> {
  const byKey = new Map<string, ExistingFeatureRequestIssue>();
  for (
    const match of await findLocalFeatureRequestIssues(
      admin,
      candidates,
      source,
    )
  ) {
    byKey.set(match.key, match);
  }
  const unmatched = candidates.filter((candidate) => !byKey.has(candidate.key));
  for (const match of await findGitHubFeatureRequestIssues(unmatched)) {
    byKey.set(match.key, match);
  }
  return [...byKey.values()];
}

async function createFeatureRequestWbsTask(
  admin: SupabaseClient,
  params: {
    title: string;
    description: string;
    expectedOutcome: string;
    category: string;
    priority: "high" | "medium" | "low";
    issueUrl: string;
    issueNumber: number | null;
    attachmentAnalysis?: FeatureRequestAttachmentAnalysis | null;
  },
): Promise<Record<string, unknown>> {
  const issueLine = params.issueUrl
    ? `GitHub Issue: ${params.issueUrl}`
    : "GitHub Issue: creation skipped or failed. Check core-hub response metadata.";
  const descriptionLines = [
    params.description,
    "",
    `カテゴリ: ${params.category}`,
    `期待する成果: ${params.expectedOutcome || "未入力"}`,
    issueLine,
  ];
  if (params.attachmentAnalysis) {
    descriptionLines.push(
      "",
      "添付画像AI診断:",
      `観察: ${params.attachmentAnalysis.observation}`,
      `改善案: ${params.attachmentAnalysis.proposal}`,
      `受入条件: ${params.attachmentAnalysis.acceptance_criteria}`,
    );
  }
  const today = new Date().toISOString().slice(0, 10);

  const { data, error } = await admin.from("wbs_tasks").insert({
    category: "ユーザー要望",
    category_icon: "REQ",
    category_order: 0,
    title: `[追加要望] ${params.title}`,
    description: descriptionLines.join("\n"),
    instance: "vscode",
    owner_instance: "vscode",
    status: "pending",
    progress: 0,
    start_date: today,
    end_date: today,
    planned_start_date: today,
    planned_end_date: today,
    milestone_code: "beta",
    priority: params.priority,
    remaining_work: issueLine,
    recovery_plan:
      "追加要望フォームから自動登録。Issue内容を確認し、優先度と担当をWBS上で調整する。",
    estimated_hours: estimateFeatureRequestHours(params.priority),
  }).select("id, title, status, owner_instance").single();
  if (error) {
    return { error: error.message };
  }
  return { ...data, github_issue_number: params.issueNumber };
}

export interface CoreHubRequestDependencies {
  createAdminClient?: () => SupabaseClient;
  authenticateUser?: (req: Request) => Promise<string | null>;
  handleMemoReaction?: typeof handleMemoReactionAction;
  serviceRoleKey?: string;
  reportError?: (error: unknown) => void;
}

export async function handleCoreHubRequest(
  req: Request,
  dependencies: CoreHubRequestDependencies = {},
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // deno-lint-ignore no-explicit-any
    let body: Record<string, any> = {};
    if (req.method === "GET" || req.method === "HEAD") {
      // GET/HEAD は query param を body 相当として扱う。ヘッダーを付けられない
      // クローラー / 外部 AI が匿名 action (memo.public.* 等) を叩けるようにする。
      // HEAD はブラウザ / AI フェッチャーが本文取得前のプリフライトとして送る。
      body = searchParamsToActionBody(req.url);
    } else {
      try {
        body = await req.json();
      } catch {
        body = {};
      }
      if (typeof body.action !== "string" || body.action === "") {
        // 一部フェッチャーは POST でも body を送らない — query param を fallback。
        body = { ...searchParamsToActionBody(req.url), ...body };
      }
    }

    const rawAction = typeof body.action === "string" ? body.action : "";
    const actionDefinition = coreHubActionDefinition(rawAction);
    if (actionDefinition === null) {
      return json({ error: `Unknown action: ${rawAction}` }, 400);
    }
    const action: CoreHubAction = rawAction as CoreHubAction;
    const bearer = (req.headers.get("authorization") ?? "").replace(
      /^Bearer\s+/i,
      "",
    ).trim();
    const serviceRoleKey = dependencies.serviceRoleKey ?? SERVICE_ROLE_KEY;
    const isServiceRole = serviceRoleKey !== "" && bearer === serviceRoleKey;
    let userId = "";
    if (actionDefinition.auth === "anonymous") {
      // skip auth — anonymous OK
    } else if (actionDefinition.auth === "service_role") {
      if (!isServiceRole) return json({ error: "Unauthorized" }, 401);
    } else {
      const authed = await (dependencies.authenticateUser ?? getUserId)(req);
      if (!authed) return json({ error: "Unauthorized" }, 401);
      userId = authed;
    }

    const admin = dependencies.createAdminClient?.() ??
      createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    switch (action) {
      // ---- Memo sharing ----
      case "memo.share": {
        const item = await addItem(admin, "memo_share", userId, {
          memo_id: body.memo_id,
          title: body.title,
          content: body.content,
        });
        return json({ success: true, item });
      }

      case "memo.share_list": {
        const items = await listItems(admin, "memo_share", userId);
        return json({ success: true, items });
      }

      // ---- Memo reactions ----
      case "memo.react": {
        const item = await addItem(admin, "memo_reaction", userId, {
          memo_id: body.memo_id,
          reaction: body.reaction,
        });
        return json({ success: true, item });
      }

      // ---- Memo reactions (anonymous, IP-based — public_memos に対する emoji reaction) ----
      // Win版#132 part 50: legacy `memo-reactions` EF が core-hub 移行で部分実装に
      // とどまっていた問題を補完。元 EF と同じ contract:
      //   request:  { action, memo_id }                 → counts + userReactions
      //             { action, memo_id, reaction }       → toggle (insert or delete) + counts
      //   response: { reactions: {emoji: count}, userReactions: [emoji, ...], (added) }
      // ip_hash は server 側で `x-forwarded-for` を sha256 して生成する (clientは送らない)。
      case "memo.react.list":
      case "memo.react.toggle": {
        const result = await (
          dependencies.handleMemoReaction ?? handleMemoReactionAction
        )({
          action: action as MemoReactionAction,
          body,
          headers: req.headers,
          store: createSupabaseMemoReactionStore(admin),
        });
        return json(result.payload, result.status);
      }

      // ---- OGP (memo) ----
      case "memo.ogp": {
        const item = await addItem(admin, "memo_ogp", userId, {
          url: body.url,
          title: body.title,
          description: body.description,
          image: body.image,
        });
        return json({ success: true, item });
      }

      // ---- Public memo bot/AI-readable view (anonymous) ----
      // Flutter SPA (/public-memo?id=X) は JS 実行後に本文を取得するため、
      // ChatGPT 等の外部 AI / クローラーは URL を開いても本文を読めない。
      // GET ?action=memo.public.view&id=44 で SSR 済み HTML を返す
      // (format=json / md も可)。RLS と同じく is_public=true の行のみ返す。
      case "memo.public.view": {
        const memoId = Number(body.id ?? body.memo_id);
        const format = resolvePublicMemoViewFormat(body.format, req.method);
        if (!Number.isInteger(memoId) || memoId <= 0) {
          return json({ error: "id (positive integer) required" }, 400);
        }
        const { data, error } = await admin
          .from("public_memos")
          .select(PUBLIC_MEMO_VIEW_COLUMNS)
          .eq("id", memoId)
          .eq("is_public", true)
          .maybeSingle();
        if (error) return json({ error: error.message }, 500);
        if (!data) {
          if (format === "html") {
            return publicText(
              renderPublicMemoNotFoundHtml(memoId),
              "text/html; charset=utf-8",
              404,
            );
          }
          return json({ error: `Public memo ${memoId} not found` }, 404);
        }
        const row = data as PublicMemoViewRow;
        if (format === "json") {
          return json({ success: true, memo: publicMemoToPayload(row) });
        }
        if (format === "md" || format === "txt") {
          return publicText(
            renderPublicMemoMarkdown(row),
            format === "md"
              ? "text/markdown; charset=utf-8"
              : "text/plain; charset=utf-8",
          );
        }
        return publicText(
          renderPublicMemoHtml(row),
          "text/html; charset=utf-8",
        );
      }

      case "memo.public.list": {
        const limit = clampPublicMemoLimit(body.limit, 20, 50);
        const format = resolvePublicMemoViewFormat(body.format, req.method);
        const { data, error } = await admin
          .from("public_memos")
          .select(PUBLIC_MEMO_VIEW_COLUMNS)
          .eq("is_public", true)
          .order("published_at", { ascending: false })
          .limit(limit);
        if (error) return json({ error: error.message }, 500);
        const rows = (data ?? []) as PublicMemoViewRow[];
        if (format === "html") {
          return publicText(
            renderPublicMemoListHtml(rows),
            "text/html; charset=utf-8",
          );
        }
        if (format === "md" || format === "txt") {
          return publicText(
            renderPublicMemoListMarkdown(rows),
            format === "md"
              ? "text/markdown; charset=utf-8"
              : "text/plain; charset=utf-8",
          );
        }
        return json({
          success: true,
          memos: rows.map(publicMemoToPayload),
        });
      }

      // ---- Public memo search (anonymous / AI 向け) ----
      // 負荷対策: query は正規化 + 2〜100 字ガード、limit は 1..50 clamp、
      // is_public=true のみ。ilike ワイルドカードは無害化済み。
      case "memo.public.search": {
        const query = normalizePublicMemoSearchQuery(body.q ?? body.query);
        if (query === null) {
          return json({
            error: `q (${PUBLIC_MEMO_SEARCH_MIN_QUERY_LENGTH}-` +
              `${PUBLIC_MEMO_SEARCH_MAX_QUERY_LENGTH} chars) required`,
          }, 400);
        }
        const limit = clampPublicMemoLimit(body.limit, 20, 50);
        const format = resolvePublicMemoViewFormat(body.format, req.method);
        const pattern = `%${query}%`;
        const { data, error } = await admin
          .from("public_memos")
          .select(PUBLIC_MEMO_VIEW_COLUMNS)
          .eq("is_public", true)
          .or(
            `title.ilike.${pattern},content.ilike.${pattern},category.ilike.${pattern}`,
          )
          .order("published_at", { ascending: false })
          .limit(limit);
        if (error) return json({ error: error.message }, 500);
        const rows = (data ?? []) as PublicMemoViewRow[];
        if (format === "html") {
          return publicText(
            renderPublicMemoListHtml(rows),
            "text/html; charset=utf-8",
          );
        }
        if (format === "md" || format === "txt") {
          return publicText(
            renderPublicMemoListMarkdown(rows),
            format === "md"
              ? "text/markdown; charset=utf-8"
              : "text/plain; charset=utf-8",
          );
        }
        return json({
          success: true,
          query,
          memos: rows.map(publicMemoToPayload),
        });
      }

      // ---- Public memo related v1 (anonymous / 同カテゴリ・自分以外・新しい順) ----
      case "memo.public.related": {
        const memoId = Number(body.id ?? body.memo_id);
        if (!Number.isInteger(memoId) || memoId <= 0) {
          return json({ error: "id (positive integer) required" }, 400);
        }
        const limit = clampPublicMemoLimit(body.limit, 5, 20);
        const format = resolvePublicMemoViewFormat(body.format, req.method);
        const { data: base, error: baseError } = await admin
          .from("public_memos")
          .select("id, category")
          .eq("id", memoId)
          .eq("is_public", true)
          .maybeSingle();
        if (baseError) return json({ error: baseError.message }, 500);
        if (!base) {
          if (format === "html") {
            return publicText(
              renderPublicMemoNotFoundHtml(memoId),
              "text/html; charset=utf-8",
              404,
            );
          }
          return json({ error: `Public memo ${memoId} not found` }, 404);
        }
        const category = ((base as { category: string | null }).category ?? "")
          .trim();
        let rows: PublicMemoViewRow[] = [];
        if (category) {
          const { data, error } = await admin
            .from("public_memos")
            .select(PUBLIC_MEMO_VIEW_COLUMNS)
            .eq("is_public", true)
            .eq("category", category)
            .neq("id", memoId)
            .order("published_at", { ascending: false })
            .limit(limit);
          if (error) return json({ error: error.message }, 500);
          rows = (data ?? []) as PublicMemoViewRow[];
        }
        if (format === "html") {
          return publicText(
            renderPublicMemoListHtml(rows),
            "text/html; charset=utf-8",
          );
        }
        if (format === "md" || format === "txt") {
          return publicText(
            renderPublicMemoListMarkdown(rows),
            format === "md"
              ? "text/markdown; charset=utf-8"
              : "text/plain; charset=utf-8",
          );
        }
        return json({
          success: true,
          memoId,
          category: category || null,
          memos: rows.map(publicMemoToPayload),
        });
      }

      // ---- Public blog bot/AI-readable view (anonymous / status='posted') ----
      // /blog/post は SPA でアプリ内ナビ引数から記事を特定するため URL で
      // クロールできない。GET ?action=blog.public.view&id=X で SSR 済み HTML
      // (format=json / md 可) を返す。RLS と同じく status='posted' のみ。
      case "blog.public.view": {
        const id = String(body.id ?? "").trim();
        const format = resolvePublicMemoViewFormat(body.format, req.method);
        if (!id) return json({ error: "id required" }, 400);
        const { data, error } = await admin
          .from("blog_posts")
          .select(BLOG_VIEW_COLUMNS)
          .eq("id", id)
          .eq("status", "posted")
          .maybeSingle();
        if (error) return json({ error: error.message }, 500);
        if (!data) {
          if (format === "html") {
            return publicText(
              renderBlogNotFoundHtml(id),
              "text/html; charset=utf-8",
              404,
            );
          }
          return json({ error: `Blog ${id} not found` }, 404);
        }
        const row = data as BlogPostRow;
        if (format === "json") {
          return json({ success: true, post: blogPostToPayload(row) });
        }
        if (format === "md" || format === "txt") {
          return publicText(
            renderBlogMarkdown(row),
            format === "md"
              ? "text/markdown; charset=utf-8"
              : "text/plain; charset=utf-8",
          );
        }
        return publicText(renderBlogHtml(row), "text/html; charset=utf-8");
      }

      case "blog.public.list": {
        const limit = clampPublicMemoLimit(body.limit, 20, 50);
        const format = resolvePublicMemoViewFormat(body.format, req.method);
        const { data, error } = await admin
          .from("blog_posts")
          .select(BLOG_VIEW_COLUMNS)
          .eq("status", "posted")
          .order("posted_at", { ascending: false })
          .limit(limit);
        if (error) return json({ error: error.message }, 500);
        const rows = (data ?? []) as BlogPostRow[];
        if (format === "html") {
          return publicText(
            renderBlogListHtml(rows),
            "text/html; charset=utf-8",
          );
        }
        if (format === "md" || format === "txt") {
          return publicText(
            renderBlogListMarkdown(rows),
            format === "md"
              ? "text/markdown; charset=utf-8"
              : "text/plain; charset=utf-8",
          );
        }
        return json({ success: true, posts: rows.map(blogPostToPayload) });
      }

      // ---- OGP fetch (stateless) ----
      case "ogp.fetch": {
        if (!body.url) return json({ error: "url required" }, 400);
        let ogTitle = "";
        let ogDescription = "";
        let ogImage = "";
        try {
          const res = await fetch(body.url as string, {
            signal: AbortSignal.timeout(8000),
          });
          const html = await res.text();
          const titleMatch = html.match(
            /<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']/i,
          );
          const descMatch = html.match(
            /<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)["']/i,
          );
          const imgMatch = html.match(
            /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i,
          );
          const titleMatchAlt = html.match(
            /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']/i,
          );
          const descMatchAlt = html.match(
            /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:description["']/i,
          );
          const imgMatchAlt = html.match(
            /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i,
          );
          ogTitle = titleMatch?.[1] ?? titleMatchAlt?.[1] ?? "";
          ogDescription = descMatch?.[1] ?? descMatchAlt?.[1] ?? "";
          ogImage = imgMatch?.[1] ?? imgMatchAlt?.[1] ?? "";
        } catch {
          // fetch failed — return empty
        }
        return json({
          success: true,
          og: { title: ogTitle, description: ogDescription, image: ogImage },
        });
      }

      // ---- Note comments ----
      case "note.comment.list": {
        const items = await listItems(admin, "note_comment", userId);
        return json({ success: true, items });
      }

      case "note.comment.add": {
        const item = await addItem(admin, "note_comment", userId, {
          note_id: body.note_id,
          text: body.text,
        });
        return json({ success: true, item });
      }

      case "note.comment.delete": {
        await deleteItem(admin, "note_comment", userId, String(body.id));
        return json({ success: true });
      }

      // ---- Notifications ----
      case "notification.list": {
        const rawItems = await listItems(admin, "notification", userId, 50);
        // metadata をフラット化して旧 notification-center 互換フォーマットに変換
        const notifications = rawItems.map((row) => {
          const meta = (row.metadata as Record<string, unknown>) ?? {};
          return {
            id: row.id,
            title: meta["title"] ?? "",
            message: meta["message"] ?? "",
            type: meta["type"] ?? "info",
            link: meta["link"] ?? "",
            is_read: !!(meta["read"] as boolean),
            created_at: row.created_at,
          };
        });
        const filter = (body.filter as string) ?? "all";
        const limit = Number(body.limit ?? 50);
        const filtered = filter === "unread"
          ? notifications.filter((n) => !n.is_read)
          : notifications;
        const result = filtered.slice(0, limit);
        const unreadCount = notifications.filter((n) => !n.is_read).length;
        return json({ success: true, notifications: result, unreadCount });
      }

      case "notification.create": {
        const dedupeKey = String(body.dedupeKey ?? body.dedupe_key ?? "")
          .trim();
        if (dedupeKey) {
          const { data: existing, error: existingErr } = await admin
            .from("hub_data")
            .select("id, metadata, created_at")
            .eq("source", "notification")
            .filter("metadata->>user_id", "eq", userId)
            .filter("metadata->>dedupe_key", "eq", dedupeKey)
            .order("created_at", { ascending: false })
            .limit(1)
            .maybeSingle();
          if (existingErr) return json({ error: existingErr.message }, 400);
          if (existing) {
            return json({ success: true, item: existing, deduped: true });
          }
        }
        const item = await addItem(admin, "notification", userId, {
          title: body.title,
          message: body.message,
          type: body.type ?? "info",
          link: body.link ?? "",
          dedupe_key: dedupeKey || undefined,
          read: false,
        });
        return json({ success: true, item });
      }

      case "notification.mark_read": {
        if (!body.id) return json({ error: "id required" }, 400);
        const { data: existing, error: fetchErr } = await admin
          .from("hub_data")
          .select("metadata")
          .eq("id", String(body.id))
          .eq("source", "notification")
          .single();
        if (fetchErr) return json({ error: fetchErr.message }, 400);
        const updatedMeta = { ...(existing?.metadata ?? {}), read: true };
        const { error: updateErr } = await admin
          .from("hub_data")
          .update({ metadata: updatedMeta })
          .eq("id", String(body.id))
          .eq("source", "notification");
        if (updateErr) return json({ error: updateErr.message }, 400);
        return json({ success: true });
      }

      case "notification.mark_all": {
        // ユーザーの全通知を既読にする
        const { data: rows, error: listErr } = await admin
          .from("hub_data")
          .select("id, metadata")
          .eq("source", "notification")
          .filter("metadata->>user_id", "eq", userId);
        if (listErr) return json({ error: listErr.message }, 400);
        for (const row of rows ?? []) {
          const meta = {
            ...(row.metadata as Record<string, unknown>),
            read: true,
          };
          await admin.from("hub_data").update({ metadata: meta }).eq(
            "id",
            row.id,
          );
        }
        return json({ success: true, updated: (rows ?? []).length });
      }

      case "notification.broadcast_release": {
        const version = String(body.version ?? "").trim();
        const releaseUrl = String(body.releaseUrl ?? "").trim();
        const commit = String(body.commit ?? "").trim().slice(0, 7);
        if (!version) return json({ error: "version required" }, 400);

        // Idempotency: 同じ version が既に broadcast 済みならスキップ
        const { data: existing } = await admin
          .from("hub_data")
          .select("id")
          .eq("source", "notification")
          .filter("metadata->>type", "eq", "feature_update")
          .filter("metadata->>version", "eq", version)
          .limit(1);
        if ((existing?.length ?? 0) > 0) {
          return json({ success: true, skipped: "already_broadcast", version });
        }

        // アクティブユーザー取得 (過去90日以内ログイン)
        const ninetyDaysAgo = new Date(Date.now() - 90 * 86_400_000)
          .toISOString();
        const { data: userList, error: userErr } = await admin.auth.admin
          .listUsers({
            perPage: 1000,
          });
        if (userErr) return json({ error: userErr.message }, 500);
        const activeUsers = (userList?.users ?? []).filter(
          (u) => u.last_sign_in_at && u.last_sign_in_at >= ninetyDaysAgo,
        );
        if (activeUsers.length === 0) {
          return json({ success: true, broadcast_to: 0, version });
        }

        const rows = activeUsers.map((u) => ({
          source: "notification",
          metadata: {
            title: `🚀 新バージョン v${version} をリリースしました`,
            message:
              `アプリを更新すると新機能・改善が反映されます。ページを再読み込みしてください。`,
            type: "feature_update",
            read: false,
            user_id: u.id,
            version,
            releaseUrl,
            commit,
            action: "update_app",
          },
        }));

        const { error: insertErr } = await admin.from("hub_data").insert(rows);
        if (insertErr) return json({ error: insertErr.message }, 500);
        return json({
          success: true,
          broadcast_to: activeUsers.length,
          version,
        });
      }

      // Issue #696 S2 — Slack Incoming Webhook 投稿 action.
      // 6 channel (default/quota/ci/alerts/daily/handoff) を env var で切替。
      // payload: { channel?: string, text?: string, blocks?: SlackBlock[] }
      case "slack.notify": {
        const channel = String(body.channel ?? "default").trim();
        const text = typeof body.text === "string" ? body.text.trim() : "";
        const blocks = Array.isArray(body.blocks) ? body.blocks : null;
        if (!text && !blocks) {
          return json({ error: "text or blocks required" }, 400);
        }

        const actorType = textValue(body.actor_type, 40).toLowerCase();
        const explicitApprovalGate = body.human_approval_required === true ||
          body.approval_required === true ||
          actorType === "ai" ||
          actorType === "agent" ||
          Array.isArray(body.requested_scopes);
        if (explicitApprovalGate) {
          const gateReason = externalSaasGateReason({
            connectorEnabled: body.connector_enabled !== false,
            humanApprovalRequired: body.human_approval_required === true ||
              body.approval_required === true,
            actorType,
            requestedScopes: coreRequestedScopes(body),
          });
          if (gateReason === "connector_disabled") {
            return json({
              success: false,
              error: "Slack connector is disabled for this team",
              connector: "slack",
            }, 403);
          }
          if (gateReason === "approval_required") {
            const ownerUserId = textValue(
              body.user_id ?? body.owner_user_id ?? body.approver_user_id,
              120,
            );
            if (!ownerUserId) {
              return json({
                success: false,
                approval_required: true,
                error:
                  "owner_user_id is required to queue an approval-gated Slack action",
              }, 202);
            }
            const approval = await enqueueCoreSaasApprovalRequest(
              admin,
              ownerUserId,
              {
                provider: "slack",
                actionKey: "slack.notify",
                actionLabel: "Send Slack notification",
                teamId: textValue(body.team_id, 120) || "default",
                preview: {
                  channel,
                  text,
                  has_blocks: blocks !== null,
                },
                payload: { channel, text, blocks },
                requestedScopes: coreRequestedScopes(body),
              },
            );
            return json({
              success: false,
              approval_required: true,
              status: "pending",
              approval,
            }, 202);
          }
        }

        const webhookEnvMap: Record<string, string> = {
          "default": "SLACK_WEBHOOK_URL",
          "quota": "SLACK_WEBHOOK_QUOTA",
          "ci": "SLACK_WEBHOOK_CI",
          "alerts": "SLACK_WEBHOOK_ALERTS",
          "daily": "SLACK_WEBHOOK_DAILY",
          "handoff": "SLACK_WEBHOOK_HANDOFF",
        };
        const envKey = webhookEnvMap[channel] ?? "SLACK_WEBHOOK_URL";
        const url = Deno.env.get(envKey);
        if (!url) {
          return json({
            error: `webhook not configured: ${envKey}`,
            channel,
          }, 500);
        }

        const slackPayload: Record<string, unknown> = {};
        if (text) slackPayload.text = text;
        if (blocks) slackPayload.blocks = blocks;

        const resp = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(slackPayload),
        });

        if (!resp.ok) {
          const errBody = await resp.text();
          const discord = await sendDiscordWebhook({
            enabled: wantsDiscordSecondary(body),
            webhookUrl: Deno.env.get("DISCORD_WEBHOOK_URL") ?? "",
            text: text || `Slack ${channel} notification failed.`,
            username: body.discord_username ?? body.username,
            channel,
          });
          return json({
            error: `slack webhook failed: ${resp.status}`,
            detail: errBody.slice(0, 500),
            channel,
            envKey,
            discord,
          }, 502);
        }

        const discord = await sendDiscordWebhook({
          enabled: wantsDiscordSecondary(body),
          webhookUrl: Deno.env.get("DISCORD_WEBHOOK_URL") ?? "",
          text: text || `Slack ${channel} notification mirrored to Discord.`,
          username: body.discord_username ?? body.username,
          channel,
        });

        return json({
          success: true,
          channel,
          envKey,
          status: resp.status,
          discord,
        });
      }

      case "discord.notify": {
        const text = typeof body.text === "string"
          ? body.text.trim()
          : typeof body.message === "string"
          ? body.message.trim()
          : "";
        if (!text) {
          return json({ error: "text or message required" }, 400);
        }

        const discord = await sendDiscordWebhook({
          enabled: true,
          webhookUrl: Deno.env.get("DISCORD_WEBHOOK_URL") ?? "",
          text,
          username: body.discord_username ?? body.username,
          channel: typeof body.channel === "string" ? body.channel : undefined,
        });

        return json(
          { success: discord.success, discord },
          discord.success || discord.skipped ? 200 : 502,
        );
      }

      // ---- User profile ----
      case "user.profile": {
        const { data } = await admin
          .from("hub_data")
          .select("metadata")
          .eq("source", "user_profile")
          .filter("metadata->>user_id", "eq", userId)
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle();
        return json({ success: true, profile: data?.metadata ?? {} });
      }

      case "user.update": {
        const item = await addItem(admin, "user_profile", userId, {
          ...body,
          user_id: userId,
        });
        return json({ success: true, item });
      }

      // ---- Onboarding ----
      case "onboarding.get": {
        const items = await listItems(admin, "onboarding_step", userId, 20);
        return json({ success: true, items });
      }

      case "onboarding.complete": {
        const item = await addItem(admin, "onboarding_step", userId, {
          step: body.step,
          completed_at: new Date().toISOString(),
        });
        return json({ success: true, item });
      }

      // ---- Feature requests ----
      case "feature_request.list": {
        const items = await listItems(admin, "feature_request_user", userId);
        return json({ success: true, items });
      }

      case "feature_request.vote": {
        const item = await addItem(admin, "feature_request_vote", userId, {
          request_id: body.request_id,
          vote: body.vote ?? 1,
        });
        return json({ success: true, item });
      }

      case "feature_request.analyze_attachment": {
        const fileName = textValue(body.file_name ?? body.fileName, 240) ||
          "attachment.png";
        const mimeType = textValue(body.mime_type ?? body.mimeType, 80) ||
          "image/png";
        const imageBase64 = textValue(
          body.image_base64 ?? body.imageBase64,
          9_000_000,
        );
        const currentTitle = textValue(
          body.current_title ?? body.currentTitle,
          120,
        );
        const currentDescription = textValue(
          body.current_description ?? body.currentDescription,
          4000,
        );
        const currentExpectedOutcome = textValue(
          body.current_expected_outcome ?? body.currentExpectedOutcome,
          1000,
        );
        const category = textValue(body.category, 80) || "UX改善";
        const priority = normalizePriority(body.priority);

        if (!mimeType.startsWith("image/")) {
          return json({ error: "image attachment required" }, 400);
        }
        if (imageBase64.length < 32) {
          return json({ error: "image_base64 required" }, 400);
        }
        if (imageBase64.length > 8_500_000) {
          return json({ error: "image is too large" }, 413);
        }

        const analysis = await analyzeFeatureRequestAttachment({
          fileName,
          mimeType,
          imageBase64,
          currentTitle,
          currentDescription,
          currentExpectedOutcome,
          category,
          priority,
        });
        const item = await addItem(
          admin,
          "feature_request_attachment_analysis",
          userId,
          {
            file_name: fileName,
            mime_type: mimeType,
            current_title: currentTitle,
            current_description: currentDescription,
            current_expected_outcome: currentExpectedOutcome,
            analysis,
            created_at: new Date().toISOString(),
          },
        );
        return json({ success: true, analysis, item });
      }

      case "feature_request.existing_issues": {
        const source = textValue(body.source, 80) ||
          "home_feature_request_form";
        const candidates = normalizeFeatureRequestCandidates(
          body.requests ?? body.candidates,
          source,
        );
        const existingIssues = await findExistingFeatureRequestIssues(
          admin,
          candidates,
          source,
        );
        return json({
          success: true,
          existingIssues,
          existing_keys: existingIssues.map((issue) => issue.key),
        });
      }

      case "feature_request.submit": {
        const title = textValue(body.title, 120);
        const description = textValue(body.description, 4000);
        const expectedOutcome = textValue(
          body.expected_outcome ?? body.expectedOutcome,
          1000,
        );
        const category = textValue(body.category, 80) || "機能追加";
        const priority = normalizePriority(body.priority);
        const source = textValue(body.source, 80) ||
          "home_feature_request_form";
        const attachmentFileName = textValue(
          body.attachment_file_name ?? body.attachmentFileName,
          240,
        );
        const attachmentMimeType = textValue(
          body.attachment_mime_type ?? body.attachmentMimeType,
          80,
        );
        let attachmentAnalysis: FeatureRequestAttachmentAnalysis | null = null;
        if (
          body.attachment_analysis &&
          typeof body.attachment_analysis === "object"
        ) {
          attachmentAnalysis = normalizeFeatureRequestAnalysis(
            body.attachment_analysis as Record<string, unknown>,
            fallbackFeatureRequestAttachmentAnalysis({
              fileName: attachmentFileName || "attachment.png",
              currentTitle: title,
              currentDescription: description,
              currentExpectedOutcome: expectedOutcome,
              category,
              priority,
              reason: "送信済みのAI診断結果をIssue本文へ反映します。",
            }),
          );
        }
        if (title.length < 3) {
          return json({ error: "title must be at least 3 characters" }, 400);
        }
        if (description.length < 10) {
          return json(
            { error: "description must be at least 10 characters" },
            400,
          );
        }

        const createdAt = new Date().toISOString();
        const userEmail = await getUserEmail(admin, userId);
        const dedupeKey = textValue(body.dedupe_key ?? body.dedupeKey, 240) ||
          featureRequestCandidateKey(title, description, source);
        const [existingIssue] = await findExistingFeatureRequestIssues(
          admin,
          [{ key: dedupeKey, title, description }],
          source,
        );
        if (existingIssue) {
          const item = await addItem(admin, "feature_request_user", userId, {
            title,
            description,
            expected_outcome: expectedOutcome,
            category,
            priority,
            status: "existing_issue",
            source,
            dedupe_key: dedupeKey,
            created_at: createdAt,
            github_issue: existingIssue,
            wbs_task: {
              skipped: true,
              reason: "existing_github_issue",
            },
          });
          return json({
            success: true,
            partialSuccess: true,
            deduped: true,
            existingIssue: true,
            item,
            githubIssue: {
              number: existingIssue.number,
              html_url: existingIssue.html_url,
              title: existingIssue.title,
              state: existingIssue.state,
            },
            wbsTask: {
              skipped: true,
              reason: "existing_github_issue",
            },
          });
        }
        const issueBody = buildFeatureRequestBody({
          title,
          description,
          expectedOutcome,
          category,
          priority,
          userId,
          createdAt,
          attachmentFileName,
          attachmentAnalysis,
        });
        const githubIssue = await createGitHubIssue({
          title,
          body: issueBody,
        });
        const issueUrl = textValue(githubIssue.html_url, 400);
        const issueNumber = Number(githubIssue.number ?? 0) || null;

        const wbsTask = await createFeatureRequestWbsTask(admin, {
          title,
          description,
          expectedOutcome,
          category,
          priority,
          issueUrl,
          issueNumber,
          attachmentAnalysis,
        });

        let publicFeatureRequest: Record<string, unknown> | null = null;
        let publicFeatureRequestError = "";
        const publicInsert = await admin.from("feature_requests").insert({
          user_id: userId,
          email: userEmail || null,
          title,
          description,
          votes: 1,
          status: "open",
        }).select("id, title, status").single();
        if (publicInsert.error) {
          const retry = await admin.from("feature_requests").insert({
            email: userEmail || null,
            title,
            description,
            votes: 1,
            status: "open",
          }).select("id, title, status").single();
          if (retry.error) {
            publicFeatureRequestError = retry.error.message;
          } else {
            publicFeatureRequest = retry.data;
          }
        } else {
          publicFeatureRequest = publicInsert.data;
        }

        let appFeedback: Record<string, unknown> | null = null;
        let appFeedbackError = "";
        const feedbackInsert = await admin.from("app_feedback").insert({
          user_id: userId,
          category: "feature",
          content: issueBody,
          status: "new",
          github_issue_number: issueNumber,
          github_issue_url: issueUrl || null,
          user_email: userEmail || null,
        }).select("id, status, github_issue_number, github_issue_url").single();
        if (feedbackInsert.error) {
          appFeedbackError = feedbackInsert.error.message;
        } else {
          appFeedback = feedbackInsert.data;
        }

        const item = await addItem(admin, "feature_request_user", userId, {
          title,
          description,
          expected_outcome: expectedOutcome,
          category,
          priority,
          status: "open",
          source,
          dedupe_key: dedupeKey,
          created_at: createdAt,
          github_issue: githubIssue,
          wbs_task: wbsTask,
          attachment_file_name: attachmentFileName || undefined,
          attachment_mime_type: attachmentMimeType || undefined,
          attachment_analysis: attachmentAnalysis || undefined,
          feature_request: publicFeatureRequest,
          feature_request_error: publicFeatureRequestError || undefined,
          app_feedback: appFeedback,
          app_feedback_error: appFeedbackError || undefined,
        });

        const issueCreated = issueUrl !== "";
        const wbsCreated = !("error" in wbsTask);
        return json({
          success: issueCreated && wbsCreated,
          partialSuccess: issueCreated || wbsCreated,
          item,
          githubIssue,
          wbsTask,
          featureRequest: publicFeatureRequest,
          featureRequestError: publicFeatureRequestError,
          appFeedback,
          appFeedbackError,
        });
      }

      // ---- User feedback ----
      case "feedback.submit": {
        const category = textValue(body.category, 80) || "other";
        const message = textValue(body.message, 4000);
        const createdAt = new Date().toISOString();
        // クライアントの自動エラー報告 (error_reporter) は Issue 化しない:
        // 公開 Issue の乱発と AI レーン占有を防ぐため hub_data 記録のみに留める。
        const isAutoErrorReport = body.source === "auto_error_report" ||
          message.startsWith("[自動エラー報告]");

        // 受付記録は従来どおり hub_data に残す。
        const item = await addItem(admin, "user_feedback", userId, {
          message,
          category,
          rating: body.rating,
          source: isAutoErrorReport ? "auto_error_report" : "feedback_form",
          created_at: createdAt,
        });

        // フィードバックを GitHub Issue 化し、github-issue-fix レーンに載せる。
        // 自動エラー報告・短すぎる本文は Issue 化しない。
        let githubIssue: Record<string, unknown> = {
          skipped: true,
          reason: isAutoErrorReport ? "auto_error_report" : "message_too_short",
        };
        if (!isAutoErrorReport && message.trim().length >= 3) {
          const draft = buildFeedbackIssue({
            category,
            message,
            userId,
            createdAt,
          });

          // 重複抑止: 同タイトルの open Issue が既にあれば再起票しない
          // (連投・同一エラーによる公開 Issue 汚染を防ぐ)。
          const repo = githubRepoName();
          const existing = (await fetchGitHubIssuesByTitle(repo, draft.title))
            .find((issue) =>
              issue.state === "open" && issue.title === draft.title
            );
          if (existing) {
            githubIssue = {
              number: existing.number,
              html_url: existing.html_url,
              title: existing.title,
              deduped: true,
            };
          } else {
            githubIssue = await createGitHubIssue({
              title: draft.title,
              titlePrefix: "",
              body: draft.body,
              labels: draft.labels,
            });
          }

          // 投稿ありがとうメール (best-effort)。Issue が実在するときのみ送る。
          const issueNumber = typeof githubIssue.number === "number"
            ? githubIssue.number
            : null;
          const resendKey = Deno.env.get("RESEND_API_KEY") ?? "";
          const userEmail = issueNumber
            ? await getUserEmail(admin, userId)
            : "";
          const fromEmail = Deno.env.get("FEEDBACK_FROM_EMAIL") ??
            "noreply@jibun.app";
          if (resendKey && userEmail) {
            try {
              const emailRes = await fetch("https://api.resend.com/emails", {
                method: "POST",
                headers: {
                  Authorization: `Bearer ${resendKey}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({
                  from: fromEmail,
                  to: userEmail,
                  subject: "【自分株式会社】ご意見・ご要望を受け付けました",
                  html: [
                    "<p>ご投稿ありがとうございます。内容を確認しました。</p>",
                    `<p>GitHub Issue #${issueNumber} として登録し、AIが対応に着手します。</p>`,
                    "<p>進捗は対応完了時にあらためてお知らせします。</p>",
                  ].join(""),
                }),
              });
              if (!emailRes.ok) {
                console.warn(
                  `feedback ack email failed: ${emailRes.status}`,
                );
              }
            } catch (_emailError) {
              // 通知失敗は致命的ではないため握りつぶす。
            }
          }
        }

        const issueNumber = Number(githubIssue.number ?? 0) || null;
        const issueUrl = textValue(githubIssue.html_url, 400);
        const issueCreated = issueNumber !== null;
        return json({
          // フィードバック自体は常に保存する。ただし「対応を追跡します」が
          // 嘘にならないよう、Issue 化の成否を issueCreated で明示する。
          success: true,
          issueCreated,
          tracked: issueCreated,
          autoErrorReport: isAutoErrorReport,
          item,
          githubIssue: issueNumber
            ? { number: issueNumber, html_url: issueUrl }
            : githubIssue,
        });
      }

      // ---- Notify feature (email via Resend) ----
      case "notify.feature": {
        const resendKey = Deno.env.get("RESEND_API_KEY") ?? "";
        if (resendKey) {
          await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              Authorization: `Bearer ${resendKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              from: "noreply@jibun.app",
              to: body.email ?? "admin@jibun.app",
              subject: body.subject ?? "新機能リクエスト",
              html: body.html ?? body.message,
            }),
          });
        }
        return json({ success: true });
      }

      // ---- Notify feature request (feedback resolution email) ----
      case "notify.feature_request": {
        const resendKey = Deno.env.get("RESEND_API_KEY") ?? "";
        const fromEmail = Deno.env.get("FEEDBACK_FROM_EMAIL") ??
          "自分株式会社 <noreply@resend.dev>";
        if (resendKey === "") {
          return json({ error: "Missing RESEND_API_KEY" }, 500);
        }

        const featureRequestId = String(body.id ?? "").trim();
        const appFeedbackId = Number(body.appFeedbackId ?? 0) || null;
        const requestedStatus = String(body.status ?? "").trim();
        const markAsResolved = body.markAsResolved === true;
        const resolutionSummary = String(body.resolutionSummary ?? "").trim();
        const issueNumber = Number(body.issueNumber ?? 0) || null;
        const issueTitle = String(body.issueTitle ?? "").trim();
        let issueUrl = String(body.issueUrl ?? "").trim();
        const releaseTitle = String(body.releaseTitle ?? "").trim();
        const releaseUrl = String(body.releaseUrl ?? "").trim();

        let featureRequest: Record<string, unknown> | null = null;
        let appFeedback: Record<string, unknown> | null = null;

        if (featureRequestId !== "") {
          const { data, error } = await admin
            .from("feature_requests")
            .select("id, email, title, description, status, admin_reply")
            .eq("id", featureRequestId)
            .maybeSingle();
          if (error) throw new Error(error.message);
          featureRequest = data;
        }
        if (appFeedbackId !== null) {
          const { data, error } = await admin
            .from("app_feedback")
            .select(
              "id, category, content, user_email, status, github_issue_number, github_issue_url",
            )
            .eq("id", appFeedbackId)
            .maybeSingle();
          if (error) throw new Error(error.message);
          appFeedback = data;
          if (issueUrl === "") {
            issueUrl = String(data?.github_issue_url ?? "");
          }
        }

        if (!featureRequest && !appFeedback) {
          return json({ error: "No matching feedback record found" }, 404);
        }

        const frStatus = (featureRequest?.status as string | null)?.trim() ??
          "";
        const fbStatus = (appFeedback?.status as string | null) ?? "";
        const finalStatus = requestedStatus !== ""
          ? requestedStatus
          : markAsResolved
          ? "done"
          : frStatus !== ""
          ? frStatus
          : fbStatus === "implemented"
          ? "done"
          : fbStatus === "reviewed"
          ? "in_progress"
          : "open";

        if (featureRequest) {
          const upd: Record<string, unknown> = {
            status: finalStatus,
            admin_replied_at: new Date().toISOString(),
          };
          if (resolutionSummary !== "") {
            upd.admin_reply = resolutionSummary;
          } else if (
            markAsResolved &&
            String(featureRequest.admin_reply ?? "").trim() === ""
          ) {
            upd.admin_reply = _buildDefaultResolutionSummary(
              issueNumber,
              releaseTitle,
              releaseUrl,
            );
          }
          const { error } = await admin
            .from("feature_requests")
            .update(upd)
            .eq("id", featureRequest.id);
          if (error) throw new Error(error.message);
        }

        if (appFeedback) {
          const upd: Record<string, unknown> = {
            status: finalStatus === "done" ? "implemented" : "reviewed",
          };
          if (issueNumber !== null) upd.github_issue_number = issueNumber;
          if (issueUrl !== "") upd.github_issue_url = issueUrl;
          const { error } = await admin
            .from("app_feedback")
            .update(upd)
            .eq("id", appFeedback.id);
          if (error) throw new Error(error.message);
        }

        const title = String(featureRequest?.title ?? "").trim() ||
          _buildFallbackTitle(String(appFeedback?.content ?? ""));
        const recipient = String(featureRequest?.email ?? "").trim() ||
          String(appFeedback?.user_email ?? "").trim();
        if (recipient === "") {
          return json({ error: "No recipient email on feedback" }, 400);
        }

        const description = String(
          featureRequest?.description ?? appFeedback?.content ?? "",
        );
        const finalSummary = resolutionSummary !== ""
          ? resolutionSummary
          : _buildDefaultResolutionSummary(
            issueNumber,
            releaseTitle,
            releaseUrl,
          );
        const html = _buildNotificationEmailHtml({
          title,
          description,
          status: finalStatus,
          resolutionSummary: finalSummary,
          issueNumber,
          issueTitle,
          issueUrl,
          releaseTitle,
          releaseUrl,
        });
        const subject = finalStatus === "done"
          ? `【自分株式会社】「${title}」への対応が完了しました`
          : finalStatus === "in_progress"
          ? `【自分株式会社】「${title}」の対応を開始しました`
          : `【自分株式会社】「${title}」の対応状況を更新しました`;

        const resendRes = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${resendKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: fromEmail,
            to: [recipient],
            subject,
            html,
          }),
        });
        if (!resendRes.ok) {
          const errBody = await resendRes.text();
          throw new Error(`Resend API error: ${errBody}`);
        }

        return json({
          success: true,
          emailSent: true,
          sentTo: recipient,
          status: finalStatus,
          featureRequestId: (featureRequest?.id as string | null) ?? null,
          appFeedbackId: (appFeedback?.id as number | null) ?? null,
          issueNumber,
        });
      }

      // ---- Personal dashboard (昨日比較付き) ----
      case "personal.dashboard": {
        const now = new Date();
        const todayStart = new Date(
          now.getFullYear(),
          now.getMonth(),
          now.getDate(),
        );
        const yesterdayStart = new Date(todayStart);
        yesterdayStart.setDate(yesterdayStart.getDate() - 1);
        const weekStart = new Date(todayStart);
        weekStart.setDate(weekStart.getDate() - 7);
        const todayStr = todayStart.toISOString().slice(0, 10);
        const yesterdayStr = yesterdayStart.toISOString().slice(0, 10);

        const [
          totalNotesRes,
          notesTodayRes,
          notesYesterdayRes,
          notesWeekRes,
          recentNotesRes,
          focusTodayRes,
          focusYesterdayRes,
          habitsRes,
          habitLogsTodayRes,
          habitLogsYesterdayRes,
        ] = await Promise.all([
          admin.from("reality_notes").select("id", {
            count: "exact",
            head: true,
          }).eq("user_id", userId),
          admin.from("reality_notes").select("id", {
            count: "exact",
            head: true,
          }).eq("user_id", userId).gte("created_at", todayStart.toISOString()),
          admin.from("reality_notes").select("id", {
            count: "exact",
            head: true,
          }).eq("user_id", userId).gte(
            "created_at",
            yesterdayStart.toISOString(),
          ).lt("created_at", todayStart.toISOString()),
          admin.from("reality_notes").select("id", {
            count: "exact",
            head: true,
          }).eq("user_id", userId).gte("created_at", weekStart.toISOString()),
          admin.from("reality_notes").select("raw_text, created_at").eq(
            "user_id",
            userId,
          ).order("created_at", { ascending: false }).limit(5),
          admin.from("focus_sessions").select("duration_minutes").eq(
            "user_id",
            userId,
          ).eq("status", "completed").gte(
            "started_at",
            todayStart.toISOString(),
          ),
          admin.from("focus_sessions").select("duration_minutes").eq(
            "user_id",
            userId,
          ).eq("status", "completed").gte(
            "started_at",
            yesterdayStart.toISOString(),
          ).lt("started_at", todayStart.toISOString()),
          admin.from("daily_habits").select("id, title, streak").eq(
            "user_id",
            userId,
          ).eq("is_active", true).limit(10),
          admin.from("daily_habit_logs").select("habit_id").eq(
            "user_id",
            userId,
          ).eq("completed_date", todayStr),
          admin.from("daily_habit_logs").select("id", {
            count: "exact",
            head: true,
          }).eq("user_id", userId).eq("completed_date", yesterdayStr),
        ]);

        type FocusRow = { duration_minutes: number };
        type HabitRow = { id: string; title: string; streak: number };
        type NoteRow = { raw_text: string; created_at: string };

        const focusTodayMin = ((focusTodayRes.data as FocusRow[]) ?? []).reduce(
          (s, r) => s + (r.duration_minutes ?? 0),
          0,
        );
        const focusYesterdayMin = ((focusYesterdayRes.data as FocusRow[]) ?? [])
          .reduce((s, r) => s + (r.duration_minutes ?? 0), 0);
        const habitsArr = (habitsRes.data as HabitRow[]) ?? [];
        const completedTodayIds = new Set(
          ((habitLogsTodayRes.data as { habit_id: string }[]) ?? []).map((l) =>
            l.habit_id
          ),
        );
        const habitsTodayCount = completedTodayIds.size;
        const habitsYesterdayCount = habitLogsYesterdayRes.count ?? 0;
        const maxStreak = habitsArr.length > 0
          ? Math.max(...habitsArr.map((h) => h.streak ?? 0))
          : 0;
        const notesTodayCount = notesTodayRes.count ?? 0;
        const notesYesterdayCount = notesYesterdayRes.count ?? 0;

        // 昨日比スコア: notes*30 + focus*0.5 + habits*20 (上限100)
        const scoreToday = Math.min(
          100,
          notesTodayCount * 30 + focusTodayMin * 0.5 + habitsTodayCount * 20,
        );
        const scoreYesterday = Math.min(
          100,
          notesYesterdayCount * 30 + focusYesterdayMin * 0.5 +
            habitsYesterdayCount * 20,
        );
        const scoreDeltaPct = scoreYesterday > 0
          ? Math.round((scoreToday - scoreYesterday) / scoreYesterday * 100)
          : (scoreToday > 0 ? 100 : 0);

        return json({
          success: true,
          kpi: {
            total_notes: totalNotesRes.count ?? 0,
            tasks_completed: 0,
            focus_minutes: focusTodayMin,
            habit_streak: maxStreak,
            note_growth: notesWeekRes.count ?? 0,
            task_rate: 0,
          },
          weekly_activity: [],
          habit_stats: habitsArr.map((h) => ({
            name: h.title,
            streak: h.streak ?? 0,
            completed_today: completedTodayIds.has(h.id),
          })),
          recent_notes: ((recentNotesRes.data as NoteRow[]) ?? []).map((n) => ({
            title: (n.raw_text ?? "").slice(0, 60),
            updated_at: n.created_at,
          })),
          yesterday_comparison: {
            notes_today: notesTodayCount,
            notes_yesterday: notesYesterdayCount,
            notes_delta: notesTodayCount - notesYesterdayCount,
            focus_today: focusTodayMin,
            focus_yesterday: focusYesterdayMin,
            focus_delta: focusTodayMin - focusYesterdayMin,
            habits_today: habitsTodayCount,
            habits_yesterday: habitsYesterdayCount,
            habits_delta: habitsTodayCount - habitsYesterdayCount,
            score_today: Math.round(scoreToday),
            score_yesterday: Math.round(scoreYesterday),
            score_delta_pct: scoreDeltaPct,
          },
        });
      }

      // ---- Development achievements ----
      case "achievements.list": {
        const period = (body.period as string) ?? "";
        let query = admin
          .from("development_achievements")
          .select("*")
          .order("completed_at", { ascending: false });
        if (period === "今週の実績") {
          const weekAgo = new Date();
          weekAgo.setDate(weekAgo.getDate() - 7);
          query = query.gte("completed_at", weekAgo.toISOString());
        }
        const { data: ach } = await query.limit(20);
        return json({ success: true, achievements: ach ?? [] });
      }

      case "achievements.add": {
        if (!body.title) return json({ error: "title required" }, 400);
        const { data, error: insertErr } = await admin
          .from("development_achievements")
          .insert({
            title: String(body.title),
            description: body.description ?? "",
            completed_at: new Date().toISOString(),
          })
          .select()
          .single();
        if (insertErr) return json({ error: insertErr.message }, 400);
        return json({ success: true, achievement: data });
      }

      // ---- Analytics summary ----
      case "analytics.summary": {
        const items = await listItems(admin, "analytics_event", userId, 100);
        return json({ success: true, total: items.length, items });
      }

      // ---- System status ----
      case "system.status": {
        return json({
          success: true,
          status: "ok",
          timestamp: new Date().toISOString(),
          version: "1.0.0",
        });
      }

      // ─── Page Share Generation (Win版#132 part 15) ──────────────────────
      // 全ページの X シェアボタン用 asset (tweet 文 + 画像) を AI で自動生成。
      // 設計: docs/PAGE_LEVEL_SHARE.md / 7 日 TTL cache / page_path UNIQUE
      // Auth: anonymous OK (page-specific cache のためユーザー秘匿情報なし)
      // Fallback: Gemini fail → template / FAL fail → /ogp.png
      case "system.proactive_diagnostics": {
        const now = new Date();
        const today = now.toISOString().slice(0, 10);
        const staleCutoff = new Date(now.getTime() - 48 * 60 * 60 * 1000);
        const findings: ProactiveFinding[] = [];

        const [wbsRes, runsRes, hubRes] = await Promise.all([
          admin.from("wbs_tasks").select(
            "id,title,status,progress,updated_at,end_date,priority,instance,owner_instance,github_issue_number,github_issue_state,user_report_status",
          ).limit(5000),
          admin.from("schedule_task_runs").select(
            "task_id,status,started_at,finished_at,summary,error_message",
          ).order("started_at", { ascending: false }).limit(180),
          admin.from("hub_data").select("id", { count: "exact", head: true }),
        ]);

        if (wbsRes.error) {
          findings.push({
            id: "supabase-wbs-unreachable",
            area: "Supabase",
            severity: "critical",
            title: "WBSテーブルへ接続できません",
            detail: wbsRes.error.message,
            next_action:
              "SupabaseのRLS、service role、wbs_tasksのスキーマを確認する",
            user_task: false,
          });
        }
        if (runsRes.error) {
          findings.push({
            id: "supabase-schedule-runs-unreachable",
            area: "Supabase",
            severity: "warning",
            title: "定期実行ログへ接続できません",
            detail: runsRes.error.message,
            next_action:
              "schedule_task_runsテーブルとGitHub Actionsの記録処理を確認する",
            user_task: false,
          });
        }
        if (hubRes.error) {
          findings.push({
            id: "supabase-hub-data-unreachable",
            area: "Supabase",
            severity: "warning",
            title: "hub_dataへ接続できません",
            detail: hubRes.error.message,
            next_action: "core-hubの蓄積先テーブルと権限を確認する",
            user_task: false,
          });
        }

        const tasks = (wbsRes.data ?? []) as Array<Record<string, unknown>>;
        const openTasks = tasks.filter((task) =>
          String(task.status ?? "") !== "completed"
        );
        const blockedTasks = openTasks.filter((task) =>
          String(task.status ?? "") === "blocked"
        );
        const overdueTasks = openTasks.filter((task) => {
          const endDate = textValue(task.end_date, 20);
          return endDate !== "" && endDate < today;
        });
        const staleTasks = openTasks.filter((task) => {
          const updatedAt = Date.parse(String(task.updated_at ?? ""));
          return Number.isFinite(updatedAt) &&
            updatedAt < staleCutoff.getTime();
        });
        const userTasks = openTasks.filter((task) =>
          String(task.owner_instance ?? task.instance ?? "") === "user"
        );
        const completedWithOpenIssues = tasks.filter((task) =>
          String(task.status ?? "") === "completed" &&
          Number(task.github_issue_number ?? 0) > 0 &&
          String(task.github_issue_state ?? "").toUpperCase() === "OPEN"
        );
        const openWithClosedIssues = openTasks.filter((task) =>
          Number(task.github_issue_number ?? 0) > 0 &&
          String(task.github_issue_state ?? "").toUpperCase() === "CLOSED"
        );

        if (blockedTasks.length > 0) {
          findings.push({
            id: "wbs-blocked",
            area: "WBS",
            severity: "critical",
            title: `ブロック中のWBSタスクが${blockedTasks.length}件あります`,
            detail: blockedTasks.slice(0, 3).map((task) => task.title).join(
              " / ",
            ),
            next_action:
              "ブロック理由を確認し、userタスクか他インスタンスへの引き継ぎに分解する",
            user_task: true,
            count: blockedTasks.length,
          });
        }
        if (overdueTasks.length > 0) {
          findings.push({
            id: "wbs-overdue",
            area: "WBS",
            severity: overdueTasks.length >= 10 ? "critical" : "warning",
            title: `期限超過のWBSタスクが${overdueTasks.length}件あります`,
            detail: overdueTasks.slice(0, 3).map((task) => task.title).join(
              " / ",
            ),
            next_action:
              "期限超過タスクを優先度順に再計画し、今日対応する1件だけをin_progressにする",
            user_task: false,
            count: overdueTasks.length,
          });
        }
        if (staleTasks.length > 0) {
          findings.push({
            id: "wbs-stale",
            area: "WBS",
            severity: staleTasks.length >= 20 ? "warning" : "info",
            title:
              `48時間以上更新されていない未完了タスクが${staleTasks.length}件あります`,
            detail: staleTasks.slice(0, 3).map((task) => task.title).join(
              " / ",
            ),
            next_action:
              "滞留タスクを追加要望・不具合・ユーザー手動操作に分類し、不要なものは閉じる",
            user_task: false,
            count: staleTasks.length,
          });
        }
        if (userTasks.length > 0) {
          findings.push({
            id: "wbs-user-tasks",
            area: "WBS",
            severity: "info",
            title: `ユーザー手動確認タスクが${userTasks.length}件あります`,
            detail: userTasks.slice(0, 3).map((task) => task.title).join(" / "),
            next_action: "/wbs-user-tasks で実施状況を更新する",
            user_task: true,
            count: userTasks.length,
          });
        }
        if (completedWithOpenIssues.length > 0) {
          findings.push({
            id: "github-completed-wbs-open-issue",
            area: "GitHub Issues",
            severity: "warning",
            title:
              `完了WBSに紐づく未クローズIssueが${completedWithOpenIssues.length}件あります`,
            detail: completedWithOpenIssues.slice(0, 3).map((task) =>
              `#${task.github_issue_number} ${task.title}`
            ).join(" / "),
            next_action:
              "実装済みであることを確認してIssueへ完了コメントを残し、クローズする",
            user_task: false,
            count: completedWithOpenIssues.length,
          });
        }
        if (openWithClosedIssues.length > 0) {
          findings.push({
            id: "github-closed-issue-open-wbs",
            area: "GitHub Issues",
            severity: "warning",
            title:
              `クローズ済みIssueに紐づく未完了WBSが${openWithClosedIssues.length}件あります`,
            detail: openWithClosedIssues.slice(0, 3).map((task) =>
              `#${task.github_issue_number} ${task.title}`
            ).join(" / "),
            next_action:
              "Issueが誤クローズでないか確認し、WBSを完了またはIssueを再オープンする",
            user_task: false,
            count: openWithClosedIssues.length,
          });
        }

        const runs = (runsRes.data ?? []) as Array<Record<string, unknown>>;
        const latestByTask = new Map<string, Record<string, unknown>>();
        for (const run of runs) {
          const taskId = textValue(run.task_id, 120);
          if (taskId !== "" && !latestByTask.has(taskId)) {
            latestByTask.set(taskId, run);
          }
        }
        const latestErrors = [...latestByTask.values()].filter((run) =>
          String(run.status ?? "") === "error"
        );
        if (latestErrors.length > 0) {
          findings.push({
            id: "actions-latest-errors",
            area: "Actions",
            severity: latestErrors.length >= 3 ? "critical" : "warning",
            title:
              `最新実行が失敗している定期処理が${latestErrors.length}件あります`,
            detail: latestErrors.slice(0, 3).map((run) =>
              `${run.task_id}: ${
                textValue(run.error_message ?? run.summary, 120)
              }`
            ).join(" / "),
            next_action:
              "失敗しているworkflowの最新ログを確認し、secret不足・YAML・APIエラーに分類する",
            user_task: false,
            count: latestErrors.length,
          });
        }
        if (runs.length === 0 && !runsRes.error) {
          findings.push({
            id: "actions-no-runs",
            area: "Actions",
            severity: "warning",
            title: "定期実行ログがありません",
            detail: "schedule_task_runsに最近の実行履歴がありません。",
            next_action:
              "GitHub Actionsからschedule_task_runsへ記録する経路を確認する",
            user_task: false,
          });
        }
        if (findings.length === 0) {
          findings.push({
            id: "system-healthy",
            area: "Supabase",
            severity: "info",
            title: "重大な異常は検出されていません",
            detail: "WBS、Issue同期、定期実行ログは確認可能です。",
            next_action: "追加要望の優先順位を維持し、次の中粒度タスクへ進む",
            user_task: false,
          });
        }

        findings.sort((a, b) =>
          proactiveSeverityWeight(a.severity) -
          proactiveSeverityWeight(b.severity)
        );
        const criticalCount = findings.filter((finding) =>
          finding.severity === "critical"
        ).length;
        const warningCount = findings.filter((finding) =>
          finding.severity === "warning"
        ).length;
        const score = Math.max(
          0,
          Math.min(100, 100 - criticalCount * 18 - warningCount * 8),
        );
        const stats = {
          open_wbs_tasks: openTasks.length,
          blocked_wbs_tasks: blockedTasks.length,
          overdue_wbs_tasks: overdueTasks.length,
          stale_wbs_tasks: staleTasks.length,
          user_tasks: userTasks.length,
          linked_issue_tasks: tasks.filter((task) =>
            Number(task.github_issue_number ?? 0) > 0
          ).length,
          latest_action_errors: latestErrors.length,
          recorded_action_runs: runs.length,
          hub_data_rows: hubRes.count ?? null,
        };
        const aiReview = await buildProactiveAiReview({
          score,
          stats,
          findings,
        });
        const item = await addItem(
          admin,
          "system_proactive_diagnostics",
          userId,
          {
            score,
            stats,
            findings: findings.slice(0, 20),
            ai_review: aiReview,
            created_at: now.toISOString(),
          },
        );
        return json({
          success: true,
          status: score >= 90 ? "healthy" : score >= 70 ? "degraded" : "risk",
          score,
          checked_at: now.toISOString(),
          stats,
          findings: findings.slice(0, 20),
          ai_review: aiReview,
          item,
        });
      }

      case "page.share_generate": {
        const pagePath = textValue(body.page_path, 200);
        const pageTitle = textValue(body.page_title, 200);
        const pageDescription = textValue(body.page_description, 1000);
        const force = body.force === true;

        if (!pagePath) {
          return json({ error: "page_path required" }, 400);
        }

        // 1. Cache check (7 日以内 + force=false)
        if (!force) {
          const sevenDaysAgo = new Date(
            Date.now() - 7 * 24 * 3600 * 1000,
          ).toISOString();
          const { data: cached } = await admin
            .from("page_shares")
            .select("*")
            .eq("page_path", pagePath)
            .gte("created_at", sevenDaysAgo)
            .maybeSingle();
          if (cached?.tweet_text && cached?.image_url) {
            // share_count increment (fire-and-forget)
            admin
              .from("page_shares")
              .update({ share_count: (cached.share_count ?? 0) + 1 })
              .eq("id", cached.id)
              .then(() => {});
            return json({
              success: true,
              cached: true,
              tweet_text: cached.tweet_text,
              image_url: cached.image_url,
              video_url: cached.video_url,
            });
          }
        }

        // 2. Gemini Flash で tweet 文生成
        const geminiKey = Deno.env.get("GEMINI_API_KEY");
        let tweetText = "";
        if (geminiKey) {
          const prompt =
            `あなたは自分株式会社のSNS担当です。以下のページを X (旧Twitter) で
シェアする魅力的な日本語 tweet を作ってください。
- 140字以内
- ハッシュタグ 2-3 個含む (#自分株式会社 #buildinpublic 等)
- 末尾に LP リンク https://my-web-app-b67f4.web.app${pagePath} を含める
- 絵文字 1-2 個

## ページ情報
title: ${pageTitle}
description: ${pageDescription}

## 出力 (JSON のみ・コードブロックなし)
{"tweet_text": "..."}`;

          try {
            const resp = await fetch(
              `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`,
              {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                  contents: [{ parts: [{ text: prompt }] }],
                  generationConfig: {
                    temperature: 0.7,
                    maxOutputTokens: 300,
                  },
                }),
              },
            );
            if (resp.ok) {
              const data = await resp.json();
              let text = String(
                data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "",
              ).trim();
              if (text.startsWith("```")) {
                text = text.split("\n").slice(1, -1).join("\n");
              }
              try {
                const parsed = JSON.parse(text);
                tweetText = String(parsed.tweet_text ?? "").slice(0, 280);
              } catch {
                // JSON parse fail → fallthrough
              }
            }
          } catch {
            // Gemini call fail → fallthrough
          }
        }

        // Gemini fallback: simple template
        if (!tweetText) {
          tweetText = `🚀 ${pageTitle || "自分株式会社"}\n` +
            `21の競合SaaSを1つに統合する AI life management\n\n` +
            `https://my-web-app-b67f4.web.app${pagePath}\n\n` +
            `#自分株式会社 #buildinpublic #SaaS統合`;
          tweetText = tweetText.slice(0, 280);
        }

        // 3. FAL flux/schnell で画像生成
        // env 名は FAL_KEY / FAL_API_KEY の 2 系統が実在する (2026-07-25 実障害:
        // FAL_API_KEY だけ登録されていて画像が黙って fallback に落ちていた)。
        // 上の GITHUB_PAT ?? GITHUB_TOKEN ?? GH_TOKEN と同じく両方を受ける。
        const falKey = Deno.env.get("FAL_KEY") ?? Deno.env.get("FAL_API_KEY");
        let imageUrl = "https://my-web-app-b67f4.web.app/ogp.png"; // fallback
        let cost = 0;
        let generatedBy = "fallback";
        if (falKey) {
          try {
            const imagePrompt =
              `Modern minimalist OGP banner for "${
                pageTitle || "自分株式会社"
              }", ` +
              `1200x630 aspect ratio, gradient orange-purple-indigo background, ` +
              `Japanese-inspired typography style, futuristic UI elements floating, ` +
              `no text overlay, professional and clean, photorealistic high quality`;
            const falResp = await fetch(
              "https://fal.run/fal-ai/flux/schnell",
              {
                method: "POST",
                headers: {
                  "Authorization": `Key ${falKey}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({
                  prompt: imagePrompt,
                  image_size: "landscape_16_9",
                  num_inference_steps: 4,
                  num_images: 1,
                  enable_safety_checker: true,
                }),
              },
            );
            if (falResp.ok) {
              const falData = await falResp.json();
              if (falData?.images?.[0]?.url) {
                imageUrl = falData.images[0].url;
                cost = 0.003;
                generatedBy = geminiKey
                  ? "gemini-flash+fal-flux-schnell"
                  : "template+fal-flux-schnell";
              }
            }
          } catch {
            // FAL fail → fallback /ogp.png
          }
        }

        // 4. page_shares に upsert
        const { data: upserted } = await admin
          .from("page_shares")
          .upsert(
            {
              page_path: pagePath,
              page_title: pageTitle,
              page_description: pageDescription,
              tweet_text: tweetText,
              image_url: imageUrl,
              generated_by: generatedBy,
              cost_usd: cost,
              share_count: 1,
              updated_at: new Date().toISOString(),
            },
            { onConflict: "page_path" },
          )
          .select()
          .single();

        return json({
          success: true,
          cached: false,
          tweet_text: tweetText,
          image_url: imageUrl,
          page_share_id: upserted?.id,
          generated_by: generatedBy,
        });
      }

      // ---- Design audit actions ----

      case "design.screens.list": {
        const { data: screens, error: e1 } = await admin
          .from("design_screens")
          .select(
            "route, name, category, compliance, audit_date, notes, mcp_tool_used",
          );
        if (e1) return json({ error: e1.message }, 500);

        const { data: rollouts, error: e2 } = await admin
          .from("design_rollout")
          .select("*");
        if (e2) return json({ error: e2.message }, 500);

        return json({ screens: screens ?? [], rollouts: rollouts ?? [] });
      }

      case "design.audit.upsert": {
        const route = String(body.route ?? "");
        if (!route) return json({ error: "route required" }, 400);
        const compliance = Array.isArray(body.compliance)
          ? body.compliance
          : null;
        if (
          compliance &&
          (compliance.length !== 7 ||
            compliance.some((v) => typeof v !== "boolean"))
        ) {
          return json({ error: "compliance must be boolean[7]" }, 400);
        }
        const { error: uErr } = await admin.from("design_screens").upsert({
          route,
          name: body.name,
          category: body.category,
          compliance,
          audit_date: body.audit_date ?? new Date().toISOString().slice(0, 10),
          notes: body.notes ?? null,
          mcp_tool_used: body.mcp_tool_used ?? null,
          updated_at: new Date().toISOString(),
        });
        if (uErr) return json({ error: uErr.message }, 500);
        return json({ success: true });
      }

      case "design.rollout.upsert": {
        const route = String(body.route ?? "");
        if (!route) return json({ error: "route required" }, 400);
        const validStages = new Set(["applied", "in_progress", "planned"]);
        for (
          const k of [
            "stage",
            "figma_mcp",
            "ai_designer",
            "design_skills",
            "design_md",
          ]
        ) {
          if (!validStages.has(String(body[k]))) {
            return json({ error: `invalid ${k}` }, 400);
          }
        }
        const { error: rErr } = await admin.from("design_rollout").upsert({
          route,
          stage: body.stage,
          figma_mcp: body.figma_mcp,
          ai_designer: body.ai_designer,
          design_skills: body.design_skills,
          design_md: body.design_md,
          headline: body.headline,
          next_step: body.next_step,
          updated_at: new Date().toISOString(),
        });
        if (rErr) return json({ error: rErr.message }, 500);
        return json({ success: true });
      }

      default:
        return assertUnreachableAction(action);
    }
  } catch (err) {
    (dependencies.reportError ?? console.error)(err);
    return json({ error: "Internal server error" }, 500);
  }
}

function assertUnreachableAction(action: never): Response {
  return json({ error: `Unknown action: ${String(action)}` }, 400);
}

if (import.meta.main) {
  serve((req) => handleCoreHubRequest(req));
}

// ---- Helpers for notify.feature_request ----
function _escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function _buildFallbackTitle(content: string): string {
  const firstLine = content.split(/\r?\n/)[0].trim();
  if (firstLine === "") return "ご意見・ご要望";
  return firstLine.length > 72 ? `${firstLine.substring(0, 72)}...` : firstLine;
}

function _buildDefaultResolutionSummary(
  issueNumber: number | null,
  releaseTitle: string,
  releaseUrl: string,
): string {
  const parts: string[] = [];
  if (issueNumber !== null) {
    parts.push(`GitHub Issue #${issueNumber} の対応を反映しました。`);
  } else {
    parts.push("ご要望への対応内容を反映しました。");
  }
  if (releaseTitle.trim() !== "") parts.push(`反映内容: ${releaseTitle}`);
  if (releaseUrl.trim() !== "") parts.push(`詳細: ${releaseUrl}`);
  return parts.join("\n");
}

function _buildNotificationEmailHtml(input: {
  title: string;
  description: string;
  status: string;
  resolutionSummary: string;
  issueNumber: number | null;
  issueTitle: string;
  issueUrl: string;
  releaseTitle: string;
  releaseUrl: string;
}): string {
  const APP_URL = "https://my-web-app-b67f4.web.app";
  const statusLabel = input.status === "done"
    ? "対応完了"
    : input.status === "in_progress"
    ? "対応中"
    : "更新";
  const issueBlock =
    (input.issueNumber !== null || input.issueUrl.trim() !== "")
      ? `<div style="background:#eef2ff;border-radius:12px;padding:16px;margin-top:20px;"><div style="font-size:12px;color:#4f46e5;font-weight:700;">GitHub Issue</div><div style="margin-top:6px;color:#111827;">${
        input.issueNumber !== null ? `#${input.issueNumber}` : ""
      } ${_escapeHtml(input.issueTitle)}</div>${
        input.issueUrl.trim() !== ""
          ? `<div style="margin-top:10px;"><a href="${input.issueUrl}" style="color:#4f46e5;text-decoration:none;font-weight:700;">Issue を見る</a></div>`
          : ""
      }</div>`
      : "";
  const releaseBlock =
    (input.releaseTitle.trim() !== "" || input.releaseUrl.trim() !== "")
      ? `<div style="background:#ecfdf5;border-radius:12px;padding:16px;margin-top:20px;"><div style="font-size:12px;color:#047857;font-weight:700;">リリース情報</div><div style="margin-top:6px;color:#111827;">${
        _escapeHtml(input.releaseTitle)
      }</div>${
        input.releaseUrl.trim() !== ""
          ? `<div style="margin-top:10px;"><a href="${input.releaseUrl}" style="color:#047857;text-decoration:none;font-weight:700;">変更内容を見る</a></div>`
          : ""
      }</div>`
      : "";
  return `<!DOCTYPE html>
<html lang="ja"><head><meta charset="UTF-8"></head>
<body style="font-family:sans-serif;max-width:640px;margin:0 auto;padding:24px;color:#111827;">
  <div style="background:linear-gradient(135deg,#111827,#4f46e5);padding:24px;border-radius:16px;margin-bottom:24px;">
    <h1 style="margin:0;color:#ffffff;font-size:22px;">${statusLabel}のお知らせ</h1>
    <p style="margin:10px 0 0;color:#c7d2fe;line-height:1.7;">ご意見・ご要望に関する最新状況をお知らせします。</p>
  </div>
  <h2 style="font-size:18px;margin:0 0 12px;">${_escapeHtml(input.title)}</h2>
  <div style="background:#f8fafc;border-radius:12px;padding:16px;line-height:1.8;">
    <div style="font-size:12px;color:#6b7280;">ご投稿内容</div>
    <div style="margin-top:8px;color:#374151;">${
    _escapeHtml(input.description).replace(/\n/g, "<br>")
  }</div>
  </div>
  <div style="background:#fff7ed;border-radius:12px;padding:16px;margin-top:20px;">
    <div style="font-size:12px;color:#c2410c;font-weight:700;">対応内容</div>
    <div style="margin-top:8px;color:#374151;line-height:1.8;">${
    _escapeHtml(input.resolutionSummary).replace(/\n/g, "<br>")
  }</div>
  </div>
  ${issueBlock}
  ${releaseBlock}
  <div style="margin-top:28px;text-align:center;">
    <a href="${APP_URL}" style="display:inline-block;background:#111827;color:#ffffff;padding:12px 24px;border-radius:10px;text-decoration:none;font-weight:700;">自分株式会社を開く</a>
  </div>
</body></html>`;
}
