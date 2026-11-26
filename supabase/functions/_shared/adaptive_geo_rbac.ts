/**
 * Neutral Traffic-Based Adaptive Rate-Limit & Geo-RBAC Middleware (#2811)
 *
 * Uses Geo-IP headers (cf-ipcountry / x-country-code) and an O(1) burst
 * counter to apply progressive friction (normal -> elevated_rate_limit ->
 * step_up_challenge) without hard political blocking or primary-region lag.
 */

export type AccessControlTier =
  | "normal"
  | "elevated_rate_limit"
  | "step_up_challenge";

export const ACCESS_TIER_LABELS = {
  normal: "Normal",
  elevated_rate_limit: "Elevated Rate Limit",
  step_up_challenge: "Step-Up Challenge",
} as const satisfies Record<AccessControlTier, string>;

export interface GeoRbacPolicy {
  readonly primaryRegions: readonly string[];
  readonly windowMs: number;
  readonly primaryLimit: number;
  readonly secondaryElevatedThreshold: number;
  readonly secondaryChallengeThreshold: number;
}

export const DEFAULT_GEO_RBAC_POLICY: GeoRbacPolicy = {
  primaryRegions: ["JP"],
  windowMs: 60_000,
  primaryLimit: 120,
  secondaryElevatedThreshold: 20,
  secondaryChallengeThreshold: 40,
};

export interface GeoAccessDecision {
  readonly countryCode: string;
  readonly isPrimaryRegion: boolean;
  readonly tier: AccessControlTier;
  readonly requestCount: number;
  readonly retryAfterSeconds: number;
  readonly requiresStepUp: boolean;
}

interface WindowBucket {
  windowStartMs: number;
  count: number;
}

export function extractCountryCode(headers: Headers): string {
  const raw =
    headers.get("cf-ipcountry") ??
    headers.get("x-country-code") ??
    "";
  const cleaned = raw.trim().toUpperCase();
  if (!cleaned || cleaned === "XX" || cleaned === "T1") {
    return "UNKNOWN";
  }
  return cleaned;
}

export class AdaptiveGeoRbacGuard {
  private readonly policy: GeoRbacPolicy;
  private readonly primarySet: Set<string>;
  private readonly buckets = new Map<string, WindowBucket>();

  constructor(policy: GeoRbacPolicy = DEFAULT_GEO_RBAC_POLICY) {
    this.policy = policy;
    this.primarySet = new Set(
      policy.primaryRegions.map((code) => code.trim().toUpperCase()),
    );
  }

  evaluate(
    headers: Headers,
    clientKey: string,
    nowMs = Date.now(),
  ): GeoAccessDecision {
    const countryCode = extractCountryCode(headers);
    const isPrimaryRegion = this.primarySet.has(countryCode);
    const bucketKey = `${countryCode}:${clientKey.trim() || "anon"}`;

    let bucket = this.buckets.get(bucketKey);
    if (!bucket || nowMs - bucket.windowStartMs >= this.policy.windowMs) {
      bucket = { windowStartMs: nowMs, count: 0 };
      this.buckets.set(bucketKey, bucket);
    }
    bucket.count += 1;

    if (isPrimaryRegion) {
      if (bucket.count > this.policy.primaryLimit) {
        return {
          countryCode,
          isPrimaryRegion: true,
          tier: "elevated_rate_limit",
          requestCount: bucket.count,
          retryAfterSeconds: Math.ceil(this.policy.windowMs / 1000),
          requiresStepUp: false,
        };
      }
      return {
        countryCode,
        isPrimaryRegion: true,
        tier: "normal",
        requestCount: bucket.count,
        retryAfterSeconds: 0,
        requiresStepUp: false,
      };
    }

    if (bucket.count >= this.policy.secondaryChallengeThreshold) {
      return {
        countryCode,
        isPrimaryRegion: false,
        tier: "step_up_challenge",
        requestCount: bucket.count,
        retryAfterSeconds: Math.ceil(this.policy.windowMs / 1000),
        requiresStepUp: true,
      };
    }

    if (bucket.count >= this.policy.secondaryElevatedThreshold) {
      return {
        countryCode,
        isPrimaryRegion: false,
        tier: "elevated_rate_limit",
        requestCount: bucket.count,
        retryAfterSeconds: Math.ceil(this.policy.windowMs / 2000),
        requiresStepUp: false,
      };
    }

    return {
      countryCode,
      isPrimaryRegion: false,
      tier: "normal",
      requestCount: bucket.count,
      retryAfterSeconds: 0,
      requiresStepUp: false,
    };
  }
}
