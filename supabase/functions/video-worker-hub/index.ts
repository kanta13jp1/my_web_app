import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  hasValidWorkerAuthorization,
  isExpectedVideoObject,
  isJobId,
  isLeaseToken,
  isVideoSha256,
  isWorkerErrorCode,
  isWorkerId,
  MAX_VIDEO_BYTES,
  validVideoOutputPaths,
  videoObjectSize,
  videoOutputObject,
} from "./worker_security.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = (
  Deno.env.get("SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    ""
).trim();
const WORKER_TOKEN = (Deno.env.get("VIDEO_WORKER_TOKEN") ?? "").trim();
const VIDEO_OUTPUT_BUCKET = "video-generations";
const MAX_BODY_BYTES = 16 * 1024;
const LEASE_SECONDS = 30 * 60;

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return response({ error: "method_not_allowed" }, 405);
  }
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || WORKER_TOKEN.length < 32) {
    return response({ error: "service_unavailable" }, 503);
  }
  if (!await hasValidWorkerAuthorization(req, WORKER_TOKEN)) {
    return response({ error: "unauthorized" }, 401);
  }

  const declaredLength = Number(req.headers.get("content-length") ?? "0");
  if (declaredLength > MAX_BODY_BYTES) {
    return response({ error: "request_too_large" }, 413);
  }
  const rawBody = await req.text();
  if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
    return response({ error: "request_too_large" }, 413);
  }
  const body = parseRecord(rawBody);
  if (!body) return response({ error: "invalid_json" }, 400);
  const action = asString(body.action);
  const workerId = asString(body.worker_id);
  if (!isWorkerId(workerId)) {
    return response({ error: "invalid_worker_id" }, 400);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  try {
    switch (action) {
      case "claim":
        return await claimResponse(admin, workerId);
      case "heartbeat":
        return await heartbeatResponse(admin, workerId, body);
      case "prepare_upload":
        return await prepareUploadResponse(admin, workerId, body);
      case "complete":
        return await completeResponse(admin, workerId, body);
      case "fail":
        return await failResponse(admin, workerId, body);
      default:
        return response({ error: "unknown_action" }, 400);
    }
  } catch (error) {
    console.error("[video-worker-hub] request failed", safeCode(error));
    return response({ error: "worker_service_unavailable" }, 503);
  }
});

async function claimResponse(
  admin: SupabaseClient,
  workerId: string,
): Promise<Response> {
  const { data, error } = await admin.rpc("video_claim_generation", {
    p_worker_id: workerId,
    p_lease_seconds: LEASE_SECONDS,
  });
  if (error) throw error;
  const claimed = asRecord(data);
  await cleanupVideoOutputs(admin, claimed.cleanup_storage_paths);
  const job = { ...claimed };
  delete job.cleanup_storage_paths;
  return response({
    success: true,
    job: asString(job.job_id) ? job : null,
  });
}

async function heartbeatResponse(
  admin: SupabaseClient,
  workerId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const lease = validLeaseInput(body);
  if (!lease) return response({ error: "invalid_lease" }, 400);
  const { data, error } = await admin.rpc("video_heartbeat_generation", {
    p_job_id: lease.jobId,
    p_worker_id: workerId,
    p_lease_token: lease.leaseToken,
    p_lease_seconds: LEASE_SECONDS,
  });
  if (error) throw error;
  return response({ success: true, lease_active: data === true });
}

async function prepareUploadResponse(
  admin: SupabaseClient,
  workerId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const lease = validLeaseInput(body);
  if (!lease) return response({ error: "invalid_lease" }, 400);
  const active = await activeLease(admin, workerId, lease);
  if (!active) return response({ error: "lease_lost" }, 409);
  const storagePath = asString(active.storage_path);
  const { data, error } = await admin.storage
    .from(VIDEO_OUTPUT_BUCKET)
    .createSignedUploadUrl(storagePath, { upsert: false });
  if (error || !data?.signedUrl) throw error ?? new Error("upload_url_missing");
  return response({
    success: true,
    upload_url: data.signedUrl,
    storage_path: storagePath,
    content_type: "video/mp4",
    max_bytes: MAX_VIDEO_BYTES,
  });
}

async function completeResponse(
  admin: SupabaseClient,
  workerId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const lease = validLeaseInput(body);
  if (!lease) return response({ error: "invalid_lease" }, 400);
  const active = await activeLease(admin, workerId, lease);
  if (!active) return response({ error: "lease_lost" }, 409);
  const storagePath = asString(active.storage_path);
  const reportedSize = asInteger(body.output_size_bytes);
  const reportedSha256 = asString(body.output_sha256);
  if (
    reportedSize === null || reportedSize < 1 ||
    reportedSize > MAX_VIDEO_BYTES || !isVideoSha256(reportedSha256)
  ) {
    return response({ error: "invalid_output_provenance" }, 400);
  }
  const outputObject = videoOutputObject(storagePath);
  if (!outputObject) throw new Error("invalid_output_storage_path");
  const { data: objects, error: listError } = await admin.storage
    .from(VIDEO_OUTPUT_BUCKET)
    .list(outputObject.folder, { limit: 10, search: outputObject.name });
  if (listError) throw listError;
  const uploaded = (objects ?? []).find(
    (item) => item.name === outputObject.name,
  );
  if (!isExpectedVideoObject(uploaded, outputObject.name)) {
    return response({ error: "output_not_ready" }, 409);
  }
  if (videoObjectSize(uploaded) !== reportedSize) {
    return response({ error: "output_size_mismatch" }, 409);
  }

  const { data, error } = await admin.rpc(
    "video_complete_claimed_generation",
    {
      p_job_id: lease.jobId,
      p_worker_id: workerId,
      p_lease_token: lease.leaseToken,
      p_output_storage_path: storagePath,
    },
  );
  if (error) throw error;
  const { error: artifactError } = await admin
    .from("video_artifacts")
    .update({ file_size_bytes: reportedSize, sha256: reportedSha256 })
    .eq("job_id", lease.jobId)
    .eq("user_id", asString(active.user_id));
  if (artifactError) {
    // Job settlement and immutable capture already succeeded. Missing technical
    // metadata must not turn a paid success into a retry or refund race.
    console.error(
      "[video-worker-hub] artifact provenance update failed",
      safeCode(artifactError),
    );
  }
  return response({ success: true, result: data });
}

async function failResponse(
  admin: SupabaseClient,
  workerId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const lease = validLeaseInput(body);
  if (!lease) return response({ error: "invalid_lease" }, 400);
  const errorCode = asString(body.error_code);
  if (!isWorkerErrorCode(errorCode)) {
    return response({ error: "invalid_error_code" }, 400);
  }
  const active = await activeLease(admin, workerId, lease);
  if (!active) return response({ error: "lease_lost" }, 409);
  const cleaned = await cleanupVideoOutputs(admin, [
    asString(active.storage_path),
  ]);
  if (!cleaned) throw new Error("output_cleanup_failed");
  const { data, error } = await admin.rpc("video_fail_claimed_generation", {
    p_job_id: lease.jobId,
    p_worker_id: workerId,
    p_lease_token: lease.leaseToken,
    p_error_code: errorCode,
    p_retryable: body.retryable !== false,
  });
  if (error) throw error;
  return response({ success: true, result: data });
}

async function cleanupVideoOutputs(
  admin: SupabaseClient,
  value: unknown,
): Promise<boolean> {
  const paths = validVideoOutputPaths(value);
  if (paths.length === 0) return true;
  const { error } = await admin.storage.from(VIDEO_OUTPUT_BUCKET).remove(paths);
  if (error) {
    console.error(
      "[video-worker-hub] stale output cleanup failed",
      safeCode(error),
    );
    return false;
  }
  return true;
}

async function activeLease(
  admin: SupabaseClient,
  workerId: string,
  lease: { jobId: string; leaseToken: string },
): Promise<Record<string, unknown> | null> {
  const { data, error } = await admin.rpc("video_validate_generation_lease", {
    p_job_id: lease.jobId,
    p_worker_id: workerId,
    p_lease_token: lease.leaseToken,
  });
  if (error) throw error;
  const value = asRecord(data);
  return asString(value.job_id) ? value : null;
}

function validLeaseInput(
  body: Record<string, unknown>,
): { jobId: string; leaseToken: string } | null {
  const jobId = asString(body.job_id);
  const leaseToken = asString(body.lease_token);
  return isJobId(jobId) && isLeaseToken(leaseToken)
    ? { jobId, leaseToken }
    : null;
}

function parseRecord(value: string): Record<string, unknown> | null {
  try {
    const parsed = JSON.parse(value);
    return parsed != null && typeof parsed === "object" &&
        !Array.isArray(parsed)
      ? parsed as Record<string, unknown>
      : null;
  } catch (_) {
    return null;
  }
}

function response(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function asRecord(value: unknown): Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asInteger(value: unknown): number | null {
  const number = typeof value === "number" ? value : Number(value);
  return Number.isSafeInteger(number) ? number : null;
}

function safeCode(error: unknown): string {
  const raw = error instanceof Error ? error.message : String(error);
  return /^[a-z0-9_]+$/i.test(raw)
    ? raw.toLowerCase().slice(0, 120)
    : "internal_error";
}
