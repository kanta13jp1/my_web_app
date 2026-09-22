export const ACCOUNT_DELETION_POLICY_VERSION = "2026-08-29.v1";
export const ACCOUNT_DELETION_GRACE_DAYS = 30;
export const ACCOUNT_DELETION_TOKEN_DRAIN_SECONDS = 65 * 60;
export const ACCOUNT_DELETION_CONFIRMATION = "アカウントを削除する";

const ACTIVE_SUBSCRIPTION_STATUSES = new Set([
  "active",
  "trialing",
  "past_due",
  "incomplete",
]);

export type BillingState = {
  status?: unknown;
  cancel_at_period_end?: unknown;
  current_period_end?: unknown;
};

export type DependencyInventoryRow = {
  deletion_strategy?: unknown;
  matching_rows?: unknown;
  is_blocking?: unknown;
};

export type CancellableDeletionRequest = {
  status?: unknown;
  attempt_count?: unknown;
  auth_user_deleted_at?: unknown;
};

export function canCancelDeletionRequest(
  request: CancellableDeletionRequest,
): boolean {
  return request.status === "pending" &&
    Number(request.attempt_count ?? 0) === 0 &&
    request.auth_user_deleted_at == null;
}

export function sessionIdFromAccessToken(token: string): string {
  const segments = token.split(".");
  if (segments.length !== 3) return "";
  try {
    const encoded = segments[1].replaceAll("-", "+").replaceAll("_", "/");
    const padded = encoded.padEnd(Math.ceil(encoded.length / 4) * 4, "=");
    const binary = atob(padded);
    const bytes = Uint8Array.from(
      binary,
      (character) => character.charCodeAt(0),
    );
    const payload = JSON.parse(new TextDecoder().decode(bytes));
    const sessionId = typeof payload?.session_id === "string"
      ? payload.session_id.trim()
      : "";
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
        .test(sessionId)
      ? sessionId
      : "";
  } catch {
    return "";
  }
}

export function requiresSubscriptionCancellation(
  billing: BillingState | null | undefined,
): boolean {
  if (!billing) return false;
  const status = String(billing.status ?? "").toLowerCase();
  return ACTIVE_SUBSCRIPTION_STATUSES.has(status) &&
    billing.cancel_at_period_end !== true;
}

export function deletionScheduledFor(
  requestedAt: Date,
  billing: BillingState | null | undefined,
): Date {
  const graceEnd = new Date(
    requestedAt.getTime() + ACCOUNT_DELETION_GRACE_DAYS * 86400 * 1000,
  );
  const periodEndRaw = billing?.current_period_end;
  if (typeof periodEndRaw !== "string" || periodEndRaw.trim() === "") {
    return graceEnd;
  }
  const periodEnd = new Date(periodEndRaw);
  if (Number.isNaN(periodEnd.getTime())) return graceEnd;
  return periodEnd > graceEnd ? periodEnd : graceEnd;
}

export function blockingDependencyCount(
  inventory: DependencyInventoryRow[] | null | undefined,
): number {
  return (inventory ?? []).reduce((total, row) => {
    if (row.is_blocking !== true) return total;
    const count = Number(row.matching_rows ?? 0);
    return total + (Number.isFinite(count) && count > 0 ? count : 0);
  }, 0);
}

export function remainingDeletionDependencyCount(
  inventory: DependencyInventoryRow[] | null | undefined,
): number {
  return (inventory ?? []).reduce((total, row) => {
    if (row.deletion_strategy === "retain_90_days") return total;
    const count = Number(row.matching_rows ?? 0);
    return total + (Number.isFinite(count) && count > 0 ? count : 0);
  }, 0);
}

export function tokenDrainSecondsRemaining(
  authUserDeletedAt: unknown,
  now = new Date(),
): number {
  if (
    typeof authUserDeletedAt !== "string" || authUserDeletedAt.trim() === ""
  ) {
    return ACCOUNT_DELETION_TOKEN_DRAIN_SECONDS;
  }
  const deletedAt = new Date(authUserDeletedAt);
  if (Number.isNaN(deletedAt.getTime())) {
    return ACCOUNT_DELETION_TOKEN_DRAIN_SECONDS;
  }
  const remainingMs = ACCOUNT_DELETION_TOKEN_DRAIN_SECONDS * 1000 -
    (now.getTime() - deletedAt.getTime());
  return Math.max(0, Math.ceil(remainingMs / 1000));
}

export function bearerToken(request: Request): string {
  const header = request.headers.get("authorization") ?? "";
  return header.toLowerCase().startsWith("bearer ")
    ? header.slice(7).trim()
    : "";
}

export function positiveRequestId(value: unknown): number | null {
  if (typeof value !== "number" && typeof value !== "string") return null;
  const normalized = typeof value === "string" ? value.trim() : value;
  if (normalized === "") return null;
  const parsed = Number(normalized);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

export function isServiceRoleRequest(
  request: Request,
  serviceRoleKey: string,
): boolean {
  const token = bearerToken(request);
  return serviceRoleKey !== "" && token.length === serviceRoleKey.length &&
    timingSafeEqual(token, serviceRoleKey);
}

function timingSafeEqual(left: string, right: string): boolean {
  let mismatch = 0;
  for (let index = 0; index < left.length; index += 1) {
    mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return mismatch === 0;
}

export function safeErrorCode(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error ?? "");
  if (message.includes("account_deletion_dependency_blocked")) {
    return "account_deletion_dependency_blocked";
  }
  if (message.includes("stripe")) return "stripe_deletion_failed";
  if (message.includes("storage")) return "storage_deletion_failed";
  if (message.includes("database deletion")) {
    return "database_deletion_failed";
  }
  if (message.includes("auth")) return "auth_deletion_failed";
  return "account_deletion_failed";
}
