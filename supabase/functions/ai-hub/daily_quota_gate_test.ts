import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type DailyQuotaStore,
  enforceDailyAiQuota,
  readDailyAiQuotaStatus,
} from "./daily_quota_gate.ts";

class InMemoryDailyQuotaStore implements DailyQuotaStore {
  planByUser = new Map<string, string>();
  limitsByPlan = new Map<string, number>([
    ["free", 50],
    ["pro", 1000],
    ["enterprise", 2000],
  ]);
  usedByUser = new Map<string, number>();
  failClaim = false;

  claimDailyQuota(userId: string): Promise<Record<string, unknown>> {
    if (this.failClaim) {
      return Promise.reject(new Error("RPC unavailable"));
    }
    const plan = this.planByUser.get(userId) ?? "free";
    const limit = this.limitsByPlan.get(plan) ?? 50;
    const current = this.usedByUser.get(userId) ?? 0;
    if (current >= limit) {
      return Promise.resolve({
        allowed: false,
        reason: "daily_limit",
        plan,
        used: current,
        daily_limit: limit,
        remaining: 0,
        quota_date: "2026-11-24",
        reset_at: "2026-11-24T15:00:00Z",
      });
    }
    const next = current + 1;
    this.usedByUser.set(userId, next);
    return Promise.resolve({
      allowed: true,
      reason: null,
      plan,
      used: next,
      daily_limit: limit,
      remaining: limit - next,
      quota_date: "2026-11-24",
      reset_at: "2026-11-24T15:00:00Z",
    });
  }

  getDailyQuotaStatus(userId: string): Promise<Record<string, unknown>> {
    const plan = this.planByUser.get(userId) ?? "free";
    const limit = this.limitsByPlan.get(plan) ?? 50;
    const current = this.usedByUser.get(userId) ?? 0;
    return Promise.resolve({
      allowed: current < limit,
      reason: current >= limit ? "daily_limit" : null,
      plan,
      used: current,
      daily_limit: limit,
      remaining: Math.max(limit - current, 0),
      quota_date: "2026-11-24",
      reset_at: "2026-11-24T15:00:00Z",
    });
  }
}

Deno.test("enforceDailyAiQuota enforces plan-specific limits and blocks once exhausted", async () => {
  const store = new InMemoryDailyQuotaStore();
  store.planByUser.set("u-free", "free");
  store.usedByUser.set("u-free", 49);

  const allowed = await enforceDailyAiQuota(store, "u-free");
  assertEquals(allowed.allowed, true);
  assertEquals(allowed.plan, "free");
  assertEquals(allowed.used, 50);
  assertEquals(allowed.dailyLimit, 50);
  assertEquals(allowed.remaining, 0);

  const blocked = await enforceDailyAiQuota(store, "u-free");
  assertEquals(blocked.allowed, false);
  assertEquals(blocked.reason, "daily_limit");
  assertEquals(blocked.used, 50);
  assertEquals(blocked.remaining, 0);

  store.planByUser.set("u-ent", "enterprise");
  store.usedByUser.set("u-ent", 1999);
  const entOk = await enforceDailyAiQuota(store, "u-ent");
  assertEquals(entOk.allowed, true);
  assertEquals(entOk.plan, "enterprise");
  assertEquals(entOk.dailyLimit, 2000);
});

Deno.test("readDailyAiQuotaStatus reads count without incrementing and enforce fails open on RPC error", async () => {
  const store = new InMemoryDailyQuotaStore();
  store.planByUser.set("u-pro", "pro");
  store.usedByUser.set("u-pro", 10);

  const status = await readDailyAiQuotaStatus(store, "u-pro");
  assertEquals(status.used, 10);
  assertEquals(status.remaining, 990);
  assertEquals(store.usedByUser.get("u-pro"), 10);

  store.failClaim = true;
  const failOpen = await enforceDailyAiQuota(store, "u-pro");
  assertEquals(failOpen.allowed, true);
  assertEquals(failOpen.reason, "daily_quota_store_error");
});
