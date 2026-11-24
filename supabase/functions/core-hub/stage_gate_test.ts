import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  handleStageGateDecide,
  handleStageGateList,
  handleStageGateSubmit,
  type StageGateAdminProfile,
  type StageGateHistoryRow,
  type StageGateReviewRow,
  type StageGateStore,
} from "./stage_gate.ts";

function createFakeStore(options: {
  adminUserIds?: string[];
  reviews?: StageGateReviewRow[];
  history?: StageGateHistoryRow[];
} = {}): StageGateStore {
  const adminSet = new Set(options.adminUserIds ?? ["admin-1"]);
  const reviews = [...(options.reviews ?? [])];
  const history = [...(options.history ?? [])];

  return {
    getAdminProfile(userId: string) {
      const data: StageGateAdminProfile = {
        is_admin: adminSet.has(userId),
        role: adminSet.has(userId) ? "admin" : "member",
      };
      return Promise.resolve({ data, error: null });
    },
    listReviews({ submittedBy, statusFilter, limit }) {
      const filtered = reviews.filter((r) => {
        if (submittedBy !== null && r.submitted_by !== submittedBy) {
          return false;
        }
        if (statusFilter !== null && r.status !== statusFilter) return false;
        return true;
      }).slice(0, limit);
      return Promise.resolve({ data: filtered, error: null });
    },
    listHistory(reviewIds, limit) {
      const idSet = new Set(reviewIds);
      return Promise.resolve({
        data: history.filter((h) => idSet.has(h.review_id)).slice(0, limit),
        error: null,
      });
    },
    insertReview(row) {
      const created: StageGateReviewRow = {
        id: `rev-${reviews.length + 1}`,
        source_type: row.source_type as StageGateReviewRow["source_type"],
        source_ref: String(row.source_ref),
        title: String(row.title),
        current_stage: row.current_stage as StageGateReviewRow["current_stage"],
        target_stage: row.target_stage as StageGateReviewRow["target_stage"],
        status: "pending",
        submitted_by: String(row.submitted_by),
        decided_by: null,
        feedback: String(row.feedback ?? ""),
        validation_summary:
          (row.validation_summary as Record<string, unknown>) ?? {},
        created_at: String(row.created_at),
        updated_at: String(row.updated_at),
        decided_at: null,
      };
      reviews.unshift(created);
      return Promise.resolve({ data: created, error: null });
    },
    getReview(reviewId) {
      return Promise.resolve({
        data: reviews.find((r) => r.id === reviewId) ?? null,
        error: null,
      });
    },
    updateReview(reviewId, updates) {
      const idx = reviews.findIndex((r) => r.id === reviewId);
      if (idx < 0) {
        return Promise.resolve({ data: null, error: { message: "not found" } });
      }
      reviews[idx] = {
        ...reviews[idx],
        ...updates,
      } as StageGateReviewRow;
      return Promise.resolve({ data: reviews[idx], error: null });
    },
    appendHistory(row) {
      const entry: StageGateHistoryRow = {
        id: `hist-${history.length + 1}`,
        review_id: String(row.review_id),
        from_stage: row.from_stage as StageGateHistoryRow["from_stage"],
        to_stage: row.to_stage as StageGateHistoryRow["to_stage"],
        decision: row.decision as StageGateHistoryRow["decision"],
        actor_user_id: row.actor_user_id ? String(row.actor_user_id) : null,
        feedback: String(row.feedback ?? ""),
        created_at: String(row.created_at),
      };
      history.unshift(entry);
      return Promise.resolve({ data: entry, error: null });
    },
  };
}

Deno.test("handleStageGateSubmit validates forward stages and records history", async () => {
  const store = createFakeStore();
  const invalid = await handleStageGateSubmit(
    store,
    { userId: "member-1", isServiceRole: false },
    {
      source_type: "github_issue",
      source_ref: "#2593",
      title: "Stage-gate skip test",
      current_stage: "intake",
      target_stage: "release",
    },
  );
  assertEquals(invalid.status, 400);

  const created = await handleStageGateSubmit(
    store,
    { userId: "member-1", isServiceRole: false },
    {
      source_type: "github_issue",
      source_ref: "#2593",
      title: "Stage-gate design transition",
      current_stage: "intake",
      target_stage: "design",
      feedback: "Ready for design review",
    },
  );
  assertEquals(created.status, 201);
  assertEquals((created.body.review as StageGateReviewRow).status, "pending");
});

Deno.test("handleStageGateDecide rejects unauthenticated or non-admin users and requires rejection feedback", async () => {
  const store = createFakeStore({
    adminUserIds: ["admin-1"],
    reviews: [
      {
        id: "rev-1",
        source_type: "github_issue",
        source_ref: "#2593",
        title: "Design review",
        current_stage: "intake",
        target_stage: "design",
        status: "pending",
        submitted_by: "member-1",
        decided_by: null,
        feedback: "",
        validation_summary: {},
        created_at: "2026-11-24T00:00:00Z",
        updated_at: "2026-11-24T00:00:00Z",
        decided_at: null,
      },
    ],
  });

  const unauth = await handleStageGateDecide(
    store,
    { userId: null, isServiceRole: false },
    { review_id: "rev-1", decision: "approved" },
  );
  assertEquals(unauth.status, 401);

  const nonAdmin = await handleStageGateDecide(
    store,
    { userId: "member-1", isServiceRole: false },
    { review_id: "rev-1", decision: "approved" },
  );
  assertEquals(nonAdmin.status, 403);

  const missingFeedback = await handleStageGateDecide(
    store,
    { userId: "admin-1", isServiceRole: false },
    { review_id: "rev-1", decision: "rejected", feedback: " " },
  );
  assertEquals(missingFeedback.status, 400);

  const approved = await handleStageGateDecide(
    store,
    { userId: "admin-1", isServiceRole: false },
    { review_id: "rev-1", decision: "approved", feedback: "LGTM" },
  );
  assertEquals(approved.status, 200);
  const rev = approved.body.review as StageGateReviewRow;
  assertEquals(rev.status, "approved");
  assertEquals(rev.current_stage, "design");

  const listAdmin = await handleStageGateList(
    store,
    { userId: "admin-1", isServiceRole: false },
    {},
  );
  assertEquals(listAdmin.status, 200);
  assertEquals((listAdmin.body.history as StageGateHistoryRow[]).length, 1);
});
