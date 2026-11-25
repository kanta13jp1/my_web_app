import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const STAGE_GATE_SEQUENCE = [
  "intake",
  "design",
  "implementation",
  "verification",
  "release",
] as const;

export type StageGateStage = (typeof STAGE_GATE_SEQUENCE)[number];
export type StageGateSourceType =
  | "github_issue"
  | "notebooklm_intake"
  | "wbs_task";
export type StageGateDecisionStatus =
  | "pending"
  | "approved"
  | "rejected"
  | "changes_requested";

export interface StageGateReviewRow {
  id: string;
  source_type: StageGateSourceType;
  source_ref: string;
  title: string;
  current_stage: StageGateStage;
  target_stage: StageGateStage;
  status: StageGateDecisionStatus;
  submitted_by: string;
  decided_by: string | null;
  feedback: string;
  validation_summary: Record<string, unknown>;
  created_at: string;
  updated_at: string;
  decided_at: string | null;
}

export interface StageGateHistoryRow {
  id: string;
  review_id: string;
  from_stage: StageGateStage;
  to_stage: StageGateStage;
  decision: "submitted" | "approved" | "rejected" | "changes_requested";
  actor_user_id: string | null;
  feedback: string;
  created_at: string;
}

export interface StageGateStoreResult<T> {
  data: T | null;
  error: { message: string } | null;
}

export interface StageGateAdminProfile {
  is_admin?: boolean | null;
  role?: string | null;
}

export interface StageGateCaller {
  userId: string | null;
  isServiceRole: boolean;
}

export interface StageGateStore {
  getAdminProfile(
    userId: string,
  ): Promise<StageGateStoreResult<StageGateAdminProfile>>;
  listReviews(params: {
    submittedBy: string | null;
    statusFilter: StageGateDecisionStatus | null;
    limit: number;
  }): Promise<StageGateStoreResult<StageGateReviewRow[]>>;
  listHistory(
    reviewIds: string[],
    limit: number,
  ): Promise<StageGateStoreResult<StageGateHistoryRow[]>>;
  insertReview(
    row: Record<string, unknown>,
  ): Promise<StageGateStoreResult<StageGateReviewRow>>;
  getReview(
    reviewId: string,
  ): Promise<StageGateStoreResult<StageGateReviewRow>>;
  updateReview(
    reviewId: string,
    updates: Record<string, unknown>,
  ): Promise<StageGateStoreResult<StageGateReviewRow>>;
  appendHistory(
    row: Record<string, unknown>,
  ): Promise<StageGateStoreResult<StageGateHistoryRow>>;
}

export function createSupabaseStageGateStore(
  admin: SupabaseClient,
): StageGateStore {
  return {
    async getAdminProfile(userId) {
      const { data, error } = await admin
        .from("user_profiles")
        .select("is_admin, role")
        .eq("user_id", userId)
        .maybeSingle();
      return {
        data: data ? (data as StageGateAdminProfile) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async listReviews({ submittedBy, statusFilter, limit }) {
      let query = admin.from("stage_gate_reviews").select("*");
      if (submittedBy !== null) {
        query = query.eq("submitted_by", submittedBy);
      }
      if (statusFilter !== null) {
        query = query.eq("status", statusFilter);
      }
      const { data, error } = await query
        .order("created_at", { ascending: false })
        .limit(limit);
      return {
        data: data ? (data as StageGateReviewRow[]) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async listHistory(reviewIds, limit) {
      if (reviewIds.length === 0) {
        return { data: [], error: null };
      }
      const { data, error } = await admin
        .from("stage_gate_approval_history")
        .select("*")
        .in("review_id", reviewIds)
        .order("created_at", { ascending: false })
        .limit(limit);
      return {
        data: data ? (data as StageGateHistoryRow[]) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async insertReview(row) {
      const { data, error } = await admin
        .from("stage_gate_reviews")
        .insert(row)
        .select("*")
        .single();
      return {
        data: data ? (data as StageGateReviewRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async getReview(reviewId) {
      const { data, error } = await admin
        .from("stage_gate_reviews")
        .select("*")
        .eq("id", reviewId)
        .maybeSingle();
      return {
        data: data ? (data as StageGateReviewRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async updateReview(reviewId, updates) {
      const { data, error } = await admin
        .from("stage_gate_reviews")
        .update(updates)
        .eq("id", reviewId)
        .select("*")
        .single();
      return {
        data: data ? (data as StageGateReviewRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async appendHistory(row) {
      const { data, error } = await admin
        .from("stage_gate_approval_history")
        .insert(row)
        .select("*")
        .single();
      return {
        data: data ? (data as StageGateHistoryRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
  };
}

export function isValidStage(raw: unknown): raw is StageGateStage {
  return STAGE_GATE_SEQUENCE.includes(
    String(raw ?? "").trim().toLowerCase() as StageGateStage,
  );
}

export function validateForwardTransition(
  currentStage: string,
  targetStage: string,
  title: string,
  sourceRef: string,
): { valid: boolean; errors: string[] } {
  const errors: string[] = [];
  if (!isValidStage(currentStage)) {
    errors.push(`Unknown current_stage: ${currentStage}`);
  }
  if (!isValidStage(targetStage)) {
    errors.push(`Unknown target_stage: ${targetStage}`);
  }
  if (title.trim().length === 0) {
    errors.push("title must not be empty");
  }
  if (sourceRef.trim().length === 0) {
    errors.push("source_ref must not be empty");
  }
  if (isValidStage(currentStage) && isValidStage(targetStage)) {
    const curIdx = STAGE_GATE_SEQUENCE.indexOf(currentStage);
    const nxtIdx = STAGE_GATE_SEQUENCE.indexOf(targetStage);
    if (nxtIdx !== curIdx + 1) {
      errors.push(
        `Invalid stage transition from ${currentStage} to ${targetStage}`,
      );
    }
  }
  return { valid: errors.length === 0, errors };
}

async function resolveIsAdmin(
  store: StageGateStore,
  caller: StageGateCaller,
): Promise<{
  allowed: boolean;
  status: number;
  error?: string;
}> {
  if (caller.isServiceRole) {
    return { allowed: true, status: 200 };
  }
  const userId = String(caller.userId ?? "").trim();
  if (!userId) {
    return { allowed: false, status: 401, error: "Unauthorized" };
  }
  const profile = await store.getAdminProfile(userId);
  if (profile.error) {
    return {
      allowed: false,
      status: 500,
      error: "Failed to verify stage-gate administrator role",
    };
  }
  const role = String(profile.data?.role ?? "").trim().toLowerCase();
  if (profile.data?.is_admin === true || role === "admin") {
    return { allowed: true, status: 200 };
  }
  return {
    allowed: false,
    status: 403,
    error: "Forbidden: admin role required for stage-gate approval decisions",
  };
}

export interface StageGateHandlerResult {
  status: number;
  body: Record<string, unknown>;
}

export async function handleStageGateList(
  store: StageGateStore,
  caller: StageGateCaller,
  body: Record<string, unknown>,
): Promise<StageGateHandlerResult> {
  const userId = String(caller.userId ?? "").trim();
  if (!caller.isServiceRole && userId === "") {
    return { status: 401, body: { error: "Unauthorized" } };
  }

  let isAdmin = caller.isServiceRole;
  if (!isAdmin && userId !== "") {
    const profile = await store.getAdminProfile(userId);
    if (profile.error) {
      return {
        status: 500,
        body: { error: profile.error.message },
      };
    }
    const role = String(profile.data?.role ?? "").trim().toLowerCase();
    isAdmin = profile.data?.is_admin === true || role === "admin";
  }

  const rawStatus = String(body.status ?? "").trim().toLowerCase();
  const allowedStatuses: readonly StageGateDecisionStatus[] = [
    "pending",
    "approved",
    "rejected",
    "changes_requested",
  ];
  const statusFilter = allowedStatuses.includes(
    rawStatus as StageGateDecisionStatus,
  )
    ? (rawStatus as StageGateDecisionStatus)
    : null;
  const rawLimit = Number(body.limit ?? 30);
  const limit = Number.isFinite(rawLimit)
    ? Math.max(1, Math.min(100, Math.trunc(rawLimit)))
    : 30;

  const reviewsRes = await store.listReviews({
    submittedBy: isAdmin ? null : userId,
    statusFilter,
    limit,
  });
  if (reviewsRes.error) {
    return { status: 500, body: { error: reviewsRes.error.message } };
  }
  const reviews = reviewsRes.data ?? [];
  const historyRes = await store.listHistory(
    reviews.map((item) => item.id),
    100,
  );
  if (historyRes.error) {
    return { status: 500, body: { error: historyRes.error.message } };
  }

  return {
    status: 200,
    body: {
      success: true,
      is_admin: isAdmin,
      reviews,
      history: historyRes.data ?? [],
    },
  };
}

export async function handleStageGateSubmit(
  store: StageGateStore,
  caller: StageGateCaller,
  body: Record<string, unknown>,
): Promise<StageGateHandlerResult> {
  const userId = String(caller.userId ?? "").trim();
  if (!userId) {
    return { status: 401, body: { error: "Unauthorized" } };
  }

  const sourceTypeRaw = String(body.source_type ?? "wbs_task")
    .trim()
    .toLowerCase();
  const sourceType: StageGateSourceType =
    sourceTypeRaw === "github_issue" || sourceTypeRaw === "notebooklm_intake"
      ? sourceTypeRaw
      : "wbs_task";
  const sourceRef = String(body.source_ref ?? "").trim().slice(0, 120);
  const title = String(body.title ?? "").trim().slice(0, 240);
  const currentStage = String(body.current_stage ?? "intake")
    .trim()
    .toLowerCase();
  const targetStage = String(body.target_stage ?? "design")
    .trim()
    .toLowerCase();
  const feedback = String(body.feedback ?? "").trim().slice(0, 2000);

  const check = validateForwardTransition(
    currentStage,
    targetStage,
    title,
    sourceRef,
  );
  if (!check.valid) {
    return {
      status: 400,
      body: {
        error: "Deterministic stage-gate validation failed",
        validation_errors: check.errors,
      },
    };
  }

  const now = new Date().toISOString();
  const inserted = await store.insertReview({
    source_type: sourceType,
    source_ref: sourceRef,
    title,
    current_stage: currentStage,
    target_stage: targetStage,
    status: "pending",
    submitted_by: userId,
    feedback,
    validation_summary: {
      deterministic_valid: true,
      checked_at: now,
    },
    created_at: now,
    updated_at: now,
  });
  if (inserted.error || !inserted.data) {
    return {
      status: 500,
      body: {
        error: inserted.error?.message ?? "Failed to create stage-gate review",
      },
    };
  }

  await store.appendHistory({
    review_id: inserted.data.id,
    from_stage: currentStage,
    to_stage: targetStage,
    decision: "submitted",
    actor_user_id: userId,
    feedback,
    created_at: now,
  });

  return {
    status: 201,
    body: {
      success: true,
      review: inserted.data,
    },
  };
}

export async function handleStageGateDecide(
  store: StageGateStore,
  caller: StageGateCaller,
  body: Record<string, unknown>,
): Promise<StageGateHandlerResult> {
  const auth = await resolveIsAdmin(store, caller);
  if (!auth.allowed) {
    return { status: auth.status, body: { error: auth.error ?? "Forbidden" } };
  }

  const reviewId = String(body.review_id ?? "").trim();
  const decision = String(body.decision ?? "").trim().toLowerCase();
  const feedback = String(body.feedback ?? "").trim().slice(0, 2000);

  if (!reviewId) {
    return { status: 400, body: { error: "review_id is required" } };
  }
  if (
    decision !== "approved" &&
    decision !== "rejected" &&
    decision !== "changes_requested"
  ) {
    return {
      status: 400,
      body: {
        error: "decision must be one of approved, rejected, changes_requested",
      },
    };
  }
  if (decision !== "approved" && feedback === "") {
    return {
      status: 400,
      body: {
        error: "feedback is required when rejecting or requesting changes",
      },
    };
  }

  const existing = await store.getReview(reviewId);
  if (existing.error) {
    return { status: 500, body: { error: existing.error.message } };
  }
  if (!existing.data) {
    return { status: 404, body: { error: "Stage-gate review not found" } };
  }

  const now = new Date().toISOString();
  const nextCurrentStage = decision === "approved"
    ? existing.data.target_stage
    : existing.data.current_stage;

  const updated = await store.updateReview(reviewId, {
    status: decision,
    current_stage: nextCurrentStage,
    decided_by: caller.userId,
    feedback,
    updated_at: now,
    decided_at: now,
  });
  if (updated.error || !updated.data) {
    return {
      status: 500,
      body: {
        error: updated.error?.message ?? "Failed to update stage-gate review",
      },
    };
  }

  const history = await store.appendHistory({
    review_id: reviewId,
    from_stage: existing.data.current_stage,
    to_stage: existing.data.target_stage,
    decision,
    actor_user_id: caller.userId,
    feedback,
    created_at: now,
  });
  if (history.error) {
    return { status: 500, body: { error: history.error.message } };
  }

  return {
    status: 200,
    body: {
      success: true,
      review: updated.data,
      history_entry: history.data,
    },
  };
}
