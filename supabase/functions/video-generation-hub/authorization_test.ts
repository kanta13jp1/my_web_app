import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateImprovementAuthorization } from "./authorization.ts";

const ARTIFACT_ID = "11111111-1111-4111-8111-111111111111";
const REVIEW_ID = "22222222-2222-4222-8222-222222222222";

Deno.test("recurring authorization requires bounded expiry and iterations", () => {
  const result = validateImprovementAuthorization({
    source_artifact_id: ARTIFACT_ID,
    source_review_id: REVIEW_ID,
    validity_hours: 168,
    total_regenerations: 2,
    rights_confirmed: true,
    adult_confirmed: true,
    terms_confirmed: true,
    prohibited_content_confirmed: true,
  });
  assertEquals(result, {
    ok: true,
    value: {
      sourceArtifactId: ARTIFACT_ID,
      sourceReviewId: REVIEW_ID,
      validityHours: 168,
      totalRegenerations: 2,
    },
  });
});

Deno.test("recurring authorization rejects missing confirmations", () => {
  assertEquals(
    validateImprovementAuthorization({
      source_artifact_id: ARTIFACT_ID,
      source_review_id: REVIEW_ID,
      validity_hours: 24,
      total_regenerations: 1,
      rights_confirmed: true,
      adult_confirmed: true,
      terms_confirmed: false,
      prohibited_content_confirmed: true,
    }),
    { ok: false, code: "authorization_confirmations_required" },
  );
});

Deno.test("recurring authorization rejects unbounded values", () => {
  assertEquals(
    validateImprovementAuthorization({
      source_artifact_id: ARTIFACT_ID,
      source_review_id: REVIEW_ID,
      validity_hours: 24 * 31,
      total_regenerations: 25,
      rights_confirmed: true,
      adult_confirmed: true,
      terms_confirmed: true,
      prohibited_content_confirmed: true,
    }),
    { ok: false, code: "invalid_authorization_expiry" },
  );
});
