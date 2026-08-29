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
  deletionScheduledFor,
  isRecentSignIn,
  isServiceRoleRequest,
  requiresSubscriptionCancellation,
  safeErrorCode,
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

type DeletionRequestRow = {
  id: number;
  user_id: string | null;
  status: string;
  policy_version: string;
  requested_at: string;
  scheduled_for: string;
  cancelled_at: string | null;
  completed_at: string | null;
  attempt_count: number;
  last_error_code: string | null;
};

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

    if (action === "process_due") {
      if (!isServiceRoleRequest(request, SERVICE_ROLE_KEY)) {
        return jsonResponse({ error: "service_role_required" }, 401);
      }
      return await processDueRequest(admin);
    }

    const user = await authenticatedUser(request);
    if (!user || user.is_anonymous) {
      return jsonResponse({ error: "authentication_required" }, 401);
    }

    switch (action) {
      case "status":
        return await statusResponse(admin, user.id);
      case "request_deletion":
        return await requestDeletion(admin, user, body);
      case "cancel_deletion":
        return await cancelDeletion(admin, user.id);
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
    request: active,
    policy: publicPolicy(),
  });
}

async function requestDeletion(
  admin: SupabaseClient,
  user: User,
  body: JsonRecord,
): Promise<Response> {
  if (asString(body.confirmation) !== ACCOUNT_DELETION_CONFIRMATION) {
    return jsonResponse({ error: "confirmation_mismatch" }, 400);
  }
  if (!isRecentSignIn(user.last_sign_in_at)) {
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
      request: existing,
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
        request: raced,
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
  if (current.status === "processing") {
    return jsonResponse({ error: "deletion_already_processing" }, 409);
  }

  const { error } = await admin
    .from("account_deletion_requests")
    .update({
      status: "cancelled",
      cancelled_at: new Date().toISOString(),
      retry_after: null,
      last_error_code: null,
    })
    .eq("id", current.id)
    .eq("user_id", userId)
    .in("status", ["pending", "failed"])
    .select(publicRequestColumns())
    .single();
  if (error) throw error;
  return jsonResponse({ success: true, request: null, policy: publicPolicy() });
}

async function processDueRequest(admin: SupabaseClient): Promise<Response> {
  const { data: claimedRows, error: claimError } = await admin.rpc(
    "claim_due_account_deletion",
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

    const billing = await billingForDeletion(admin, request.user_id);
    if (requiresSubscriptionCancellation(billing)) {
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

    if (billing?.stripe_customer_id) {
      await deleteStripeCustomer(String(billing.stripe_customer_id));
      stripeCustomerDeleted = true;
    }

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

    const remainingRows = await dependencyMatches(admin, request.user_id);
    if (remainingRows > 0) {
      await markFailed(
        admin,
        request.id,
        "account_deletion_residual_rows",
        remainingRows,
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
      request_id: request.id,
      storage_objects_deleted: storageObjectsDeleted,
      stripe_customer_deleted: stripeCustomerDeleted,
    });
  } catch (error) {
    const errorCode = safeErrorCode(error);
    await markFailed(admin, request.id, errorCode, 0).catch((markError) => {
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
  return (Array.isArray(data) ? data : []).reduce((total, row) => {
    const count = Number((row as JsonRecord).matching_rows ?? 0);
    return total + (Number.isFinite(count) && count > 0 ? count : 0);
  }, 0);
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
    if (error) throw new Error(`storage inventory failed: ${error.message}`);
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
        throw new Error(`storage deletion failed: ${removeError.message}`);
      }
      deleted += paths.length;
    }
    if (objects.length < 1000) return deleted;
  }
  throw new Error("storage deletion failed: batch limit exceeded");
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
): Promise<void> {
  const { error } = await admin.rpc("fail_account_deletion", {
    p_request_id: requestId,
    p_error_code: errorCode,
    p_database_rows_remaining: Math.max(0, remainingRows),
    p_retry_seconds: 86400,
  });
  if (error) throw error;
}

async function activeRequest(
  admin: SupabaseClient,
  userId: string,
): Promise<DeletionRequestRow | null> {
  const { data, error } = await admin
    .from("account_deletion_requests")
    .select(publicRequestColumns())
    .eq("user_id", userId)
    .in("status", ["pending", "processing", "failed"])
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

function publicPolicy(): JsonRecord {
  return {
    version: ACCOUNT_DELETION_POLICY_VERSION,
    grace_days: ACCOUNT_DELETION_GRACE_DAYS,
    subscription_cancellation_deletes_account: false,
    confirmation: ACCOUNT_DELETION_CONFIRMATION,
  };
}

async function authenticatedUser(request: Request): Promise<User | null> {
  const token = bearerToken(request);
  if (token === "") return null;
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { authorization: `Bearer ${token}` } },
    auth: { persistSession: false },
  });
  const { data, error } = await client.auth.getUser();
  return error ? null : data.user;
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
