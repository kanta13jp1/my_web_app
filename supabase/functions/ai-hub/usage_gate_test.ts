import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  checkAndRecordAiUsage,
  currentBillingPeriodStart,
  decideUsage,
  FREE_AI_QUERY_LIMIT,
  type UsageStore,
} from "./usage_gate.ts";

Deno.test("currentBillingPeriodStart returns first day of the UTC month", () => {
  assertEquals(
    currentBillingPeriodStart(new Date("2026-06-25T14:00:00Z")),
    "2026-06-01",
  );
  assertEquals(
    currentBillingPeriodStart(new Date("2026-01-31T23:59:59Z")),
    "2026-01-01",
  );
});

Deno.test("decideUsage: free under limit is allowed", () => {
  const d = decideUsage("free", 5, 30);
  assertEquals(d.allowed, true);
  assertEquals(d.limit, 30);
});

Deno.test("decideUsage: free at/over limit is denied", () => {
  assertEquals(decideUsage("free", 30, 30).allowed, false);
  assertEquals(decideUsage("free", 31, 30).allowed, false);
  assertEquals(decideUsage("free", 30, 30).reason, "free_limit_reached");
});

Deno.test("decideUsage: pro/team are unlimited regardless of count", () => {
  assertEquals(decideUsage("pro", 9999, 30).allowed, true);
  assertEquals(decideUsage("pro", 9999, 30).limit, null);
  assertEquals(decideUsage("team", 9999, 30).allowed, true);
  assertEquals(decideUsage("TEAM", 9999, 30).allowed, true); // case-insensitive
});

Deno.test("decideUsage: unknown/empty tier defaults to free rules", () => {
  assertEquals(decideUsage("", 0, 30).allowed, true);
  assertEquals(decideUsage("", 30, 30).allowed, false);
});

function fakeStore(
  tier: string,
  count: number,
): UsageStore & { written: number[] } {
  const written: number[] = [];
  return {
    written,
    getTier: () => Promise.resolve(tier),
    getCount: () => Promise.resolve(count),
    setCount: (_u, _p, c) => {
      written.push(c);
      return Promise.resolve();
    },
  };
}

Deno.test("checkAndRecordAiUsage: free under limit increments and allows", async () => {
  const store = fakeStore("free", 5);
  const d = await checkAndRecordAiUsage(store, "u1", {
    now: new Date("2026-06-10T00:00:00Z"),
  });
  assertEquals(d.allowed, true);
  assertEquals(d.used, 6); // incremented
  assertEquals(store.written, [6]);
});

Deno.test("checkAndRecordAiUsage: free at limit denies and does NOT increment", async () => {
  const store = fakeStore("free", FREE_AI_QUERY_LIMIT);
  const d = await checkAndRecordAiUsage(store, "u1");
  assertEquals(d.allowed, false);
  assertEquals(store.written, []); // no write when denied
});

Deno.test("checkAndRecordAiUsage: pro is unlimited but still records usage", async () => {
  const store = fakeStore("pro", 100);
  const d = await checkAndRecordAiUsage(store, "u1");
  assertEquals(d.allowed, true);
  assertEquals(d.limit, null);
  assertEquals(store.written, [101]);
});

Deno.test("checkAndRecordAiUsage: fails OPEN when the store throws", async () => {
  const store: UsageStore = {
    getTier: () => Promise.reject(new Error("db down")),
    getCount: () => Promise.resolve(0),
    setCount: () => Promise.resolve(),
  };
  const d = await checkAndRecordAiUsage(store, "u1");
  assertEquals(d.allowed, true); // never block AI on metering error
  assertEquals(d.reason, "metering_error");
});
