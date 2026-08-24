export type VideoArtifactReviewInput = {
  artifactId: string;
  qualityScore: number;
  promptAlignmentScore: number;
  motionQualityScore: number;
  commercialValueScore: number;
  decision: "keep" | "improve" | "reject";
  strengths: string;
  improvementRequest: string;
  suggestedPrompt: string;
  notes: string;
  rightsStatus: "review_required" | "allowed" | "blocked";
  privacyStatus: "review_required" | "cleared" | "blocked";
};

export type VideoImprovementLink = {
  parentArtifactId: string;
  appliedReviewId: string;
};

type ValidationResult<T> =
  | { ok: true; value: T }
  | { ok: false; code: string };

export function validateArtifactReview(
  body: Record<string, unknown>,
): ValidationResult<VideoArtifactReviewInput> {
  const artifactId = asString(body.artifact_id);
  const scores = [
    asInteger(body.quality_score),
    asInteger(body.prompt_alignment_score),
    asInteger(body.motion_quality_score),
    asInteger(body.commercial_value_score),
  ];
  const decision = asString(body.decision);
  const strengths = asString(body.strengths);
  const improvementRequest = asString(body.improvement_request);
  const suggestedPrompt = asString(body.suggested_prompt);
  const notes = asString(body.notes);
  const rightsStatus = asString(body.rights_status) || "review_required";
  const privacyStatus = asString(body.privacy_status) || "review_required";

  if (!isUuid(artifactId)) return invalid("invalid_artifact_id");
  if (scores.some((score) => score === null || score < 1 || score > 5)) {
    return invalid("invalid_review_score");
  }
  if (!["keep", "improve", "reject"].includes(decision)) {
    return invalid("invalid_review_decision");
  }
  if (
    !["review_required", "allowed", "blocked"].includes(rightsStatus) ||
    !["review_required", "cleared", "blocked"].includes(privacyStatus)
  ) {
    return invalid("invalid_review_clearance");
  }
  if (
    strengths.length > 1000 || improvementRequest.length > 1500 ||
    notes.length > 2000 || suggestedPrompt.length < 3 ||
    suggestedPrompt.length > 1000
  ) {
    return invalid("invalid_review_text");
  }
  return {
    ok: true,
    value: {
      artifactId,
      qualityScore: scores[0]!,
      promptAlignmentScore: scores[1]!,
      motionQualityScore: scores[2]!,
      commercialValueScore: scores[3]!,
      decision: decision as VideoArtifactReviewInput["decision"],
      strengths,
      improvementRequest,
      suggestedPrompt,
      notes,
      rightsStatus: rightsStatus as VideoArtifactReviewInput["rightsStatus"],
      privacyStatus: privacyStatus as VideoArtifactReviewInput["privacyStatus"],
    },
  };
}

export function validateImprovementLink(
  body: Record<string, unknown>,
): ValidationResult<VideoImprovementLink | null> {
  const parentArtifactId = asString(body.parent_artifact_id);
  const appliedReviewId = asString(body.applied_review_id);
  if (!parentArtifactId && !appliedReviewId) return { ok: true, value: null };
  if (!isUuid(parentArtifactId) || !isUuid(appliedReviewId)) {
    return invalid("invalid_improvement_lineage");
  }
  return { ok: true, value: { parentArtifactId, appliedReviewId } };
}

export function isSha256(value: string): boolean {
  return /^[0-9a-f]{64}$/.test(value);
}

function invalid<T>(code: string): ValidationResult<T> {
  return { ok: false, code };
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asInteger(value: unknown): number | null {
  const number = typeof value === "number" ? value : Number(value);
  return Number.isInteger(number) ? number : null;
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}
