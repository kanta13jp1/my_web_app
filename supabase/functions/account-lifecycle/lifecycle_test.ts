import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ACCOUNT_DELETION_CONFIRMATION,
  blockingDependencyCount,
  deletionScheduledFor,
  isRecentSignIn,
  isServiceRoleRequest,
  requiresSubscriptionCancellation,
} from "./lifecycle.ts";

Deno.test("recent sign-in expires after fifteen minutes", () => {
  const now = new Date("2026-08-29T10:00:00Z");
  assertEquals(isRecentSignIn("2026-08-29T09:45:00Z", now), true);
  assertFalse(isRecentSignIn("2026-08-29T09:44:59Z", now));
  assertFalse(isRecentSignIn("not-a-date", now));
});

Deno.test("active subscription must be cancelled before account deletion", () => {
  assertEquals(
    requiresSubscriptionCancellation({
      status: "active",
      cancel_at_period_end: false,
    }),
    true,
  );
  assertFalse(
    requiresSubscriptionCancellation({
      status: "active",
      cancel_at_period_end: true,
    }),
  );
  assertFalse(requiresSubscriptionCancellation({ status: "canceled" }));
});

Deno.test("schedule uses later of grace window and paid period end", () => {
  const requestedAt = new Date("2026-08-01T00:00:00Z");
  assertEquals(
    deletionScheduledFor(requestedAt, null).toISOString(),
    "2026-08-31T00:00:00.000Z",
  );
  assertEquals(
    deletionScheduledFor(requestedAt, {
      current_period_end: "2026-09-10T00:00:00Z",
    }).toISOString(),
    "2026-09-10T00:00:00.000Z",
  );
});

Deno.test("inventory counts only populated blocking dependencies", () => {
  assertEquals(
    blockingDependencyCount([
      { is_blocking: true, matching_rows: 3 },
      { is_blocking: false, matching_rows: 10 },
      { is_blocking: true, matching_rows: 0 },
    ]),
    3,
  );
});

Deno.test("service role comparison requires an exact bearer token", () => {
  const key = "service-role-secret";
  assertEquals(
    isServiceRoleRequest(
      new Request("https://example.test", {
        headers: { authorization: `Bearer ${key}` },
      }),
      key,
    ),
    true,
  );
  assertFalse(
    isServiceRoleRequest(
      new Request("https://example.test", {
        headers: { authorization: "Bearer wrong" },
      }),
      key,
    ),
  );
  assertEquals(ACCOUNT_DELETION_CONFIRMATION, "アカウントを削除する");
});
