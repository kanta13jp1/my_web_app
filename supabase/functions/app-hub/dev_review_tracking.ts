export const DEV_REVIEW_PHASES = [
  "intake",
  "design",
  "implementation",
  "verification",
  "release",
] as const;

export type DevReviewPhase = (typeof DEV_REVIEW_PHASES)[number];

export type DevReviewItemStatus =
  | "pending"
  | "in_review"
  | "changes_requested"
  | "approved";

export type DevReviewItemKind = "checklist" | "test_variation" | "finding";

export interface DevReviewChecklistItem {
  id: string;
  kind: DevReviewItemKind;
  title: string;
  category: string;
  status: DevReviewItemStatus;
  assignee: string;
  note: string;
  updatedAt: string;
}

export interface DevReviewGithubSnapshot {
  provider: "github";
  repo: string;
  targetType: "issue" | "pr";
  number: number;
  url: string;
  state: "open" | "closed" | "merged";
  reviewDecision: "none" | "approved" | "changes_requested" | "commented";
  syncedAt: string;
}

export interface DevReviewPhaseHistory {
  fromPhase: DevReviewPhase;
  toPhase: DevReviewPhase;
  actorUserId: string;
  decidedAt: string;
  note: string;
}

export interface DevReviewSession {
  id: string;
  userId: string;
  title: string;
  targetType: "issue" | "pr";
  githubRepo: string;
  targetNumber: number;
  currentPhase: DevReviewPhase;
  approver: string;
  items: DevReviewChecklistItem[];
  githubSnapshot: DevReviewGithubSnapshot | null;
  phaseHistory: DevReviewPhaseHistory[];
  createdAt: string;
  updatedAt: string;
}

export interface DevReviewStore {
  listSessions(userId: string, limit: number): Promise<DevReviewSession[]>;
  getSession(
    sessionId: string,
    userId: string,
  ): Promise<DevReviewSession | null>;
  findSessionsByGithubTarget(
    githubRepo: string,
    targetNumber: number,
  ): Promise<DevReviewSession[]>;
  createSession(input: {
    userId: string;
    title: string;
    targetType: "issue" | "pr";
    githubRepo: string;
    targetNumber: number;
    currentPhase: DevReviewPhase;
    approver: string;
    items: DevReviewChecklistItem[];
    githubSnapshot: DevReviewGithubSnapshot | null;
  }): Promise<DevReviewSession>;
  updateSession(
    sessionId: string,
    userId: string,
    session: DevReviewSession,
  ): Promise<DevReviewSession | null>;
}

const VALID_STATUSES = new Set<string>([
  "pending",
  "in_review",
  "changes_requested",
  "approved",
]);

const VALID_KINDS = new Set<string>(["checklist", "test_variation", "finding"]);

const VALID_REPO_RE = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;

function asRecord(raw: unknown): Record<string, unknown> {
  if (raw !== null && typeof raw === "object" && !Array.isArray(raw)) {
    return raw as Record<string, unknown>;
  }
  return {};
}

function asText(raw: unknown, maxLen = 300): string {
  return String(raw ?? "").trim().slice(0, maxLen);
}

function asPosInt(raw: unknown, fallback = 0): number {
  const n = Number(raw);
  if (!Number.isFinite(n) || n <= 0) return fallback;
  return Math.trunc(n);
}

export function isValidGithubRepo(repo: string): boolean {
  return VALID_REPO_RE.test(repo.trim());
}

export function buildDefaultReviewItems(input: {
  targetType: "issue" | "pr";
  assignee: string;
  nowIso: string;
}): DevReviewChecklistItem[] {
  const owner = input.assignee || "unassigned";
  const prefix = input.targetType === "pr" ? "PR" : "Issue";
  const defs: Array<{
    id: string;
    kind: DevReviewItemKind;
    title: string;
    category: string;
  }> = [
    {
      id: "chk-spec",
      kind: "checklist",
      title: `${prefix} 受入条件と仕様整合確認`,
      category: "specification",
    },
    {
      id: "chk-security",
      kind: "checklist",
      title: "認証・RLS・シークレット非混入監査",
      category: "security",
    },
    {
      id: "chk-evidence",
      kind: "checklist",
      title: "レビュー証跡・変更理由記録",
      category: "audit_trail",
    },
    {
      id: "tv-unit",
      kind: "test_variation",
      title: "正常系・境界値ユニットテスト",
      category: "unit_variation",
    },
    {
      id: "tv-auth",
      kind: "test_variation",
      title: "権限拒否 (401/403) 異常系テスト",
      category: "security_variation",
    },
    {
      id: "tv-ui",
      kind: "test_variation",
      title: "モバイル・デスクトップ・文字拡大 UI 検証",
      category: "responsive_variation",
    },
  ];
  return defs.map((d) => ({
    id: d.id,
    kind: d.kind,
    title: d.title,
    category: d.category,
    status: "pending",
    assignee: owner,
    note: "",
    updatedAt: input.nowIso,
  }));
}

export interface PhaseTransitionCheck {
  allowed: boolean;
  blockingReasons: string[];
  unapprovedItemCount: number;
  openFindingCount: number;
}

export function validatePhaseTransition(
  session: DevReviewSession,
  targetPhase: DevReviewPhase,
): PhaseTransitionCheck {
  const reasons: string[] = [];
  const currentIdx = DEV_REVIEW_PHASES.indexOf(session.currentPhase);
  const targetIdx = DEV_REVIEW_PHASES.indexOf(targetPhase);

  if (targetIdx < 0) {
    reasons.push(`未知のフェーズです: ${targetPhase}`);
  } else if (targetIdx <= currentIdx) {
    reasons.push(
      `現在フェーズ (${session.currentPhase}) より後の` +
        `フェーズを指定してください。`,
    );
  }

  if (session.items.length === 0) {
    reasons.push("レビュー項目が 0 件のためフェーズ移行できません。");
  }

  const unapproved = session.items.filter((i) => i.status !== "approved");
  const openFindings = unapproved.filter((i) => i.kind === "finding");

  for (const item of unapproved.slice(0, 6)) {
    reasons.push(
      `未承認 [${item.kind}] ${item.title} (status=${item.status})`,
    );
  }
  if (unapproved.length > 6) {
    reasons.push(`他 ${unapproved.length - 6} 件の未承認項目があります。`);
  }

  if (
    session.githubSnapshot !== null &&
    session.githubSnapshot.reviewDecision === "changes_requested"
  ) {
    reasons.push(
      "GitHub レビューが changes_requested のため移行を保留します。",
    );
  }

  if (session.approver.trim() === "") {
    reasons.push("最終承認者 (approver) が設定されていません。");
  }

  return {
    allowed: reasons.length === 0,
    blockingReasons: reasons,
    unapprovedItemCount: unapproved.length,
    openFindingCount: openFindings.length,
  };
}

function constantTimeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i += 1) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

export async function signGithubWebhookPayload(
  rawBody: string,
  signingKey: string,
): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(signingKey),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuf = await crypto.subtle.sign("HMAC", key, enc.encode(rawBody));
  const hex = Array.from(new Uint8Array(sigBuf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `sha256=${hex}`;
}

export async function verifyGithubWebhookSignature(
  rawBody: string,
  signatureHeader: string,
  signingKey: string,
): Promise<boolean> {
  const key = signingKey.trim();
  const provided = signatureHeader.trim().toLowerCase();
  if (!key || !/^sha256=[0-9a-f]{64}$/.test(provided)) {
    return false;
  }
  const expected = await signGithubWebhookPayload(rawBody, key);
  return constantTimeEqualHex(expected, provided);
}

function mapGithubState(
  rawState: string,
  merged: boolean,
): "open" | "closed" | "merged" {
  if (merged) return "merged";
  return rawState.toLowerCase() === "closed" ? "closed" : "open";
}

function mapReviewDecision(
  rawState: string,
): "none" | "approved" | "changes_requested" | "commented" {
  const lower = rawState.toLowerCase();
  if (lower === "approved") return "approved";
  if (lower === "changes_requested") return "changes_requested";
  if (lower === "commented") return "commented";
  return "none";
}

export function resolveAppHubAction(
  requestUrl: string,
  body: Record<string, unknown>,
): string {
  const queryAction = new URL(requestUrl).searchParams.get("action") ?? "";
  if (queryAction === "dev_review.github_webhook") {
    return queryAction;
  }
  return String(body.action ?? queryAction);
}

export async function handleDevReviewAction(params: {
  action: string;
  body: Record<string, unknown>;
  rawBody?: string;
  signatureHeader?: string;
  userId: string;
  store: DevReviewStore;
  fetcher?: typeof fetch;
  getEnv?: (name: string) => string | undefined;
}): Promise<{ status: number; body: Record<string, unknown> }> {
  const {
    action,
    body,
    rawBody = "",
    signatureHeader = "",
    userId,
    store,
    fetcher = fetch,
    getEnv = (name: string) => Deno.env.get(name),
  } = params;

  if (action === "dev_review.github_webhook") {
    const webhookEnvName = "GITHUB_WEBHOOK_SECRET";
    const webhookCred = (getEnv(webhookEnvName) ?? "").trim();
    if (!webhookCred) {
      console.warn(
        `[dev_review.github_webhook] ${webhookEnvName} is not configured.`,
      );
      return {
        status: 503,
        body: { error: `${webhookEnvName} is not configured.` },
      };
    }
    const valid = await verifyGithubWebhookSignature(
      rawBody,
      signatureHeader,
      webhookCred,
    );
    if (!valid) {
      return { status: 401, body: { error: "Invalid webhook signature." } };
    }

    const repoObj = asRecord(body.repository);
    const repoName = asText(repoObj.full_name, 160);
    const prObj = asRecord(body.pull_request);
    const issueObj = asRecord(body.issue);
    const reviewObj = asRecord(body.review);
    const targetType: "issue" | "pr" = Object.keys(prObj).length > 0
      ? "pr"
      : "issue";
    const targetObj = targetType === "pr" ? prObj : issueObj;
    const targetNumber = asPosInt(targetObj.number, 0);

    if (!isValidGithubRepo(repoName) || targetNumber <= 0) {
      return {
        status: 400,
        body: {
          error: "Webhook missing repository.full_name or target number.",
        },
      };
    }

    const matched = await store.findSessionsByGithubTarget(
      repoName,
      targetNumber,
    );
    const nowIso = new Date().toISOString();
    const snapshot: DevReviewGithubSnapshot = {
      provider: "github",
      repo: repoName,
      targetType,
      number: targetNumber,
      url: asText(targetObj.html_url, 300),
      state: mapGithubState(
        asText(targetObj.state, 20),
        targetObj.merged === true,
      ),
      reviewDecision: mapReviewDecision(asText(reviewObj.state, 40)),
      syncedAt: nowIso,
    };

    let updatedCount = 0;
    for (const sess of matched) {
      const next: DevReviewSession = {
        ...sess,
        githubSnapshot: snapshot,
        updatedAt: nowIso,
      };
      const saved = await store.updateSession(sess.id, sess.userId, next);
      if (saved) updatedCount += 1;
    }

    return {
      status: 200,
      body: {
        success: true,
        matched_sessions: updatedCount,
        snapshot,
      },
    };
  }

  if (!userId) {
    return { status: 401, body: { error: "Unauthorized" } };
  }

  if (action === "dev_review.session.list") {
    const statusFilter = asText(body.status_filter, 40);
    const assigneeFilter = asText(body.assignee_filter, 120).toLowerCase();
    const sessions = await store.listSessions(userId, 40);

    const filtered = sessions.map((sess) => {
      const matchingItems = sess.items.filter((item) => {
        if (
          statusFilter &&
          statusFilter !== "all" &&
          item.status !== statusFilter
        ) {
          return false;
        }
        if (
          assigneeFilter &&
          !item.assignee.toLowerCase().includes(assigneeFilter)
        ) {
          return false;
        }
        return true;
      });
      return { ...sess, items: matchingItems };
    });

    return {
      status: 200,
      body: { success: true, sessions: filtered },
    };
  }

  if (action === "dev_review.session.create") {
    const title = asText(body.title, 160);
    const githubRepo = asText(body.github_repo, 160);
    const targetNumber = asPosInt(body.target_number, 0);
    const targetTypeRaw = asText(body.target_type, 20);
    const targetType: "issue" | "pr" = targetTypeRaw === "pr" ? "pr" : "issue";
    const approver = asText(body.approver, 120);
    const defaultAssignee = asText(body.assignee, 120);

    if (!title || !isValidGithubRepo(githubRepo) || targetNumber <= 0) {
      return {
        status: 400,
        body: {
          error:
            "title, valid github_repo (owner/repo), and target_number > 0 " +
            "are required.",
        },
      };
    }

    const nowIso = new Date().toISOString();
    const generated = buildDefaultReviewItems({
      targetType,
      assignee: defaultAssignee,
      nowIso,
    });

    const created = await store.createSession({
      userId,
      title,
      targetType,
      githubRepo,
      targetNumber,
      currentPhase: "intake",
      approver,
      items: generated,
      githubSnapshot: {
        provider: "github",
        repo: githubRepo,
        targetType,
        number: targetNumber,
        url: `https://github.com/${githubRepo}/${
          targetType === "pr" ? "pull" : "issues"
        }/${targetNumber}`,
        state: "open",
        reviewDecision: "none",
        syncedAt: nowIso,
      },
    });

    return { status: 200, body: { success: true, session: created } };
  }

  if (action === "dev_review.item.update") {
    const sessionId = asText(body.session_id, 80);
    const itemId = asText(body.item_id, 80);
    const statusRaw = asText(body.status, 40);
    const kindRaw = asText(body.kind, 40) || "finding";
    const titleRaw = asText(body.title, 160);
    const assignee = asText(body.assignee, 120);
    const note = asText(body.note, 500);

    if (!sessionId) {
      return { status: 400, body: { error: "session_id is required." } };
    }
    if (!VALID_STATUSES.has(statusRaw)) {
      return {
        status: 400,
        body: { error: `Invalid item status: ${statusRaw}` },
      };
    }

    const existing = await store.getSession(sessionId, userId);
    if (!existing) {
      return { status: 404, body: { error: "Review session not found." } };
    }

    const nowIso = new Date().toISOString();
    const nextItems = [...existing.items];
    const idx = itemId ? nextItems.findIndex((i) => i.id === itemId) : -1;

    if (idx >= 0) {
      const prev = nextItems[idx];
      nextItems[idx] = {
        ...prev,
        status: statusRaw as DevReviewItemStatus,
        assignee: assignee || prev.assignee,
        note: note || prev.note,
        updatedAt: nowIso,
      };
    } else {
      if (!titleRaw || !VALID_KINDS.has(kindRaw)) {
        return {
          status: 400,
          body: {
            error: "New review item requires valid kind and non-empty title.",
          },
        };
      }
      nextItems.push({
        id: itemId || `item-${crypto.randomUUID().slice(0, 8)}`,
        kind: kindRaw as DevReviewItemKind,
        title: titleRaw,
        category: asText(body.category, 60) || "review_finding",
        status: statusRaw as DevReviewItemStatus,
        assignee: assignee || "unassigned",
        note,
        updatedAt: nowIso,
      });
    }

    const updated = await store.updateSession(sessionId, userId, {
      ...existing,
      items: nextItems,
      updatedAt: nowIso,
    });
    return { status: 200, body: { success: true, session: updated } };
  }

  if (action === "dev_review.github.sync") {
    const sessionId = asText(body.session_id, 80);
    if (!sessionId) {
      return { status: 400, body: { error: "session_id is required." } };
    }
    const existing = await store.getSession(sessionId, userId);
    if (!existing) {
      return { status: 404, body: { error: "Review session not found." } };
    }

    const nowIso = new Date().toISOString();
    let snapshot: DevReviewGithubSnapshot;

    if (body.fetch_live === true) {
      if (!isValidGithubRepo(existing.githubRepo)) {
        return { status: 400, body: { error: "Invalid repository format." } };
      }
      const segment = existing.targetType === "pr" ? "pulls" : "issues";
      const url = `https://api.github.com/repos/${existing.githubRepo}/` +
        `${segment}/${existing.targetNumber}`;
      const ghAuth = (getEnv("GITHUB_TOKEN") ?? "").trim();
      const headers: Record<string, string> = {
        Accept: "application/vnd.github+json",
        "User-Agent": "my-web-app-dev-review-tracker",
      };
      if (ghAuth) {
        headers.Authorization = `Bearer ${ghAuth}`;
      }
      const resp = await fetcher(url, { method: "GET", headers });
      if (!resp.ok) {
        return {
          status: 502,
          body: { error: `GitHub API returned HTTP ${resp.status}` },
        };
      }
      const payload = asRecord(await resp.json());
      snapshot = {
        provider: "github",
        repo: existing.githubRepo,
        targetType: existing.targetType,
        number: existing.targetNumber,
        url: asText(payload.html_url, 300),
        state: mapGithubState(
          asText(payload.state, 20),
          payload.merged === true,
        ),
        reviewDecision: mapReviewDecision(
          asText(body.review_decision, 40) || "none",
        ),
        syncedAt: nowIso,
      };
    } else {
      snapshot = {
        provider: "github",
        repo: existing.githubRepo,
        targetType: existing.targetType,
        number: existing.targetNumber,
        url: asText(body.html_url, 300) ||
          (existing.githubSnapshot?.url ?? ""),
        state: mapGithubState(
          asText(body.state, 20) || "open",
          body.merged === true,
        ),
        reviewDecision: mapReviewDecision(asText(body.review_decision, 40)),
        syncedAt: nowIso,
      };
    }

    const updated = await store.updateSession(sessionId, userId, {
      ...existing,
      githubSnapshot: snapshot,
      updatedAt: nowIso,
    });
    return { status: 200, body: { success: true, session: updated } };
  }

  if (action === "dev_review.phase.advance") {
    const sessionId = asText(body.session_id, 80);
    const targetPhaseRaw = asText(body.target_phase, 40);
    const note = asText(body.note, 300);

    if (!sessionId) {
      return { status: 400, body: { error: "session_id is required." } };
    }
    if (!DEV_REVIEW_PHASES.includes(targetPhaseRaw as DevReviewPhase)) {
      return {
        status: 400,
        body: { error: `Invalid target_phase: ${targetPhaseRaw}` },
      };
    }

    const existing = await store.getSession(sessionId, userId);
    if (!existing) {
      return { status: 404, body: { error: "Review session not found." } };
    }

    const targetPhase = targetPhaseRaw as DevReviewPhase;
    const check = validatePhaseTransition(existing, targetPhase);
    if (!check.allowed) {
      return {
        status: 409,
        body: {
          success: false,
          blocked: true,
          error: "Phase transition blocked by unapproved review items.",
          blocking_reasons: check.blockingReasons,
          unapproved_item_count: check.unapprovedItemCount,
          open_finding_count: check.openFindingCount,
        },
      };
    }

    const nowIso = new Date().toISOString();
    const updated = await store.updateSession(sessionId, userId, {
      ...existing,
      currentPhase: targetPhase,
      phaseHistory: [
        ...existing.phaseHistory,
        {
          fromPhase: existing.currentPhase,
          toPhase: targetPhase,
          actorUserId: userId,
          decidedAt: nowIso,
          note,
        },
      ],
      updatedAt: nowIso,
    });

    return {
      status: 200,
      body: { success: true, blocked: false, session: updated },
    };
  }

  return { status: 400, body: { error: `Unknown action: ${action}` } };
}
