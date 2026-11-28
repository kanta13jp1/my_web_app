// Issue #4026: 立憲民主党 地方議員トラッカー MVP (docs/X_TRACKER_SERIES_PLAYBOOK.md 準拠)
// scripts/update_cdp_benchmark.mjs が 47 都道府県ページから集計した都道府県別人数を受領し、
// 40 県以上 / 500 人以上のサニティチェックを通過したスナップショットのみを永続化する。
// 数値・在籍県の差分発生時のみ HITL 候補キュー (pending_approval) へ data_report 候補を生成する。

import { buildXPostCandidateMetadata } from "../growth-hub/x_post_candidate.ts";
import { PREFECTURES } from "./official_site_parsers.ts";
import {
  type HubDataRow,
  type JsonRecord,
  type LocalElectionHubStore,
  stableStringify,
} from "./snapshot_history.ts";

export const CDP_MEMBER_PAGE_URL = "https://cdp-japan.jp/members/prefecture/";
export const CDP_DATASET = "cdp_local_members";
export const CDP_DATASET_SOURCE = "local-election-intelligence";
export const CDP_TRACKER_VARIANT = "cdp_member_tracker";
export const CDP_SNAPSHOT_SCHEMA_VERSION = 1;
export const CDP_MIN_PREFECTURES = 40;
export const CDP_MIN_TOTAL_MEMBERS = 500;

export interface CdpPrefectureTally {
  prefecture: string;
  count: number;
}

export interface CdpMemberSnapshot {
  sourceUrl: string;
  totalLocalMembers: number;
  reportedPrefectureCount: number;
  activePrefectureCount: number;
  prefectures: CdpPrefectureTally[];
  missingPrefectures: string[];
}

export interface CdpPrefectureDelta {
  prefecture: string;
  before: number;
  after: number;
  delta: number;
}

export interface CdpSnapshotDiff {
  hasChanges: boolean;
  totalLocalMembersDelta: number;
  activePrefectureDelta: number;
  reportedPrefectureDelta: number;
  prefectureDeltas: CdpPrefectureDelta[];
  newlyFilledPrefectures: string[];
  newlyBlankPrefectures: string[];
}

export interface PersistCdpSnapshotResult {
  dataset: string;
  datasetVersion: string;
  snapshotHash: string;
  previousSnapshotId: string | null;
  previousSnapshotHash: string | null;
  baselineCreated: boolean;
  snapshotCreated: boolean;
  deduplicated: boolean;
  hasChanges: boolean;
  candidateCount: number;
  candidatesCreated: number;
  snapshotRow: HubDataRow;
  candidateRows: HubDataRow[];
}

const PREFECTURE_ORDER = new Map<string, number>(
  PREFECTURES.map((name, index) => [name, index]),
);

const PREFECTURE_ALIAS_MAP = new Map<string, string>();
for (const prefecture of PREFECTURES) {
  PREFECTURE_ALIAS_MAP.set(prefecture, prefecture);
  const shortName = prefecture === "北海道"
    ? prefecture
    : prefecture.replace(/[都府県]$/u, "");
  PREFECTURE_ALIAS_MAP.set(shortName, prefecture);
}

export function normalizeCdpPrefectureName(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  return PREFECTURE_ALIAS_MAP.get(trimmed) ?? null;
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNonNegativeInt(value: unknown): number | null {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0
    ? value
    : null;
}

export function buildCdpMemberSnapshot(
  rawPayload: unknown,
): CdpMemberSnapshot | null {
  if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
    return null;
  }
  const raw = rawPayload as JsonRecord;
  const rawPrefectures = raw.prefectures;
  if (!rawPrefectures || typeof rawPrefectures !== "object") {
    return null;
  }

  const countByPrefecture = new Map<string, number>();
  if (Array.isArray(rawPrefectures)) {
    for (const item of rawPrefectures) {
      if (!item || typeof item !== "object" || Array.isArray(item)) {
        return null;
      }
      const entry = item as JsonRecord;
      if (typeof entry.prefecture !== "string") return null;
      const normalized = normalizeCdpPrefectureName(entry.prefecture);
      const count = asNonNegativeInt(entry.count);
      if (!normalized || count === null || countByPrefecture.has(normalized)) {
        return null;
      }
      countByPrefecture.set(normalized, count);
    }
  } else {
    for (
      const [key, value] of Object.entries(rawPrefectures as JsonRecord)
    ) {
      const normalized = normalizeCdpPrefectureName(key);
      const count = asNonNegativeInt(value);
      if (!normalized || count === null || countByPrefecture.has(normalized)) {
        return null;
      }
      countByPrefecture.set(normalized, count);
    }
  }

  const reportedPrefectureCount = countByPrefecture.size;
  let totalLocalMembers = 0;
  let activePrefectureCount = 0;
  const prefectures: CdpPrefectureTally[] = [];

  for (const [prefecture, count] of countByPrefecture.entries()) {
    totalLocalMembers += count;
    if (count > 0) {
      activePrefectureCount += 1;
    }
    prefectures.push({ prefecture, count });
  }

  if (
    reportedPrefectureCount < CDP_MIN_PREFECTURES ||
    totalLocalMembers < CDP_MIN_TOTAL_MEMBERS
  ) {
    return null;
  }

  prefectures.sort((a, b) =>
    b.count - a.count ||
    (PREFECTURE_ORDER.get(a.prefecture) ?? 999) -
      (PREFECTURE_ORDER.get(b.prefecture) ?? 999)
  );

  const missingPrefectures = PREFECTURES.filter((pref) =>
    (countByPrefecture.get(pref) ?? 0) === 0
  );

  const sourceUrl = asString(raw.sourceUrl) ||
    asString(raw.source) ||
    CDP_MEMBER_PAGE_URL;

  return {
    sourceUrl,
    totalLocalMembers,
    reportedPrefectureCount,
    activePrefectureCount,
    prefectures,
    missingPrefectures,
  };
}

export async function hashCdpSnapshot(
  snapshot: CdpMemberSnapshot,
): Promise<string> {
  // 数値・県別集計のみハッシュ化し、URL 表現差などの非数値ノイズを抑止する。
  const hashInput = {
    schemaVersion: CDP_SNAPSHOT_SCHEMA_VERSION,
    totalLocalMembers: snapshot.totalLocalMembers,
    reportedPrefectureCount: snapshot.reportedPrefectureCount,
    activePrefectureCount: snapshot.activePrefectureCount,
    prefectures: snapshot.prefectures,
    missingPrefectures: snapshot.missingPrefectures,
  };
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(stableStringify(hashInput)),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function formatCount(value: number): string {
  return value.toLocaleString("en-US");
}

function signed(value: number): string {
  return value > 0 ? `+${formatCount(value)}` : formatCount(value);
}

export function computeCdpDiff(
  previous: CdpMemberSnapshot,
  current: CdpMemberSnapshot,
): CdpSnapshotDiff {
  const prevMap = new Map(
    previous.prefectures.map((p) => [p.prefecture, p.count]),
  );
  const currMap = new Map(
    current.prefectures.map((p) => [p.prefecture, p.count]),
  );

  const prefectureDeltas: CdpPrefectureDelta[] = [];
  const newlyFilledPrefectures: string[] = [];
  const newlyBlankPrefectures: string[] = [];

  for (const prefecture of PREFECTURES) {
    const before = prevMap.get(prefecture) ?? 0;
    const after = currMap.get(prefecture) ?? 0;
    const delta = after - before;
    if (delta !== 0) {
      prefectureDeltas.push({ prefecture, before, after, delta });
    }
    if (before === 0 && after > 0) {
      newlyFilledPrefectures.push(prefecture);
    } else if (before > 0 && after === 0) {
      newlyBlankPrefectures.push(prefecture);
    }
  }

  prefectureDeltas.sort((a, b) =>
    Math.abs(b.delta) - Math.abs(a.delta) ||
    (PREFECTURE_ORDER.get(a.prefecture) ?? 999) -
      (PREFECTURE_ORDER.get(b.prefecture) ?? 999)
  );

  const totalLocalMembersDelta = current.totalLocalMembers -
    previous.totalLocalMembers;
  const activePrefectureDelta = current.activePrefectureCount -
    previous.activePrefectureCount;
  const reportedPrefectureDelta = current.reportedPrefectureCount -
    previous.reportedPrefectureCount;

  const hasChanges = totalLocalMembersDelta !== 0 ||
    activePrefectureDelta !== 0 ||
    reportedPrefectureDelta !== 0 ||
    prefectureDeltas.length > 0 ||
    newlyFilledPrefectures.length > 0 ||
    newlyBlankPrefectures.length > 0;

  return {
    hasChanges,
    totalLocalMembersDelta,
    activePrefectureDelta,
    reportedPrefectureDelta,
    prefectureDeltas,
    newlyFilledPrefectures,
    newlyBlankPrefectures,
  };
}

export function buildCdpTrackerCandidateMetadata(
  current: CdpMemberSnapshot,
  previous: CdpMemberSnapshot | null,
  options: {
    snapshotObservationId: string;
    snapshotHash: string;
    previousSnapshotHash: string | null;
    datasetVersion: string;
    observedAt: string;
    targetUrl?: string;
  },
): JsonRecord | null {
  if (!previous || !options.previousSnapshotHash) return null;
  const diff = computeCdpDiff(previous, current);
  if (!diff.hasChanges) return null;

  const prefChangeLines = diff.prefectureDeltas.slice(0, 5).map((d) =>
    `・${d.prefecture}: ${formatCount(d.before)}→${formatCount(d.after)}人 (${signed(d.delta)})`
  );

  const leadLines = [
    "立憲民主党 地方議員データ集計・更新",
    "",
    `取得日時: ${options.observedAt}`,
    `現職自治体議員: ${formatCount(previous.totalLocalMembers)}→${formatCount(current.totalLocalMembers)}人 (${signed(diff.totalLocalMembersDelta)})`,
    `在籍都道府県: ${current.activePrefectureCount}/47県 (${signed(diff.activePrefectureDelta)})・確認県 ${current.reportedPrefectureCount}/47県`,
  ];
  if (prefChangeLines.length > 0) {
    leadLines.push("", "増減のあった都道府県:", ...prefChangeLines);
  }
  leadLines.push(
    "",
    "数字は立憲民主党公式サイト掲載の都道府県別所属議員ページから自動集計した実測値です。",
  );
  const lead = leadLines.join("\n");

  const deltaSectionLines = diff.prefectureDeltas.slice(0, 12).map((d) =>
    `・${d.prefecture}: ${formatCount(d.before)}→${formatCount(d.after)}人 (${signed(d.delta)})`
  );
  if (diff.prefectureDeltas.length > 12) {
    deltaSectionLines.push(`…ほか ${diff.prefectureDeltas.length - 12}件`);
  }

  const topPrefs = current.prefectures.slice(0, 10).map((p, idx) =>
    `${idx + 1}. ${p.prefecture}: ${formatCount(p.count)}人`
  );

  const reply1Parts: string[] = [
    "立憲民主党 地方議員 都道府県別内訳",
  ];
  if (diff.newlyFilledPrefectures.length > 0) {
    reply1Parts.push(
      `新規確認県 (${diff.newlyFilledPrefectures.length}): ${diff.newlyFilledPrefectures.join("・")}`,
    );
  }
  if (diff.newlyBlankPrefectures.length > 0) {
    reply1Parts.push(
      `確認外となった県 (${diff.newlyBlankPrefectures.length}): ${diff.newlyBlankPrefectures.join("・")}`,
    );
  }
  if (deltaSectionLines.length > 0) {
    reply1Parts.push(["主要増減都道府県:", ...deltaSectionLines].join("\n"));
  }
  reply1Parts.push(["議員数上位都道府県:", ...topPrefs].join("\n"));
  const reply1 = reply1Parts.join("\n\n");

  const targetUrl = options.targetUrl ??
    "https://my-web-app-b67f4.web.app/local-election-700?utm_source=x&utm_medium=data_report&utm_campaign=first_user_growth&utm_content=cdp_member_tracker";
  const reply2 = [
    "立憲民主党公式サイト（都道府県別所属議員一覧）の定点観測レポートです。",
    `公式出典: ${current.sourceUrl}`,
    `ダッシュボード: ${targetUrl}`,
  ].join("\n");

  const common = buildXPostCandidateMetadata({
    action: "x.post",
    text: lead,
    replyTexts: [reply1, reply2],
    source: CDP_DATASET_SOURCE,
    route: "local-election-intelligence.cdpMemberTracker",
    variant: CDP_TRACKER_VARIANT,
    contentKind: CDP_TRACKER_VARIANT,
    contentArchetype: "data_report",
    linkInReply: true,
    ownerUserId: "service_role",
  }, {
    candidateKey: `cdp-member-tracker:${
      options.previousSnapshotHash.slice(0, 12)
    }:${options.snapshotHash.slice(0, 12)}`,
    candidateType: CDP_TRACKER_VARIANT,
    sourceKind: "cdp_member_snapshot",
    sourceUrls: [current.sourceUrl],
    createdBy: CDP_DATASET_SOURCE,
    now: new Date(options.observedAt),
  });

  return {
    ...common,
    dataset: CDP_DATASET,
    dataset_source: CDP_DATASET_SOURCE,
    dataset_version: options.datasetVersion,
    snapshot_observation_id: options.snapshotObservationId,
    dataset_snapshot_hash: options.snapshotHash,
    observed_at: options.observedAt,
    requires_human_approval: true,
    auto_publish: false,
    user_id: "service_role",
    cdp_summary: {
      total_local_members: current.totalLocalMembers,
      reported_prefecture_count: current.reportedPrefectureCount,
      active_prefecture_count: current.activePrefectureCount,
      total_local_members_delta: diff.totalLocalMembersDelta,
    },
  };
}

export function parseCdpSnapshotRecord(
  value: unknown,
): CdpMemberSnapshot | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const r = value as JsonRecord;
  const totalLocalMembers = asNonNegativeInt(r.totalLocalMembers);
  const reportedPrefectureCount = asNonNegativeInt(r.reportedPrefectureCount);
  const activePrefectureCount = asNonNegativeInt(r.activePrefectureCount);
  if (
    typeof r.sourceUrl !== "string" ||
    totalLocalMembers === null ||
    reportedPrefectureCount === null ||
    activePrefectureCount === null ||
    !Array.isArray(r.prefectures) ||
    !Array.isArray(r.missingPrefectures)
  ) {
    return null;
  }

  const normalized = buildCdpMemberSnapshot({
    sourceUrl: r.sourceUrl,
    prefectures: r.prefectures,
  });
  if (!normalized) return null;
  if (
    normalized.totalLocalMembers !== totalLocalMembers ||
    normalized.reportedPrefectureCount !== reportedPrefectureCount ||
    normalized.activePrefectureCount !== activePrefectureCount
  ) {
    return null;
  }
  return normalized;
}

export async function persistCdpSnapshot(
  store: LocalElectionHubStore,
  snapshot: CdpMemberSnapshot,
  observedAt = new Date().toISOString(),
): Promise<PersistCdpSnapshotResult> {
  const snapshotHash = await hashCdpSnapshot(snapshot);
  const datasetVersion = `v${CDP_SNAPSHOT_SCHEMA_VERSION}-${
    snapshotHash.slice(0, 16)
  }`;
  const latestRow = await store.getLatestSnapshot(CDP_DATASET);
  const isConsecutiveRetry = latestRow != null &&
    asString(latestRow.metadata.snapshot_hash) === snapshotHash;

  let snapshotRow: HubDataRow;
  let snapshotCreated = false;
  let previousSnapshotId: string | null = null;
  let previousSnapshotHash: string | null = null;
  let previousRow: HubDataRow | null = null;

  if (isConsecutiveRetry && latestRow) {
    snapshotRow = latestRow;
    previousSnapshotId = asString(snapshotRow.metadata.previous_snapshot_id) ||
      null;
    previousSnapshotHash =
      asString(snapshotRow.metadata.previous_snapshot_hash) || null;
    if (previousSnapshotId) {
      previousRow = await store.findSnapshotById(previousSnapshotId);
    }
  } else {
    previousRow = latestRow;
    previousSnapshotId = previousRow?.id ?? null;
    previousSnapshotHash = previousRow
      ? asString(previousRow.metadata.snapshot_hash) || null
      : null;
    const insertion = await store.insertSnapshot({
      record_type: "dataset_snapshot",
      dataset: CDP_DATASET,
      dataset_source: CDP_DATASET_SOURCE,
      dataset_version: datasetVersion,
      dataset_schema_version: CDP_SNAPSHOT_SCHEMA_VERSION,
      snapshot_hash: snapshotHash,
      previous_snapshot_id: previousSnapshotId,
      previous_snapshot_hash: previousSnapshotHash,
      observed_at: observedAt,
      snapshot,
      is_baseline: previousRow === null,
      created_by: CDP_DATASET_SOURCE,
      user_id: "service_role",
    });
    snapshotRow = insertion.row;
    snapshotCreated = insertion.created;
    previousSnapshotId = asString(snapshotRow.metadata.previous_snapshot_id) ||
      null;
    previousSnapshotHash =
      asString(snapshotRow.metadata.previous_snapshot_hash) || null;
    if (
      previousSnapshotId &&
      (!previousRow || previousRow.id !== previousSnapshotId)
    ) {
      previousRow = await store.findSnapshotById(previousSnapshotId);
    } else if (!previousSnapshotId) {
      previousRow = null;
    }
  }

  const previousSnapshot = previousRow
    ? parseCdpSnapshotRecord(previousRow.metadata.snapshot)
    : null;
  if (!previousSnapshot || !previousSnapshotId || !previousSnapshotHash) {
    return {
      dataset: CDP_DATASET,
      datasetVersion,
      snapshotHash,
      previousSnapshotId: null,
      previousSnapshotHash: null,
      baselineCreated: snapshotCreated && previousSnapshotId === null,
      snapshotCreated,
      deduplicated: !snapshotCreated,
      hasChanges: false,
      candidateCount: 0,
      candidatesCreated: 0,
      snapshotRow,
      candidateRows: [],
    };
  }

  const diff = computeCdpDiff(previousSnapshot, snapshot);
  const candidateMetadata = buildCdpTrackerCandidateMetadata(
    snapshot,
    previousSnapshot,
    {
      snapshotObservationId: snapshotRow.id,
      snapshotHash,
      previousSnapshotHash,
      datasetVersion,
      observedAt: asString(snapshotRow.metadata.observed_at) || observedAt,
    },
  );
  if (!candidateMetadata) {
    return {
      dataset: CDP_DATASET,
      datasetVersion,
      snapshotHash,
      previousSnapshotId,
      previousSnapshotHash,
      baselineCreated: false,
      snapshotCreated,
      deduplicated: !snapshotCreated,
      hasChanges: diff.hasChanges,
      candidateCount: 0,
      candidatesCreated: 0,
      snapshotRow,
      candidateRows: [],
    };
  }

  const insertion = await store.insertPostCandidate(candidateMetadata);
  return {
    dataset: CDP_DATASET,
    datasetVersion,
    snapshotHash,
    previousSnapshotId,
    previousSnapshotHash,
    baselineCreated: false,
    snapshotCreated,
    deduplicated: !snapshotCreated,
    hasChanges: diff.hasChanges,
    candidateCount: 1,
    candidatesCreated: insertion.created ? 1 : 0,
    snapshotRow,
    candidateRows: [insertion.row],
  };
}
