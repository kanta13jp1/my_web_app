export const LOCAL_ELECTION_MEMBER_HISTORY_TABLE =
  "local_election_member_history";
export const LOCAL_ELECTION_MEMBER_HISTORY_MAX_POINTS = 180;

const JST_OFFSET_MS = 9 * 60 * 60 * 1000;

export interface LocalElectionMemberHistoryPoint {
  fetchedAt: string;
  officialCurrentLocalMembers: number;
  actualNetIncreaseRequired: number;
}

export interface LocalElectionMemberHistoryUpsertRow {
  snapshot_date: string;
  fetched_at: string;
  official_current_local_members: number;
  actual_net_increase_required: number;
  source: string;
}

export interface LocalElectionMemberHistoryStore {
  listHistory(limit: number): Promise<LocalElectionMemberHistoryPoint[]>;
  upsertDailyPoint(row: LocalElectionMemberHistoryUpsertRow): Promise<void>;
}

/**
 * Converts an ISO timestamp into its JST (`Asia/Tokyo`, UTC+9) calendar date
 * (`YYYY-MM-DD`). Returns `null` if the input cannot be parsed as a valid date.
 */
export function toJstSnapshotDate(isoTimestamp: string): string | null {
  if (typeof isoTimestamp !== "string" || isoTimestamp.trim() === "") {
    return null;
  }
  const parsedMs = Date.parse(isoTimestamp);
  if (!Number.isFinite(parsedMs)) {
    return null;
  }
  return new Date(parsedMs + JST_OFFSET_MS).toISOString().slice(0, 10);
}

/**
 * Validates and extracts a non-zero history point from a snapshot payload.
 */
export function buildHistoryPointFromSnapshot(snapshot: {
  fetchedAt?: unknown;
  officialCurrentLocalMembers?: unknown;
  actualNetIncreaseRequired?: unknown;
}): LocalElectionMemberHistoryPoint | null {
  const fetchedAt = typeof snapshot.fetchedAt === "string"
    ? snapshot.fetchedAt.trim()
    : "";
  if (!toJstSnapshotDate(fetchedAt)) {
    return null;
  }

  const membersRaw = snapshot.officialCurrentLocalMembers;
  if (
    typeof membersRaw !== "number" ||
    !Number.isInteger(membersRaw) ||
    membersRaw <= 0
  ) {
    return null;
  }

  const netRequiredRaw = snapshot.actualNetIncreaseRequired;
  if (
    typeof netRequiredRaw !== "number" ||
    !Number.isInteger(netRequiredRaw) ||
    netRequiredRaw < 0
  ) {
    return null;
  }

  return {
    fetchedAt,
    officialCurrentLocalMembers: membersRaw,
    actualNetIncreaseRequired: netRequiredRaw,
  };
}

/**
 * Deduplicates points by JST day (retaining the latest `fetchedAt` per day),
 * sorts chronologically ascending, and caps to at most `maxPoints` entries.
 */
export function mergeMemberHistoryPoints(
  points: readonly LocalElectionMemberHistoryPoint[],
  maxPoints = LOCAL_ELECTION_MEMBER_HISTORY_MAX_POINTS,
): LocalElectionMemberHistoryPoint[] {
  const byDay = new Map<string, LocalElectionMemberHistoryPoint>();

  for (const point of points) {
    const valid = buildHistoryPointFromSnapshot(point);
    if (!valid) {
      continue;
    }
    const dayKey = toJstSnapshotDate(valid.fetchedAt);
    if (!dayKey) {
      continue;
    }
    const existing = byDay.get(dayKey);
    if (!existing) {
      byDay.set(dayKey, valid);
      continue;
    }
    if (Date.parse(valid.fetchedAt) >= Date.parse(existing.fetchedAt)) {
      byDay.set(dayKey, valid);
    }
  }

  const sorted = [...byDay.values()].sort((left, right) =>
    Date.parse(left.fetchedAt) - Date.parse(right.fetchedAt)
  );
  if (maxPoints > 0 && sorted.length > maxPoints) {
    return sorted.slice(sorted.length - maxPoints);
  }
  return sorted;
}

/**
 * Persists today's JST point only when authorized (`persistDailyPoint = true`),
 * then loads up to `maxPoints` persisted history points merged with the current
 * snapshot point (failing open if the database is unavailable).
 */
export async function recordAndLoadMemberHistory(options: {
  store: LocalElectionMemberHistoryStore | null;
  snapshot: {
    fetchedAt?: unknown;
    officialCurrentLocalMembers?: unknown;
    actualNetIncreaseRequired?: unknown;
  };
  persistDailyPoint: boolean;
  includeCurrentPoint?: boolean;
  maxPoints?: number;
  source?: string;
}): Promise<LocalElectionMemberHistoryPoint[]> {
  const maxPoints = options.maxPoints ?? LOCAL_ELECTION_MEMBER_HISTORY_MAX_POINTS;
  const includeCurrentPoint = options.includeCurrentPoint ?? true;
  const currentPoint = buildHistoryPointFromSnapshot(options.snapshot);

  if (options.persistDailyPoint && options.store && currentPoint) {
    const snapshotDate = toJstSnapshotDate(currentPoint.fetchedAt);
    if (snapshotDate) {
      try {
        await options.store.upsertDailyPoint({
          snapshot_date: snapshotDate,
          fetched_at: currentPoint.fetchedAt,
          official_current_local_members:
            currentPoint.officialCurrentLocalMembers,
          actual_net_increase_required: currentPoint.actualNetIncreaseRequired,
          source: options.source ?? "local-election-intelligence",
        });
      } catch (error) {
        console.warn(
          "Failed to persist daily local election member history:",
          error,
        );
      }
    }
  }

  let persisted: LocalElectionMemberHistoryPoint[] = [];
  if (options.store) {
    try {
      persisted = await options.store.listHistory(maxPoints);
    } catch (error) {
      console.warn(
        "Failed to load persisted local election member history:",
        error,
      );
      persisted = [];
    }
  }

  return mergeMemberHistoryPoints(
    [
      ...persisted,
      ...(includeCurrentPoint && currentPoint ? [currentPoint] : []),
    ],
    maxPoints,
  );
}
