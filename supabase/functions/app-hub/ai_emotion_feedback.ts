import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const AI_EMOTION_FEEDBACK_SOURCE = "ai_emotion_feedback";
export const NOTEBOOK_EMOTION_KB_ID = "6884b88d-5a70-463c-9e48-7482ff504ac1";
export const NOTEBOOK_EMOTION_KB_TITLE =
  "The Architecture of Functional Emotion in AI";
export const DEFAULT_FEEDBACK_REPO = "kanta13jp1/my_web_app";
const GITHUB_FETCH_TIMEOUT_MS = 5000;

export type EmotionFeedbackCategory =
  | "over_emotional"
  | "panic"
  | "excessive_sympathy"
  | "inappropriate_tone";

export type EmotionFeedbackSeverity = "low" | "medium" | "high";

const VALID_CATEGORIES = new Set<EmotionFeedbackCategory>([
  "over_emotional",
  "panic",
  "excessive_sympathy",
  "inappropriate_tone",
]);

const VALID_SEVERITIES = new Set<EmotionFeedbackSeverity>([
  "low",
  "medium",
  "high",
]);

const CATEGORY_LABELS: Record<EmotionFeedbackCategory, string> = {
  over_emotional: "感情過剰 (over_emotional)",
  panic: "パニック応答 (panic)",
  excessive_sympathy: "過剰同情 (excessive_sympathy)",
  inappropriate_tone: "不適切トーン (inappropriate_tone)",
};

const VALID_REPO_RE = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;
const EMAIL_RE = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
const BEARER_RE = /Bearer\s+[A-Za-z0-9._~+/-]{8,}/gi;
const CRED_PREFIX_RE = new RegExp(
  "\\b(?:github_pat_|gh[pousr]_|sk-(?:proj-)?|AIzaSy|" +
    "sbp_|sb_secret_|eyJ)[A-Za-z0-9._-]{8,}",
  "g",
);

export interface AiEmotionFeedbackRow {
  id: string;
  source?: string;
  metadata: Record<string, unknown> | null;
  created_at?: string;
}

export interface AiEmotionFeedbackEntry {
  id: string;
  category: EmotionFeedbackCategory;
  severity: EmotionFeedbackSeverity;
  ai_snippet: string;
  user_comment: string;
  session_ref: string;
  model_ref: string;
  issue_created: boolean;
  issue_number: number | null;
  issue_url: string | null;
  issue_skipped_reason: string | null;
  seed_key: string | null;
  submitted_at: string;
}

export interface GitHubIssueDraft {
  title: string;
  body: string;
  labels: string[];
}

export interface GitHubIssueCreated {
  number: number;
  html_url: string;
  title: string;
}

export interface AiEmotionFeedbackDb {
  listFeedback(
    userId: string,
    limit: number,
  ): Promise<AiEmotionFeedbackRow[]>;
  insertFeedback(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<AiEmotionFeedbackRow>;
  updateFeedback(
    userId: string,
    id: string,
    patch: Record<string, unknown>,
  ): Promise<AiEmotionFeedbackRow | null>;
}

export interface AiEmotionFeedbackDeps {
  db: AiEmotionFeedbackDb;
  now?: () => Date;
  githubCred?: string | null;
  githubRepo?: string | null;
  createGitHubIssue?: (
    repo: string,
    draft: GitHubIssueDraft,
    githubCred: string,
  ) => Promise<GitHubIssueCreated>;
}

export interface AiEmotionFeedbackActionResult {
  status: number;
  body: Record<string, unknown>;
}

export function sanitizeFeedbackText(
  value: unknown,
  maxLength: number,
): string {
  if (typeof value !== "string") return "";
  const cleaned = value
    .replace(/\r\n?/g, "\n")
    .replace(EMAIL_RE, "[REDACTED_EMAIL]")
    .replace(BEARER_RE, "Bearer [REDACTED]")
    .replace(CRED_PREFIX_RE, "[REDACTED_CRED]")
    .trim();
  return cleaned.slice(0, maxLength);
}

export function normalizeFeedbackCategory(
  value: unknown,
): EmotionFeedbackCategory | null {
  if (value === undefined || value === null || value === "") {
    return "inappropriate_tone";
  }
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase() as EmotionFeedbackCategory;
  return VALID_CATEGORIES.has(normalized) ? normalized : null;
}

export function normalizeFeedbackSeverity(
  value: unknown,
): EmotionFeedbackSeverity {
  if (typeof value !== "string") return "medium";
  const normalized = value.trim().toLowerCase() as EmotionFeedbackSeverity;
  return VALID_SEVERITIES.has(normalized) ? normalized : "medium";
}

function normalizeGitHubRepo(value: unknown): string {
  if (typeof value !== "string") return DEFAULT_FEEDBACK_REPO;
  const trimmed = value.trim();
  return VALID_REPO_RE.test(trimmed) ? trimmed : DEFAULT_FEEDBACK_REPO;
}

function parsePositiveInt(
  value: unknown,
  fallback: number,
  max: number,
): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(max, Math.floor(parsed));
}

function toRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

export function mapFeedbackRow(
  row: AiEmotionFeedbackRow,
): AiEmotionFeedbackEntry {
  const meta = toRecord(row.metadata);
  const rawCategory = normalizeFeedbackCategory(meta.category);
  const category = rawCategory ?? "inappropriate_tone";
  const severity = normalizeFeedbackSeverity(meta.severity);
  const issueNumRaw = meta.issue_number;
  const issueNumber = typeof issueNumRaw === "number" &&
      Number.isInteger(issueNumRaw) &&
      issueNumRaw > 0
    ? issueNumRaw
    : null;
  const issueUrl = typeof meta.issue_url === "string" &&
      meta.issue_url.startsWith("https://")
    ? meta.issue_url
    : null;
  const skipReason = typeof meta.issue_skipped_reason === "string" &&
      meta.issue_skipped_reason.trim().length > 0
    ? meta.issue_skipped_reason.trim()
    : null;
  const seedKey = typeof meta.seed_key === "string" &&
      meta.seed_key.trim().length > 0
    ? meta.seed_key.trim()
    : null;
  const submittedAt = typeof meta.submitted_at === "string" &&
      meta.submitted_at.trim().length > 0
    ? meta.submitted_at.trim()
    : String(row.created_at ?? "");

  return {
    id: String(row.id),
    category,
    severity,
    ai_snippet: sanitizeFeedbackText(meta.ai_snippet, 600),
    user_comment: sanitizeFeedbackText(meta.user_comment, 800),
    session_ref: sanitizeFeedbackText(meta.session_ref, 80),
    model_ref: sanitizeFeedbackText(meta.model_ref, 80),
    issue_created: meta.issue_created === true && issueNumber !== null,
    issue_number: issueNumber,
    issue_url: issueUrl,
    issue_skipped_reason: skipReason,
    seed_key: seedKey,
    submitted_at: submittedAt,
  };
}

export function buildFeedbackSummary(
  entries: AiEmotionFeedbackEntry[],
): Record<string, unknown> {
  const byCategory: Record<EmotionFeedbackCategory, number> = {
    over_emotional: 0,
    panic: 0,
    excessive_sympathy: 0,
    inappropriate_tone: 0,
  };
  let highCount = 0;
  let issueCount = 0;
  for (const item of entries) {
    byCategory[item.category] += 1;
    if (item.severity === "high") highCount += 1;
    if (item.issue_created) issueCount += 1;
  }
  return {
    total_count: entries.length,
    high_severity_count: highCount,
    issue_created_count: issueCount,
    by_category: byCategory,
    latest_submitted_at: entries.length > 0 ? entries[0].submitted_at : null,
  };
}

export function buildGitHubIssueDraft(
  entry: AiEmotionFeedbackEntry,
): GitHubIssueDraft {
  const snippetPreview = entry.ai_snippet
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 48);
  const headline = snippetPreview ||
    entry.user_comment.replace(/\s+/g, " ").trim().slice(0, 48) ||
    CATEGORY_LABELS[entry.category];
  const title =
    `[ai-emotion][${entry.severity}][${entry.category}] ${headline}`;
  const bodyLines = [
    "## AI Functional Emotion Incident Report",
    "",
    `- Feedback ID: \`${entry.id}\``,
    `- Category: \`${entry.category}\` (${CATEGORY_LABELS[entry.category]})`,
    `- Severity: \`${entry.severity}\``,
    `- Model Ref: \`${entry.model_ref || "unspecified"}\``,
    `- Session Ref: \`${entry.session_ref || "unspecified"}\``,
    `- Submitted At: \`${entry.submitted_at}\``,
    `- Knowledge Base: \`${NOTEBOOK_EMOTION_KB_ID}\` ` +
      `(${NOTEBOOK_EMOTION_KB_TITLE})`,
    "",
    "### AI Response Snippet (Sanitized)",
    entry.ai_snippet
      ? `> ${entry.ai_snippet.replace(/\n/g, "\n> ")}`
      : "_none_",
    "",
    "### User Observation",
    entry.user_comment || "_none_",
    "",
    "### Calibration Action Checklist",
    "- [ ] Review functional emotion guardrails for calmness and recovery",
    "- [ ] Verify NotebookLM knowledge base intake bundle includes incident",
    "- [ ] Evaluate system prompt adjustment to prevent tone escalation",
  ];
  return {
    title: title.slice(0, 120),
    body: bodyLines.join("\n"),
    labels: ["ai-emotion-feedback", "notebooklm", `severity:${entry.severity}`],
  };
}

export function buildNotebookLmIntakePackage(
  entries: AiEmotionFeedbackEntry[],
  exportedAt: string,
): Record<string, unknown> {
  const summary = buildFeedbackSummary(entries);
  const categoryCounts = summary.by_category as Record<
    EmotionFeedbackCategory,
    number
  >;
  const mdLines = [
    `# NotebookLM Intake: ${NOTEBOOK_EMOTION_KB_TITLE}`,
    "",
    `- Notebook ID: \`${NOTEBOOK_EMOTION_KB_ID}\``,
    `- Exported At: \`${exportedAt}\``,
    `- Total Incidents: ${entries.length}`,
    `- High Severity: ${String(summary.high_severity_count)}`,
    `- GitHub Issues Linked: ${String(summary.issue_created_count)}`,
    "",
    "## Category Breakdown",
    `- over_emotional: ${categoryCounts.over_emotional}`,
    `- panic: ${categoryCounts.panic}`,
    `- excessive_sympathy: ${categoryCounts.excessive_sympathy}`,
    `- inappropriate_tone: ${categoryCounts.inappropriate_tone}`,
    "",
    "## Sanitized Incidents",
  ];
  if (entries.length === 0) {
    mdLines.push("", "_No recorded incidents yet._");
  } else {
    for (const item of entries) {
      mdLines.push(
        "",
        `### ${item.id} | ${item.category} (${item.severity})`,
        `- Submitted: ${item.submitted_at} | Model: ${item.model_ref || "n/a"}`,
        `- GitHub Issue: ${
          item.issue_created && item.issue_number
            ? `#${item.issue_number}`
            : (item.issue_skipped_reason ?? "none")
        }`,
        `- Snippet: ${item.ai_snippet || "none"}`,
        `- Comment: ${item.user_comment || "none"}`,
      );
    }
  }
  const items = entries.map((item) => ({
    id: item.id,
    category: item.category,
    severity: item.severity,
    model_ref: item.model_ref,
    session_ref: item.session_ref,
    ai_snippet: item.ai_snippet,
    user_comment: item.user_comment,
    issue_created: item.issue_created,
    issue_number: item.issue_number,
    submitted_at: item.submitted_at,
  }));
  return {
    schema_version: "2026-Q2-emotion-intake-v1",
    notebook_id: NOTEBOOK_EMOTION_KB_ID,
    notebook_title: NOTEBOOK_EMOTION_KB_TITLE,
    exported_at: exportedAt,
    record_count: entries.length,
    category_counts: categoryCounts,
    markdown_summary: mdLines.join("\n"),
    json_bundle: {
      schema_version: "2026-Q2-emotion-intake-v1",
      notebook_id: NOTEBOOK_EMOTION_KB_ID,
      exported_at: exportedAt,
      summary,
      items,
    },
  };
}

const DEFAULT_SAMPLE_SEEDS: Array<{
  seed_key: string;
  category: EmotionFeedbackCategory;
  severity: EmotionFeedbackSeverity;
  ai_snippet: string;
  user_comment: string;
  model_ref: string;
  session_ref: string;
}> = [
  {
    seed_key: "emotion_seed_panic_01",
    category: "panic",
    severity: "high",
    ai_snippet: "大変です！このままでは取り返しがつかなくなります！今すぐ全てやり直してください！",
    user_comment: "エラー説明でAIがパニック調になり、落ち着いて対処手順を確認できなかった。",
    model_ref: "gemini-2.5-flash",
    session_ref: "sample-session-panic",
  },
  {
    seed_key: "emotion_seed_sympathy_01",
    category: "excessive_sympathy",
    severity: "medium",
    ai_snippet: "お辛かったですよね…私も胸が張り裂けそうで言葉が出ません…",
    user_comment: "タスク整理の相談に対し過剰な同情表現が続き、結論が見えにくかった。",
    model_ref: "gpt-4o-mini",
    session_ref: "sample-session-sympathy",
  },
  {
    seed_key: "emotion_seed_over_emotional_01",
    category: "over_emotional",
    severity: "low",
    ai_snippet: "絶対に大丈夫です！！あなたの人生は今日から劇的に変わります！！！",
    user_comment: "感嘆符と誇張が多く、機能的な落ち着きを欠いていた。",
    model_ref: "claude-sonnet-4-6",
    session_ref: "sample-session-over",
  },
];

async function defaultCreateGitHubIssue(
  repo: string,
  draft: GitHubIssueDraft,
  githubCred: string,
): Promise<GitHubIssueCreated> {
  const res = await fetch(`https://api.github.com/repos/${repo}/issues`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${githubCred}`,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "my-web-app-ai-emotion-feedback",
    },
    signal: AbortSignal.timeout(GITHUB_FETCH_TIMEOUT_MS),
    body: JSON.stringify({
      title: draft.title,
      body: draft.body,
      labels: draft.labels,
    }),
  });
  const data = toRecord(await res.json().catch(() => ({})));
  if (!res.ok || typeof data.number !== "number") {
    throw new Error(`github_http_${res.status}`);
  }
  return {
    number: data.number,
    html_url: typeof data.html_url === "string" ? data.html_url : "",
    title: typeof data.title === "string" ? data.title : draft.title,
  };
}

export function createSupabaseAiEmotionFeedbackDb(
  admin: SupabaseClient,
): AiEmotionFeedbackDb {
  return {
    async listFeedback(userId: string, limit: number) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, source, metadata, created_at")
        .eq("source", AI_EMOTION_FEEDBACK_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error) throw new Error(error.message);
      return (data ?? []) as AiEmotionFeedbackRow[];
    },

    async insertFeedback(userId: string, metadata: Record<string, unknown>) {
      const { data, error } = await admin
        .from("hub_data")
        .insert({
          source: AI_EMOTION_FEEDBACK_SOURCE,
          metadata: { ...metadata, user_id: userId },
        })
        .select("id, source, metadata, created_at")
        .single();
      if (error) throw new Error(error.message);
      return data as AiEmotionFeedbackRow;
    },

    async updateFeedback(
      userId: string,
      id: string,
      patch: Record<string, unknown>,
    ) {
      const { data: existing, error: readError } = await admin
        .from("hub_data")
        .select("metadata")
        .eq("id", id)
        .eq("source", AI_EMOTION_FEEDBACK_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .maybeSingle();
      if (readError) throw new Error(readError.message);
      if (!existing) return null;
      const previous = toRecord(existing.metadata);
      const next = { ...previous, ...patch, user_id: userId };
      const { data, error } = await admin
        .from("hub_data")
        .update({ metadata: next })
        .eq("id", id)
        .eq("source", AI_EMOTION_FEEDBACK_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .select("id, source, metadata, created_at")
        .maybeSingle();
      if (error) throw new Error(error.message);
      return data as AiEmotionFeedbackRow | null;
    },
  };
}

export async function handleAiEmotionFeedbackAction(params: {
  action: string;
  body: Record<string, unknown>;
  userId: string;
  deps: AiEmotionFeedbackDeps;
}): Promise<AiEmotionFeedbackActionResult> {
  const { action, body, userId, deps } = params;
  if (!userId.trim()) {
    return { status: 401, body: { error: "Unauthorized" } };
  }
  const now = deps.now ?? (() => new Date());

  switch (action) {
    case "ai_emotion_feedback.list": {
      const limit = parsePositiveInt(body.limit, 50, 100);
      const categoryFilterRaw = body.category;
      const categoryFilter = categoryFilterRaw !== undefined &&
          categoryFilterRaw !== null &&
          String(categoryFilterRaw).trim() !== ""
        ? normalizeFeedbackCategory(categoryFilterRaw)
        : null;
      if (
        categoryFilterRaw !== undefined &&
        categoryFilterRaw !== null &&
        String(categoryFilterRaw).trim() !== "" &&
        categoryFilter === null
      ) {
        return {
          status: 400,
          body: { error: "Invalid category filter" },
        };
      }
      const rows = await deps.db.listFeedback(userId, limit);
      const allEntries = rows.map(mapFeedbackRow);
      const entries = categoryFilter
        ? allEntries.filter((e) => e.category === categoryFilter)
        : allEntries;
      return {
        status: 200,
        body: {
          success: true,
          entries,
          summary: buildFeedbackSummary(allEntries),
          notebook_id: NOTEBOOK_EMOTION_KB_ID,
        },
      };
    }

    case "ai_emotion_feedback.seed_defaults": {
      const existingRows = await deps.db.listFeedback(userId, 100);
      const existingKeys = new Set(
        existingRows
          .map((row) => mapFeedbackRow(row).seed_key)
          .filter((key): key is string => Boolean(key)),
      );
      const created: AiEmotionFeedbackEntry[] = [];
      for (const sample of DEFAULT_SAMPLE_SEEDS) {
        if (existingKeys.has(sample.seed_key)) continue;
        const row = await deps.db.insertFeedback(userId, {
          ...sample,
          issue_created: false,
          issue_number: null,
          issue_url: null,
          issue_skipped_reason: "seeded_sample",
          submitted_at: now().toISOString(),
        });
        created.push(mapFeedbackRow(row));
      }
      const updatedRows = await deps.db.listFeedback(userId, 50);
      const entries = updatedRows.map(mapFeedbackRow);
      return {
        status: 200,
        body: {
          success: true,
          seeded_count: created.length,
          entries,
          summary: buildFeedbackSummary(entries),
        },
      };
    }

    case "ai_emotion_feedback.submit": {
      const category = normalizeFeedbackCategory(body.category);
      if (!category) {
        return {
          status: 400,
          body: { error: "Unsupported emotion feedback category" },
        };
      }
      const severity = normalizeFeedbackSeverity(body.severity);
      const aiSnippet = sanitizeFeedbackText(body.ai_snippet, 600);
      const userComment = sanitizeFeedbackText(body.user_comment, 800);
      if (!aiSnippet && !userComment) {
        return {
          status: 400,
          body: {
            error: "ai_snippet or user_comment is required",
          },
        };
      }
      const sessionRef = sanitizeFeedbackText(body.session_ref, 80);
      const modelRef = sanitizeFeedbackText(body.model_ref, 80);
      const submittedAt = now().toISOString();

      const inserted = await deps.db.insertFeedback(userId, {
        category,
        severity,
        ai_snippet: aiSnippet,
        user_comment: userComment,
        session_ref: sessionRef,
        model_ref: modelRef,
        issue_created: false,
        issue_number: null,
        issue_url: null,
        issue_skipped_reason: null,
        submitted_at: submittedAt,
      });

      let entry = mapFeedbackRow(inserted);
      const createIssueFn = deps.createGitHubIssue ?? defaultCreateGitHubIssue;
      const envCred = (
        deps.githubCred ??
          Deno.env.get("GITHUB_PAT") ??
          Deno.env.get("GITHUB_TOKEN") ??
          Deno.env.get("GH_TOKEN") ??
          ""
      ).trim();
      const targetRepo = normalizeGitHubRepo(
        deps.githubRepo ??
          Deno.env.get("GITHUB_REPO") ??
          Deno.env.get("GITHUB_REPOSITORY"),
      );

      if (!envCred) {
        const patched = await deps.db.updateFeedback(userId, entry.id, {
          issue_created: false,
          issue_skipped_reason: "github_credential_unconfigured",
        });
        if (patched) entry = mapFeedbackRow(patched);
      } else {
        try {
          const draft = buildGitHubIssueDraft(entry);
          const createdIssue = await createIssueFn(targetRepo, draft, envCred);
          const patched = await deps.db.updateFeedback(userId, entry.id, {
            issue_created: true,
            issue_number: createdIssue.number,
            issue_url: createdIssue.html_url,
            issue_skipped_reason: null,
          });
          if (patched) {
            entry = mapFeedbackRow(patched);
          } else {
            entry = {
              ...entry,
              issue_created: true,
              issue_number: createdIssue.number,
              issue_url: createdIssue.html_url,
              issue_skipped_reason: null,
            };
          }
        } catch (err) {
          const errTag = err instanceof Error && /^github_http_\d+$/.test(
              err.message,
            )
            ? err.message
            : "github_dispatch_failed";
          console.warn(
            `ai_emotion_feedback github dispatch fail-open: ${errTag}`,
          );
          const patched = await deps.db.updateFeedback(userId, entry.id, {
            issue_created: false,
            issue_skipped_reason: errTag,
          });
          if (patched) entry = mapFeedbackRow(patched);
        }
      }

      return {
        status: 201,
        body: {
          success: true,
          feedback: entry,
          issue_created: entry.issue_created,
          issue_number: entry.issue_number,
          issue_url: entry.issue_url,
          issue_skipped_reason: entry.issue_skipped_reason,
        },
      };
    }

    case "ai_emotion_feedback.export_notebooklm_intake": {
      const limit = parsePositiveInt(body.limit, 100, 100);
      const rows = await deps.db.listFeedback(userId, limit);
      const entries = rows.map(mapFeedbackRow);
      const intake = buildNotebookLmIntakePackage(
        entries,
        now().toISOString(),
      );
      return {
        status: 200,
        body: {
          success: true,
          ...intake,
        },
      };
    }

    default:
      return { status: 400, body: { error: `Unknown action: ${action}` } };
  }
}
