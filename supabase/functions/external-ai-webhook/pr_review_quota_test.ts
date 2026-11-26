import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  DEFAULT_CONSUMER_PR_QUOTA,
  DEFAULT_ENTERPRISE_PR_QUOTA,
  defaultDailyLimitForTier,
  estimatePrReviewModelCalls,
  handlePrReviewQuotaRequest,
  type PrReviewQuotaDecision,
  type PrReviewQuotaStore,
} from "./pr_review_quota.ts";

const TEST_OWNER = "11111111-1111-4111-8111-111111111111";

function createInMemoryPrQuotaStore(initial?: {
  used?: number;
  limit?: number;
  planTier?: "consumer" | "enterprise";
}): {
  store: PrReviewQuotaStore;
  events: Array<Record<string, unknown>>;
  bucket: {
    used: number;
    skipped: number;
    modelCalls: number;
    limit: number;
    planTier: "consumer" | "enterprise";
  };
} {
  const events: Array<Record<string, unknown>> = [];
  const bucket = {
    used: initial?.used ?? 0,
    skipped: 0,
    modelCalls: 0,
    limit: initial?.limit ?? DEFAULT_CONSUMER_PR_QUOTA,
    planTier: initial?.planTier ?? ("consumer" as const),
  };

  const store: PrReviewQuotaStore = {
    claimOrSkip(input) {
      const limit = input.dailyLimit ?? bucket.limit;
      if (input.dryRun) {
        const decision: PrReviewQuotaDecision = {
          allowed: bucket.used < limit,
          skipped: bucket.used >= limit,
          status: "dry_run",
          http_status: 200,
          quota_date: "2026-11-25",
          plan_tier: input.planTier,
          pr_reviews_used: bucket.used,
          pr_review_daily_limit: limit,
          remaining: Math.max(0, limit - bucket.used),
          pr_reviews_skipped: bucket.skipped,
          pr_review_model_calls_used: bucket.modelCalls,
          isolated_from_general_quota: true,
        };
        events.push({ outcome: "dry_run", pr: input.prNumber });
        return Promise.resolve(decision);
      }

      if (bucket.used + 1 > limit) {
        bucket.skipped += 1;
        const skipReason =
          `PR review daily quota reached (${bucket.used}/${limit}); skipped cleanly.`;
        events.push({
          outcome: "skipped_quota_exceeded",
          pr: input.prNumber,
          skip_reason: skipReason,
        });
        return Promise.resolve({
          allowed: false,
          skipped: true,
          status: "skipped_quota_exceeded",
          http_status: 200,
          skip_reason: skipReason,
          quota_date: "2026-11-25",
          plan_tier: input.planTier,
          pr_reviews_used: bucket.used,
          pr_review_daily_limit: limit,
          remaining: 0,
          pr_reviews_skipped: bucket.skipped,
          pr_review_model_calls_used: bucket.modelCalls,
          isolated_from_general_quota: true,
        });
      }

      bucket.used += 1;
      bucket.modelCalls += input.estimatedModelCalls;
      events.push({
        outcome: "reviewed",
        pr: input.prNumber,
        estimated: input.estimatedModelCalls,
      });
      return Promise.resolve({
        allowed: true,
        skipped: false,
        status: "reviewed",
        http_status: 200,
        quota_date: "2026-11-25",
        plan_tier: input.planTier,
        pr_reviews_used: bucket.used,
        pr_review_daily_limit: limit,
        remaining: Math.max(0, limit - bucket.used),
        pr_reviews_skipped: bucket.skipped,
        pr_review_model_calls_used: bucket.modelCalls,
        isolated_from_general_quota: true,
      });
    },
    reconcileModelCalls(args) {
      const delta = args.actualModelCalls - args.estimatedModelCalls;
      bucket.modelCalls = Math.max(0, bucket.modelCalls + delta);
      events.push({
        outcome: "async_reconciled",
        pr: args.prNumber,
        actual: args.actualModelCalls,
        delta,
      });
      return Promise.resolve({
        reconciled: true,
        delta_model_calls: delta,
        pr_review_model_calls_used: bucket.modelCalls,
        isolated_from_general_quota: true,
      });
    },
    getStatus(args) {
      return Promise.resolve({
        installation_key: args.installationKey,
        pr_reviews_used: bucket.used,
        pr_review_daily_limit: bucket.limit,
        pr_reviews_skipped: bucket.skipped,
        pr_review_model_calls_used: bucket.modelCalls,
      });
    },
  };

  return { store, events, bucket };
}

Deno.test("plan tier defaults and multi-call estimation scale accurately", () => {
  assertEquals(defaultDailyLimitForTier("consumer"), DEFAULT_CONSUMER_PR_QUOTA);
  assertEquals(defaultDailyLimitForTier("enterprise"), DEFAULT_ENTERPRISE_PR_QUOTA);
  assertEquals(
    estimatePrReviewModelCalls({ changedFilesCount: 2, diffLinesCount: 60 }),
    1,
  );
  assertEquals(
    estimatePrReviewModelCalls({ changedFilesCount: 16, diffLinesCount: 900 }),
    4,
  );
});

Deno.test("executes PR review webhook and reconciles async multi-model calls", async () => {
  const { store, events, bucket } = createInMemoryPrQuotaStore({
    used: 0,
    limit: 33,
  });

  const res = await handlePrReviewQuotaRequest({
    action: "pr_review_quota.evaluate",
    body: {
      source_tool: "github_app",
      event_type: "github.pull_request.opened",
      payload: {
        installation: { id: 9001 },
        repository: { full_name: "kanta13jp1/my_web_app" },
        pull_request: {
          number: 6340,
          changed_files: 10,
          additions: 400,
          deletions: 120,
          head: { sha: "abc123def456" },
        },
      },
    },
    ownerUserId: TEST_OWNER,
    store,
    executeReview: () =>
      Promise.resolve({
        executed: true,
        provider: "mock-reviewer",
        summary: "Reviewed 10 files with 5 model calls",
        actualModelCalls: 5,
      }),
  });

  assertEquals(res.status, 200);
  assertEquals(res.body.ok, true);
  assertEquals(res.body.reviewed, true);
  assertEquals(res.body.skipped, false);
  assertEquals(bucket.used, 1);
  assertEquals(bucket.modelCalls, 5);
  assertEquals(events.length, 2);
  assertEquals(events[1].outcome, "async_reconciled");
});

Deno.test("skips PR cleanly with HTTP 200 and structured audit log when quota exhausted", async () => {
  const { store, events, bucket } = createInMemoryPrQuotaStore({
    used: 33,
    limit: 33,
  });
  let executorInvoked = false;

  const res = await handlePrReviewQuotaRequest({
    action: "pr_review_quota.evaluate",
    body: {
      source_tool: "github_app",
      event_type: "github.pull_request.synchronize",
      repository: "kanta13jp1/my_web_app",
      pr_number: 6341,
      installation_key: "gh-app-9001",
    },
    ownerUserId: TEST_OWNER,
    store,
    executeReview: () => {
      executorInvoked = true;
      return Promise.resolve({
        executed: true,
        provider: "should-not-run",
        summary: "",
        actualModelCalls: 1,
      });
    },
  });

  assertEquals(res.status, 200);
  assertEquals(res.body.ok, true);
  assertEquals(res.body.reviewed, false);
  assertEquals(res.body.skipped, true);
  assertEquals(res.body.status, "skipped_quota_exceeded");
  assertEquals(executorInvoked, false);
  assertEquals(bucket.used, 33);
  assertEquals(bucket.skipped, 1);
  assertEquals(events.length, 1);
  assertEquals(events[0].outcome, "skipped_quota_exceeded");
});

Deno.test("supports dry_run without consuming PR quota and returns isolated status", async () => {
  const { store, bucket } = createInMemoryPrQuotaStore({
    used: 4,
    limit: 100,
    planTier: "enterprise",
  });

  const dry = await handlePrReviewQuotaRequest({
    action: "pr_review_quota.evaluate",
    body: {
      dry_run: true,
      plan_tier: "enterprise",
      repository: "kanta13jp1/my_web_app",
      pr_number: 6342,
      installation_key: "gh-app-ent",
    },
    ownerUserId: TEST_OWNER,
    store,
  });
  assertEquals(dry.status, 200);
  assertEquals(dry.body.dry_run, true);
  assertEquals(dry.body.reviewed, false);
  assertEquals(bucket.used, 4);

  const statusRes = await handlePrReviewQuotaRequest({
    action: "pr_review_quota.status",
    body: { installation_key: "gh-app-ent" },
    ownerUserId: TEST_OWNER,
    store,
  });
  assertEquals(statusRes.status, 200);
  assertEquals(statusRes.body.isolated_from_general_quota, true);
});
