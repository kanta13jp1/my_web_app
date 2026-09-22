export type ImprovementAuthorizationRequest = {
  sourceArtifactId: string;
  sourceReviewId: string;
  validityHours: number;
  totalRegenerations: number;
};

export type AuthorizationValidationResult =
  | { ok: true; value: ImprovementAuthorizationRequest }
  | { ok: false; code: string };

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function validateImprovementAuthorization(
  body: Record<string, unknown>,
): AuthorizationValidationResult {
  const sourceArtifactId = asString(body.source_artifact_id);
  const sourceReviewId = asString(body.source_review_id);
  if (
    !UUID_PATTERN.test(sourceArtifactId) || !UUID_PATTERN.test(sourceReviewId)
  ) {
    return { ok: false, code: "invalid_authorization_source" };
  }

  const validityHours = asInteger(body.validity_hours);
  if (validityHours < 1 || validityHours > 24 * 30) {
    return { ok: false, code: "invalid_authorization_expiry" };
  }

  const totalRegenerations = asInteger(body.total_regenerations);
  if (totalRegenerations < 1 || totalRegenerations > 24) {
    return { ok: false, code: "invalid_authorization_iterations" };
  }

  if (
    body.rights_confirmed !== true ||
    body.adult_confirmed !== true ||
    body.terms_confirmed !== true ||
    body.prohibited_content_confirmed !== true
  ) {
    return { ok: false, code: "authorization_confirmations_required" };
  }

  return {
    ok: true,
    value: {
      sourceArtifactId,
      sourceReviewId,
      validityHours,
      totalRegenerations,
    },
  };
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asInteger(value: unknown): number {
  if (typeof value === "number" && Number.isInteger(value)) return value;
  if (typeof value === "string" && /^\d+$/.test(value.trim())) {
    return Number(value);
  }
  return 0;
}
