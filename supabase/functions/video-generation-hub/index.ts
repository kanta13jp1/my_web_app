import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/edge.ts";
import {
  publicCatalog,
  validateVideoRequest,
  VIDEO_MODELS,
} from "./catalog.ts";
import {
  validateArtifactReview,
  validateImprovementLink,
} from "./artifact_review.ts";
import type { VideoImprovementLink } from "./artifact_review.ts";
import { validateImprovementAuthorization } from "./authorization.ts";
import { resolveVideoOperator } from "./operator_auth.ts";
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
  started_at: string | null;
  created_at: string;
  updated_at: string;
  completed_at: string | null;
  parent_artifact_id: string | null;
  applied_review_id: string | null;
  authorization_id: string | null;
};

type AuthorizationRow = {
  id: string;
  user_id: string;
  environment: string;
  authorization_scope: string;
  status: string;
  pending_reasons: string[];
  last_reservation_attempt_at: string | null;
  valid_from: string;
  valid_until: string;
  per_run_credit_limit: number;
  total_credit_limit: number;
  reserved_credits: number;
  consumed_credits: number;
  per_run_regeneration_limit: number;
  total_regeneration_limit: number;
  consumed_regenerations: number;
  allow_credit_purchase: boolean;
  max_spend_jpy_per_run: number;
  max_spend_jpy_total: number;
  consumed_spend_jpy: number;
  root_artifact_id: string;
  initial_review_id: string;
  source_selection_rule: string;
  created_at: string;
  updated_at: string;
  revoked_at: string | null;
};

type ArtifactRow = {
  id: string;
  user_id: string;
  job_id: string;
  parent_artifact_id: string | null;
  title: string;
  file_size_bytes: number | null;
  sha256: string | null;
  lifecycle_stage: string;
  rights_status: string;
  privacy_status: string;
  commerce_status: string;
  intended_for_sale: boolean;
  shop_product_id: string | null;
  iteration: number;
  latest_review_id: string | null;
  created_at: string;
  updated_at: string;
};

type ReviewRow = {
  id: string;
  artifact_id: string;
  iteration: number;
  quality_score: number;
  prompt_alignment_score: number;
  motion_quality_score: number;
  commercial_value_score: number;
  decision: string;
  strengths: string;
  improvement_request: string;
  suggested_prompt: string;
  notes: string;
  created_at: string;
};

type ArtifactWithReview = ArtifactRow & { latest_review: ReviewRow | null };

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
  "started_at",
  "created_at",
  "updated_at",
  "completed_at",
  "parent_artifact_id",
  "applied_review_id",
  "authorization_id",
].join(",");

const ARTIFACT_SELECT = [
  "id",
  "user_id",
  "job_id",
  "parent_artifact_id",
  "title",
  "file_size_bytes",
  "sha256",
  "lifecycle_stage",
  "rights_status",
  "privacy_status",
  "commerce_status",
  "intended_for_sale",
  "shop_product_id",
  "iteration",
  "latest_review_id",
  "created_at",
  "updated_at",
].join(",");

const REVIEW_SELECT = [
  "id",
  "artifact_id",
  "iteration",
  "quality_score",
  "prompt_alignment_score",
  "motion_quality_score",
  "commercial_value_score",
  "decision",
  "strengths",
  "improvement_request",
  "suggested_prompt",
  "notes",
  "created_at",
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
    const operator = resolveVideoOperator({
      authorization: req.headers.get("Authorization") ?? "",
      serviceRoleKey: SERVICE_ROLE_KEY,
      action,
      requestedUserId: asString(input.user_id),
    });
    if (operator.kind === "error") {
      return jsonResponse({ error: operator.code }, operator.status);
    }
    const user = operator.kind === "service_role"
      ? { id: operator.userId, isAnonymous: false }
      : await authenticatedUser(req);
    if (!user || user.isAnonymous) {
      return jsonResponse({ error: "authentication_required" }, 401);
    }
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
      case "review_artifact":
        return await reviewArtifactResponse(admin, user.id, input);
      case "review_authorized_artifact":
        return await reviewAuthorizedArtifactResponse(admin, user.id, input);
      case "authorization_status":
        return await authorizationStatusResponse(admin, user.id);
      case "authorize_improvement":
        return await authorizeImprovementResponse(admin, user.id, input);
      case "run_authorized_improvement":
        return await runAuthorizedImprovementResponse(admin, user.id, input);
      case "revoke_authorization":
        return await revokeAuthorizationResponse(admin, user.id, input);
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

async function authorizationStatusResponse(
  admin: SupabaseClient,
  userId: string,
): Promise<Response> {
  const { data, error } = await admin
    .from("video_improvement_authorizations")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(10);
  if (error) throw error;
  return jsonResponse({
    success: true,
    authorizations: ((data ?? []) as unknown as AuthorizationRow[]).map(
      publicAuthorization,
    ),
  });
}

async function authorizeImprovementResponse(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const validation = validateImprovementAuthorization(body);
  if (!validation.ok) {
    return jsonResponse({ error: validation.code }, 400);
  }
  const idempotencyKey = asString(body.idempotency_key);
  if (!/^[a-z0-9_-]{8,128}$/i.test(idempotencyKey)) {
    return jsonResponse({ error: "invalid_idempotency_key" }, 400);
  }
  const value = validation.value;
  const validUntil = new Date(
    Date.now() + value.validityHours * 60 * 60 * 1000,
  ).toISOString();
  const { data: reservation, error: reserveError } = await admin.rpc(
    "video_authorize_and_reserve_improvement",
    {
      p_user_id: userId,
      p_idempotency_key: idempotencyKey,
      p_source_artifact_id: value.sourceArtifactId,
      p_source_review_id: value.sourceReviewId,
      p_valid_until: validUntil,
      p_total_regenerations: value.totalRegenerations,
      p_rights_confirmed: true,
      p_adult_confirmed: true,
      p_terms_confirmed: true,
      p_prohibited_content_confirmed: true,
    },
  );
  if (reserveError) {
    const known = knownAuthorizationError(reserveError.message);
    if (known) return jsonResponse({ error: known.code }, known.status);
    throw reserveError;
  }

  return await authorizedReservationResponse(admin, userId, reservation);
}

async function revokeAuthorizationResponse(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const authorizationId = asString(body.authorization_id);
  if (!isUuid(authorizationId)) {
    return jsonResponse({ error: "invalid_authorization_id" }, 400);
  }
  const { data, error } = await admin
    .from("video_improvement_authorizations")
    .update({
      status: "revoked",
      pending_reasons: [],
      revoked_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("id", authorizationId)
    .eq("user_id", userId)
    .in("status", [
      "active",
      "pending_review",
      "pending_funding",
      "pending_execution",
    ])
    .select("*")
    .maybeSingle();
  if (error) throw error;
  if (!data) return jsonResponse({ error: "authorization_not_found" }, 404);
  return jsonResponse({
    success: true,
    authorization: publicAuthorization(data as unknown as AuthorizationRow),
  });
}

async function runAuthorizedImprovementResponse(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const authorizationId = asString(body.authorization_id);
  const sourceArtifactId = asString(body.source_artifact_id);
  const sourceReviewId = asString(body.source_review_id);
  const idempotencyKey = asString(body.idempotency_key);
  if (
    !isUuid(authorizationId) ||
    !isUuid(sourceArtifactId) ||
    !isUuid(sourceReviewId) ||
    !/^[a-z0-9_-]{8,128}$/i.test(idempotencyKey)
  ) {
    return jsonResponse({ error: "invalid_authorized_improvement" }, 400);
  }
  const { data: reservation, error: reserveError } = await admin.rpc(
    "video_reserve_authorized_improvement",
    {
      p_user_id: userId,
      p_authorization_id: authorizationId,
      p_source_artifact_id: sourceArtifactId,
      p_source_review_id: sourceReviewId,
      p_idempotency_key: idempotencyKey,
    },
  );
  if (reserveError) {
    const known = knownAuthorizationError(reserveError.message);
    if (known) return jsonResponse({ error: known.code }, known.status);
    throw reserveError;
  }
  return await authorizedReservationResponse(
    admin,
    userId,
    reservation,
  );
}

async function authorizedReservationResponse(
  admin: SupabaseClient,
  userId: string,
  reservation: unknown,
): Promise<Response> {
  const reservationRecord = asRecord(reservation);
  const jobId = asString(reservationRecord.job_id);
  const authorizationId = asString(reservationRecord.authorization_id);
  if (!authorizationId) {
    throw new Error("authorization_reservation_incomplete");
  }
  if (!jobId) {
    const authorization = await loadOwnedAuthorization(
      admin,
      userId,
      authorizationId,
    );
    return jsonResponse({
      success: true,
      pending: true,
      idempotent_replay: reservationRecord.idempotent_replay === true,
      pending_reasons: publicPendingReasons(
        reservationRecord.pending_reasons,
        authorization.pending_reasons,
      ),
      authorization: publicAuthorization(authorization),
      job: null,
      balance: publicBalance(reservation),
    }, 202);
  }
  let job = await loadOwnedJob(admin, userId, jobId);
  if (!isTerminal(job.status)) {
    const wakeConfiguration = loadWorkerWakeConfiguration();
    try {
      if (!wakeConfiguration) throw new Error("worker_wake_unconfigured");
      await wakeVideoWorker(jobId, wakeConfiguration);
    } catch (error) {
      console.error(
        "[video-generation-hub] authorized worker wake failed",
        safeErrorCode(error),
      );
      const cancelled = await cancelUnclaimedJob(admin, userId, jobId);
      if (cancelled) {
        return jsonResponse({ error: "generation_queue_unavailable" }, 503);
      }
      job = await loadOwnedJob(admin, userId, jobId);
    }
  }
  const authorization = await loadOwnedAuthorization(
    admin,
    userId,
    authorizationId,
  );
  return jsonResponse({
    success: true,
    idempotent_replay: reservationRecord.idempotent_replay === true,
    authorization: publicAuthorization(authorization),
    job: await publicJob(
      admin,
      job,
      false,
      await loadArtifactForJob(admin, userId, job.id),
    ),
    balance: publicBalance(reservation),
  }, isTerminal(job.status) ? 200 : 202);
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
  const lineageValidation = validateImprovementLink(body);
  if (!lineageValidation.ok) {
    return jsonResponse({ error: lineageValidation.code }, 400);
  }
  const lineage = lineageValidation.value;
  if (lineage && !await isOwnedImprovement(admin, userId, lineage)) {
    return jsonResponse({ error: "improvement_review_not_found" }, 404);
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
  if (lineage) {
    const alreadyLinked = job.parent_artifact_id === lineage.parentArtifactId &&
      job.applied_review_id === lineage.appliedReviewId;
    if (!alreadyLinked) {
      if (isTerminal(job.status)) {
        return jsonResponse({ error: "generation_iteration_conflict" }, 409);
      }
      const { error: linkError } = await admin.rpc(
        "video_link_generation_iteration",
        {
          p_user_id: userId,
          p_job_id: jobId,
          p_parent_artifact_id: lineage.parentArtifactId,
          p_applied_review_id: lineage.appliedReviewId,
        },
      );
      if (linkError) {
        const cancelled = await cancelUnclaimedJob(admin, userId, jobId);
        if (cancelled) {
          return jsonResponse(
            { error: "generation_iteration_unavailable" },
            503,
          );
        }
        throw linkError;
      }
      job = await loadOwnedJob(admin, userId, jobId);
    }
  }
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
    job: await publicJob(
      admin,
      job,
      false,
      await loadArtifactForJob(admin, userId, job.id),
    ),
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
    job: await publicJob(
      admin,
      job,
      true,
      await loadArtifactForJob(admin, userId, job.id),
    ),
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
  const rows = (data ?? []) as unknown as JobRow[];
  const artifacts = await loadArtifactsForJobs(
    admin,
    userId,
    rows.map((row) => row.id),
  );
  const jobs = await Promise.all(
    rows.map((row) =>
      publicJob(admin, row, false, artifacts.get(row.id) ?? null)
    ),
  );
  return jsonResponse({ success: true, jobs });
}

async function reviewAuthorizedArtifactResponse(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const authorizationId = asString(body.authorization_id);
  if (!isUuid(authorizationId)) {
    return jsonResponse({ error: "invalid_authorization_id" }, 400);
  }
  const validation = validateArtifactReview(body);
  if (!validation.ok) {
    return jsonResponse({ error: validation.code }, 400);
  }
  const value = validation.value;
  const { error } = await admin.rpc(
    "video_record_authorized_artifact_review",
    {
      p_user_id: userId,
      p_authorization_id: authorizationId,
      p_artifact_id: value.artifactId,
      p_quality_score: value.qualityScore,
      p_prompt_alignment_score: value.promptAlignmentScore,
      p_motion_quality_score: value.motionQualityScore,
      p_commercial_value_score: value.commercialValueScore,
      p_decision: value.decision,
      p_strengths: value.strengths,
      p_improvement_request: value.improvementRequest,
      p_suggested_prompt: value.suggestedPrompt,
      p_notes: value.notes,
      p_rights_status: value.rightsStatus,
      p_privacy_status: value.privacyStatus,
    },
  );
  if (error) {
    const known = knownAuthorizedReviewError(error.message);
    if (known) return jsonResponse({ error: known.code }, known.status);
    throw error;
  }
  const artifact = await loadArtifactById(admin, userId, value.artifactId);
  if (!artifact) throw new Error("reviewed_artifact_missing");
  return jsonResponse({
    success: true,
    artifact: publicArtifact(artifact),
    review: publicReview(artifact.latest_review),
  });
}
async function reviewArtifactResponse(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const validation = validateArtifactReview(body);
  if (!validation.ok) {
    return jsonResponse({ error: validation.code }, 400);
  }
  const value = validation.value;
  const { error } = await admin.rpc("video_record_artifact_review", {
    p_user_id: userId,
    p_artifact_id: value.artifactId,
    p_quality_score: value.qualityScore,
    p_prompt_alignment_score: value.promptAlignmentScore,
    p_motion_quality_score: value.motionQualityScore,
    p_commercial_value_score: value.commercialValueScore,
    p_decision: value.decision,
    p_strengths: value.strengths,
    p_improvement_request: value.improvementRequest,
    p_suggested_prompt: value.suggestedPrompt,
    p_notes: value.notes,
    p_rights_status: value.rightsStatus,
    p_privacy_status: value.privacyStatus,
  });
  if (error) {
    if (error.message.includes("video_artifact_not_found")) {
      return jsonResponse({ error: "artifact_not_found" }, 404);
    }
    throw error;
  }
  const artifact = await loadArtifactById(admin, userId, value.artifactId);
  if (!artifact) throw new Error("reviewed_artifact_missing");
  return jsonResponse({
    success: true,
    artifact: publicArtifact(artifact),
    review: publicReview(artifact.latest_review),
  });
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

async function loadOwnedAuthorization(
  admin: SupabaseClient,
  userId: string,
  authorizationId: string,
): Promise<AuthorizationRow> {
  const { data, error } = await admin
    .from("video_improvement_authorizations")
    .select("*")
    .eq("id", authorizationId)
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new Error("authorization_not_found");
  return data as unknown as AuthorizationRow;
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
  artifact: ArtifactWithReview | null,
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
    started_at: job.started_at,
    created_at: job.created_at,
    updated_at: job.updated_at,
    completed_at: job.completed_at,
    parent_artifact_id: job.parent_artifact_id,
    applied_review_id: job.applied_review_id,
    authorization_id: job.authorization_id,
    artifact: artifact ? publicArtifact(artifact) : null,
  };
}

function publicAuthorization(authorization: AuthorizationRow) {
  const expired = [
    "active",
    "pending_review",
    "pending_funding",
    "pending_execution",
  ].includes(authorization.status) &&
    Date.parse(authorization.valid_until) <= Date.now();
  const status = expired ? "expired" : authorization.status;
  const remainingCredits = Math.max(
    0,
    authorization.total_credit_limit - authorization.consumed_credits -
      authorization.reserved_credits,
  );
  const remainingRegenerations = Math.max(
    0,
    authorization.total_regeneration_limit -
      authorization.consumed_regenerations,
  );
  return {
    id: authorization.id,
    environment: authorization.environment,
    scope: authorization.authorization_scope,
    status,
    pending_reasons: expired ? [] : authorization.pending_reasons ?? [],
    last_reservation_attempt_at: authorization.last_reservation_attempt_at,
    valid_from: authorization.valid_from,
    valid_until: authorization.valid_until,
    per_run_credit_limit: authorization.per_run_credit_limit,
    total_credit_limit: authorization.total_credit_limit,
    reserved_credits: authorization.reserved_credits,
    consumed_credits: authorization.consumed_credits,
    remaining_credits: remainingCredits,
    per_run_regeneration_limit: authorization.per_run_regeneration_limit,
    total_regeneration_limit: authorization.total_regeneration_limit,
    consumed_regenerations: authorization.consumed_regenerations,
    remaining_regenerations: remainingRegenerations,
    allow_credit_purchase: authorization.allow_credit_purchase,
    max_spend_jpy_per_run: authorization.max_spend_jpy_per_run,
    max_spend_jpy_total: authorization.max_spend_jpy_total,
    consumed_spend_jpy: authorization.consumed_spend_jpy,
    root_artifact_id: authorization.root_artifact_id,
    initial_review_id: authorization.initial_review_id,
    source_selection_rule: authorization.source_selection_rule,
    created_at: authorization.created_at,
    updated_at: authorization.updated_at,
    revoked_at: authorization.revoked_at,
  };
}

function publicPendingReasons(
  rpcValue: unknown,
  storedValue: readonly string[],
): string[] {
  const allowed = new Set([
    "review_not_latest",
    "review_not_improve",
    "review_consumed",
    "insufficient_credits",
    "active_generation",
  ]);
  const values = Array.isArray(rpcValue) ? rpcValue : storedValue;
  return values.filter((value): value is string =>
    typeof value === "string" && allowed.has(value)
  );
}

function publicArtifact(artifact: ArtifactWithReview) {
  return {
    id: artifact.id,
    job_id: artifact.job_id,
    parent_artifact_id: artifact.parent_artifact_id,
    title: artifact.title,
    file_size_bytes: artifact.file_size_bytes,
    sha256: artifact.sha256,
    lifecycle_stage: artifact.lifecycle_stage,
    rights_status: artifact.rights_status,
    privacy_status: artifact.privacy_status,
    commerce_status: artifact.commerce_status,
    intended_for_sale: artifact.intended_for_sale,
    shop_product_id: artifact.shop_product_id,
    iteration: artifact.iteration,
    latest_review: publicReview(artifact.latest_review),
    created_at: artifact.created_at,
    updated_at: artifact.updated_at,
  };
}

function publicReview(review: ReviewRow | null) {
  if (!review) return null;
  return {
    id: review.id,
    artifact_id: review.artifact_id,
    iteration: review.iteration,
    quality_score: review.quality_score,
    prompt_alignment_score: review.prompt_alignment_score,
    motion_quality_score: review.motion_quality_score,
    commercial_value_score: review.commercial_value_score,
    decision: review.decision,
    strengths: review.strengths,
    improvement_request: review.improvement_request,
    suggested_prompt: review.suggested_prompt,
    notes: review.notes,
    created_at: review.created_at,
  };
}

async function loadArtifactForJob(
  admin: SupabaseClient,
  userId: string,
  jobId: string,
): Promise<ArtifactWithReview | null> {
  const { data, error } = await admin
    .from("video_artifacts")
    .select(ARTIFACT_SELECT)
    .eq("user_id", userId)
    .eq("job_id", jobId)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  return await attachLatestReview(admin, data as unknown as ArtifactRow);
}

async function loadArtifactById(
  admin: SupabaseClient,
  userId: string,
  artifactId: string,
): Promise<ArtifactWithReview | null> {
  const { data, error } = await admin
    .from("video_artifacts")
    .select(ARTIFACT_SELECT)
    .eq("user_id", userId)
    .eq("id", artifactId)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  return await attachLatestReview(admin, data as unknown as ArtifactRow);
}

async function attachLatestReview(
  admin: SupabaseClient,
  artifact: ArtifactRow,
): Promise<ArtifactWithReview> {
  if (!artifact.latest_review_id) return { ...artifact, latest_review: null };
  const { data, error } = await admin
    .from("video_artifact_reviews")
    .select(REVIEW_SELECT)
    .eq("id", artifact.latest_review_id)
    .eq("user_id", artifact.user_id)
    .maybeSingle();
  if (error) throw error;
  return {
    ...artifact,
    latest_review: data ? data as unknown as ReviewRow : null,
  };
}

async function loadArtifactsForJobs(
  admin: SupabaseClient,
  userId: string,
  jobIds: string[],
): Promise<Map<string, ArtifactWithReview>> {
  const result = new Map<string, ArtifactWithReview>();
  if (jobIds.length === 0) return result;
  const { data, error } = await admin
    .from("video_artifacts")
    .select(ARTIFACT_SELECT)
    .eq("user_id", userId)
    .in("job_id", jobIds);
  if (error) throw error;
  const artifacts = (data ?? []) as unknown as ArtifactRow[];
  const reviewIds = artifacts
    .map((artifact) => artifact.latest_review_id)
    .filter((id): id is string => Boolean(id));
  const reviews = new Map<string, ReviewRow>();
  if (reviewIds.length > 0) {
    const { data: reviewRows, error: reviewError } = await admin
      .from("video_artifact_reviews")
      .select(REVIEW_SELECT)
      .eq("user_id", userId)
      .in("id", reviewIds);
    if (reviewError) throw reviewError;
    for (const review of (reviewRows ?? []) as unknown as ReviewRow[]) {
      reviews.set(review.id, review);
    }
  }
  for (const artifact of artifacts) {
    result.set(artifact.job_id, {
      ...artifact,
      latest_review: artifact.latest_review_id
        ? reviews.get(artifact.latest_review_id) ?? null
        : null,
    });
  }
  return result;
}

async function isOwnedImprovement(
  admin: SupabaseClient,
  userId: string,
  lineage: VideoImprovementLink,
): Promise<boolean> {
  const { data, error } = await admin
    .from("video_artifact_reviews")
    .select("id")
    .eq("id", lineage.appliedReviewId)
    .eq("artifact_id", lineage.parentArtifactId)
    .eq("user_id", userId)
    .eq("decision", "improve")
    .maybeSingle();
  if (error) throw error;
  return data != null;
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

function knownAuthorizedReviewError(
  message: string,
): { code: string; status: number } | null {
  const mappings: readonly [string, number][] = [
    ["video_authorized_review_artifact_already_reviewed", 409],
    ["video_authorized_review_target_invalid", 409],
    ["video_authorization_not_found", 404],
    ["video_artifact_not_found", 404],
    ["invalid_video_artifact_review", 400],
  ];
  for (const [code, status] of mappings) {
    if (message.includes(code)) return { code, status };
  }
  return null;
}
function knownAuthorizationError(
  message: string,
): { code: string; status: number } | null {
  const mappings: readonly [string, number][] = [
    ["insufficient_video_credits", 402],
    ["video_generation_already_active", 409],
    ["improvement_review_already_consumed", 409],
    ["improvement_review_is_not_latest", 409],
    ["artifact_clearance_blocked", 409],
    ["video_authorization_inactive", 409],
    ["video_authorization_exhausted", 409],
    ["authorization_source_mismatch", 409],
    ["video_artifact_not_found", 404],
    ["improvement_review_not_found", 404],
    ["invalid_authorization_expiry", 400],
    ["invalid_authorization_iterations", 400],
    ["authorization_confirmations_required", 400],
    ["authorization_idempotency_conflict", 409],
  ];
  for (const [code, status] of mappings) {
    if (message.includes(code)) return { code, status };
  }
  return null;
}

if (VIDEO_MODELS.length === 0) throw new Error("video_catalog_empty");
