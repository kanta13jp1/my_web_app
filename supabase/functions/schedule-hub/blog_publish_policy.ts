export type BlogPublishPlatform = "qiita" | "devto";

const SUPPORTED_PLATFORMS = new Set<BlogPublishPlatform>([
  "qiita",
  "devto",
]);
const LEGACY_DEFAULT_PLATFORMS: BlogPublishPlatform[] = ["qiita", "devto"];

export interface BlogPublishPlatformResolution {
  platforms: BlogPublishPlatform[];
  error?: string;
}

function isSupportedPlatform(value: unknown): value is BlogPublishPlatform {
  return typeof value === "string" &&
    SUPPORTED_PLATFORMS.has(value as BlogPublishPlatform);
}

function uniquePlatforms(values: unknown[]): BlogPublishPlatform[] {
  return Array.from(new Set(values.filter(isSupportedPlatform)));
}

/**
 * Resolve the platforms used by blog.publish_post.
 *
 * An omitted override preserves the legacy DB-driven behavior. An explicit
 * override is an allowlist intersected with the stored targets, so callers can
 * narrow a publish operation but cannot add a destination. Invalid or empty
 * overrides fail closed.
 */
export function resolveBlogPublishPlatforms(
  storedTargets: unknown,
  requestedOverride: unknown,
): BlogPublishPlatformResolution {
  const stored = Array.isArray(storedTargets)
    ? uniquePlatforms(storedTargets)
    : [...LEGACY_DEFAULT_PLATFORMS];

  if (requestedOverride === undefined) {
    return { platforms: stored };
  }
  if (!Array.isArray(requestedOverride) || requestedOverride.length === 0) {
    return {
      platforms: [],
      error: "platforms override must be a non-empty array",
    };
  }
  if (!requestedOverride.every(isSupportedPlatform)) {
    return {
      platforms: [],
      error: "platforms override contains an unsupported value",
    };
  }

  const requested = uniquePlatforms(requestedOverride);
  const platforms = requested.filter((platform) => stored.includes(platform));
  if (platforms.length === 0) {
    return {
      platforms: [],
      error: "platforms override does not match the stored targets",
    };
  }
  return { platforms };
}

/** Qiita traffic stays disabled unless operators explicitly opt it back in. */
export function isQiitaAccessEnabled(
  value: string | null | undefined,
): boolean {
  return value?.trim().toLowerCase() === "true";
}
