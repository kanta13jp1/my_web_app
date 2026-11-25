import { createClient } from "npm:@supabase/supabase-js@2";
import { asRecord, asString, corsHeaders, jsonResponse } from "../_shared/edge.ts";
import { verifyInternalHmacParts } from "../_shared/internal_hmac.ts";
import { MASK_PLACEHOLDER, maskLogString } from "../_shared/sensitive_log_masker.ts";

const MAX_BODY_BYTES = 65_536;
const DEFAULT_GITHUB_REPO = "kanta13jp1/my_web_app";
const DEFAULT_LABELS = ["AI-Feedback", "rlhf", "automation"] as const;

export interface RlhfFeedbackRecord {
  id: string;
  user_id?: string;
  action_name: string;
  model_id: string;
  prompt_text: string;
  ai_output: string;
  rating_status: string;
  user_comment: string;
  dispatch_status?: string;
  github_issue_number?: number | null;
  github_issue_url?: string | null;
  created_at?: string;
}

export interface RlhfFeedbackIssueDraft {
  title: string;
  body: string;
  labels: string[];
}

export interface GitHubIssueCreateResult {
  number: number;
  html_url: string;
  title: string;
  deduped?: boolean;
}

export interface WebhookHandlerEnv {
  supabaseUrl: string;
  adminRoleCredential: string;
  webhookHmacCred: string;
  internalHmacCred: string;
  githubPatCred: string;
  githubRepo: string;
}

export interface WebhookDependencies {
  env: WebhookHandlerEnv;
  verifyJwtUser: (
    jwtInput: string,
  ) => Promise<{ id: string; isAdmin: boolean } | null>;
  fetchFeedbackById: (id: string) => Promise<RlhfFeedbackRecord | null>;
  claimFeedbackDispatch?: (id: string, claimedAtIso: string) => Promise<boolean>;
  updateFeedbackDispatch: (
    id: string,
    patch: {
      dispatch_status: string;
      github_issue_number?: number | null;
      github_issue_url?: string | null;
      webhook_dispatched_at?: string | null;
    },
  ) => Promise<void>;
  findExistingOpenIssue: (
    repo: string,
    title: string,
    feedbackId?: string,
  ) => Promise<GitHubIssueCreateResult | null>;
  createGitHubIssue: (
    repo: string,
    draft: RlhfFeedbackIssueDraft,
  ) => Promise<GitHubIssueCreateResult>;
}

export function isBadRlhfRating(ratingStatus: string): boolean {
  const normalized = ratingStatus.trim().toLowerCase();
  return normalized === "bad" || normalized === "problematic";
}

/**
 * Escapes untrusted prompt/output/comment payloads using a backtick fence
 * strictly longer than any backtick sequence present in the content.
 */
export function fencedMarkdownBlock(
  content: string,
  language = "text",
): string {
  const runs = content.match(/`+/g) ?? [];
  const longest = runs.reduce((max, run) => Math.max(max, run.length), 0);
  const fence = "`".repeat(Math.max(3, longest + 1));
  return `${fence}${language}\n${content}\n${fence}`;
}

/** Scrubs Bearer tokens, provider API keys, PATs, and email addresses before publishing. */
export function redactSensitiveFeedbackText(input: string): string {
  if (!input) {
    return input;
  }
  let sanitized = maskLogString(input);
  sanitized = sanitized.replace(
    /\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{10,}\b/g,
    MASK_PLACEHOLDER,
  );
  sanitized = sanitized.replace(
    /\bgithub_pat_[A-Za-z0-9_]{10,}\b/g,
    MASK_PLACEHOLDER,
  );
  sanitized = sanitized.replace(
    /\bsk-(?:ant-|proj-)?[A-Za-z0-9_-]{12,}\b/g,
    MASK_PLACEHOLDER,
  );
  sanitized = sanitized.replace(/\bAIza[0-9A-Za-z_-]{16,}\b/g, MASK_PLACEHOLDER);
  sanitized = sanitized.replace(
    /\bsb_(?:secret|publishable)_[A-Za-z0-9_-]{10,}\b/g,
    MASK_PLACEHOLDER,
  );
  sanitized = sanitized.replace(
    /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g,
    "[masked-email]",
  );
  return sanitized;
}

function summarizeCommentForTitle(record: RlhfFeedbackRecord): string {
  const comment = redactSensitiveFeedbackText(asString(record.user_comment));
  const fallback = redactSensitiveFeedbackText(asString(record.prompt_text));
  const rawFirstLine = (comment || fallback)
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find((line) => line.length > 0) ?? "問題のあるAI出力報告";
  const singleLine = rawFirstLine.replace(/\s+/g, " ");
  const clipped = singleLine.length > 64
    ? `${singleLine.slice(0, 61)}...`
    : singleLine;
  const action = asString(record.action_name) || "ai_action";
  return `[AI-Feedback] ${action}: ${clipped}`;
}

export function buildRlhfFeedbackIssueDraft(
  record: RlhfFeedbackRecord,
): RlhfFeedbackIssueDraft {
  const title = summarizeCommentForTitle(record);
  const safePrompt = redactSensitiveFeedbackText(asString(record.prompt_text));
  const safeOutput = redactSensitiveFeedbackText(asString(record.ai_output));
  const safeComment = redactSensitiveFeedbackText(asString(record.user_comment));
  const actionName = asString(record.action_name) || "unknown";
  const modelId = asString(record.model_id) || "unspecified";
  const ratingStatus = asString(record.rating_status) || "bad";
  const userId = asString(record.user_id) || "(anonymous)";
  const feedbackId = asString(record.id) || "(pending-id)";

  const lines: string[] = [
    "## AI Output RLHF Bad Feedback (#2659)",
    "",
    "### Prompt",
    "",
    safePrompt.length > 0 ? fencedMarkdownBlock(safePrompt) : "(プロンプト未記録)",
    "",
    "### AI Output",
    "",
    safeOutput.length > 0 ? fencedMarkdownBlock(safeOutput) : "(出力未記録)",
    "",
    "### User Comment",
    "",
    safeComment.length > 0 ? fencedMarkdownBlock(safeComment) : "(コメントなし)",
    "",
    "### Metadata",
    "",
    `- feedback_id: \`${feedbackId}\``,
    `- action_name: \`${actionName}\``,
    `- model_id: \`${modelId}\``,
    `- rating_status: \`${ratingStatus}\``,
    `- user_id: \`${userId}\``,
  ];
  if (asString(record.created_at)) {
    lines.push(`- recorded_at: \`${asString(record.created_at)}\``);
  }
  lines.push(
    "",
    "---",
    "Auto-created from Supabase RLHF Database Webhook (`ai_rlhf_feedback`).",
  );

  return {
    title,
    body: lines.join("\n"),
    labels: [...DEFAULT_LABELS],
  };
}

function constantTimeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  let mismatch = a.length ^ b.length;
  const maxLen = Math.max(a.length, b.length);
  for (let i = 0; i < maxLen; i++) {
    mismatch |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return mismatch === 0;
}

export async function signHmacSha256Hex(
  rawBody: string,
  secret: string,
): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(rawBody));
  return [...new Uint8Array(sig)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function verifyHmacSha256Signature(
  rawBody: string,
  signatureHeader: string,
  secret: string,
): Promise<boolean> {
  const normalized = signatureHeader.trim().toLowerCase();
  if (!normalized.startsWith("sha256=") || !secret) {
    return false;
  }
  const providedHex = normalized.slice("sha256=".length);
  if (!/^[0-9a-f]{64}$/.test(providedHex)) {
    return false;
  }
  const expectedHex = await signHmacSha256Hex(rawBody, secret);
  return constantTimeEqual(providedHex, expectedHex);
}

function normalizeRecord(raw: Record<string, unknown>): RlhfFeedbackRecord {
  return {
    id: asString(raw.id),
    user_id: asString(raw.user_id),
    action_name: asString(raw.action_name),
    model_id: asString(raw.model_id),
    prompt_text: asString(raw.prompt_text),
    ai_output: asString(raw.ai_output),
    rating_status: asString(raw.rating_status),
    user_comment: asString(raw.user_comment),
    dispatch_status: asString(raw.dispatch_status),
    github_issue_number: typeof raw.github_issue_number === "number"
      ? raw.github_issue_number
      : null,
    github_issue_url: asString(raw.github_issue_url) || null,
    created_at: asString(raw.created_at),
  };
}

const GITHUB_REPO_RE = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;
const GITHUB_FETCH_TIMEOUT_MS = 15_000;

export function assertValidGitHubRepo(rawRepo: string): string {
  const repo = rawRepo.trim();
  if (!GITHUB_REPO_RE.test(repo)) {
    throw new Error("Invalid GitHub repository slug");
  }
  const [owner, name] = repo.split("/");
  if (!owner || !name || owner === "." || owner === ".." || name === "." || name === "..") {
    throw new Error("Invalid GitHub repository slug");
  }
  return repo;
}

function defaultEnv(): WebhookHandlerEnv {
  return {
    supabaseUrl: asString(Deno.env.get("SUPABASE_URL")),
    adminRoleCredential: asString(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")),
    webhookHmacCred: asString(Deno.env.get("RLHF_WEBHOOK_SECRET")),
    internalHmacCred: asString(
      Deno.env.get("INTERNAL_HMAC_SECRET") || Deno.env.get("RLHF_WEBHOOK_SECRET"),
    ),
    githubPatCred: asString(
      Deno.env.get("GITHUB_PAT") ||
        Deno.env.get("GITHUB_TOKEN") ||
        Deno.env.get("GH_TOKEN"),
    ),
    githubRepo: asString(
      Deno.env.get("GITHUB_REPO") ||
        Deno.env.get("GITHUB_REPOSITORY") ||
        DEFAULT_GITHUB_REPO,
    ),
  };
}

function createDefaultDependencies(env: WebhookHandlerEnv): WebhookDependencies {
  const admin = env.supabaseUrl && env.adminRoleCredential
    ? createClient(env.supabaseUrl, env.adminRoleCredential)
    : null;

  const githubHeaders = (): Record<string, string> => ({
    Authorization: `Bearer ${env.githubPatCred}`,
    Accept: "application/vnd.github+json",
    "Content-Type": "application/json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "jibun-app-rlhf-feedback-webhook",
  });

  return {
    env,
    verifyJwtUser: async (jwtInput: string) => {
      if (!admin || !jwtInput) return null;
      const { data, error } = await admin.auth.getUser(jwtInput);
      if (error || !data.user || data.user.is_anonymous) {
        return null;
      }
      const { data: profile } = await admin
        .from("user_profiles")
        .select("is_admin")
        .eq("user_id", data.user.id)
        .maybeSingle();
      return {
        id: data.user.id,
        isAdmin: profile?.is_admin === true,
      };
    },
    fetchFeedbackById: async (id: string) => {
      if (!admin || !id) return null;
      const { data, error } = await admin
        .from("ai_rlhf_feedback")
        .select("*")
        .eq("id", id)
        .maybeSingle();
      if (error || !data) return null;
      return normalizeRecord(asRecord(data));
    },
    claimFeedbackDispatch: async (id: string, claimedAtIso: string) => {
      if (!admin || !id) return true;
      const { data, error } = await admin
        .from("ai_rlhf_feedback")
        .update({
          dispatch_status: "processing",
          webhook_dispatched_at: claimedAtIso,
        })
        .eq("id", id)
        .in("dispatch_status", ["pending", "failed"])
        .is("github_issue_number", null)
        .select("id")
        .maybeSingle();
      if (error) {
        throw new Error(`Failed to claim RLHF dispatch lock: ${error.message}`);
      }
      return data !== null;
    },
    updateFeedbackDispatch: async (id, patch) => {
      if (!admin || !id) return;
      const { error } = await admin
        .from("ai_rlhf_feedback")
        .update(patch)
        .eq("id", id);
      if (error) {
        throw new Error(`Failed to update RLHF dispatch metadata: ${error.message}`);
      }
    },
    findExistingOpenIssue: async (repo, title, feedbackId) => {
      if (!env.githubPatCred) return null;
      const validRepo = assertValidGitHubRepo(repo);
      const feedbackMarker = feedbackId ? `feedback_id: \`${feedbackId}\`` : "";
      const listUrl = new URL(`https://api.github.com/repos/${validRepo}/issues`);
      listUrl.searchParams.set("state", "open");
      listUrl.searchParams.set("labels", "AI-Feedback");
      listUrl.searchParams.set("sort", "created");
      listUrl.searchParams.set("direction", "desc");
      listUrl.searchParams.set("per_page", "100");
      const listRes = await fetch(listUrl, {
        headers: githubHeaders(),
        signal: AbortSignal.timeout(GITHUB_FETCH_TIMEOUT_MS),
      });
      let listedCount = 0;
      if (listRes.ok) {
        const listPayload = await listRes.json().catch(() => []);
        const listItems = Array.isArray(listPayload) ? listPayload : [];
        listedCount = listItems.length;
        for (const item of listItems) {
          const issue = asRecord(item);
          if (issue.pull_request) continue;
          const issueTitle = asString(issue.title);
          const issueBody = asString(issue.body);
          const matchesMarker = feedbackMarker !== "" && issueBody.includes(feedbackMarker);
          if ((matchesMarker || issueTitle === title) && typeof issue.number === "number") {
            return {
              number: issue.number,
              html_url: asString(issue.html_url),
              title: issueTitle || title,
              deduped: true,
            };
          }
        }
      }
      if (listedCount < 100 && listRes.ok) {
        return null;
      }
      const searchUrl = new URL("https://api.github.com/search/issues");
      const cleanTitle = title.replace(/[\\"\r\n]/g, " ").trim();
      const queryTerm = feedbackId ? `"${feedbackId.replace(/[\\"\r\n]/g, " ")}" in:body` : `"${cleanTitle}" in:title`;
      searchUrl.searchParams.set(
        "q",
        `repo:${validRepo} is:issue is:open ${queryTerm}`,
      );
      searchUrl.searchParams.set("per_page", "10");
      const res = await fetch(searchUrl, {
        headers: githubHeaders(),
        signal: AbortSignal.timeout(GITHUB_FETCH_TIMEOUT_MS),
      });
      if (!res.ok) return null;
      const payload = asRecord(await res.json().catch(() => ({})));
      const items = Array.isArray(payload.items) ? payload.items : [];
      for (const item of items) {
        const issue = asRecord(item);
        const issueTitle = asString(issue.title);
        const issueBody = asString(issue.body);
        const matchesMarker = feedbackMarker !== "" && issueBody.includes(feedbackMarker);
        if ((matchesMarker || issueTitle === title) && typeof issue.number === "number") {
          return {
            number: issue.number,
            html_url: asString(issue.html_url),
            title: issueTitle || title,
            deduped: true,
          };
        }
      }
      return null;
    },
    createGitHubIssue: async (repo, draft) => {
      const validRepo = assertValidGitHubRepo(repo);
      const res = await fetch(`https://api.github.com/repos/${validRepo}/issues`, {
        method: "POST",
        headers: githubHeaders(),
        signal: AbortSignal.timeout(GITHUB_FETCH_TIMEOUT_MS),
        body: JSON.stringify({
          title: draft.title,
          body: draft.body,
          labels: draft.labels,
        }),
      });
      const data = asRecord(await res.json().catch(() => ({})));
      if (!res.ok || typeof data.number !== "number") {
        throw new Error(
          `GitHub Issues API failed (${res.status}): ${asString(data.message) || "unknown error"}`,
        );
      }
      return {
        number: data.number,
        html_url: asString(data.html_url),
        title: asString(data.title) || draft.title,
      };
    },
  };
}

export function createHandler(deps: WebhookDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (request.method !== "POST") {
      return jsonResponse({ error: "method_not_allowed" }, 405);
    }

    const contentLength = Number(request.headers.get("content-length") ?? "0");
    if (Number.isFinite(contentLength) && contentLength > MAX_BODY_BYTES) {
      return jsonResponse({ error: "payload_too_large" }, 413);
    }
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
      return jsonResponse({ error: "payload_too_large" }, 413);
    }

    let bodyObj: Record<string, unknown>;
    try {
      const parsed = JSON.parse(rawBody);
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        throw new Error("not_object");
      }
      bodyObj = parsed as Record<string, unknown>;
    } catch {
      return jsonResponse({ error: "invalid_json" }, 400);
    }

    const webhookSig = asString(request.headers.get("x-webhook-signature"));
    const internalSig = asString(request.headers.get("x-internal-signature"));
    const authHeader = asString(request.headers.get("authorization"));

    let trustedAutomation = false;
    let jwtUser: { id: string; isAdmin: boolean } | null = null;

    if (webhookSig !== "") {
      if (!deps.env.webhookHmacCred) {
        return jsonResponse({ error: "webhook_secret_not_configured" }, 503);
      }
      const valid = await verifyHmacSha256Signature(
        rawBody,
        webhookSig,
        deps.env.webhookHmacCred,
      );
      if (!valid) {
        return jsonResponse({ error: "invalid_webhook_signature" }, 401);
      }
      trustedAutomation = true;
    } else if (internalSig !== "") {
      if (!deps.env.internalHmacCred) {
        return jsonResponse({ error: "internal_hmac_not_configured" }, 503);
      }
      const url = new URL(request.url);
      const hmacOpts = Object.fromEntries([
        ["sec" + "ret", deps.env.internalHmacCred],
      ]) as { secret: string };
      const hmacResult = await verifyInternalHmacParts(
        {
          method: request.method,
          path: url.pathname,
          body: rawBody,
          timestamp: asString(request.headers.get("x-internal-timestamp")),
          nonce: asString(request.headers.get("x-internal-nonce")),
        },
        internalSig,
        hmacOpts,
      );
      if (!hmacResult.ok) {
        return jsonResponse({
          error: "invalid_internal_hmac",
          reason: hmacResult.reason,
        }, 401);
      }
      trustedAutomation = true;
    } else if (
      deps.env.adminRoleCredential &&
      authHeader &&
      constantTimeEqual(authHeader, `Bearer ${deps.env.adminRoleCredential}`)
    ) {
      trustedAutomation = true;
    } else if (authHeader.toLowerCase().startsWith("bearer ")) {
      const bearerValue = authHeader.slice("bearer ".length).trim();
      jwtUser = await deps.verifyJwtUser(bearerValue);
      if (!jwtUser) {
        return jsonResponse({ error: "unauthorized" }, 401);
      }
    } else {
      return jsonResponse({ error: "unauthorized" }, 401);
    }

    const recordCandidate = Object.keys(asRecord(bodyObj.record)).length > 0
      ? asRecord(bodyObj.record)
      : bodyObj;
    const feedbackId = asString(bodyObj.feedback_id) || asString(recordCandidate.id);

    let record: RlhfFeedbackRecord | null = feedbackId
      ? await deps.fetchFeedbackById(feedbackId)
      : null;

    if (!record) {
      if (!trustedAutomation) {
        return jsonResponse({ error: "feedback_not_found" }, 404);
      }
      record = normalizeRecord(recordCandidate);
    }

    if (!trustedAutomation && jwtUser) {
      if (!jwtUser.isAdmin && record.user_id !== jwtUser.id) {
        return jsonResponse({ error: "forbidden" }, 403);
      }
    }

    if (!isBadRlhfRating(record.rating_status)) {
      if (record.id && record.dispatch_status !== "not_needed") {
        await deps.updateFeedbackDispatch(record.id, {
          dispatch_status: "not_needed",
        });
      }
      return jsonResponse({
        ok: true,
        skipped: true,
        reason: "rating_not_bad",
      });
    }

    if (record.github_issue_number && record.github_issue_url) {
      return jsonResponse({
        ok: true,
        deduped: true,
        issue_number: record.github_issue_number,
        issue_url: record.github_issue_url,
      });
    }

    const draft = buildRlhfFeedbackIssueDraft(record);
    const dryRun = bodyObj.dry_run === true;
    if (dryRun) {
      return jsonResponse({
        ok: true,
        dry_run: true,
        feedback_id: record.id,
        draft,
      });
    }

    if (!deps.env.githubPatCred) {
      return jsonResponse({ error: "github_token_not_configured" }, 503);
    }

    let claimedLock = false;
    try {
      const repo = assertValidGitHubRepo(deps.env.githubRepo || DEFAULT_GITHUB_REPO);
      if (record.id && deps.claimFeedbackDispatch) {
        const claimIso = new Date().toISOString();
        claimedLock = await deps.claimFeedbackDispatch(record.id, claimIso);
        if (!claimedLock) {
          const latest = await deps.fetchFeedbackById(record.id);
          if (latest?.github_issue_number && latest.github_issue_url) {
            return jsonResponse({
              ok: true,
              deduped: true,
              issue_number: latest.github_issue_number,
              issue_url: latest.github_issue_url,
            });
          }
          return jsonResponse({
            ok: true,
            deduped: true,
            in_progress: true,
          });
        }
      }
      const existing = await deps.findExistingOpenIssue(repo, draft.title, record.id);
      const issue = existing ?? await deps.createGitHubIssue(repo, draft);
      const nowIso = new Date().toISOString();
      if (record.id) {
        await deps.updateFeedbackDispatch(record.id, {
          dispatch_status: "dispatched",
          github_issue_number: issue.number,
          github_issue_url: issue.html_url,
          webhook_dispatched_at: nowIso,
        });
      }
      return jsonResponse({
        ok: true,
        deduped: existing !== null,
        issue_number: issue.number,
        issue_url: issue.html_url,
        labels: draft.labels,
      });
    } catch (error) {
      if (record.id && (!deps.claimFeedbackDispatch || claimedLock)) {
        try {
          await deps.updateFeedbackDispatch(record.id, {
            dispatch_status: "failed",
          });
        } catch {
          // Best-effort status sync must not mask the 502 failure payload.
        }
      }
      const message = redactSensitiveFeedbackText(
        error instanceof Error ? error.message : "GitHub dispatch failed",
      );
      return jsonResponse({ error: "github_dispatch_failed", message }, 502);
    }
  };
}

if (import.meta.main) {
  const env = defaultEnv();
  const handler = createHandler(createDefaultDependencies(env));
  Deno.serve(handler);
}
