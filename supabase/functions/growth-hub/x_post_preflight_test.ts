import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { decideXPostPreflight } from "./x_post_preflight.ts";
import { parseBillingBlockedUntil } from "../_shared/x-client.ts";

const NOW = new Date("2026-07-08T03:00:00Z");

function row(
  createdAt: string,
  metadata: Record<string, unknown>,
): { created_at: string; metadata: Record<string, unknown> } {
  return { created_at: createdAt, metadata };
}

const BILLING_FAIL = row("2026-07-08T00:15:00Z", {
  status: "failed",
  code: "x_billing_blocked",
  error:
    "X APIのクレジットが不足しています（Your enrolled account has reached its billing cycle spend cap. API requests will be blocked until the next cycle begins on 2026-07-10.）。",
});

Deno.test("parseBillingBlockedUntil extracts the cycle reset date", () => {
  assertEquals(
    parseBillingBlockedUntil(
      "API requests will be blocked until the next cycle begins on 2026-07-10.",
    ),
    "2026-07-10",
  );
  assertEquals(parseBillingBlockedUntil("no credits"), null);
  assertEquals(parseBillingBlockedUntil(""), null);
});

Deno.test("blocked before reset date, with resetAt surfaced", () => {
  const result = decideXPostPreflight([BILLING_FAIL], NOW);
  assertEquals(result.blocked, true);
  assertEquals(result.code, "x_billing_blocked");
  assertEquals(result.resetAt, "2026-07-10");
});

Deno.test("unblocked after the reset date (+grace)", () => {
  const after = new Date("2026-07-10T13:00:00Z");
  assertEquals(decideXPostPreflight([BILLING_FAIL], after).blocked, false);
});

Deno.test("a newer posted success self-heals the block", () => {
  const rows = [
    BILLING_FAIL,
    row("2026-07-08T02:00:00Z", { status: "posted" }),
  ];
  assertEquals(decideXPostPreflight(rows, NOW).blocked, false);
});

Deno.test("pre-post rejection rows never unblock (dry_run newest)", () => {
  // x.post は投稿前 rejection 行も書く。最新行が dry_run でも billing 失敗が
  // 生きている限り blocked を維持する。
  const rows = [
    row("2026-07-08T02:30:00Z", { status: "dry_run" }),
    BILLING_FAIL,
  ];
  assertEquals(decideXPostPreflight(rows, NOW).blocked, true);
});

Deno.test("structured billing_blocked_until wins over prose", () => {
  const rows = [
    row("2026-07-08T00:15:00Z", {
      status: "failed",
      code: "x_billing_blocked",
      billing_blocked_until: "2026-07-11",
      error: "no parseable prose here",
    }),
  ];
  const result = decideXPostPreflight(rows, NOW);
  assertEquals(result.resetAt, "2026-07-11");
});

Deno.test("unparseable reset date falls back to 24h TTL", () => {
  const rows = [
    row("2026-07-08T00:15:00Z", {
      status: "failed",
      code: "x_billing_blocked",
      error: "generic 402 without a date",
    }),
  ];
  assert(decideXPostPreflight(rows, NOW).blocked);
  const afterTtl = new Date("2026-07-09T01:00:00Z");
  assertEquals(decideXPostPreflight(rows, afterTtl).blocked, false);
});

Deno.test("no billing failure means not blocked", () => {
  assertEquals(decideXPostPreflight([], NOW).blocked, false);
  const rows = [row("2026-07-08T01:00:00Z", {
    status: "failed",
    code: "x_post_failed",
    error: "some other error",
  })];
  assertEquals(decideXPostPreflight(rows, NOW).blocked, false);
});
