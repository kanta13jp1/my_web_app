import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export type CandidateReviewDecision = "pending" | "approved" | "rejected";

export interface CompetitorCandidateReviewRow {
  id: string;
  display_name: string;
  category: string | null;
  website: string | null;
  source_url_status_code: number | null;
  source_url_checked_at: string | null;
  source_url_error: string | null;
  needs_manual_review: boolean;
  review_decision: CandidateReviewDecision;
  reviewed: boolean;
  rejected_reason: string | null;
  staged_at: string | null;
  reviewed_at: string | null;
}

export interface CandidateStoreResult<T> {
  data: T | null;
  error: { message: string } | null;
}

export interface AdminProfileRow {
  is_admin?: boolean | null;
  role?: string | null;
}

export interface CandidateCallerContext {
  userId: string | null;
  isServiceRole: boolean;
}

export interface CompetitorCandidateStore {
  getAdminProfile(userId: string): Promise<CandidateStoreResult<AdminProfileRow>>;
  listCandidates(
    onlyManualReview: boolean,
    limit: number,
  ): Promise<CandidateStoreResult<CompetitorCandidateReviewRow[]>>;
  getCandidate(
    id: string,
  ): Promise<CandidateStoreResult<CompetitorCandidateReviewRow>>;
  updateCandidate(
    id: string,
    updates: Record<string, unknown>,
  ): Promise<CandidateStoreResult<CompetitorCandidateReviewRow>>;
}

export function createSupabaseCompetitorCandidateStore(
  admin: SupabaseClient,
): CompetitorCandidateStore {
  return {
    async getAdminProfile(userId) {
      const { data, error } = await admin
        .from("user_profiles")
        .select("is_admin, role")
        .eq("user_id", userId)
        .maybeSingle();
      return {
        data: data ? (data as AdminProfileRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async listCandidates(onlyManualReview, limit) {
      let query = admin
        .from("competitor_candidates")
        .select(
          "id,display_name,category,website,source_url_status_code,source_url_checked_at,source_url_error,needs_manual_review,review_decision,reviewed,rejected_reason,staged_at,reviewed_at",
        );
      if (onlyManualReview) {
        query = query.eq("needs_manual_review", true);
      }
      const { data, error } = await query
        .order("needs_manual_review", { ascending: false })
        .order("staged_at", { ascending: false })
        .limit(limit);
      return {
        data: data ? (data as CompetitorCandidateReviewRow[]) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async getCandidate(id) {
      const { data, error } = await admin
        .from("competitor_candidates")
        .select(
          "id,display_name,category,website,source_url_status_code,source_url_checked_at,source_url_error,needs_manual_review,review_decision,reviewed,rejected_reason,staged_at,reviewed_at",
        )
        .eq("id", id)
        .maybeSingle();
      return {
        data: data ? (data as CompetitorCandidateReviewRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async updateCandidate(id, updates) {
      const { data, error } = await admin
        .from("competitor_candidates")
        .update(updates)
        .eq("id", id)
        .select(
          "id,display_name,category,website,source_url_status_code,source_url_checked_at,source_url_error,needs_manual_review,review_decision,reviewed,rejected_reason,staged_at,reviewed_at",
        )
        .maybeSingle();
      return {
        data: data ? (data as CompetitorCandidateReviewRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
  };
}

export interface UrlCheckResult {
  statusCode: number | null;
  needsManualReview: boolean;
  error: string | null;
  checkedAt: string;
}

function isBlockedPrivateIpv4(host: string): boolean {
  const parts = host.split(".");
  if (parts.length !== 4 || parts.some((p) => !/^\d{1,3}$/.test(p))) {
    return false;
  }
  const nums = parts.map((p) => Number(p));
  if (nums.some((n) => n < 0 || n > 255)) return true;
  const [a, b] = nums;
  if (a === 10 || a === 127 || a === 0) return true;
  if (a === 169 && b === 254) return true;
  if (a === 192 && b === 168) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  return false;
}

export function validatePublicHttpUrl(
  rawUrl: string | null | undefined,
): { ok: true; url: string } | { ok: false; error: string } {
  const candidate = (rawUrl ?? "").trim();
  if (!candidate) {
    return { ok: false, error: "Empty source URL" };
  }
  let parsed: URL;
  try {
    parsed = new URL(candidate);
  } catch {
    return { ok: false, error: "Malformed source URL" };
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    return { ok: false, error: `Unsupported URL scheme: ${parsed.protocol}` };
  }
  if (parsed.username !== "" || parsed.password !== "") {
    return { ok: false, error: "Credentials in URL are not allowed" };
  }
  const host = parsed.hostname.toLowerCase();
  if (
    host === "" ||
    host === "localhost" ||
    host === "::1" ||
    host === "[::1]" ||
    host.endsWith(".local") ||
    host.endsWith(".internal") ||
    isBlockedPrivateIpv4(host)
  ) {
    return { ok: false, error: `Blocked non-public host: ${host}` };
  }
  return { ok: true, url: parsed.toString() };
}

export type FetchLike = (
  input: string | URL,
  init?: RequestInit,
) => Promise<Response>;

export async function verifyCandidateUrl(
  rawUrl: string | null | undefined,
  fetchFn: FetchLike = fetch,
  nowIso: string = new Date().toISOString(),
): Promise<UrlCheckResult> {
  const checked = validatePublicHttpUrl(rawUrl);
  if (!checked.ok) {
    return {
      statusCode: null,
      needsManualReview: true,
      error: checked.error,
      checkedAt: nowIso,
    };
  }

  async function probe(method: "HEAD" | "GET"): Promise<Response> {
    return await fetchFn(checked.url, {
      method,
      redirect: "follow",
      signal: AbortSignal.timeout(5000),
    });
  }

  try {
    let resp = await probe("HEAD");
    if (resp.status === 405 || resp.status === 501) {
      resp = await probe("GET");
    }
    const ok = resp.status >= 200 && resp.status < 400;
    return {
      statusCode: resp.status,
      needsManualReview: !ok,
      error: ok ? null : `HTTP ${resp.status}`,
      checkedAt: nowIso,
    };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return {
      statusCode: null,
      needsManualReview: true,
      error: msg.slice(0, 200),
      checkedAt: nowIso,
    };
  }
}

export interface CandidateServiceResponse {
  status: number;
  body: Record<string, unknown>;
}

export async function authorizeCandidateAdmin(
  store: CompetitorCandidateStore,
  caller: CandidateCallerContext,
): Promise<CandidateServiceResponse | null> {
  if (!caller.userId && !caller.isServiceRole) {
    return { status: 401, body: { error: "Unauthorized" } };
  }
  if (caller.isServiceRole) {
    return null;
  }
  const profileRes = await store.getAdminProfile(caller.userId!);
  if (profileRes.error) {
    return { status: 500, body: { error: profileRes.error.message } };
  }
  const profile = profileRes.data;
  if (profile?.is_admin !== true && profile?.role !== "admin") {
    return { status: 403, body: { error: "admin_required" } };
  }
  return null;
}

export async function handleCompetitorCandidateList(
  store: CompetitorCandidateStore,
  caller: CandidateCallerContext,
  input: Record<string, unknown>,
): Promise<CandidateServiceResponse> {
  const denied = await authorizeCandidateAdmin(store, caller);
  if (denied) return denied;
  const onlyManual = input.only_manual_review === true;
  const rawLimit = typeof input.limit === "number"
    ? input.limit
    : Number(input.limit);
  const limit = Number.isFinite(rawLimit) && rawLimit > 0
    ? Math.min(Math.max(Math.trunc(rawLimit), 1), 100)
    : 50;
  const { data, error } = await store.listCandidates(onlyManual, limit);
  if (error) {
    return { status: 500, body: { error: error.message } };
  }
  return {
    status: 200,
    body: {
      success: true,
      candidates: data ?? [],
    },
  };
}

export async function handleCompetitorCandidateVerifyUrl(
  store: CompetitorCandidateStore,
  caller: CandidateCallerContext,
  input: Record<string, unknown>,
  fetchFn: FetchLike = fetch,
  nowIso: string = new Date().toISOString(),
): Promise<CandidateServiceResponse> {
  const denied = await authorizeCandidateAdmin(store, caller);
  if (denied) return denied;
  const id = typeof input.candidate_id === "string"
    ? input.candidate_id.trim()
    : "";
  if (!id) {
    return { status: 400, body: { error: "candidate_id is required" } };
  }
  const existing = await store.getCandidate(id);
  if (existing.error) {
    return { status: 500, body: { error: existing.error.message } };
  }
  if (!existing.data) {
    return { status: 404, body: { error: "Candidate not found" } };
  }

  const targetUrl = typeof input.website === "string" &&
      input.website.trim() !== ""
    ? input.website.trim()
    : existing.data.website;
  const check = await verifyCandidateUrl(targetUrl, fetchFn, nowIso);
  const updated = await store.updateCandidate(id, {
    source_url_status_code: check.statusCode,
    source_url_checked_at: check.checkedAt,
    source_url_error: check.error,
    needs_manual_review: check.needsManualReview,
  });
  if (updated.error || !updated.data) {
    return {
      status: 500,
      body: { error: updated.error?.message ?? "Failed to update verification" },
    };
  }
  return {
    status: 200,
    body: {
      success: true,
      candidate: updated.data,
    },
  };
}

export async function handleCompetitorCandidateReview(
  store: CompetitorCandidateStore,
  caller: CandidateCallerContext,
  input: Record<string, unknown>,
  nowIso: string = new Date().toISOString(),
): Promise<CandidateServiceResponse> {
  const denied = await authorizeCandidateAdmin(store, caller);
  if (denied) return denied;
  const id = typeof input.candidate_id === "string"
    ? input.candidate_id.trim()
    : "";
  const rawDecision = typeof input.decision === "string"
    ? input.decision.trim().toLowerCase()
    : "";
  if (!id) {
    return { status: 400, body: { error: "candidate_id is required" } };
  }
  if (rawDecision !== "approved" && rawDecision !== "rejected") {
    return {
      status: 400,
      body: { error: "decision must be 'approved' or 'rejected'" },
    };
  }

  const reason = typeof input.rejected_reason === "string"
    ? input.rejected_reason.trim().slice(0, 300)
    : "";

  const updated = await store.updateCandidate(id, {
    reviewed: true,
    needs_manual_review: false,
    review_decision: rawDecision,
    reviewed_at: nowIso,
    rejected_reason: rawDecision === "rejected"
      ? (reason !== "" ? reason : "Manual review rejected")
      : null,
  });
  if (updated.error) {
    return { status: 500, body: { error: updated.error.message } };
  }
  if (!updated.data) {
    return { status: 404, body: { error: "Candidate not found" } };
  }
  return {
    status: 200,
    body: {
      success: true,
      candidate: updated.data,
    },
  };
}
