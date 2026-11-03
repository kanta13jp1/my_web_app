export type XPostAttribution = {
  variant: string | null;
  utmContent: string | null;
};

function firstNonEmpty(...values: unknown[]): string | null {
  for (const value of values) {
    const normalized = String(value ?? "").trim();
    if (normalized !== "") return normalized;
  }
  return null;
}

/// Normalize caller attribution while preserving both the experiment-facing
/// `variant` and the URL-facing `utm_content` in x_post_log metadata.
export function resolveXPostAttribution(
  body: Record<string, unknown>,
): XPostAttribution {
  return {
    variant: firstNonEmpty(
      body.variant,
      body.utmContent,
      body.utm_content,
    ),
    utmContent: firstNonEmpty(
      body.utmContent,
      body.utm_content,
      body.variant,
    ),
  };
}
