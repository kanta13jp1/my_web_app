export type PublicationPacket = {
  artifactId: string;
  reviewId: string;
  validityHours: number;
  productId: string;
  title: string;
  summary: string;
  description: string;
  priceJpy: number;
  licenseSummary: string;
};

export type PublicationValidationResult =
  | { ok: true; value: PublicationPacket }
  | { ok: false; code: string };

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PRODUCT_ID_PATTERN = /^[a-z0-9][a-z0-9-]{2,79}$/;

export function validatePublicationPacket(
  body: Record<string, unknown>,
): PublicationValidationResult {
  const artifactId = asString(body.artifact_id);
  const reviewId = asString(body.review_id);
  if (!isUuid(artifactId) || !isUuid(reviewId)) {
    return { ok: false, code: "invalid_publication_source" };
  }

  const validityHours = asInteger(body.validity_hours);
  if (validityHours < 1 || validityHours > 24 * 30) {
    return { ok: false, code: "invalid_publication_authorization_expiry" };
  }

  const productId = asString(body.product_id);
  const title = asString(body.title);
  const summary = asString(body.summary);
  const description = asString(body.description);
  const priceJpy = asInteger(body.price_jpy);
  const licenseSummary = asString(body.license_summary);
  if (
    !PRODUCT_ID_PATTERN.test(productId) ||
    title.length < 1 || title.length > 140 ||
    summary.length < 1 || summary.length > 500 ||
    description.length < 1 || description.length > 20_000 ||
    priceJpy < 50 || priceJpy > 1_000_000 ||
    licenseSummary.length < 1 || licenseSummary.length > 1000
  ) {
    return { ok: false, code: "invalid_video_publication_packet" };
  }

  if (
    asString(body.currency).toLowerCase() !== "jpy" ||
    asString(body.territory).toLowerCase() !== "worldwide" ||
    asString(body.publication_channel) !== "/shop" ||
    asString(body.rollback_action) !== "deactivate_listing"
  ) {
    return { ok: false, code: "unsupported_publication_policy" };
  }

  if (
    body.rights_confirmed !== true ||
    body.privacy_confirmed !== true ||
    body.fictional_person_confirmed !== true ||
    body.no_third_party_logos_confirmed !== true ||
    body.no_unlicensed_material_confirmed !== true
  ) {
    return { ok: false, code: "publication_confirmations_required" };
  }

  return {
    ok: true,
    value: {
      artifactId,
      reviewId,
      validityHours,
      productId,
      title,
      summary,
      description,
      priceJpy,
      licenseSummary,
    },
  };
}

export function isUuid(value: string): boolean {
  return UUID_PATTERN.test(value);
}

export function safeErrorCode(error: unknown): string {
  const raw = error instanceof Error
    ? error.message
    : typeof error === "object" && error !== null &&
        typeof (error as Record<string, unknown>).message === "string"
    ? String((error as Record<string, unknown>).message)
    : String(error);
  const normalized = raw.trim().toLowerCase().replace(/[^a-z0-9_]+/g, "_")
    .replace(/^_+|_+$/g, "").slice(0, 120);
  return normalized || "internal_error";
}

export async function sha256Hex(value: Blob): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    await value.arrayBuffer(),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
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
