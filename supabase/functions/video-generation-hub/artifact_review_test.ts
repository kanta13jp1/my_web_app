import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  isSha256,
  validateArtifactReview,
  validateImprovementLink,
} from "./artifact_review.ts";

const ARTIFACT_ID = "11111111-1111-4111-8111-111111111111";
const REVIEW_ID = "22222222-2222-4222-8222-222222222222";

Deno.test("artifact review accepts bounded owner feedback", () => {
  const result = validateArtifactReview({
    artifact_id: ARTIFACT_ID,
    quality_score: 4,
    prompt_alignment_score: 5,
    motion_quality_score: 3,
    commercial_value_score: 4,
    decision: "improve",
    strengths: "構図がよい",
    improvement_request: "手の動きを自然にする",
    suggested_prompt: "自然な手の動きで資料を確認するビジネス人物",
    notes: "販売候補",
    rights_status: "allowed",
    privacy_status: "cleared",
  });
  assertEquals(result.ok, true);
  if (result.ok) {
    assertEquals(result.value.qualityScore, 4);
    assertEquals(result.value.decision, "improve");
  }
});

Deno.test("artifact review rejects invalid scores, ids, and oversized prompts", () => {
  assertEquals(
    validateArtifactReview({
      artifact_id: "not-a-uuid",
      quality_score: 6,
      prompt_alignment_score: 3,
      motion_quality_score: 3,
      commercial_value_score: 3,
      decision: "publish",
      suggested_prompt: "ok prompt",
    }),
    { ok: false, code: "invalid_artifact_id" },
  );
  const oversized = validateArtifactReview({
    artifact_id: ARTIFACT_ID,
    quality_score: 3,
    prompt_alignment_score: 3,
    motion_quality_score: 3,
    commercial_value_score: 3,
    decision: "keep",
    suggested_prompt: "x".repeat(1001),
  });
  assertEquals(oversized, { ok: false, code: "invalid_review_text" });
});

Deno.test("improvement lineage must contain both owned-looking UUIDs", () => {
  assertEquals(validateImprovementLink({}), { ok: true, value: null });
  assertEquals(
    validateImprovementLink({
      parent_artifact_id: ARTIFACT_ID,
      applied_review_id: REVIEW_ID,
    }),
    {
      ok: true,
      value: { parentArtifactId: ARTIFACT_ID, appliedReviewId: REVIEW_ID },
    },
  );
  assertEquals(
    validateImprovementLink({ parent_artifact_id: ARTIFACT_ID }),
    { ok: false, code: "invalid_improvement_lineage" },
  );
});

Deno.test("artifact digest accepts lowercase sha256 only", () => {
  assertEquals(isSha256("a".repeat(64)), true);
  assertEquals(isSha256("A".repeat(64)), false);
  assertEquals(isSha256("a".repeat(63)), false);
});
