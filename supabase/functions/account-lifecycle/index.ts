import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  createClient,
  type SupabaseClient,
  type User,
} from "npm:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/edge.ts";
import {
  ACCOUNT_DELETION_CONFIRMATION,
  ACCOUNT_DELETION_GRACE_DAYS,
  ACCOUNT_DELETION_POLICY_VERSION,
  bearerToken,
  blockingDependencyCount,
  canCancelDeletionRequest,
  deletionScheduledFor,
  isServiceRoleRequest,
  positiveRequestId,
  remainingDeletionDependencyCount,
  requiresSubscriptionCancellation,
  safeErrorCode,
  sessionIdFromAccessToken,
  tokenDrainSecondsRemaining,
} from "./lifecycle.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = (
  Deno.env.get("SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    ""
).trim();
const STRIPE_SECRET_KEY = (Deno.env.get("STRIPE_SECRET_KEY") ?? "").trim();
const MAX_BODY_BYTES = 8 * 1024;
const MAX_STORAGE_BATCHES = 100;

type JsonRecord = Record<string, unknown>;

type AuthenticatedContext = {
  user: User;
  sessionId: string;
};

type DeletionRequestRow = {
  id: number;
  user_id: string | null;
  status: string;
  policy_version: string;
  requested_at: string;
  scheduled_for: string;
  auth_user_deleted_at: string | null;
  cancelled_at: string | null;
  completed_at: string | null;
  attempt_count: number;
  last_error_code: string | null;
  storage_objects_deleted: number;
  stripe_customer_deleted: boolean;
};

class StorageDeletionError extends Error {
  constructor(message: string, readonly deletedCount: number) {
    super(message);
    this.name = "StorageDeletionError";
  }
}

serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  try {
    assertConfiguration();
    const body = await readBody(request);
    const action = asString(body.action);
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    if (action === "process_due" || action === "preflight_due") {
      if (!isServiceRoleRequest(request, SERVICE_ROLE_KEY)) {
        return jsonResponse({ error: "service_role_required" }, 401);
      }
      const requestId = positiveRequestId(body.request_id);
      if (body.request_id != null && requestId == null) {
        return jsonResponse({ error: "invalid_request_id" }, 400);
      }
      if (action === "preflight_due") {
        return await preflightDueRequest(admin, requestId);
      }
      return await processDueRequest(admin, requestId);
    }

    const authenticated = await authenticatedContext(request);
    if (!authenticated || authenticated.user.is_anonymous) {
      return jsonResponse({ error: "authentication_required" }, 401);
    }

    switch (action) {
      case "status":
        return await statusResponse(admin, authenticated.user.id);
      case "request_deletion":
        return await requestDeletion(
          admin,
          authenticated.user,
          authenticated.sessionId,
          body,
        );
      case "cancel_deletion":
        return await cancelDeletion(admin, authenticated.user.id);
      default:
        return jsonResponse({ error: "unknown_action" }, 400);
    }
  } catch (error) {
    console.error("[account-lifecycle] request failed", safeErrorCode(error));
    return jsonResponse({ error: "account_lifecycle_unavailable" }, 503);
  }
});

async function statusResponse(
  admin: SupabaseClient,
  userId: string,
): Promise<Response> {
  const active = await activeRequest(admin, userId);
  return jsonResponse({
    success: true,
    request: toPublicRequest(active),
    policy: publicPolicy(),
  });
}

async function requestDeletion(
  admin: SupabaseClient,
  user: User,
  sessionId: string,
  body: JsonRecord,
): Promise<Response> {
  if (asString(body.confirmation) !== ACCOUNT_DELETION_CONFIRMATION) {
    return jsonResponse({ error: "confirmation_mismatch" }, 400);
  }
  if (!await hasRecentAccountDeletionSession(admin, user.id, sessionId)) {
    return jsonResponse({
      error: "reauthentication_required",
      reauthentication_window_minutes: 15,
    }, 403);
  }

  const existing = await activeRequest(admin, user.id);
  if (existing) {
    return jsonResponse({
      success: true,
      idempotent: true,
      request: toPublicRequest(existing),
      policy: publicPolicy(),
    });
  }

  const { data: billing, error: billingError } = await admin
    .from("billing_subscriptions")
    .select("status,cancel_at_period_end,current_period_end")
    .eq("user_id", user.id)
    .maybeSingle();
  if (billingError) throw billingError;
  if (requiresSubscriptionCancellation(billing)) {
    return jsonResponse(
      { error: "active_subscription_must_be_cancelled" },
      409,
    );
  }

  const requestedAt = new Date();
  const scheduledFor = deletionScheduledFor(requestedAt, billing);
  const { data, error } = await admin
    .from("account_deletion_requests")
    .insert({
      user_id: user.id,
      status: "pending",
      policy_version: ACCOUNT_DELETION_POLICY_VERSION,
      requested_at: requestedAt.toISOString(),
      scheduled_for: scheduledFor.toISOString(),
    })
    .select(publicRequestColumns())
    .single();
  if (error?.code === "23505") {
    const raced = await activeRequest(admin, user.id);
    if (raced) {
      return jsonResponse({
        success: true,
        idempotent: true,
        request: toPublicRequest(raced),
        policy: publicPolicy(),
      });
    }
  }
  if (error) throw error;

  return jsonResponse({
    success: true,
    idempotent: false,
    request: data,
    policy: publicPolicy(),
  }, 201);
}

async function cancelDeletion(
  admin: SupabaseClient,
  userId: string,
): Promise<Response> {
  const current = await activeRequest(admin, userId);
  if (!current) {
    return jsonResponse({ error: "deletion_request_not_found" }, 404);
  }
  if (!canCancelDeletionRequest(current)) {
    return jsonResponse({ error: "deletion_already_processing" }, 409);
  }

  const { data, error } = await admin
    .from("account_deletion_requests")
    .update({
      status: "cancelled",
      cancelled_at: new Date().toISOString(),
      retry_after: null,
      last_error_code: null,
    })
    .eq("id", current.id)
    .eq("user_id", userId)
    .eq("status", "pending")
    .eq("attempt_count", 0)
    .is("auth_user_deleted_at", null)
    .select(publicRequestColumns())
    .maybeSingle();
  if (error) throw error;
  if (!data) {
    return jsonResponse({ error: "deletion_already_processing" }, 409);
  }
  return jsonResponse({ success: true, request: null, policy: publicPolicy() });
}

async function hasRecentAccountDeletionSession(
  admin: SupabaseClient,
  userId: string,
  sessionId: string,
): Promise<boolean> {
  if (sessionId === "") return false;
  const { data, error } = await admin.rpc(
    "has_recent_account_deletion_session",
    { p_user_id: userId, p_session_id: sessionId },
  );
  if (error) throw error;
  return data === true;
}

async function preflightDueRequest(
  admin: SupabaseClient,
  requestId: number | null,
): Promise<Response> {
  const { data, error } = await admin.rpc(
    "preflight_due_account_deletion",
    { p_request_id: requestId },
  );
  if (error) throw error;
  const candidate = Array.isArray(data) ? data[0] : undefined;
  if (!candidate) {
    return jsonResponse({
      success: true,
      candidate: null,
      reason: "no_due_request",
    });
  }
  return jsonResponse({ success: true, candidate });
}

async function processDueRequest(
  admin: SupabaseClient,
  requestId: number | null,
): Promise<Response> {
  const { data: claimedRows, error: claimError } = await admin.rpc(
    requestId == null
      ? "claim_due_account_deletion"
      : "claim_due_account_deletion_by_id",
    requestId == null ? undefined : { p_request_id: requestId },
  );
  if (claimError) throw claimError;
  const request = Array.isArray(claimedRows)
    ? claimedRows[0] as DeletionRequestRow | undefined
    : undefined;
  if (!request?.user_id) {
    return jsonResponse({
      success: true,
      processed: false,
      reason: "no_due_request",
    });
  }

  let storageObjectsDeleted = 0;
  let stripeCustomerDeleted = false;
  let authUserDeleted = request.auth_user_deleted_at != null;
  try {
    const blockers = await dependencyBlockers(admin, request.user_id);
    if (blockers > 0) {
      await markFailed(
        admin,
        request.id,
        "account_deletion_dependency_blocked",
        blockers,
      );
      return jsonResponse({
        success: false,
        processed: false,
        request_id: request.id,
        error: "account_deletion_dependency_blocked",
        blocking_rows: blockers,
      }, 409);
    }

    const billing = authUserDeleted
      ? null
      : await billingForDeletion(admin, request.user_id);
    if (!authUserDeleted && requiresSubscriptionCancellation(billing)) {
      await markFailed(
        admin,
        request.id,
        "active_subscription_not_cancelled",
        0,
      );
      return jsonResponse({
        success: false,
        processed: false,
        request_id: request.id,
        error: "active_subscription_not_cancelled",
      }, 409);
    }

    if (!request.stripe_customer_deleted && billing?.stripe_customer_id) {
      await deleteStripeCustomer(String(billing.stripe_customer_id));
      stripeCustomerDeleted = true;
    }

    await deleteDirectDatabaseRows(admin, request.user_id);

    storageObjectsDeleted = await deleteOwnedStorageObjects(
      admin,
      request.user_id,
    );

    const { error: deleteUserError } = await admin.auth.admin.deleteUser(
      request.user_id,
    );
    if (deleteUserError && !isAuthUserMissing(deleteUserError)) {
      throw new Error(`auth deletion failed: ${deleteUserError.message}`);
    }
    authUserDeleted = true;

    const tokenDrainSeconds = tokenDrainSecondsRemaining(
      request.auth_user_deleted_at,
    );
    if (tokenDrainSeconds > 0) {
      const { error: deferError } = await admin.rpc(
        "defer_account_deletion_finalization",
        {
          p_request_id: request.id,
          p_storage_objects_deleted: storageObjectsDeleted,
          p_stripe_customer_deleted: stripeCustomerDeleted,
        },
      );
      if (deferError) throw deferError;
      return jsonResponse({
        success: true,
        processed: true,
        completed: false,
        request_id: request.id,
        reason: "awaiting_token_expiry",
        retry_after_seconds: tokenDrainSeconds,
      });
    }

    const remainingRows = await dependencyMatches(admin, request.user_id);
    if (remainingRows > 0) {
      await markFailed(
        admin,
        request.id,
        "account_deletion_residual_rows",
        remainingRows,
        storageObjectsDeleted,
        stripeCustomerDeleted,
        authUserDeleted,
      );
      return jsonResponse({
        success: false,
        processed: false,
        request_id: request.id,
        error: "account_deletion_residual_rows",
        remaining_rows: remainingRows,
      }, 409);
    }

    const { error: completeError } = await admin.rpc(
      "complete_account_deletion",
      {
        p_request_id: request.id,
        p_storage_objects_deleted: storageObjectsDeleted,
        p_stripe_customer_deleted: stripeCustomerDeleted,
      },
    );
    if (completeError) throw completeError;

    return jsonResponse({
      success: true,
      processed: true,
      completed: true,
      request_id: request.id,
      storage_objects_deleted: request.storage_objects_deleted +
        storageObjectsDeleted,
      stripe_customer_deleted: request.stripe_customer_deleted ||
        stripeCustomerDeleted,
    });
  } catch (error) {
    if (error instanceof StorageDeletionError) {
      storageObjectsDeleted += error.deletedCount;
    }
    const errorCode = safeErrorCode(error);
    await markFailed(
      admin,
      request.id,
      errorCode,
      0,
      storageObjectsDeleted,
      stripeCustomerDeleted,
      authUserDeleted,
    ).catch((markError) => {
      console.error(
        "[account-lifecycle] failed to record retry state",
        safeErrorCode(markError),
      );
    });
    throw error;
  }
}

async function dependencyBlockers(
  admin: SupabaseClient,
  userId: string,
): Promise<number> {
  const { data, error } = await admin.rpc(
    "account_deletion_dependency_inventory",
    { p_user_id: userId },
  );
  if (error) throw error;
  return blockingDependencyCount(data);
}

async function dependencyMatches(
  admin: SupabaseClient,
  userId: string,
): Promise<number> {
  const { data, error } = await admin.rpc(
    "account_deletion_dependency_inventory",
    { p_user_id: userId },
  );
  if (error) throw error;
  return remainingDeletionDependencyCount(
    Array.isArray(data) ? data : [],
  );
}

async function deleteDirectDatabaseRows(
  admin: SupabaseClient,
  userId: string,
): Promise<void> {
  const { error } = await admin.rpc("delete_account_deletion_direct_rows", {
    p_user_id: userId,
  });
  if (error) throw new Error(`database deletion failed: ${error.message}`);
}

async function billingForDeletion(
  admin: SupabaseClient,
  userId: string,
): Promise<JsonRecord | null> {
  const { data, error } = await admin
    .from("billing_subscriptions")
    .select(
      "stripe_customer_id,status,cancel_at_period_end,current_period_end",
    )
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  return data == null ? null : data as unknown as JsonRecord;
}

async function deleteOwnedStorageObjects(
  admin: SupabaseClient,
  userId: string,
): Promise<number> {
  let deleted = 0;
  for (let batch = 0; batch < MAX_STORAGE_BATCHES; batch += 1) {
    const { data, error } = await admin.rpc(
      "account_deletion_storage_objects",
      { p_user_id: userId, p_limit: 1000 },
    );
    if (error) {
      throw new StorageDeletionError(
        `storage inventory failed: ${error.message}`,
        deleted,
      );
    }
    const objects = Array.isArray(data) ? data as JsonRecord[] : [];
    if (objects.length === 0) return deleted;

    const byBucket = new Map<string, string[]>();
    for (const object of objects) {
      const bucket = asString(object.bucket_id);
      const name = asString(object.object_name);
      if (bucket === "" || name === "") continue;
      byBucket.set(bucket, [...(byBucket.get(bucket) ?? []), name]);
    }
    for (const [bucket, paths] of byBucket.entries()) {
      const { error: removeError } = await admin.storage.from(bucket).remove(
        paths,
      );
      if (removeError) {
        throw new StorageDeletionError(
          `storage deletion failed: ${removeError.message}`,
          deleted,
        );
      }
      deleted += paths.length;
    }
    if (objects.length < 1000) return deleted;
  }
  throw new StorageDeletionError(
    "storage deletion failed: batch limit exceeded",
    deleted,
  );
}

async function deleteStripeCustomer(customerId: string): Promise<void> {
  if (STRIPE_SECRET_KEY === "") {
    throw new Error("stripe deletion failed: STRIPE_SECRET_KEY missing");
  }
  const response = await fetch(
    `https://api.stripe.com/v1/customers/${encodeURIComponent(customerId)}`,
    {
      method: "DELETE",
      headers: { authorization: `Bearer ${STRIPE_SECRET_KEY}` },
    },
  );
  if (response.ok) return;
  const text = await response.text();
  if (response.status === 404 && text.includes("resource_missing")) return;
  throw new Error(`stripe deletion failed: HTTP ${response.status}`);
}

async function markFailed(
  admin: SupabaseClient,
  requestId: number,
  errorCode: string,
  remainingRows: number,
  storageObjectsDeleted = 0,
  stripeCustomerDeleted = false,
  authUserDeleted = false,
): Promise<void> {
  const { error } = await admin.rpc("fail_account_deletion", {
    p_request_id: requestId,
    p_error_code: errorCode,
    p_database_rows_remaining: Math.max(0, remainingRows),
    p_retry_seconds: 86400,
    p_storage_objects_deleted: Math.max(0, storageObjectsDeleted),
    p_stripe_customer_deleted: stripeCustomerDeleted,
    p_auth_user_deleted: authUserDeleted,
  });
  if (error) throw error;
}

async function activeRequest(
  admin: SupabaseClient,
  userId: string,
): Promise<DeletionRequestRow | null> {
  const { data, error } = await admin
    .from("account_deletion_requests")
    .select(internalRequestColumns())
    .eq("user_id", userId)
    .in("status", [
      "pending",
      "processing",
      "awaiting_token_expiry",
      "failed",
    ])
    .order("requested_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data == null ? null : data as unknown as DeletionRequestRow;
}

function publicRequestColumns(): string {
  return [
    "id",
    "status",
    "policy_version",
    "requested_at",
    "scheduled_for",
    "cancelled_at",
    "completed_at",
    "attempt_count",
    "last_error_code",
  ].join(",");
}

function internalRequestColumns(): string {
  return `${publicRequestColumns()},auth_user_deleted_at`;
}

function toPublicRequest(
  request: DeletionRequestRow | null,
): JsonRecord | null {
  if (!request) return null;
  return {
    id: request.id,
    status: request.status,
    policy_version: request.policy_version,
    requested_at: request.requested_at,
    scheduled_for: request.scheduled_for,
    cancelled_at: request.cancelled_at,
    completed_at: request.completed_at,
    attempt_count: request.attempt_count,
    last_error_code: request.last_error_code,
  };
}

function publicPolicy(): JsonRecord {
  return {
    version: ACCOUNT_DELETION_POLICY_VERSION,
    grace_days: ACCOUNT_DELETION_GRACE_DAYS,
    subscription_cancellation_deletes_account: false,
    confirmation: ACCOUNT_DELETION_CONFIRMATION,
  };
}

async function authenticatedContext(
  request: Request,
): Promise<AuthenticatedContext | null> {
  const token = bearerToken(request);
  if (token === "") return null;
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { authorization: `Bearer ${token}` } },
    auth: { persistSession: false },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return null;
  return {
    user: data.user,
    sessionId: sessionIdFromAccessToken(token),
  };
}

async function readBody(request: Request): Promise<JsonRecord> {
  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (contentLength > MAX_BODY_BYTES) throw new Error("request_too_large");
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > MAX_BODY_BYTES) {
    throw new Error("request_too_large");
  }
  if (text.trim() === "") return {};
  const parsed = JSON.parse(text);
  return parsed && typeof parsed === "object" && !Array.isArray(parsed)
    ? parsed as JsonRecord
    : {};
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function assertConfiguration(): void {
  if (
    SUPABASE_URL === "" || SUPABASE_ANON_KEY === "" || SERVICE_ROLE_KEY === ""
  ) {
    throw new Error("account lifecycle server configuration missing");
  }
}

function isAuthUserMissing(
  error: { message?: string; status?: number },
): boolean {
  const message = String(error.message ?? "").toLowerCase();
  return error.status === 404 || message.includes("user not found");
}
