/**
 * Growth Achievement Summary Aggregation & Date Normalization (#4187)
 *
 * Normalizes incoming `since` timestamps (including local ISO without `Z` and
 * non-zero ms) to UTC ISO and aggregates `app_analytics.source_details`.
 */

export type GrowthSummaryMetricKey =
  | "newUsers"
  | "totalUsersEver"
  | "acquisitionSignals"
  | "referralsCompleted"
  | "importPreviews";

export const GROWTH_SUMMARY_METRIC_LABELS = {
  newUsers: "New Users",
  totalUsersEver: "Total Users Ever",
  acquisitionSignals: "Acquisition Signals",
  referralsCompleted: "Referrals Completed",
  importPreviews: "Import Previews",
} as const satisfies Record<GrowthSummaryMetricKey, string>;

export interface NormalizedSinceBoundary {
  readonly sinceUtcIso: string;
  readonly sinceDateKey: string;
}

export interface AnalyticsSummaryRow {
  readonly source_details?: Record<string, unknown> | null;
}

export interface GrowthSummaryAggregateInput {
  readonly newUsers: number;
  readonly totalUsersEver: number;
  readonly referralsCompleted: number;
  readonly analyticsRows: readonly AnalyticsSummaryRow[];
  readonly label: string;
}

export interface GrowthSummaryPayload {
  readonly success: true;
  readonly newUsers: number;
  readonly totalUsersEver: number;
  readonly acquisitionSignals: number;
  readonly referralsCompleted: number;
  readonly importPreviews: number;
  readonly label: string;
}

const FALLBACK_SINCE_ISO = "2020-01-01T00:00:00.000Z";

export function normalizeSinceUtcIso(
  rawSince: unknown,
  fallbackIso = FALLBACK_SINCE_ISO,
): NormalizedSinceBoundary {
  const trimmed = typeof rawSince === "string" ? rawSince.trim() : "";
  if (!trimmed) {
    return {
      sinceUtcIso: fallbackIso,
      sinceDateKey: fallbackIso.slice(0, 10),
    };
  }

  const hasZone = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(trimmed);
  const candidate = hasZone ? trimmed : `${trimmed}Z`;
  const parsedMs = Date.parse(candidate);
  if (Number.isNaN(parsedMs)) {
    return {
      sinceUtcIso: fallbackIso,
      sinceDateKey: fallbackIso.slice(0, 10),
    };
  }

  const utcIso = new Date(parsedMs).toISOString();
  return {
    sinceUtcIso: utcIso,
    sinceDateKey: utcIso.slice(0, 10),
  };
}

export function aggregateGrowthSummaryCounts(
  input: GrowthSummaryAggregateInput,
): GrowthSummaryPayload {
  let acquisitionSignals = 0;
  let importPreviews = 0;

  for (const row of input.analyticsRows) {
    const details = row.source_details ?? {};
    for (const [key, rawVal] of Object.entries(details)) {
      const count = typeof rawVal === "number" ? rawVal : Number(rawVal);
      if (!Number.isFinite(count) || count <= 0) {
        continue;
      }
      if (key.startsWith("touch_") || key.startsWith("share_")) {
        acquisitionSignals += count;
      } else if (key.startsWith("import_preview")) {
        importPreviews += count;
      }
    }
  }

  return {
    success: true,
    newUsers: Math.max(0, Math.round(input.newUsers)),
    totalUsersEver: Math.max(0, Math.round(input.totalUsersEver)),
    acquisitionSignals: Math.round(acquisitionSignals),
    referralsCompleted: Math.max(0, Math.round(input.referralsCompleted)),
    importPreviews: Math.round(importPreviews),
    label: input.label.trim() || "すべて",
  };
}
