import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ACCOUNT_DELETION_CONFIRMATION,
  ACCOUNT_DELETION_TOKEN_DRAIN_SECONDS,
  blockingDependencyCount,
  canCancelDeletionRequest,
  deletionScheduledFor,
  isServiceRoleRequest,
  positiveRequestId,
  remainingDeletionDependencyCount,
  requiresSubscriptionCancellation,
  sessionIdFromAccessToken,
  tokenDrainSecondsRemaining,
} from "./lifecycle.ts";

Deno.test("extracts only a valid session UUID from a verified access token", () => {
  const payload = btoa(JSON.stringify({
    session_id: "00000000-0000-4000-8000-100000002844",
  })).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
  assertEquals(
    sessionIdFromAccessToken(`header.${payload}.signature`),
    "00000000-0000-4000-8000-100000002844",
  );
  assertEquals(sessionIdFromAccessToken("not-a-jwt"), "");
  assertEquals(
    sessionIdFromAccessToken(
      `header.${btoa(JSON.stringify({ session_id: "not-a-uuid" }))}.signature`,
    ),
    "",
  );
});

Deno.test("cancellation closes permanently when worker processing begins", () => {
  assertEquals(
    canCancelDeletionRequest({ status: "pending", attempt_count: 0 }),
    true,
  );
  assertFalse(
    canCancelDeletionRequest({ status: "failed", attempt_count: 1 }),
  );
  assertFalse(
    canCancelDeletionRequest({
      status: "pending",
      attempt_count: 0,
      auth_user_deleted_at: "2026-08-29T10:00:00Z",
    }),
  );
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

Deno.test("finalization waits until pre-deletion JWTs have expired", () => {
  const now = new Date("2026-08-29T11:05:00Z");
  assertEquals(
    tokenDrainSecondsRemaining("2026-08-29T10:00:00Z", now),
    0,
  );
  assertEquals(
    tokenDrainSecondsRemaining("2026-08-29T10:30:00Z", now),
    30 * 60,
  );
  assertEquals(
    tokenDrainSecondsRemaining(null, now),
    ACCOUNT_DELETION_TOKEN_DRAIN_SECONDS,
  );
  assertEquals(
    remainingDeletionDependencyCount([
      { deletion_strategy: "cascade", matching_rows: 0 },
      { deletion_strategy: "delete_direct", matching_rows: 2 },
      { deletion_strategy: "retain_90_days", matching_rows: 5 },
    ]),
    2,
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

Deno.test("staged worker accepts only positive safe request identifiers", () => {
  assertEquals(positiveRequestId(2844), 2844);
  assertEquals(positiveRequestId(" 2844 "), 2844);
  assertEquals(positiveRequestId(0), null);
  assertEquals(positiveRequestId("1.5"), null);
  assertEquals(positiveRequestId(Number.MAX_SAFE_INTEGER + 1), null);
  assertEquals(positiveRequestId(null), null);
});
