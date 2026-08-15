export const X_POST_CANDIDATE_SOURCE = "x_post_candidate";
export const X_POST_CANDIDATE_SCHEMA_VERSION = 1;

type JsonRecord = Record<string, unknown>;

export type XPostCandidatePayload = {
  action: "x.post";
  text: string;
  replyTexts: string[];
  poll?: {
    options: string[];
    durationMinutes: number;
  };
  mediaUrl?: string;
  mediaType?: string;
  mediaAlt?: string;
  source?: string;
  route?: string;
  experimentKey?: string;
  variant?: string;
  utmContent?: string;
  promptProfile?: string;
  fallbackUsed?: boolean;
  contentKind?: string;
  linkInReply?: boolean;
  contentArchetype?: string;
  ownerUserId?: string;
};

export type XPostCandidateApproval = {
  actorUserId: string;
  approvedBy: string;
  channel: string;
  context?: unknown;
};

export type XPostCandidateRejection = {
  actorUserId: string;
  rejectedBy: string;
  reason?: unknown;
};

function asRecord(value: unknown): JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

function firstString(...values: unknown[]): string {
  for (const value of values) {
    if (typeof value === "string" && value.trim() !== "") {
      return value.trim();
    }
  }
  return "";
}

function optionalString(...values: unknown[]): string | undefined {
  const value = firstString(...values);
  return value || undefined;
}

function limitedString(value: unknown, max: number): string | undefined {
  const text = firstString(value);
  if (!text) return undefined;
  return text.slice(0, max);
}

function finiteInteger(
  value: unknown,
  fallback: number,
  min: number,
  max: number,
): number {
  const parsed = Number(value);
  const resolved = Number.isFinite(parsed) ? Math.trunc(parsed) : fallback;
  return Math.max(min, Math.min(max, resolved));
}

function normalizeStringList(
  value: unknown,
  maxItems: number,
  maxLength: number,
): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => firstString(entry).slice(0, maxLength))
    .filter(Boolean)
    .slice(0, maxItems);
}

/// Keep only non-sensitive generation fields needed to review and audit a
/// candidate. Arbitrary UI/workflow JSON must not be copied into metadata.
export function normalizeXPostCandidateContext(value: unknown): JsonRecord {
  const context = asRecord(value);
  const result: JsonRecord = {};
  const stringFields: Array<[string, number]> = [
    ["workflow", 160],
    ["workflow_run_id", 80],
    ["workflow_run_attempt", 20],
    ["event", 80],
    ["actor", 160],
    ["ref", 300],
    ["sha", 80],
    ["jst_day", 40],
    ["trend_source", 120],
    ["selected_variant", 160],
    ["best_variant", 160],
    ["target_url", 2000],
  ];
  for (const [key, max] of stringFields) {
    const normalized = limitedString(context[key], max);
    if (normalized !== undefined) result[key] = normalized;
  }
  if (Array.isArray(context["topics"])) {
    result["topics"] = normalizeStringList(context["topics"], 10, 200);
  }
  const performanceRows = Number(context["performance_rows"]);
  if (Number.isFinite(performanceRows) && performanceRows >= 0) {
    result["performance_rows"] = Math.trunc(performanceRows);
  }
  return result;
}

/// Whitelist the fields accepted by x.post and validate post lengths/poll data
/// before persistence. Control fields such as dryRun/status/approval are never
/// copied into post_payload.
export function normalizeXPostCandidatePayload(
  value: unknown,
): XPostCandidatePayload {
  const body = asRecord(value);
  const text = firstString(body.text);
  if (!text) throw new Error("text required");
  if (text.length > 25000) {
    throw new Error("text exceeds 25000 characters");
  }

  const replyText = firstString(body.replyText, body.reply_text);
  const replyTexts = [
    ...(Array.isArray(body.replyTexts) ? body.replyTexts : []),
    ...(Array.isArray(body.reply_texts) ? body.reply_texts : []),
    ...(replyText ? [replyText] : []),
  ]
    .map((entry) => firstString(entry))
    .filter(Boolean)
    .slice(0, 8);
  const longReplyIndex = replyTexts.findIndex((entry) => entry.length > 25000);
  if (longReplyIndex >= 0) {
    throw new Error(
      `replyTexts[${longReplyIndex}] exceeds 25000 characters`,
    );
  }

  const rawPoll = asRecord(body.poll);
  const pollOptions = normalizeStringList(rawPoll.options, 4, 25);
  const poll = pollOptions.length >= 2
    ? {
      options: pollOptions,
      durationMinutes: finiteInteger(
        rawPoll.durationMinutes ?? rawPoll.duration_minutes,
        1440,
        5,
        10080,
      ),
    }
    : undefined;

  const payload: XPostCandidatePayload = {
    action: "x.post",
    text,
    replyTexts,
  };
  if (poll) payload.poll = poll;

  const strings: Array<[
    keyof XPostCandidatePayload,
    unknown,
    unknown,
  ]> = [
    ["mediaUrl", body.mediaUrl, body.media_url],
    ["mediaType", body.mediaType, body.media_type],
    ["mediaAlt", body.mediaAlt, body.media_alt ?? body.altText],
    ["source", body.source, undefined],
    ["route", body.route, undefined],
    ["experimentKey", body.experimentKey, body.experiment_key],
    ["variant", body.variant, undefined],
    ["utmContent", body.utmContent, body.utm_content],
    ["promptProfile", body.promptProfile, body.prompt_profile],
    ["contentKind", body.contentKind, body.content_kind],
    ["contentArchetype", body.contentArchetype, body.content_archetype],
    ["ownerUserId", body.ownerUserId, body.owner_user_id],
  ];
  for (const [key, first, second] of strings) {
    const normalized = optionalString(first, second);
    if (normalized !== undefined) {
      (payload as JsonRecord)[key] = normalized;
    }
  }

  if (body.fallbackUsed === true || body.fallback_used === true) {
    payload.fallbackUsed = true;
  }
  if (body.linkInReply === true || body.link_in_reply === true) {
    payload.linkInReply = true;
  }
  return payload;
}

export function normalizeXPostCandidateKey(value: unknown): string {
  const key = firstString(value);
  if (!key) return "";
  if (key.length > 200) {
    throw new Error("candidateKey exceeds 200 characters");
  }
  if (!/^[A-Za-z0-9._:/-]+$/.test(key)) {
    throw new Error("candidateKey contains unsupported characters");
  }
  return key;
}

export function buildXPostCandidateMetadata(
  payloadValue: unknown,
  options: {
    candidateKey?: unknown;
    candidateType?: unknown;
    sourceKind?: unknown;
    sourceUrls?: unknown;
    createdBy?: unknown;
    context?: unknown;
    now?: Date;
  } = {},
): JsonRecord {
  const payload = normalizeXPostCandidatePayload(payloadValue);
  const generatedAt = (options.now ?? new Date()).toISOString();
  const candidateKey = normalizeXPostCandidateKey(
    options.candidateKey,
  );
  const candidateType = firstString(
    options.candidateType,
    payload.contentKind,
    "x_post",
  );
  const sourceKind = firstString(
    options.sourceKind,
    payload.source,
    "growth-hub",
  );
  const createdBy = firstString(options.createdBy, "growth-hub");
  const sourceUrls = normalizeStringList(options.sourceUrls, 20, 2000);
  return {
    schema_version: X_POST_CANDIDATE_SCHEMA_VERSION,
    status: "pending_approval",
    candidate_key: candidateKey || null,
    candidate_type: candidateType,
    source_kind: sourceKind,
    text: payload.text,
    reply_texts: payload.replyTexts,
    variant: payload.variant ?? null,
    content_archetype: payload.contentArchetype ?? null,
    source_urls: sourceUrls,
    created_by: createdBy,
    approval_required: true,
    approved_at: null,
    approved_by: null,
    generated_at: generatedAt,
    updated_at: generatedAt,
    idempotency_key: candidateKey || null,
    source: payload.source ?? "growth-hub",
    route: payload.route ?? null,
    content_kind: payload.contentKind ?? null,
    experiment_key: payload.experimentKey ?? null,
    post_payload: payload,
    generation_context: normalizeXPostCandidateContext(options.context),
  };
}

export function approveXPostCandidateMetadata(
  value: unknown,
  approval: XPostCandidateApproval,
  now = new Date(),
): { metadata: JsonRecord; postPayload: XPostCandidatePayload } {
  const metadata = asRecord(value);
  const status = firstString(metadata.status);
  if (!["pending_approval", "approved", "publish_failed"].includes(status)) {
    throw new Error(`draft status ${status || "missing"} cannot be approved`);
  }
  const actorUserId = firstString(approval.actorUserId);
  const approvedBy = firstString(approval.approvedBy);
  const channel = firstString(approval.channel);
  if (!actorUserId || !approvedBy || !channel) {
    throw new Error("approval actor, approver, and channel are required");
  }
  const postPayload = normalizeXPostCandidatePayload(metadata.post_payload);
  const approvedAt = now.toISOString();
  return {
    metadata: {
      ...metadata,
      status: "approved",
      approval_required: true,
      approved_at: approvedAt,
      approved_by: approvedBy.slice(0, 200),
      approval_actor_user_id: actorUserId.slice(0, 200),
      approval_channel: channel.slice(0, 120),
      approval_context: normalizeXPostCandidateContext(approval.context),
      updated_at: approvedAt,
      publish_attempts: finiteInteger(metadata.publish_attempts, 0, 0, 100000) +
        1,
      post_payload: postPayload,
    },
    postPayload,
  };
}

/// 却下 = 運用者が「もう投稿しない」と決めた終端状態 (#4080)。
///
/// 状態機械の設計判断:
/// - 却下できるのは actionable な 3 状態のみ。`posted` は既に公開済みで
///   取り消しにはならず、却下扱いにすると「投稿していない」と誤読させる。
/// - `rejected` / `rejected_duplicate` は既に終端なので **冪等に no-op**
///   (再押下やバッチ再送でエラーにしない)。ただし最初の却下情報は保持する。
/// - 却下は投稿試行ではないので `publish_attempts` を増やさない。
export function rejectXPostCandidateMetadata(
  value: unknown,
  rejection: XPostCandidateRejection,
  now = new Date(),
): { metadata: JsonRecord; changed: boolean } {
  const metadata = asRecord(value);
  const status = firstString(metadata.status);
  if (status === "rejected" || status === "rejected_duplicate") {
    return { metadata, changed: false };
  }
  if (!["pending_approval", "approved", "publish_failed"].includes(status)) {
    throw new Error(`draft status ${status || "missing"} cannot be rejected`);
  }
  const actorUserId = firstString(rejection.actorUserId);
  const rejectedBy = firstString(rejection.rejectedBy);
  if (!actorUserId || !rejectedBy) {
    throw new Error("rejection actor and rejector are required");
  }
  const rejectedAt = now.toISOString();
  return {
    metadata: {
      ...metadata,
      status: "rejected",
      rejected_at: rejectedAt,
      rejected_by: rejectedBy.slice(0, 200),
      rejection_actor_user_id: actorUserId.slice(0, 200),
      reject_reason: limitedString(rejection.reason, 500) ?? null,
      updated_at: rejectedAt,
    },
    changed: true,
  };
}

export function finalizeXPostCandidateMetadata(
  value: unknown,
  resultValue: unknown,
  now = new Date(),
): JsonRecord {
  const metadata = asRecord(value);
  const currentStatus = firstString(metadata.status);
  if (currentStatus === "posted") return metadata;
  if (currentStatus !== "approved") {
    throw new Error(
      `draft status ${currentStatus || "missing"} cannot finalize`,
    );
  }
  const result = asRecord(resultValue);
  const posted = result.posted === true && firstString(result.tweetId) !== "";
  const code = firstString(result.code);
  const status = posted
    ? "posted"
    : code === "duplicate_content"
    ? "rejected_duplicate"
    : "publish_failed";
  const finalizedAt = now.toISOString();
  return {
    ...metadata,
    status,
    updated_at: finalizedAt,
    published_at: posted ? finalizedAt : null,
    tweet_id: optionalString(result.tweetId) ?? null,
    reply_tweet_id: optionalString(result.replyTweetId) ?? null,
    reply_tweet_ids: normalizeStringList(result.replyTweetIds, 8, 100),
    post_log_id: optionalString(result.logId, asRecord(result.log).id) ?? null,
    publish_error: optionalString(result.error) ?? null,
    publish_code: code || null,
  };
}
