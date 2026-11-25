import {
  type AgentToolPolicyDecision,
  evaluateAgentToolPolicy,
  parseAgentToolRequestedScopes,
} from "../_shared/agent_tool_policy.ts";

export type SafetyCheckpointStatus =
  | "paused_lossless"
  | "resumed"
  | "failed"
  | "running"
  | "warning_90";

export type SafetyApprovalChannel = "admin_ui" | "github_issue";

export type SafetyApprovalState =
  | "awaiting_admin_approval"
  | "approved"
  | "rejected";

export interface SafetyCheckpointRow {
  id?: string;
  user_id: string;
  run_key: string;
  agent_name: string;
  checkpoint_seq: number;
  state_snapshot: Record<string, unknown>;
  usage_ratio_pct: number;
  warning_90_threshold_pct: number;
  pause_status: SafetyCheckpointStatus;
  warning_90_sent: boolean;
  silent_pause_alerted: boolean;
  resumed_by: string | null;
  resumed_at: string | null;
  created_at?: string;
  updated_at?: string;
}

export interface SafetyCheckpointQueryResult {
  data?: unknown[] | null;
  error?: { message?: string } | null;
}

export interface SafetyCheckpointSingleResult {
  data?: unknown | null;
  error?: { message?: string } | null;
}

export interface SafetyCheckpointDbQuery {
  select(columns?: string): SafetyCheckpointDbQuery;
  eq(column: string, value: unknown): SafetyCheckpointDbQuery;
  order(
    column: string,
    options?: { ascending?: boolean },
  ): SafetyCheckpointDbQuery;
  limit(count: number): Promise<SafetyCheckpointQueryResult>;
  maybeSingle(): Promise<SafetyCheckpointSingleResult>;
  insert(
    value: Record<string, unknown>,
  ): {
    select(columns?: string): {
      single(): Promise<SafetyCheckpointSingleResult>;
    };
  };
  update(
    value: Record<string, unknown>,
  ): {
    eq(column: string, value: unknown): {
      select(columns?: string): {
        single(): Promise<SafetyCheckpointSingleResult>;
      };
    };
  };
}

export interface SafetyCheckpointDb {
  from(table: string): SafetyCheckpointDbQuery;
}

export interface GitHubIssueCommentEntry {
  id: number | string;
  author: string;
  authorAssociation: string;
  body: string;
  createdAt?: string;
}

export type GitHubIssueCommentFetcher = (
  repo: string,
  issueNumber: number,
) => Promise<GitHubIssueCommentEntry[]>;

export interface SafetyCheckpointActionContext {
  db: SafetyCheckpointDb;
  action: string;
  userId: string | null;
  isElevatedAutomation: boolean;
  body: Record<string, unknown>;
  nowIso?: string;
  fetchIssueComments?: GitHubIssueCommentFetcher;
}

export interface SafetyCheckpointHttpResponse {
  status: number;
  body: Record<string, unknown>;
}

const SYSTEM_IMPACT_PREFIXES = [
  "db.",
  "deploy.",
  "git.push",
  "admin.",
  "billing.",
  "migration.",
  "infra.",
  "workflow.",
  "secret.",
];

const AUTHORIZED_GITHUB_ASSOCIATIONS = new Set([
  "OWNER",
  "MEMBER",
  "COLLABORATOR",
]);

function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value === "object" && value !== null && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function asNonEmptyString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asPositiveInt(value: unknown): number | null {
  if (typeof value === "number" && Number.isInteger(value) && value > 0) {
    return value;
  }
  if (typeof value === "string" && /^\d+$/.test(value.trim())) {
    const parsed = Number.parseInt(value.trim(), 10);
    return parsed > 0 ? parsed : null;
  }
  return null;
}

function normalizeJsonValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => normalizeJsonValue(item));
  }
  if (typeof value === "object" && value !== null) {
    const entries = Object.entries(value as Record<string, unknown>).sort((
      [a],
      [b],
    ) => a.localeCompare(b));
    const normalized: Record<string, unknown> = {};
    for (const [key, item] of entries) {
      normalized[key] = normalizeJsonValue(item);
    }
    return normalized;
  }
  return value;
}

export async function sha256Hex(payload: unknown): Promise<string> {
  const canonical = JSON.stringify(normalizeJsonValue(payload));
  const bytes = new TextEncoder().encode(canonical);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function verifySnapshotIntegrity(
  snapshot: Record<string, unknown>,
): Promise<boolean> {
  const expected = asNonEmptyString(snapshot.snapshot_sha256);
  if (!expected) {
    return false;
  }
  const base: Record<string, unknown> = { ...snapshot };
  delete base.snapshot_sha256;
  const actual = await sha256Hex(base);
  return actual === expected;
}

export function isSystemImpactToolName(toolName: string): boolean {
  const normalized = toolName.trim().toLowerCase();
  return SYSTEM_IMPACT_PREFIXES.some((prefix) => normalized.startsWith(prefix));
}

export async function resolveCallerIsAdmin(
  db: SafetyCheckpointDb,
  userId: string | null,
  isElevatedAutomation: boolean,
): Promise<boolean> {
  if (isElevatedAutomation) {
    return true;
  }
  if (!userId) {
    return false;
  }
  const { data, error } = await db
    .from("user_profiles")
    .select("is_admin, role")
    .eq("user_id", userId)
    .maybeSingle();
  if (error || !data) {
    return false;
  }
  const profile = asRecord(data);
  return profile.is_admin === true || profile.role === "admin";
}

export function extractApprovalCommandTarget(body: string): {
  approvedTargets: string[];
  rejectedTargets: string[];
} {
  const approvedTargets: string[] = [];
  const rejectedTargets: string[] = [];
  const approveMatches = body.matchAll(
    /(?:\/approve-checkpoint\s+|\[safety-checkpoint-approved:)([A-Za-z0-9_.:-]+)\]?/gi,
  );
  for (const match of approveMatches) {
    const target = asNonEmptyString(match[1]);
    if (target) approvedTargets.push(target);
  }
  const rejectMatches = body.matchAll(
    /(?:\/reject-checkpoint\s+|\[safety-checkpoint-rejected:)([A-Za-z0-9_.:-]+)\]?/gi,
  );
  for (const match of rejectMatches) {
    const target = asNonEmptyString(match[1]);
    if (target) rejectedTargets.push(target);
  }
  return { approvedTargets, rejectedTargets };
}

export async function defaultFetchGitHubIssueComments(
  repo: string,
  issueNumber: number,
): Promise<GitHubIssueCommentEntry[]> {
  const cleanRepo = repo.trim();
  if (!/^[\w.-]+\/[\w.-]+$/.test(cleanRepo)) {
    throw new Error("Invalid GitHub repository slug");
  }
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "User-Agent": "my-web-app-safety-checkpoints",
  };
  const authValue = asNonEmptyString(Deno.env.get("GITHUB_PAT") ?? "") ||
    asNonEmptyString(Deno.env.get("GH_TOKEN") ?? "");
  if (authValue) {
    headers.Authorization = `Bearer ${authValue}`;
  }
  const url =
    `https://api.github.com/repos/${cleanRepo}/issues/${issueNumber}/comments?per_page=100`;
  const response = await fetch(url, { headers });
  if (!response.ok) {
    throw new Error(`GitHub Issue comments lookup failed (${response.status})`);
  }
  const rawList = await response.json();
  if (!Array.isArray(rawList)) {
    return [];
  }
  return rawList.map((entry) => {
    const item = asRecord(entry);
    const user = asRecord(item.user);
    return {
      id: typeof item.id === "number" || typeof item.id === "string"
        ? item.id
        : "",
      author: asNonEmptyString(user.login),
      authorAssociation: asNonEmptyString(item.author_association)
        .toUpperCase(),
      body: typeof item.body === "string" ? item.body : "",
      createdAt: asNonEmptyString(item.created_at),
    };
  });
}

function summarizeCheckpointRow(row: Record<string, unknown>) {
  const snapshot = asRecord(row.state_snapshot);
  const safety = asRecord(snapshot.safety_checkpoint);
  return {
    id: asNonEmptyString(row.id),
    user_id: asNonEmptyString(row.user_id),
    run_key: asNonEmptyString(row.run_key),
    agent_name: asNonEmptyString(row.agent_name),
    checkpoint_seq: typeof row.checkpoint_seq === "number"
      ? row.checkpoint_seq
      : 1,
    pause_status: asNonEmptyString(row.pause_status),
    pending_step: asNonEmptyString(snapshot.pending_step),
    snapshot_sha256: asNonEmptyString(snapshot.snapshot_sha256),
    tool_name: asNonEmptyString(safety.tool_name),
    requested_scopes: Array.isArray(safety.requested_scopes)
      ? safety.requested_scopes
      : [],
    high_risk_scopes: Array.isArray(safety.high_risk_scopes)
      ? safety.high_risk_scopes
      : [],
    operation_digest: asNonEmptyString(safety.operation_digest),
    approval_state: asNonEmptyString(safety.approval_state),
    approval_channel: asNonEmptyString(safety.approval_channel) || null,
    approved_by_actor: asNonEmptyString(safety.approved_by_actor) || null,
    github_issue_number: asPositiveInt(safety.github_issue_number),
    github_repo: asNonEmptyString(safety.github_repo) || null,
    github_comment_id: safety.github_comment_id ?? null,
    resumed_by: asNonEmptyString(row.resumed_by) || null,
    resumed_at: asNonEmptyString(row.resumed_at) || null,
    created_at: asNonEmptyString(row.created_at),
    updated_at: asNonEmptyString(row.updated_at),
  };
}

function matchesCheckpointTarget(
  target: string,
  checkpointId: string,
  runKey: string,
): boolean {
  return target === checkpointId || target === runKey;
}

function findVerifiedGitHubIssueApproval(
  comments: GitHubIssueCommentEntry[],
  checkpointId: string,
  runKey: string,
  allowedActors: Set<string>,
): GitHubIssueCommentEntry | null {
  let latestApproval: GitHubIssueCommentEntry | null = null;
  let latestRejected = false;

  for (const comment of comments) {
    const assoc = comment.authorAssociation.toUpperCase();
    const actor = comment.author.toLowerCase();
    const isAuthorized = AUTHORIZED_GITHUB_ASSOCIATIONS.has(assoc) ||
      (allowedActors.size > 0 && allowedActors.has(actor));
    if (!isAuthorized) {
      continue;
    }
    const { approvedTargets, rejectedTargets } = extractApprovalCommandTarget(
      comment.body,
    );
    const hasApprove = approvedTargets.some((target) =>
      matchesCheckpointTarget(target, checkpointId, runKey)
    );
    const hasReject = rejectedTargets.some((target) =>
      matchesCheckpointTarget(target, checkpointId, runKey)
    );
    if (hasReject) {
      latestApproval = null;
      latestRejected = true;
    } else if (hasApprove) {
      latestApproval = comment;
      latestRejected = false;
    }
  }
  return latestRejected ? null : latestApproval;
}

async function handleEvaluate(
  ctx: SafetyCheckpointActionContext,
): Promise<SafetyCheckpointHttpResponse> {
  const { db, userId, body, nowIso } = ctx;
  const effectiveUserId = asNonEmptyString(userId) ||
    asNonEmptyString(body.user_id);
  const toolName = asNonEmptyString(body.tool_name);
  if (!toolName) {
    return {
      status: 400,
      body: { error: "tool_name is required" },
    };
  }
  const requestedScopes = parseAgentToolRequestedScopes(body.requested_scopes);
  const allowedScopes = body.allowed_scopes === undefined
    ? undefined
    : parseAgentToolRequestedScopes(body.allowed_scopes);
  const actorRole = asNonEmptyString(body.actor_role) || undefined;

  const policy: AgentToolPolicyDecision = evaluateAgentToolPolicy({
    actorRole,
    toolName,
    requestedScopes,
    allowedScopes,
  });

  if (
    policy.blockedReason === "invalid_requested_scope" ||
    policy.blockedReason === "empty_requested_scope" ||
    policy.blockedReason === "missing_scope"
  ) {
    return {
      status: 200,
      body: {
        success: true,
        decision: "blocked_policy",
        execution_allowed: false,
        pause_required: false,
        blocked_reason: policy.blockedReason,
        policy,
      },
    };
  }

  const runKey = asNonEmptyString(body.run_key) ||
    `safety-${toolName.replace(/[^A-Za-z0-9_.-]+/g, "-")}`;
  const agentName = asNonEmptyString(body.agent_name) || "autonomous-agent";
  const pendingStep = asNonEmptyString(body.pending_step) ||
    `execute_mcp_tool:${toolName}`;
  const toolPayload = asRecord(body.tool_payload);
  const systemImpactFlag = body.system_impact === true ||
    isSystemImpactToolName(toolName);
  const requiresSafetyPause = policy.requiresApproval || systemImpactFlag;

  const operationDigest = await sha256Hex({
    run_key: runKey,
    agent_name: agentName,
    tool_name: toolName,
    requested_scopes: policy.auditPayload.requested_scopes,
    pending_step: pendingStep,
    tool_payload: toolPayload,
  });

  if (!requiresSafetyPause) {
    return {
      status: 200,
      body: {
        success: true,
        decision: "allow_direct",
        execution_allowed: true,
        pause_required: false,
        operation_digest: operationDigest,
        policy,
      },
    };
  }

  if (!effectiveUserId) {
    return {
      status: 401,
      body: { error: "Authenticated user_id is required to checkpoint tool" },
    };
  }

  const requestedCheckpointId = asNonEmptyString(body.checkpoint_id);
  if (requestedCheckpointId) {
    const { data: existingData, error: existingErr } = await db
      .from("agent_pause_checkpoints")
      .select("*")
      .eq("id", requestedCheckpointId)
      .maybeSingle();
    if (!existingErr && existingData) {
      const existing = asRecord(existingData);
      const callerIsAdmin = await resolveCallerIsAdmin(
        db,
        userId,
        ctx.isElevatedAutomation,
      );
      if (
        !callerIsAdmin &&
        asNonEmptyString(existing.user_id) !== effectiveUserId
      ) {
        return {
          status: 403,
          body: { error: "Not authorized to access this safety checkpoint" },
        };
      }
      const existingSnapshot = asRecord(existing.state_snapshot);
      const existingSafety = asRecord(existingSnapshot.safety_checkpoint);
      const snapshotIntact = await verifySnapshotIntegrity(existingSnapshot);
      if (!snapshotIntact) {
        return {
          status: 200,
          body: {
            success: true,
            decision: "blocked_tampered_snapshot",
            execution_allowed: false,
            pause_required: true,
            blocked_reason: "snapshot_sha256_mismatch",
            operation_digest: operationDigest,
            checkpoint: summarizeCheckpointRow(existing),
            policy,
          },
        };
      }
      const sameDigest = asNonEmptyString(existingSafety.operation_digest) ===
          operationDigest &&
        asNonEmptyString(existingSafety.tool_name) === toolName &&
        asNonEmptyString(existing.run_key) === runKey;
      if (
        sameDigest &&
        existing.pause_status === "resumed" &&
        existingSafety.approval_state === "approved" &&
        asNonEmptyString(existing.resumed_by).length > 0
      ) {
        return {
          status: 200,
          body: {
            success: true,
            decision: "approved_resumed",
            execution_allowed: true,
            pause_required: false,
            operation_digest: operationDigest,
            checkpoint: summarizeCheckpointRow(existing),
            policy,
          },
        };
      }
      if (
        sameDigest &&
        existing.pause_status === "failed" &&
        existingSafety.approval_state === "rejected"
      ) {
        return {
          status: 200,
          body: {
            success: true,
            decision: "rejected_blocked",
            execution_allowed: false,
            pause_required: true,
            operation_digest: operationDigest,
            checkpoint: summarizeCheckpointRow(existing),
            policy,
          },
        };
      }
    }
  }

  const { data: seqRows } = await db
    .from("agent_pause_checkpoints")
    .select(
      "checkpoint_seq, pause_status, state_snapshot, resumed_by, id, user_id, run_key, agent_name, resumed_at, created_at, updated_at",
    )
    .eq("user_id", effectiveUserId)
    .eq("run_key", runKey)
    .order("checkpoint_seq", { ascending: false })
    .limit(5);

  let nextSeq = 1;
  const rows = Array.isArray(seqRows) ? seqRows : [];
  for (const item of rows) {
    const rec = asRecord(item);
    const seqNum = typeof rec.checkpoint_seq === "number"
      ? rec.checkpoint_seq
      : 0;
    if (seqNum >= nextSeq) {
      nextSeq = seqNum + 1;
    }
    if (!requestedCheckpointId) {
      const recSnap = asRecord(rec.state_snapshot);
      const recSafety = asRecord(recSnap.safety_checkpoint);
      if (
        asNonEmptyString(recSafety.operation_digest) === operationDigest &&
        rec.pause_status === "paused_lossless" &&
        recSafety.approval_state === "awaiting_admin_approval" &&
        await verifySnapshotIntegrity(recSnap)
      ) {
        return {
          status: 200,
          body: {
            success: true,
            decision: "paused_for_approval",
            execution_allowed: false,
            pause_required: true,
            reused_existing_pause: true,
            operation_digest: operationDigest,
            checkpoint: summarizeCheckpointRow(rec),
            policy,
          },
        };
      }
    }
  }

  const timestamp = nowIso ?? new Date().toISOString();
  const githubIssueNumber = asPositiveInt(body.github_issue_number);
  const githubRepo = asNonEmptyString(body.github_repo) || null;
  const reason = asNonEmptyString(body.reason) ||
    `System-impact MCP tool call paused prior to execution: ${toolName}`;

  const baseSnapshot: Record<string, unknown> = {
    run_key: runKey,
    agent_name: agentName,
    checkpoint_seq: nextSeq,
    pending_step: pendingStep,
    cursor_payload: {
      tool_name: toolName,
      tool_payload: toolPayload,
      operation_digest: operationDigest,
    },
    completed_items: Array.isArray(body.completed_items)
      ? body.completed_items
      : [],
    captured_at: timestamp,
    reason,
    safety_checkpoint: {
      kind: "architectural_safety_checkpoint",
      tool_name: toolName,
      requested_scopes: policy.auditPayload.requested_scopes,
      high_risk_scopes: policy.highRiskScopes,
      actor_role: actorRole ?? null,
      operation_digest: operationDigest,
      approval_state: "awaiting_admin_approval",
      approval_channel: null,
      approved_by_actor: null,
      github_issue_number: githubIssueNumber,
      github_repo: githubRepo,
      github_comment_id: null,
      approved_at: null,
    },
  };
  const snapshotSha256 = await sha256Hex(baseSnapshot);
  const fullSnapshot: Record<string, unknown> = {
    ...baseSnapshot,
    snapshot_sha256: snapshotSha256,
  };

  const { data: inserted, error: insertError } = await db
    .from("agent_pause_checkpoints")
    .insert({
      user_id: effectiveUserId,
      run_key: runKey,
      agent_name: agentName,
      checkpoint_seq: nextSeq,
      state_snapshot: fullSnapshot,
      usage_ratio_pct: 100.0,
      warning_90_threshold_pct: 90.0,
      pause_status: "paused_lossless",
      warning_90_sent: true,
      silent_pause_alerted: true,
    })
    .select("*")
    .single();

  if (insertError || !inserted) {
    return {
      status: 500,
      body: {
        error: insertError?.message ?? "Failed to persist safety checkpoint",
      },
    };
  }

  return {
    status: 200,
    body: {
      success: true,
      decision: "paused_for_approval",
      execution_allowed: false,
      pause_required: true,
      operation_digest: operationDigest,
      checkpoint: summarizeCheckpointRow(asRecord(inserted)),
      policy,
    },
  };
}

async function handleList(
  ctx: SafetyCheckpointActionContext,
): Promise<SafetyCheckpointHttpResponse> {
  const { db, userId, isElevatedAutomation } = ctx;
  const isAdmin = await resolveCallerIsAdmin(
    db,
    userId,
    isElevatedAutomation,
  );
  let query = db
    .from("agent_pause_checkpoints")
    .select("*")
    .order("updated_at", { ascending: false });
  if (!isAdmin && userId) {
    query = query.eq("user_id", userId);
  }
  const { data, error } = await query.limit(50);
  if (error) {
    return {
      status: 500,
      body: { error: error.message ?? "Failed to fetch safety checkpoints" },
    };
  }
  const rows = Array.isArray(data) ? data : [];
  const checkpoints = rows
    .map((item) => asRecord(item))
    .filter((rec) => {
      const snap = asRecord(rec.state_snapshot);
      const safety = asRecord(snap.safety_checkpoint);
      return safety.kind === "architectural_safety_checkpoint";
    })
    .map((rec) => summarizeCheckpointRow(rec));

  return {
    status: 200,
    body: {
      success: true,
      is_admin: isAdmin,
      checkpoints,
    },
  };
}

async function handleApprove(
  ctx: SafetyCheckpointActionContext,
): Promise<SafetyCheckpointHttpResponse> {
  const {
    db,
    userId,
    isElevatedAutomation,
    body,
    nowIso,
    fetchIssueComments,
  } = ctx;

  const isAdmin = await resolveCallerIsAdmin(
    db,
    userId,
    isElevatedAutomation,
  );
  if (!isAdmin) {
    return {
      status: 403,
      body: {
        error: "Admin privileges required to approve safety checkpoints",
      },
    };
  }

  const checkpointId = asNonEmptyString(body.checkpoint_id);
  if (!checkpointId) {
    return {
      status: 400,
      body: { error: "checkpoint_id is required" },
    };
  }

  const rawChannel = asNonEmptyString(body.approval_channel) || "admin_ui";
  if (rawChannel !== "admin_ui" && rawChannel !== "github_issue") {
    return {
      status: 400,
      body: { error: "approval_channel must be admin_ui or github_issue" },
    };
  }
  const channel: SafetyApprovalChannel = rawChannel;

  const { data: existingData, error: existingErr } = await db
    .from("agent_pause_checkpoints")
    .select("*")
    .eq("id", checkpointId)
    .maybeSingle();

  if (existingErr) {
    return {
      status: 500,
      body: { error: existingErr.message ?? "Checkpoint lookup failed" },
    };
  }
  if (!existingData) {
    return {
      status: 404,
      body: { error: "Safety checkpoint not found" },
    };
  }

  const row = asRecord(existingData);
  const runKey = asNonEmptyString(row.run_key);
  if (row.pause_status !== "paused_lossless") {
    return {
      status: 409,
      body: {
        error: `Checkpoint is in state '${
          String(row.pause_status)
        }' and cannot be approved`,
      },
    };
  }

  const snapshot = asRecord(row.state_snapshot);
  const safety = asRecord(snapshot.safety_checkpoint);
  if (safety.kind !== "architectural_safety_checkpoint") {
    return {
      status: 400,
      body: {
        error: "Target record is not an architectural safety checkpoint",
      },
    };
  }
  if (!(await verifySnapshotIntegrity(snapshot))) {
    return {
      status: 409,
      body: {
        error:
          "Safety checkpoint snapshot integrity check failed (snapshot_sha256 mismatch)",
      },
    };
  }

  const timestamp = nowIso ?? new Date().toISOString();
  let approvedByActor = asNonEmptyString(userId) ||
    asNonEmptyString(body.approved_by) ||
    "admin";
  const pinnedIssueNumber = asPositiveInt(safety.github_issue_number);
  const requestedIssueNumber = asPositiveInt(body.github_issue_number);
  if (
    pinnedIssueNumber &&
    requestedIssueNumber &&
    pinnedIssueNumber !== requestedIssueNumber
  ) {
    return {
      status: 403,
      body: {
        error:
          "github_issue_number does not match pinned safety checkpoint issue",
      },
    };
  }
  const githubIssueNumber = pinnedIssueNumber ?? requestedIssueNumber;

  const pinnedRepo = asNonEmptyString(safety.github_repo);
  const requestedRepo = asNonEmptyString(body.github_repo);
  if (pinnedRepo && requestedRepo && pinnedRepo !== requestedRepo) {
    return {
      status: 403,
      body: {
        error: "github_repo does not match pinned safety checkpoint repository",
      },
    };
  }
  const githubRepo = pinnedRepo || requestedRepo || "kanta13jp1/my_web_app";
  let githubCommentId: number | string | null = null;

  if (channel === "github_issue") {
    if (!githubIssueNumber) {
      return {
        status: 400,
        body: {
          error:
            "github_issue_number is required for github_issue approval channel",
        },
      };
    }
    const allowedActorsRaw = Array.isArray(body.allowed_github_actors)
      ? body.allowed_github_actors
      : [];
    const allowedActors = new Set(
      allowedActorsRaw
        .map((actor) => asNonEmptyString(actor).toLowerCase())
        .filter(Boolean),
    );
    const commentsFetcher = fetchIssueComments ??
      defaultFetchGitHubIssueComments;
    let comments: GitHubIssueCommentEntry[];
    try {
      comments = await commentsFetcher(githubRepo, githubIssueNumber);
    } catch (err) {
      return {
        status: 502,
        body: {
          error: err instanceof Error
            ? err.message
            : "GitHub Issue verification failed",
        },
      };
    }
    const matched = findVerifiedGitHubIssueApproval(
      comments,
      checkpointId,
      runKey,
      allowedActors,
    );
    if (!matched) {
      return {
        status: 403,
        body: {
          error:
            "No authorized GitHub Issue approval comment found for this checkpoint",
        },
      };
    }
    approvedByActor = `github:${matched.author}`;
    githubCommentId = matched.id || null;
  }

  const nextSafety: Record<string, unknown> = {
    ...safety,
    approval_state: "approved",
    approval_channel: channel,
    approved_by_actor: approvedByActor,
    github_issue_number: githubIssueNumber,
    github_repo: channel === "github_issue"
      ? githubRepo
      : safety.github_repo ?? null,
    github_comment_id: githubCommentId,
    approval_note: asNonEmptyString(body.approval_note) || null,
    approved_at: timestamp,
  };
  const nextSnapshotBase: Record<string, unknown> = {
    ...snapshot,
    safety_checkpoint: nextSafety,
  };
  delete nextSnapshotBase.snapshot_sha256;
  const nextSha256 = await sha256Hex(nextSnapshotBase);
  const nextSnapshot: Record<string, unknown> = {
    ...nextSnapshotBase,
    snapshot_sha256: nextSha256,
  };

  const resumedBy = asNonEmptyString(userId) ||
    asNonEmptyString(row.user_id);

  const { data: updated, error: updateError } = await db
    .from("agent_pause_checkpoints")
    .update({
      pause_status: "resumed",
      resumed_by: resumedBy,
      resumed_at: timestamp,
      state_snapshot: nextSnapshot,
    })
    .eq("id", checkpointId)
    .select("*")
    .single();

  if (updateError || !updated) {
    return {
      status: 500,
      body: {
        error: updateError?.message ?? "Failed to update approved checkpoint",
      },
    };
  }

  return {
    status: 200,
    body: {
      success: true,
      decision: "approved_resumed",
      execution_allowed: true,
      checkpoint: summarizeCheckpointRow(asRecord(updated)),
    },
  };
}

async function handleReject(
  ctx: SafetyCheckpointActionContext,
): Promise<SafetyCheckpointHttpResponse> {
  const { db, userId, isElevatedAutomation, body, nowIso } = ctx;
  const checkpointId = asNonEmptyString(body.checkpoint_id);
  if (!checkpointId) {
    return {
      status: 400,
      body: { error: "checkpoint_id is required" },
    };
  }
  const isAdmin = await resolveCallerIsAdmin(
    db,
    userId,
    isElevatedAutomation,
  );
  const { data: existingData, error: existingErr } = await db
    .from("agent_pause_checkpoints")
    .select("*")
    .eq("id", checkpointId)
    .maybeSingle();
  if (existingErr) {
    return {
      status: 500,
      body: { error: existingErr.message ?? "Checkpoint lookup failed" },
    };
  }
  if (!existingData) {
    return {
      status: 404,
      body: { error: "Safety checkpoint not found" },
    };
  }

  const row = asRecord(existingData);
  const isOwner = Boolean(userId && row.user_id === userId);
  if (!isAdmin && !isOwner) {
    return {
      status: 403,
      body: { error: "Not authorized to reject this safety checkpoint" },
    };
  }
  if (row.pause_status !== "paused_lossless") {
    return {
      status: 409,
      body: {
        error: `Checkpoint is in state '${
          String(row.pause_status)
        }' and cannot be rejected`,
      },
    };
  }

  const timestamp = nowIso ?? new Date().toISOString();
  const snapshot = asRecord(row.state_snapshot);
  const safety = asRecord(snapshot.safety_checkpoint);
  const nextSnapshotBase: Record<string, unknown> = {
    ...snapshot,
    safety_checkpoint: {
      ...safety,
      approval_state: "rejected",
      rejected_by: asNonEmptyString(userId) || "admin",
      rejected_at: timestamp,
      rejection_reason: asNonEmptyString(body.reason) ||
        "Rejected by safety checkpoint reviewer",
    },
  };
  delete nextSnapshotBase.snapshot_sha256;
  const nextSha256 = await sha256Hex(nextSnapshotBase);

  const { data: updated, error: updateError } = await db
    .from("agent_pause_checkpoints")
    .update({
      pause_status: "failed",
      state_snapshot: {
        ...nextSnapshotBase,
        snapshot_sha256: nextSha256,
      },
    })
    .eq("id", checkpointId)
    .select("*")
    .single();

  if (updateError || !updated) {
    return {
      status: 500,
      body: {
        error: updateError?.message ?? "Failed to reject safety checkpoint",
      },
    };
  }

  return {
    status: 200,
    body: {
      success: true,
      decision: "rejected",
      execution_allowed: false,
      checkpoint: summarizeCheckpointRow(asRecord(updated)),
    },
  };
}

export async function handleSafetyCheckpointAction(
  ctx: SafetyCheckpointActionContext,
): Promise<SafetyCheckpointHttpResponse> {
  switch (ctx.action) {
    case "agent.safety_checkpoint.evaluate":
      return await handleEvaluate(ctx);
    case "agent.safety_checkpoint.list":
      return await handleList(ctx);
    case "agent.safety_checkpoint.approve":
      return await handleApprove(ctx);
    case "agent.safety_checkpoint.reject":
      return await handleReject(ctx);
    default:
      return {
        status: 400,
        body: { error: `Unsupported safety checkpoint action: ${ctx.action}` },
      };
  }
}
