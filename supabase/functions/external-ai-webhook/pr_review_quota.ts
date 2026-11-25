import { asRecord, asString } from "../_shared/edge.ts";

export type PrReviewPlanTier = "consumer" | "enterprise";
export type PrReviewQuotaStatus =
  | "reviewed"
  | "skipped_quota_exceeded"
  | "dry_run"
  | "async_reconciled";

export const DEFAULT_CONSUMER_PR_QUOTA = 33;
export const DEFAULT_ENTERPRISE_PR_QUOTA = 100;

export interface PrReviewQuotaClaimInput {
  ownerUserId: string;
  installationKey: string;
  repository: string;
  prNumber: number;
  headSha: string;
  deliveryId: string;
  planTier: PrReviewPlanTier;
  dailyLimit: number | null;
  estimatedModelCalls: number;
  dryRun: boolean;
}

export interface PrReviewQuotaDecision {
  allowed: boolean;
  skipped: boolean;
  status: PrReviewQuotaStatus;
  http_status: number;
  skip_reason?: string;
  quota_date: string;
  plan_tier: PrReviewPlanTier;
  pr_reviews_used: number;
  pr_review_daily_limit: number;
  remaining: number;
  pr_reviews_skipped: number;
  pr_review_model_calls_used: number;
  isolated_from_general_quota: boolean;
}

export interface PrReviewQuotaStore {
  claimOrSkip(input: PrReviewQuotaClaimInput): Promise<PrReviewQuotaDecision>;
  reconcileModelCalls(args: {
    ownerUserId: string;
    installationKey: string;
    repository: string;
    prNumber: number;
    actualModelCalls: number;
    estimatedModelCalls: number;
    headSha: string;
  }): Promise<Record<string, unknown>>;
  getStatus(args: {
    ownerUserId: string;
    installationKey: string;
  }): Promise<Record<string, unknown> | null>;
}

export interface PrReviewDispatchResult {
  executed: boolean;
  provider: string;
  summary: string;
  actualModelCalls: number;
}

export type ReviewExecutor = (
  ctx: PrReviewQuotaClaimInput,
) => Promise<PrReviewDispatchResult>;

export function defaultDailyLimitForTier(tier: PrReviewPlanTier): number {
  return tier === "enterprise"
    ? DEFAULT_ENTERPRISE_PR_QUOTA
    : DEFAULT_CONSUMER_PR_QUOTA;
}

export function estimatePrReviewModelCalls(args: {
  changedFilesCount: number;
  diffLinesCount: number;
}): number {
  const files = Math.max(1, Math.trunc(args.changedFilesCount));
  const lines = Math.max(1, Math.trunc(args.diffLinesCount));
  const chunkCalls = Math.ceil(lines / 250);
  const fileCalls = Math.ceil(files / 8);
  return Math.max(1, Math.min(20, 1 + Math.max(chunkCalls, fileCalls) - 1));
}

export function normalizePlanTier(raw: unknown): PrReviewPlanTier {
  const clean = asString(raw).toLowerCase();
  return clean === "enterprise" ? "enterprise" : "consumer";
}

export function extractPrWebhookContext(
  body: Record<string, unknown>,
  ownerUserId: string,
): { input: PrReviewQuotaClaimInput } | { error: string } {
  const payload = asRecord(body.payload);
  const prObj = asRecord(payload.pull_request);
  const repoObj = asRecord(payload.repository);
  const installObj = asRecord(payload.installation);

  const prNumberRaw = body.pr_number ?? prObj.number ?? payload.pr_number;
  const prNumber = typeof prNumberRaw === "number"
    ? Math.trunc(prNumberRaw)
    : Number.parseInt(asString(prNumberRaw), 10);
  if (!Number.isFinite(prNumber) || prNumber <= 0) {
    return { error: "positive_pr_number_required" };
  }

  const repository = asString(body.repository) ||
    asString(repoObj.full_name) ||
    asString(payload.repository_name);
  if (!repository) {
    return { error: "repository_required" };
  }

  const installationKey = asString(body.installation_key) ||
    (installObj.id !== undefined ? `gh-app-${String(installObj.id)}` : "") ||
    `repo-${repository}`;

  const headObj = asRecord(prObj.head);
  const headSha = asString(body.head_sha) || asString(headObj.sha);
  const deliveryId = asString(body.external_event_id) ||
    asString(body.delivery_id);
  const planTier = normalizePlanTier(body.plan_tier ?? payload.plan_tier);

  const rawLimit = Number(body.daily_limit ?? payload.daily_limit ?? 0);
  const dailyLimit = Number.isFinite(rawLimit) && rawLimit > 0
    ? Math.trunc(rawLimit)
    : null;

  const changedFilesCount = Number(
    body.changed_files ?? prObj.changed_files ?? payload.changed_files ?? 1,
  );
  const diffLinesCount = Number(
    body.diff_lines ??
      (Number(prObj.additions ?? 0) + Number(prObj.deletions ?? 0)) ??
      1,
  );
  const explicitEstimate = Number(body.estimated_model_calls ?? 0);
  const estimatedModelCalls = Number.isFinite(explicitEstimate) && explicitEstimate > 0
    ? Math.min(100, Math.trunc(explicitEstimate))
    : estimatePrReviewModelCalls({
      changedFilesCount: Number.isFinite(changedFilesCount)
        ? changedFilesCount
        : 1,
      diffLinesCount: Number.isFinite(diffLinesCount) ? diffLinesCount : 1,
    });

  return {
    input: {
      ownerUserId,
      installationKey: installationKey.slice(0, 160),
      repository: repository.slice(0, 200),
      prNumber,
      headSha: headSha.slice(0, 64),
      deliveryId: deliveryId.slice(0, 128),
      planTier,
      dailyLimit,
      estimatedModelCalls,
      dryRun: body.dry_run === true,
    },
  };
}

export async function handlePrReviewQuotaRequest(args: {
  action: string;
  body: Record<string, unknown>;
  ownerUserId: string;
  store: PrReviewQuotaStore;
  executeReview?: ReviewExecutor;
}): Promise<{ status: number; body: Record<string, unknown> }> {
  const { action, body, ownerUserId, store } = args;

  if (action === "pr_review_quota.status") {
    const installKey = asString(body.installation_key);
    if (!installKey) {
      return { status: 400, body: { error: "installation_key_required" } };
    }
    const row = await store.getStatus({
      ownerUserId,
      installationKey: installKey,
    });
    return {
      status: 200,
      body: {
        ok: true,
        isolated_from_general_quota: true,
        bucket: row,
      },
    };
  }

  if (action === "pr_review_quota.reconcile") {
    const installKey = asString(body.installation_key);
    const repository = asString(body.repository);
    const prNumber = Number(body.pr_number);
    const actualCalls = Number(body.actual_model_calls);
    const estCalls = Number(body.estimated_model_calls ?? 1);
    if (
      !installKey ||
      !repository ||
      !Number.isFinite(prNumber) ||
      prNumber <= 0 ||
      !Number.isFinite(actualCalls) ||
      actualCalls < 0
    ) {
      return {
        status: 400,
        body: { error: "invalid_reconcile_parameters" },
      };
    }
    const res = await store.reconcileModelCalls({
      ownerUserId,
      installationKey: installKey,
      repository,
      prNumber: Math.trunc(prNumber),
      actualModelCalls: Math.trunc(actualCalls),
      estimatedModelCalls: Number.isFinite(estCalls) ? Math.trunc(estCalls) : 1,
      headSha: asString(body.head_sha),
    });
    return { status: 200, body: { ok: true, ...res } };
  }

  const extracted = extractPrWebhookContext(body, ownerUserId);
  if ("error" in extracted) {
    return { status: 400, body: { error: extracted.error } };
  }
  const input = extracted.input;
  const decision = await store.claimOrSkip(input);

  // Critical contract (#2700 AC3): when PR review quota is exceeded,
  // skip the PR cleanly with HTTP 200 and structured audit metadata rather than erroring.
  if (decision.skipped || !decision.allowed) {
    return {
      status: 200,
      body: {
        ok: true,
        reviewed: false,
        skipped: true,
        status: "skipped_quota_exceeded",
        skip_reason: decision.skip_reason ??
          "PR review daily quota reached; skipped cleanly.",
        quota: decision,
      },
    };
  }

  if (input.dryRun) {
    return {
      status: 200,
      body: {
        ok: true,
        dry_run: true,
        reviewed: false,
        skipped: false,
        status: "dry_run",
        quota: decision,
      },
    };
  }

  const executor: ReviewExecutor = args.executeReview ??
    ((ctx) =>
      Promise.resolve({
        executed: true,
        provider: "offline-review-dispatcher",
        summary: `Queued PR review for ${ctx.repository}#${ctx.prNumber}`,
        actualModelCalls: ctx.estimatedModelCalls,
      }));
  const reviewResult = await executor(input);

  let reconciliation: Record<string, unknown> | null = null;
  if (reviewResult.actualModelCalls !== input.estimatedModelCalls) {
    reconciliation = await store.reconcileModelCalls({
      ownerUserId: input.ownerUserId,
      installationKey: input.installationKey,
      repository: input.repository,
      prNumber: input.prNumber,
      actualModelCalls: reviewResult.actualModelCalls,
      estimatedModelCalls: input.estimatedModelCalls,
      headSha: input.headSha,
    });
  }

  return {
    status: 200,
    body: {
      ok: true,
      reviewed: reviewResult.executed,
      skipped: false,
      status: "reviewed",
      review: reviewResult,
      quota: decision,
      async_reconciliation: reconciliation,
    },
  };
}
