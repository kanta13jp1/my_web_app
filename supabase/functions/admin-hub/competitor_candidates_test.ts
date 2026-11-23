import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type AdminProfileRow,
  type CandidateCallerContext,
  type CandidateStoreResult,
  type CompetitorCandidateReviewRow,
  type CompetitorCandidateStore,
  handleCompetitorCandidateList,
  handleCompetitorCandidateReview,
  handleCompetitorCandidateVerifyUrl,
  verifyCandidateUrl,
} from "./competitor_candidates.ts";

class InMemoryCandidateStore implements CompetitorCandidateStore {
  rows: CompetitorCandidateReviewRow[] = [];
  profiles = new Map<string, AdminProfileRow>();

  getAdminProfile(userId: string): Promise<CandidateStoreResult<AdminProfileRow>> {
    return Promise.resolve({
      data: this.profiles.get(userId) ?? null,
      error: null,
    });
  }

  listCandidates(
    onlyManualReview: boolean,
    limit: number,
  ): Promise<CandidateStoreResult<CompetitorCandidateReviewRow[]>> {
    const items = this.rows
      .filter((r) => !onlyManualReview || r.needs_manual_review)
      .slice(0, limit)
      .map((r) => ({ ...r }));
    return Promise.resolve({ data: items, error: null });
  }

  getCandidate(
    id: string,
  ): Promise<CandidateStoreResult<CompetitorCandidateReviewRow>> {
    const found = this.rows.find((r) => r.id === id) ?? null;
    return Promise.resolve({ data: found ? { ...found } : null, error: null });
  }

  updateCandidate(
    id: string,
    updates: Record<string, unknown>,
  ): Promise<CandidateStoreResult<CompetitorCandidateReviewRow>> {
    const found = this.rows.find((r) => r.id === id) ?? null;
    if (!found) return Promise.resolve({ data: null, error: null });
    Object.assign(found, updates);
    return Promise.resolve({ data: { ...found }, error: null });
  }
}

const ADMIN_CALLER: CandidateCallerContext = {
  userId: "admin-1",
  isServiceRole: false,
};

Deno.test("verifyCandidateUrl flags 404 and SSRF private IPs while passing 200", async () => {
  const okRes = await verifyCandidateUrl(
    "https://example.com/about",
    () => Promise.resolve(new Response(null, { status: 200 })),
    "2026-11-24T00:00:00Z",
  );
  assertEquals(okRes.statusCode, 200);
  assertEquals(okRes.needsManualReview, false);

  const notFound = await verifyCandidateUrl(
    "https://example.com/fake-404",
    () => Promise.resolve(new Response(null, { status: 404 })),
    "2026-11-24T00:00:00Z",
  );
  assertEquals(notFound.statusCode, 404);
  assertEquals(notFound.needsManualReview, true);

  const blocked = await verifyCandidateUrl("http://127.0.0.1:8080/internal");
  assertEquals(blocked.statusCode, null);
  assertEquals(blocked.needsManualReview, true);
});

Deno.test("competitor_candidate actions reject unauthenticated (401) and non-admin (403) callers", async () => {
  const store = new InMemoryCandidateStore();
  store.profiles.set("non-admin", { is_admin: false, role: "user" });

  const unauthList = await handleCompetitorCandidateList(
    store,
    { userId: null, isServiceRole: false },
    {},
  );
  assertEquals(unauthList.status, 401);

  const nonAdminReview = await handleCompetitorCandidateReview(
    store,
    { userId: "non-admin", isServiceRole: false },
    { candidate_id: "cand-1", decision: "approved" },
  );
  assertEquals(nonAdminReview.status, 403);

  const nonAdminVerify = await handleCompetitorCandidateVerifyUrl(
    store,
    { userId: "non-admin", isServiceRole: false },
    { candidate_id: "cand-1" },
  );
  assertEquals(nonAdminVerify.status, 403);
});

Deno.test("handleCompetitorCandidateVerifyUrl and handleCompetitorCandidateReview update store for admin", async () => {
  const store = new InMemoryCandidateStore();
  store.profiles.set("admin-1", { is_admin: true, role: "admin" });
  store.rows.push({
    id: "cand-404",
    display_name: "Ghost Tool",
    category: "productivity",
    website: "https://ghost.example.com/404",
    source_url_status_code: 404,
    source_url_checked_at: "2026-11-24T00:00:00Z",
    source_url_error: "HTTP 404",
    needs_manual_review: true,
    review_decision: "pending",
    reviewed: false,
    rejected_reason: null,
    staged_at: "2026-11-24T00:00:00Z",
    reviewed_at: null,
  });

  const list = await handleCompetitorCandidateList(
    store,
    ADMIN_CALLER,
    { only_manual_review: true },
  );
  assertEquals(list.status, 200);
  assertEquals((list.body.candidates as CompetitorCandidateReviewRow[]).length, 1);

  const reverified = await handleCompetitorCandidateVerifyUrl(
    store,
    ADMIN_CALLER,
    { candidate_id: "cand-404" },
    () => Promise.resolve(new Response(null, { status: 200 })),
    "2026-11-24T01:00:00Z",
  );
  assertEquals(reverified.status, 200);
  assertEquals(
    (reverified.body.candidate as CompetitorCandidateReviewRow).needs_manual_review,
    false,
  );

  const badDecision = await handleCompetitorCandidateReview(
    store,
    ADMIN_CALLER,
    { candidate_id: "cand-404", decision: "invalid" },
  );
  assertEquals(badDecision.status, 400);

  const rejected = await handleCompetitorCandidateReview(
    store,
    { userId: null, isServiceRole: true },
    {
      candidate_id: "cand-404",
      decision: "rejected",
      rejected_reason: "URL not reachable",
    },
    "2026-11-24T02:00:00Z",
  );
  assertEquals(rejected.status, 200);
  const row = rejected.body.candidate as CompetitorCandidateReviewRow;
  assertEquals(row.reviewed, true);
  assertEquals(row.review_decision, "rejected");
  assertEquals(row.needs_manual_review, false);
});
