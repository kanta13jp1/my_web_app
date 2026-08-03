/**
 * Normalizes cumulative X metric snapshots into comparable post-age windows.
 *
 * Selection rule:
 * - lead tweets only;
 * - I3h / I24h / I72h stay null until the post reaches that age;
 * - choose the snapshot whose checked_at is closest to the target age, but only
 *   within +/- 2 hours (the collector runs every 3 hours);
 * - on an exact tie, prefer the snapshot at/after the target, then the later
 *   snapshot;
 * - malformed, future-dated, pre-post, negative-count, and out-of-tolerance
 *   snapshots are ignored.
 */

export type XMetricWindowKey = "i3h" | "i24h" | "i72h";

export const X_METRIC_WINDOW_TARGET_HOURS: Readonly<
  Record<XMetricWindowKey, number>
> = {
  i3h: 3,
  i24h: 24,
  i72h: 72,
};

export const X_METRIC_WINDOW_MAX_DISTANCE_HOURS = 2;

export const X_METRIC_WINDOW_SELECTION_RULE =
  "lead only; nearest snapshot within +/-2h of each post-age target; " +
  "ties prefer at/after target; unreached or invalid windows are null";

export const X_METRIC_COMPARISON_MIN_SAMPLES = 3;

export const X_METRIC_LEARNING_SELECTION_RULE =
  "use one shared window with at least 3 valid posts; priority I24h, then " +
  "I72h, then I3h; otherwise fall back to latest cumulative metrics";

const HOUR_MS = 3_600_000;
const FUTURE_CLOCK_SKEW_MS = 5 * 60_000;
const WINDOW_KEYS: readonly XMetricWindowKey[] = ["i3h", "i24h", "i72h"];

export interface XMetricSourceRow {
  id?: unknown;
  metadata?: unknown;
  created_at?: unknown;
}

export interface XMetricWindowSample {
  sourceSnapshotId: string;
  checkedAt: string;
  postAgeHours: number;
  distanceMinutes: number;
  impressions: number;
  engagements: number | null;
  likeCount: number | null;
  replyCount: number | null;
  repostCount: number | null;
  quoteCount: number | null;
  bookmarkCount: number | null;
  urlClicks: number | null;
  profileClicks: number | null;
  engagementRate: number | null;
  bookmarkRate: number | null;
  profileClickRate: number | null;
  urlClickRate: number | null;
}

export interface NormalizedXPostMetrics {
  sourceLogId: string;
  tweetId: string;
  postedAt: string | null;
  postAgeHours: number | null;
  i3h: number | null;
  i24h: number | null;
  i72h: number | null;
  windows: Record<XMetricWindowKey, XMetricWindowSample | null>;
}

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function cleanString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function firstValidDateMs(...values: unknown[]): number | null {
  for (const value of values) {
    if (typeof value !== "string" || value.trim() === "") continue;
    const parsed = Date.parse(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function count(value: unknown): number | null {
  if (typeof value === "string" && value.trim() === "") return null;
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isSafeInteger(parsed) && parsed >= 0 ? parsed : null;
}

function rate(numerator: number | null, impressions: number): number | null {
  if (numerator === null || impressions <= 0) return null;
  return numerator / impressions;
}

function emptyWindows(): Record<XMetricWindowKey, XMetricWindowSample | null> {
  return { i3h: null, i24h: null, i72h: null };
}

type Candidate = {
  sourceSnapshotId: string;
  checkedMs: number;
  postAgeMs: number;
  impressions: number;
  engagements: number | null;
  likeCount: number | null;
  replyCount: number | null;
  repostCount: number | null;
  quoteCount: number | null;
  bookmarkCount: number | null;
  urlClicks: number | null;
  profileClicks: number | null;
};

function candidateForLog(
  snapshot: XMetricSourceRow,
  sourceLogId: string,
  tweetId: string,
  postedMs: number,
  nowMs: number,
): Candidate | null {
  const metadata = asRecord(snapshot.metadata);
  if (cleanString(metadata.tweet_role) !== "lead") return null;

  const snapshotLogId = cleanString(metadata.source_log_id);
  const snapshotTweetId = cleanString(metadata.tweet_id);
  const matchesByLogId = snapshotLogId !== "" && snapshotLogId === sourceLogId;
  const matchesLegacyTweetId = snapshotLogId === "" && tweetId !== "" &&
    snapshotTweetId === tweetId;
  if (!matchesByLogId && !matchesLegacyTweetId) return null;
  if (
    matchesByLogId && tweetId !== "" && snapshotTweetId !== "" &&
    snapshotTweetId !== tweetId
  ) {
    return null;
  }

  const checkedMs = firstValidDateMs(metadata.checked_at, snapshot.created_at);
  const impressions = count(metadata.impressions);
  if (checkedMs === null || impressions === null) return null;
  if (checkedMs < postedMs || checkedMs > nowMs + FUTURE_CLOCK_SKEW_MS) {
    return null;
  }

  return {
    sourceSnapshotId: cleanString(snapshot.id),
    checkedMs,
    postAgeMs: checkedMs - postedMs,
    impressions,
    engagements: count(metadata.engagements),
    likeCount: count(metadata.like_count),
    replyCount: count(metadata.reply_count),
    repostCount: count(metadata.repost_count),
    quoteCount: count(metadata.quote_count),
    bookmarkCount: count(metadata.bookmark_count),
    urlClicks: count(metadata.url_clicks),
    profileClicks: count(metadata.profile_clicks),
  };
}

function chooseSample(
  candidates: readonly Candidate[],
  targetHours: number,
): XMetricWindowSample | null {
  const targetMs = targetHours * HOUR_MS;
  const maxDistanceMs = X_METRIC_WINDOW_MAX_DISTANCE_HOURS * HOUR_MS;
  const eligible = candidates
    .map((candidate) => ({
      candidate,
      distanceMs: Math.abs(candidate.postAgeMs - targetMs),
      isBeforeTarget: candidate.postAgeMs < targetMs,
    }))
    .filter(({ distanceMs }) => distanceMs <= maxDistanceMs)
    .sort((left, right) =>
      left.distanceMs - right.distanceMs ||
      Number(left.isBeforeTarget) - Number(right.isBeforeTarget) ||
      right.candidate.checkedMs - left.candidate.checkedMs ||
      left.candidate.sourceSnapshotId.localeCompare(
        right.candidate.sourceSnapshotId,
      )
    );
  const selected = eligible[0];
  if (!selected) return null;

  const value = selected.candidate;
  return {
    sourceSnapshotId: value.sourceSnapshotId,
    checkedAt: new Date(value.checkedMs).toISOString(),
    postAgeHours: Number((value.postAgeMs / HOUR_MS).toFixed(3)),
    distanceMinutes: Number((selected.distanceMs / 60_000).toFixed(1)),
    impressions: value.impressions,
    engagements: value.engagements,
    likeCount: value.likeCount,
    replyCount: value.replyCount,
    repostCount: value.repostCount,
    quoteCount: value.quoteCount,
    bookmarkCount: value.bookmarkCount,
    urlClicks: value.urlClicks,
    profileClicks: value.profileClicks,
    engagementRate: rate(value.engagements, value.impressions),
    bookmarkRate: rate(value.bookmarkCount, value.impressions),
    profileClickRate: rate(value.profileClicks, value.impressions),
    urlClickRate: rate(value.urlClicks, value.impressions),
  };
}

/** Returns one row per post log, including all-null windows for invalid logs. */
export function normalizeXMetricWindows(
  logs: readonly XMetricSourceRow[],
  snapshots: readonly XMetricSourceRow[],
  nowMs: number,
): NormalizedXPostMetrics[] {
  const validNow = Number.isFinite(nowMs);
  return logs.map((log) => {
    const metadata = asRecord(log.metadata);
    const sourceLogId = cleanString(log.id);
    const tweetId = cleanString(metadata.tweet_id);
    const postedMs = firstValidDateMs(metadata.posted_at, log.created_at);
    const windows = emptyWindows();
    if (
      !validNow || sourceLogId === "" || postedMs === null ||
      postedMs > nowMs + FUTURE_CLOCK_SKEW_MS
    ) {
      return {
        sourceLogId,
        tweetId,
        postedAt: postedMs === null ? null : new Date(postedMs).toISOString(),
        postAgeHours: null,
        i3h: null,
        i24h: null,
        i72h: null,
        windows,
      };
    }

    const candidates = snapshots
      .map((snapshot) =>
        candidateForLog(
          snapshot,
          sourceLogId,
          tweetId,
          postedMs,
          nowMs,
        )
      )
      .filter((candidate): candidate is Candidate => candidate !== null);
    const postAgeMs = Math.max(0, nowMs - postedMs);
    for (const key of WINDOW_KEYS) {
      const targetHours = X_METRIC_WINDOW_TARGET_HOURS[key];
      if (postAgeMs < targetHours * HOUR_MS) continue;
      windows[key] = chooseSample(candidates, targetHours);
    }

    return {
      sourceLogId,
      tweetId,
      postedAt: new Date(postedMs).toISOString(),
      postAgeHours: Number((postAgeMs / HOUR_MS).toFixed(3)),
      i3h: windows.i3h?.impressions ?? null,
      i24h: windows.i24h?.impressions ?? null,
      i72h: windows.i72h?.impressions ?? null,
      windows,
    };
  });
}

/**
 * Picks one common comparison cohort for learning. A shared window avoids
 * ranking a 72-hour cumulative value against a 3-hour cumulative value.
 */
export function selectXMetricComparisonWindow(
  rows: readonly NormalizedXPostMetrics[],
  minimumSamples = X_METRIC_COMPARISON_MIN_SAMPLES,
): XMetricWindowKey | null {
  const required = Number.isFinite(minimumSamples)
    ? Math.max(1, Math.trunc(minimumSamples))
    : X_METRIC_COMPARISON_MIN_SAMPLES;
  const priority: readonly XMetricWindowKey[] = ["i24h", "i72h", "i3h"];
  for (const key of priority) {
    if (rows.filter((row) => row[key] !== null).length >= required) return key;
  }
  return null;
}

export function metricWindowLabel(key: XMetricWindowKey): string {
  return key === "i3h" ? "I3h" : key === "i24h" ? "I24h" : "I72h";
}
