import {
  assertEquals,
  assertObjectMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildFirstUserFunnelReport } from "./first_user_funnel.ts";

const post = {
  sourceLogId: "log-1",
  tweetId: "tweet-1",
  postedAt: "2026-07-24T00:00:00.000Z",
  latestImpressions: 80,
  latestUrlClicks: 0,
  normalized: null,
};

Deno.test("first user funnel waits for publish without leaking visitors", () => {
  const report = buildFirstUserFunnelReport({
    utmSource: "x",
    utmMedium: "organic",
    utmContent: "outcome_first_a",
    post: null,
    events: [],
    payments: [],
    nowMs: Date.parse("2026-07-24T03:00:00.000Z"),
  });

  assertObjectMatch(report, {
    success: true,
    attribution: {
      utmSource: "x",
      utmMedium: "organic",
      utmCampaign: "first_user_growth",
      utmContent: "outcome_first_a",
    },
    decision: {
      stage: "awaiting_publish",
      nextVariable: "publish",
    },
    paymentCaptured: false,
    bankPayoutVerified: false,
    sessionGoalComplete: false,
  });
  assertEquals(
    (report.privacy as Record<string, unknown>).containsRawVisitorIds,
    false,
  );
});

Deno.test("first user funnel counts each visitor once and changes one variable", () => {
  const events = [
    {
      visitor_id: "visitor-1",
      stage: "view",
      first_occurred_at: "2026-07-24T00:05:00.000Z",
    },
    {
      visitor_id: "visitor-1",
      stage: "view",
      first_occurred_at: "2026-07-24T00:06:00.000Z",
    },
  ];
  const report = buildFirstUserFunnelReport({
    utmSource: "x",
    utmMedium: "organic",
    utmContent: "outcome_first_a",
    post,
    events,
    payments: [],
    nowMs: Date.parse("2026-07-24T04:00:00.000Z"),
  });
  const funnel = report.funnel as Record<string, unknown>;

  assertEquals(
    (funnel.counts as Record<string, number>).view,
    1,
  );
  assertObjectMatch(report, {
    decision: {
      stage: "reach_bottleneck",
      nextVariable: "hook",
    },
  });
});

Deno.test("first user funnel advances to payout verification after paid event", () => {
  const stages = [
    "view",
    "trial",
    "signup_submit",
    "signup_complete",
    "first_action_completed",
    "billing_view",
    "supporter_checkout",
  ];
  const report = buildFirstUserFunnelReport({
    utmSource: "x",
    utmMedium: "organic",
    utmContent: "outcome_first_a",
    post: { ...post, latestImpressions: 12000, latestUrlClicks: 50 },
    events: stages.map((stage) => ({
      visitor_id: "visitor-1",
      stage,
      first_occurred_at: "2026-07-24T01:00:00.000Z",
    })),
    payments: [{
      amountJpy: 100,
      createdAt: "2026-07-24T02:00:00.000Z",
    }],
    nowMs: Date.parse("2026-07-25T01:00:00.000Z"),
  });

  assertObjectMatch(report, {
    revenue: { paidPayments: 1, revenueJpy: 100 },
    decision: {
      stage: "payment_received",
      nextVariable: "bank_payout_verification",
    },
    paymentCaptured: true,
    bankPayoutVerified: false,
    sessionGoalComplete: false,
  });
});

Deno.test("Zenn first user funnel preserves the 24-hour measurement window", () => {
  const report = buildFirstUserFunnelReport({
    utmSource: "zenn",
    utmMedium: "organic",
    utmContent: "oauth_case_study_a",
    campaignStartedAt: "2026-08-19T17:46:00.000Z",
    post: null,
    events: [],
    payments: [],
    nowMs: Date.parse("2026-08-20T15:00:00.000Z"),
  });

  assertObjectMatch(report, {
    attribution: {
      utmSource: "zenn",
      utmMedium: "organic",
      utmCampaign: "first_user_growth",
      utmContent: "oauth_case_study_a",
    },
    campaign: {
      source: "zenn",
      startedAt: "2026-08-19T17:46:00.000Z",
    },
    x: null,
    decision: {
      stage: "collecting_24h",
      nextVariable: "none",
    },
  });
});

Deno.test("Zenn first user funnel diagnoses distribution after 24 hours", () => {
  const report = buildFirstUserFunnelReport({
    utmSource: "zenn",
    utmMedium: "organic",
    utmContent: "oauth_case_study_a",
    campaignStartedAt: "2026-08-19T17:46:00.000Z",
    post: null,
    events: [],
    payments: [],
    nowMs: Date.parse("2026-08-20T17:47:00.000Z"),
  });

  assertObjectMatch(report, {
    decision: {
      stage: "reach_bottleneck",
      nextVariable: "article_distribution",
    },
  });
});
