/**
 * Untrusted marketing tags only. Never use these values for authentication,
 * price, payment status or download rights. No I/O or environment access.
 *
 * Candidate contract: connected locally, not deployed or execution-verified.
 */
export interface ShopAttribution {
  source: string;
  campaign: string;
  contentId: string;
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function tag(value: unknown): string | null {
  if (value === undefined || value === null) return "";
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  // Reject rather than truncate/substitute: two invalid post IDs must not be
  // silently aliased to the same real post. Missing is represented by "".
  return /^[a-z0-9_.-]{0,64}$/.test(normalized) ? normalized : null;
}

function parse(
  sourceValue: unknown,
  campaignValue: unknown,
  contentValue: unknown,
): ShopAttribution | null {
  const source = tag(sourceValue);
  const campaign = tag(campaignValue);
  const contentId = tag(contentValue);
  if (source === null || campaign === null || contentId === null) return null;
  return { source: source || "direct", campaign, contentId };
}

/** Invalid tags suppress attribution, not the purchase itself. */
export function shopAttributionFromClient(
  value: unknown,
): ShopAttribution | null {
  const payload = record(value);
  if (!payload) return null;
  // A client may suppress invalid/ambiguous URL labels without echoing the raw
  // values. This flag controls telemetry only, never checkout eligibility.
  if (payload.attribution_valid !== undefined && payload.attribution_valid !== true) {
    return null;
  }
  return parse(payload.source, payload.campaign, payload.content_id);
}

/** Only read the three shop-specific keys, never unrelated metadata. */
export function shopAttributionFromMetadata(
  value: unknown,
): ShopAttribution | null {
  const metadata = record(value);
  if (!metadata) return null;
  return parse(
    metadata.shop_source,
    metadata.shop_campaign,
    metadata.shop_content_id,
  );
}

/** Plain key names for the Checkout Session's metadata object. */
export function shopAttributionMetadata(
  clientPayload: unknown,
): Record<string, string> | null {
  const attribution = shopAttributionFromClient(clientPayload);
  if (!attribution) return null;
  return {
    shop_source: attribution.source,
    shop_campaign: attribution.campaign,
    shop_content_id: attribution.contentId,
  };
}

/** Only allowlisted tags for a trusted, server-built return URL. */
export function shopAttributionQuery(
  clientPayload: unknown,
): Record<string, string> | null {
  const attribution = shopAttributionFromClient(clientPayload);
  if (!attribution) return null;
  return {
    utm_source: attribution.source,
    ...(attribution.campaign ? { utm_campaign: attribution.campaign } : {}),
    ...(attribution.contentId ? { utm_content: attribution.contentId } : {}),
  };
}
