import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export type AsyncJobStatus =
  | "queued"
  | "running"
  | "completed"
  | "failed"
  | "cancelled";

export interface AsyncJobRecord {
  id: string;
  user_id: string;
  job_type: string;
  title: string;
  status: AsyncJobStatus;
  progress_percent: number;
  request_payload: Record<string, unknown>;
  result_payload: Record<string, unknown> | null;
  error_message: string | null;
  created_at: string;
  updated_at: string;
  started_at: string | null;
  completed_at: string | null;
}

export interface AsyncJobQueryResult<T> {
  data: T | null;
  error: { message: string } | null;
}

export interface AsyncJobStore {
  insertJob(
    row: Record<string, unknown>,
  ): Promise<AsyncJobQueryResult<AsyncJobRecord>>;
  getJob(
    jobId: string,
    userId: string,
  ): Promise<AsyncJobQueryResult<AsyncJobRecord>>;
  listJobs(
    userId: string,
    status: AsyncJobStatus | null,
    limit: number,
  ): Promise<AsyncJobQueryResult<AsyncJobRecord[]>>;
  updateJob(
    jobId: string,
    userId: string,
    updates: Record<string, unknown>,
  ): Promise<AsyncJobQueryResult<AsyncJobRecord>>;
}

export function createSupabaseAsyncJobStore(
  admin: SupabaseClient,
): AsyncJobStore {
  return {
    async insertJob(row) {
      const { data, error } = await admin
        .from("async_jobs")
        .insert(row)
        .select("*")
        .single();
      return {
        data: data ? (data as AsyncJobRecord) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async getJob(jobId, userId) {
      const { data, error } = await admin
        .from("async_jobs")
        .select("*")
        .eq("id", jobId)
        .eq("user_id", userId)
        .maybeSingle();
      return {
        data: data ? (data as AsyncJobRecord) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async listJobs(userId, status, limit) {
      let query = admin
        .from("async_jobs")
        .select("*")
        .eq("user_id", userId);
      if (status !== null) {
        query = query.eq("status", status);
      }
      const { data, error } = await query
        .order("created_at", { ascending: false })
        .limit(limit);
      return {
        data: data ? (data as AsyncJobRecord[]) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async updateJob(jobId, userId, updates) {
      const { data, error } = await admin
        .from("async_jobs")
        .update(updates)
        .eq("id", jobId)
        .eq("user_id", userId)
        .select("*")
        .maybeSingle();
      return {
        data: data ? (data as AsyncJobRecord) : null,
        error: error ? { message: error.message } : null,
      };
    },
  };
}

const VALID_JOB_TYPE_RE = /^[a-z0-9][a-z0-9._-]{1,63}$/;
const VALID_STATUSES = new Set<AsyncJobStatus>([
  "queued",
  "running",
  "completed",
  "failed",
  "cancelled",
]);

const ALLOWED_TRANSITIONS: Record<AsyncJobStatus, readonly AsyncJobStatus[]> = {
  queued: ["running", "completed", "failed", "cancelled"],
  running: ["running", "completed", "failed", "cancelled"],
  completed: [],
  failed: ["queued"],
  cancelled: ["queued"],
};

export interface AsyncJobServiceResult {
  status: number;
  body: Record<string, unknown>;
}

function asObject(value: unknown): Record<string, unknown> {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

export function clampAsyncJobLimit(raw: unknown): number {
  const n = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(n) || n <= 0) return 20;
  return Math.min(Math.max(Math.trunc(n), 1), 100);
}

export function clampProgressPercent(
  raw: unknown,
  status: AsyncJobStatus,
): number {
  if (status === "completed") return 100;
  const n = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(n)) return 0;
  return Math.min(Math.max(Math.trunc(n), 0), 100);
}

export function validateJobType(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const trimmed = raw.trim().toLowerCase();
  if (!VALID_JOB_TYPE_RE.test(trimmed)) return null;
  return trimmed;
}

export function isValidStatusTransition(
  currentStatus: AsyncJobStatus,
  nextStatus: AsyncJobStatus,
): boolean {
  return ALLOWED_TRANSITIONS[currentStatus].includes(nextStatus);
}

export async function handleAsyncJobEnqueue(
  store: AsyncJobStore,
  userId: string,
  input: Record<string, unknown>,
  nowIso: string = new Date().toISOString(),
): Promise<AsyncJobServiceResult> {
  const jobType = validateJobType(input.job_type);
  if (!jobType) {
    return {
      status: 400,
      body: {
        error: "job_type must be a 2-64 char lowercase slug ([a-z0-9._-])",
      },
    };
  }

  const rawTitle = typeof input.title === "string" ? input.title.trim() : "";
  const title = rawTitle !== "" ? rawTitle.slice(0, 120) : jobType;
  const requestPayload = asObject(input.request_payload);

  const { data, error } = await store.insertJob({
    user_id: userId,
    job_type: jobType,
    title,
    status: "queued",
    progress_percent: 0,
    request_payload: requestPayload,
    created_at: nowIso,
    updated_at: nowIso,
  });

  if (error || !data) {
    return {
      status: 500,
      body: { error: error?.message ?? "Failed to enqueue async job" },
    };
  }

  return {
    status: 202,
    body: {
      success: true,
      job_id: data.id,
      job: data,
    },
  };
}

export async function handleAsyncJobStatus(
  store: AsyncJobStore,
  userId: string,
  input: Record<string, unknown>,
): Promise<AsyncJobServiceResult> {
  const jobId = typeof input.job_id === "string" ? input.job_id.trim() : "";
  if (jobId === "") {
    return { status: 400, body: { error: "job_id is required" } };
  }

  const { data, error } = await store.getJob(jobId, userId);

  if (error) {
    return { status: 500, body: { error: error.message } };
  }
  if (!data) {
    return { status: 404, body: { error: "Async job not found" } };
  }

  return {
    status: 200,
    body: { success: true, job: data },
  };
}

export async function handleAsyncJobList(
  store: AsyncJobStore,
  userId: string,
  input: Record<string, unknown>,
): Promise<AsyncJobServiceResult> {
  const rawStatus = typeof input.status === "string"
    ? input.status.trim().toLowerCase()
    : "";
  const statusFilter =
    rawStatus !== "" && VALID_STATUSES.has(rawStatus as AsyncJobStatus)
      ? (rawStatus as AsyncJobStatus)
      : null;
  const limit = clampAsyncJobLimit(input.limit);

  const { data, error } = await store.listJobs(userId, statusFilter, limit);

  if (error) {
    return { status: 500, body: { error: error.message } };
  }

  return {
    status: 200,
    body: {
      success: true,
      jobs: data ?? [],
    },
  };
}

export async function handleAsyncJobUpdateStatus(
  store: AsyncJobStore,
  userId: string,
  input: Record<string, unknown>,
  nowIso: string = new Date().toISOString(),
): Promise<AsyncJobServiceResult> {
  const jobId = typeof input.job_id === "string" ? input.job_id.trim() : "";
  if (jobId === "") {
    return { status: 400, body: { error: "job_id is required" } };
  }

  const rawNextStatus = typeof input.status === "string"
    ? input.status.trim().toLowerCase()
    : "";
  if (!VALID_STATUSES.has(rawNextStatus as AsyncJobStatus)) {
    return {
      status: 400,
      body: { error: `Invalid job status: ${rawNextStatus}` },
    };
  }
  const nextStatus = rawNextStatus as AsyncJobStatus;

  const currentRes = await store.getJob(jobId, userId);

  if (currentRes.error) {
    return { status: 500, body: { error: currentRes.error.message } };
  }
  if (!currentRes.data) {
    return { status: 404, body: { error: "Async job not found" } };
  }

  if (!isValidStatusTransition(currentRes.data.status, nextStatus)) {
    return {
      status: 409,
      body: {
        error:
          `Cannot transition async job from ${currentRes.data.status} to ${nextStatus}`,
      },
    };
  }

  const progress = nextStatus === "queued"
    ? 0
    : clampProgressPercent(
      input.progress_percent ?? currentRes.data.progress_percent,
      nextStatus,
    );
  const errorMessage = nextStatus === "failed"
    ? (typeof input.error_message === "string"
      ? input.error_message.slice(0, 1000)
      : "Job execution failed")
    : nextStatus === "queued"
    ? null
    : currentRes.data.error_message;
  const resultPayload = input.result_payload !== undefined
    ? asObject(input.result_payload)
    : nextStatus === "queued"
    ? null
    : currentRes.data.result_payload;

  const updates: Record<string, unknown> = {
    status: nextStatus,
    progress_percent: progress,
    error_message: errorMessage,
    result_payload: resultPayload,
    updated_at: nowIso,
  };
  if (nextStatus === "running" && currentRes.data.started_at === null) {
    updates.started_at = nowIso;
  }
  if (
    nextStatus === "completed" ||
    nextStatus === "failed" ||
    nextStatus === "cancelled"
  ) {
    updates.completed_at = nowIso;
  } else if (nextStatus === "queued") {
    updates.completed_at = null;
  }

  const updated = await store.updateJob(jobId, userId, updates);

  if (updated.error || !updated.data) {
    return {
      status: 500,
      body: { error: updated.error?.message ?? "Failed to update async job" },
    };
  }

  return {
    status: 200,
    body: {
      success: true,
      job: updated.data,
    },
  };
}
