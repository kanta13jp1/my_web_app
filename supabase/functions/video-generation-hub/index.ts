import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/edge.ts";
import {
  publicCatalog,
  validateVideoRequest,
  VIDEO_MODELS,
} from "./catalog.ts";
import { loadWorkerWakeConfiguration, wakeVideoWorker } from "./worker_wake.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = (
  Deno.env.get("SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    ""
).trim();
const VIDEO_OUTPUT_BUCKET = "video-generations";
const SIGNED_URL_TTL_SECONDS = 60 * 60;
const MAX_BODY_BYTES = 16 * 1024;
const FIRST_PARTY_ENGINE = "omocha_works_gpu";
const FIRST_PARTY_MODEL_REVISION =
  "wan2.2-ti2v-5b@921dbaf3f1674a56f47e83fb80a34bac8a8f203e";

type JobRow = {
  id: string;
  user_id: string;
  model_key: string;
  prompt: string;
  duration_seconds: number;
  aspect_ratio: string;
  resolution: string;
  status: string;
  quoted_credits: number;
  charged_credits: number;
  output_storage_path: string | null;
  error_code: string | null;
  created_at: string;
  updated_at: string;
  completed_at: string | null;
};

const JOB_SELECT = [
  "id",
  "user_id",
  "model_key",
  "prompt",
  "duration_seconds",
  "aspect_ratio",
  "resolution",
  "status",
  "quoted_credits",
  "charged_credits",
  "output_storage_path",
  "error_code",
  "created_at",
  "updated_at",
  "completed_at",
].join(",");

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  try {
    assertServerConfiguration();
    const contentLength = Number(req.headers.get("content-length") ?? "0");
    if (contentLength > MAX_BODY_BYTES) {
      return jsonResponse({ error: "request_too_large" }, 413);
    }

    const user = await authenticatedUser(req);
    if (!user || user.isAnonymous) {
      return jsonResponse({ error: "authentication_required" }, 401);
    }

    const rawBody = await req.text();
    if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
      return jsonResponse({ error: "request_too_large" }, 413);
    }
    const body = parseRecord(rawBody);
    if (!body) {
      return jsonResponse({ error: "invalid_json" }, 400);
    }
    const input = body;
    const action = asString(input.action);
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    switch (action) {
      case "catalog":
        return jsonResponse({ success: true, ...publicCatalog() });
      case "balance":
        return await balanceResponse(admin, user.id);
      case "quote":
        return quoteResponse(input);
      case "create":
        return await createJob(admin, user.id, input);
      case "status":
        return await statusResponse(admin, user.id, asString(input.job_id));
      case "list":
        return await listJobs(admin, user.id);
      default:
        return jsonResponse({ error: "unknown_action" }, 400);
    }
  } catch (error) {
    console.error(
      "[video-generation-hub] request failed",
      safeErrorCode(error),
    );
    return jsonResponse({ error: "video_service_unavailable" }, 503);
  }
});

function quoteResponse(body: Record<string, unknown>): Response {
  const result = validateVideoRequest(body);
  if (!result.ok) {
    return jsonResponse({ error: result.code, message: result.message }, 400);
  }
  return jsonResponse({
    success: true,
    quote: {
      model_key: result.value.model.key,
      duration_seconds: result.value.durationSeconds,
      aspect_ratio: result.value.aspectRatio,
      resolution: result.value.resolution,
      required_credits: result.value.requiredCredits,
    },
  });
}

async function balanceResponse(
  admin: SupabaseClient,
  userId: string,
): Promise<Response> {
  const { data, error } = await admin
    .from("video_credit_accounts")
    .select("available_credits,reserved_credits,credit_debt")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  return jsonResponse({
    success: true,
    balance: data ?? {
      available_credits: 0,
      reserved_credits: 0,
      credit_debt: 0,
    },
  });
}

async function createJob(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const validation = validateVideoRequest(body);
  if (!validation.ok) {
    return jsonResponse(
      { error: validation.code, message: validation.message },
      400,
    );
  }
  const idempotencyKey = asString(body.idempotency_key);
  if (!/^[a-z0-9_-]{8,128}$/i.test(idempotencyKey)) {
    return jsonResponse({ error: "invalid_idempotency_key" }, 400);
  }

  const value = validation.value;
  const { data: reservation, error: reserveError } = await admin.rpc(
    "video_reserve_generation",
    {
      p_user_id: userId,
      p_idempotency_key: idempotencyKey,
      p_model_key: value.model.key,
      p_inference_engine: FIRST_PARTY_ENGINE,
      p_model_revision: FIRST_PARTY_MODEL_REVISION,
      p_prompt: value.prompt,
      p_duration_seconds: value.durationSeconds,
      p_aspect_ratio: value.aspectRatio,
      p_resolution: value.resolution,
      p_required_credits: value.requiredCredits,
    },
  );
  if (reserveError) {
    if (reserveError.message.includes("insufficient_video_credits")) {
      return jsonResponse({ error: "insufficient_video_credits" }, 402);
    }
    if (reserveError.message.includes("video_generation_already_active")) {
      return jsonResponse({ error: "generation_already_active" }, 409);
    }
    throw reserveError;
  }

  const jobId = asString(asRecord(reservation).job_id);
  if (!jobId) throw new Error("reservation_missing_job_id");
  let job = await loadOwnedJob(admin, userId, jobId);
  if (!isTerminal(job.status)) {
    const wakeConfiguration = loadWorkerWakeConfiguration();
    try {
      if (!wakeConfiguration) throw new Error("worker_wake_unconfigured");
      await wakeVideoWorker(jobId, wakeConfiguration);
    } catch (error) {
      console.error(
        "[video-generation-hub] worker wake failed",
        safeErrorCode(error),
      );
      const cancelled = await cancelUnclaimedJob(admin, userId, jobId);
      if (cancelled) {
        return jsonResponse({ error: "generation_queue_unavailable" }, 503);
      }
      job = await loadOwnedJob(admin, userId, jobId);
    }
  }
  return jsonResponse({
    success: true,
    idempotent_replay: asRecord(reservation).idempotent_replay === true,
    job: await publicJob(admin, job, false),
    balance: publicBalance(reservation),
  }, isTerminal(job.status) ? 200 : 202);
}

async function cancelUnclaimedJob(
  admin: SupabaseClient,
  userId: string,
  jobId: string,
): Promise<boolean> {
  const { data, error } = await admin.rpc("video_cancel_queued_generation", {
    p_user_id: userId,
    p_job_id: jobId,
    p_error_code: "generation_queue_unavailable",
  });
  if (error) throw error;
  return asString(asRecord(data).status) === "failed";
}

async function statusResponse(
  admin: SupabaseClient,
  userId: string,
  jobId: string,
): Promise<Response> {
  if (!isUuid(jobId)) return jsonResponse({ error: "invalid_job_id" }, 400);
  const job = await loadOwnedJobOrNull(admin, userId, jobId);
  if (!job) return jsonResponse({ error: "job_not_found" }, 404);
  return jsonResponse({
    success: true,
    job: await publicJob(admin, job, true),
  });
}

async function listJobs(
  admin: SupabaseClient,
  userId: string,
): Promise<Response> {
  const { data, error } = await admin
    .from("video_generation_jobs")
    .select(JOB_SELECT)
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(20);
  if (error) throw error;
  const jobs = await Promise.all(
    (data ?? []).map((row) =>
      publicJob(admin, row as unknown as JobRow, false)
    ),
  );
  return jsonResponse({ success: true, jobs });
}

async function loadOwnedJob(
  admin: SupabaseClient,
  userId: string,
  jobId: string,
): Promise<JobRow> {
  const row = await loadOwnedJobOrNull(admin, userId, jobId);
  if (!row) throw new Error("job_not_found");
  return row;
}

async function loadOwnedJobOrNull(
  admin: SupabaseClient,
  userId: string,
  jobId: string,
): Promise<JobRow | null> {
  const { data, error } = await admin
    .from("video_generation_jobs")
    .select(JOB_SELECT)
    .eq("id", jobId)
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  return data ? data as unknown as JobRow : null;
}

async function publicJob(
  admin: SupabaseClient,
  job: JobRow,
  includeSignedUrl: boolean,
) {
  let outputUrl: string | null = null;
  let outputExpiresAt: string | null = null;
  if (
    includeSignedUrl && job.status === "succeeded" && job.output_storage_path
  ) {
    const { data, error } = await admin.storage
      .from(VIDEO_OUTPUT_BUCKET)
      .createSignedUrl(job.output_storage_path, SIGNED_URL_TTL_SECONDS);
    if (error) throw error;
    outputUrl = data?.signedUrl ?? null;
    outputExpiresAt = new Date(
      Date.now() + SIGNED_URL_TTL_SECONDS * 1000,
    ).toISOString();
  }
  return {
    id: job.id,
    model_key: job.model_key,
    prompt: job.prompt,
    duration_seconds: job.duration_seconds,
    aspect_ratio: job.aspect_ratio,
    resolution: job.resolution,
    status: job.status,
    quoted_credits: job.quoted_credits,
    charged_credits: job.charged_credits,
    error_code: job.error_code,
    output_url: outputUrl,
    output_expires_at: outputExpiresAt,
    created_at: job.created_at,
    updated_at: job.updated_at,
    completed_at: job.completed_at,
  };
}

async function authenticatedUser(
  req: Request,
): Promise<{ id: string; isAnonymous: boolean } | null> {
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization) return null;
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authorization } },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return null;
  return { id: data.user.id, isAnonymous: data.user.is_anonymous === true };
}

function publicBalance(value: unknown) {
  const record = asRecord(value);
  return {
    available_credits: asNumber(record.available_credits),
    reserved_credits: asNumber(record.reserved_credits),
    credit_debt: asNumber(record.credit_debt),
  };
}

function assertServerConfiguration(): void {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SERVICE_ROLE_KEY) {
    throw new Error("supabase_configuration_missing");
  }
}

function isTerminal(status: string): boolean {
  return ["succeeded", "failed", "cancelled"].includes(status);
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function asRecord(value: unknown): Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
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

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNumber(value: unknown): number {
  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) ? number : 0;
}

function safeErrorCode(error: unknown): string {
  const raw = error instanceof Error ? error.message : String(error);
  return /^[a-z0-9_]+$/i.test(raw)
    ? raw.toLowerCase().slice(0, 120)
    : "internal_error";
}

if (VIDEO_MODELS.length === 0) throw new Error("video_catalog_empty");
