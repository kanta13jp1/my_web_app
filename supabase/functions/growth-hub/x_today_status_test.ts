import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { computeTodayStatus } from "./x_today_status.ts";

// JST 深夜 = 前日 15:00Z。クライアントはこの絶対時刻を送る。
const START_OF_DAY_JST = "2026-07-07T15:00:00.000Z"; // 2026-07-08 00:00 JST
const NOW = new Date("2026-07-08T04:00:00Z"); // = 13:00 JST

function row(
  createdAt: string,
  metadata: Record<string, unknown>,
): { created_at: string; metadata: Record<string, unknown> } {
  return { created_at: createdAt, metadata };
}

const POSTED_TODAY = row("2026-07-08T02:57:00Z", {
  status: "posted",
  tweet_id: "2074687597742616995",
  posted_at: "2026-07-08T02:57:00Z", // 11:57 JST
  media_type: "video",
  variant: "daily_briefing",
  latest_metrics: { impressions: 13 },
  metrics_checked_at: "2026-07-08T03:30:00Z",
});

Deno.test("counts a post made today and maps its fields", () => {
  const s = computeTodayStatus([POSTED_TODAY], START_OF_DAY_JST, NOW);
  assertEquals(s.available, true);
  assertEquals(s.postedTodayCount, 1);
  assertEquals(s.lastTweetId, "2074687597742616995");
  assertEquals(s.lastMediaType, "video");
  assertEquals(s.latestImpressions, 13);
  assertEquals(s.blocked, false);
});

Deno.test("no post today → count 0, null fields", () => {
  const yesterday = row("2026-07-07T02:00:00Z", {
    status: "posted",
    tweet_id: "old",
    posted_at: "2026-07-07T02:00:00Z", // before today's JST midnight
  });
  const s = computeTodayStatus([yesterday], START_OF_DAY_JST, NOW);
  assertEquals(s.postedTodayCount, 0);
  assertEquals(s.lastTweetId, null);
  assertEquals(s.latestImpressions, null);
});

Deno.test("failed / billing-blocked rows never count as posted", () => {
  const rows = [
    row("2026-07-08T02:00:00Z", { status: "failed", code: "x_post_failed" }),
    row("2026-07-08T02:30:00Z", {
      status: "failed",
      code: "x_billing_blocked",
      posted_at: "2026-07-08T02:30:00Z",
    }),
    row("2026-07-08T01:00:00Z", { status: "dry_run" }),
  ];
  assertEquals(
    computeTodayStatus(rows, START_OF_DAY_JST, NOW).postedTodayCount,
    0,
  );
});

Deno.test("JST 00:30 post (= prior-day 15:30 UTC) still counts as today", () => {
  const earlyMorning = row("2026-07-07T15:30:00Z", {
    status: "posted",
    tweet_id: "early",
    posted_at: "2026-07-07T15:30:00Z", // 00:30 JST 2026-07-08
  });
  const s = computeTodayStatus([earlyMorning], START_OF_DAY_JST, NOW);
  assertEquals(s.postedTodayCount, 1);
  assertEquals(s.lastTweetId, "early");
});

Deno.test("missing latest_metrics → latestImpressions null (計測待ち)", () => {
  const noMetrics = row("2026-07-08T02:57:00Z", {
    status: "posted",
    tweet_id: "t",
    posted_at: "2026-07-08T02:57:00Z",
  });
  const s = computeTodayStatus([noMetrics], START_OF_DAY_JST, NOW);
  assertEquals(s.postedTodayCount, 1);
  assertEquals(s.latestImpressions, null);
});

Deno.test("multiple posts today → count all, last = newest", () => {
  const earlier = row("2026-07-08T00:10:00Z", {
    status: "posted",
    tweet_id: "first",
    posted_at: "2026-07-08T00:10:00Z",
  });
  const s = computeTodayStatus([POSTED_TODAY, earlier], START_OF_DAY_JST, NOW);
  assertEquals(s.postedTodayCount, 2);
  assertEquals(s.lastTweetId, "2074687597742616995"); // 02:57 > 00:10
});

Deno.test("spend-cap block surfaces from decideXPostPreflight", () => {
  const blockedRows = [
    row("2026-07-08T02:30:00Z", {
      status: "failed",
      code: "x_billing_blocked",
      billing_blocked_until: "2026-07-10",
    }),
  ];
  const s = computeTodayStatus(blockedRows, START_OF_DAY_JST, NOW);
  assertEquals(s.blocked, true);
  assertEquals(s.resetAt, "2026-07-10");
  assertEquals(s.postedTodayCount, 0);
});
