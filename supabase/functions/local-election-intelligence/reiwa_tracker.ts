// Issue #4026: れいわ新選組 地方議員トラッカー MVP (docs/X_TRACKER_SERIES_PLAYBOOK.md 準拠)
// 公式ページ https://reiwa-shinsengumi.com/member/ (単一静的 HTML) から
// 現職自治体議員・公認候補予定者・衆参国会議員数を決定的に抽出し、
// 差分発生時のみ HITL 候補キュー (pending_approval) へ data_report 候補を生成する。

import { buildXPostCandidateMetadata } from "../growth-hub/x_post_candidate.ts";
import {
  decodeHtml,
  stripTags,
  toAsciiDigits,
} from "./official_site_parsers.ts";
import {
  type HubDataRow,
  type JsonRecord,
  type LocalElectionHubStore,
  stableStringify,
} from "./snapshot_history.ts";

export const REIWA_MEMBER_PAGE_URL = "https://reiwa-shinsengumi.com/member/";
export const REIWA_DATASET = "reiwa_local_members";
export const REIWA_DATASET_SOURCE = "local-election-intelligence";
export const REIWA_TRACKER_VARIANT = "reiwa_member_tracker";
export const REIWA_SNAPSHOT_SCHEMA_VERSION = 1;
export const REIWA_MINIMUM_EXPECTED_LOCAL_MEMBERS = 20;

export interface ReiwaLocalMemberRecord {
  profileUrl: string;
  slug: string;
  prefecture: string;
  block: string;
  assemblyLabel: string;
}

export interface ReiwaScheduledCandidateRecord {
  profileUrl: string;
  slug: string;
  caption: string;
}

export interface ReiwaPrefectureTally {
  prefecture: string;
  count: number;
}

export interface ReiwaBlockTally {
  block: string;
  count: number;
}

export interface ReiwaMemberSnapshot {
  sourceUrl: string;
  localMembers: number;
  scheduledCandidates: number;
  houseOfRepresentatives: number;
  houseOfCouncillors: number;
  activePrefectureCount: number;
  blocks: ReiwaBlockTally[];
  prefectures: ReiwaPrefectureTally[];
  members: ReiwaLocalMemberRecord[];
  candidates: ReiwaScheduledCandidateRecord[];
}

export interface ReiwaPrefectureDelta {
  prefecture: string;
  before: number;
  after: number;
  delta: number;
}

export interface ReiwaSnapshotDiff {
  hasChanges: boolean;
  localMembersDelta: number;
  scheduledCandidatesDelta: number;
  activePrefectureDelta: number;
  prefectureDeltas: ReiwaPrefectureDelta[];
  addedMembers: ReiwaLocalMemberRecord[];
  removedMembers: ReiwaLocalMemberRecord[];
  addedCandidates: ReiwaScheduledCandidateRecord[];
  removedCandidates: ReiwaScheduledCandidateRecord[];
}

export interface PersistReiwaSnapshotResult {
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

function normalizeText(rawHtml: string): string {
  return toAsciiDigits(decodeHtml(stripTags(rawHtml)))
    .replace(/[\s\u3000]+/g, " ")
    .trim();
}

export function normalizeReiwaProfileUrl(rawHref: string): string {
  const trimmed = decodeHtml(rawHref).trim();
  if (!trimmed) return "";
  let resolved = trimmed;
  if (trimmed.startsWith("/")) {
    resolved = `https://reiwa-shinsengumi.com${trimmed}`;
  } else if (!/^https?:\/\//i.test(trimmed)) {
    resolved = `https://reiwa-shinsengumi.com/${trimmed}`;
  }
  return resolved.split("#")[0].split("?")[0];
}

export function extractReiwaProfileSlug(profileUrl: string): string {
  try {
    const url = new URL(profileUrl);
    const segments = url.pathname.split("/").filter(Boolean);
    if (segments.length > 0) {
      return segments[segments.length - 1];
    }
    return url.hostname;
  } catch {
    return profileUrl.replace(/[^A-Za-z0-9._-]+/g, "_");
  }
}

function resolvePrefectureFromContext(
  caption: string,
  currentPref: string,
  currentBlock: string,
): string {
  const capMatch = caption.match(
    /^(北海道|東京都|京都府|大阪府|[^\s・]{2,3}県)/,
  );
  if (capMatch) {
    return capMatch[1];
  }
  if (currentPref) {
    return currentPref === "東京" ? "東京都" : currentPref;
  }
  if (currentBlock === "東京") return "東京都";
  if (currentBlock === "北海道") return "北海道";
  return "";
}

function parseScheduledCandidateSlice(
  candidateHtml: string,
): ReiwaScheduledCandidateRecord[] {
  const seen = new Set<string>();
  const records: ReiwaScheduledCandidateRecord[] = [];
  const figRe = /<figure\b[^>]*>([\s\S]*?)<\/figure>/gi;
  for (const match of candidateHtml.matchAll(figRe)) {
    const inner = match[1] ?? "";
    const hrefMatch = inner.match(/href=["']([^"']+)["']/i);
    const profileUrl = normalizeReiwaProfileUrl(hrefMatch?.[1] ?? "");
    if (!profileUrl || seen.has(profileUrl)) continue;
    seen.add(profileUrl);
    const capMatch = inner.match(/<figcaption\b[^>]*>([\s\S]*?)<\/figcaption>/i);
    const caption = normalizeText(capMatch?.[1] ?? "");
    records.push({
      profileUrl,
      slug: extractReiwaProfileSlug(profileUrl),
      caption,
    });
  }
  records.sort((a, b) => a.profileUrl.localeCompare(b.profileUrl));
  return records;
}

export function parseReiwaMemberPageHtml(
  html: string,
  sourceUrl = REIWA_MEMBER_PAGE_URL,
  options: { minimumExpectedLocalMembers?: number } = {},
): ReiwaMemberSnapshot | null {
  const h2Matches: Array<{ start: number; end: number; title: string }> = [];
  const h2Re = /<h2\b[^>]*>([\s\S]*?)<\/h2>/gi;
  for (const m of html.matchAll(h2Re)) {
    const start = m.index ?? -1;
    if (start < 0) continue;
    h2Matches.push({
      start,
      end: start + m[0].length,
      title: normalizeText(m[1] ?? ""),
    });
  }

  const shugiinH2 = h2Matches.find((h) => h.title === "衆議院議員");
  const sangiinH2 = h2Matches.find((h) => h.title === "参議院議員");
  const localH2 = h2Matches.find((h) => h.title.includes("れいわの自治体議員"));
  const candH2 = h2Matches.find((h) => h.title.includes("自治体議員選挙"));
  if (!localH2 || !candH2 || candH2.start <= localH2.end) {
    return null;
  }

  const komonH2 = h2Matches.find((h) =>
    h.start > candH2.end && h.title.includes("顧問")
  );

  let houseOfRepresentatives = 0;
  if (shugiinH2 && sangiinH2 && sangiinH2.start > shugiinH2.end) {
    const slice = html.slice(shugiinH2.end, sangiinH2.start);
    houseOfRepresentatives = (slice.match(/<figure\b/gi) ?? []).length;
  }

  let houseOfCouncillors = 0;
  if (sangiinH2 && localH2.start > sangiinH2.end) {
    const slice = html.slice(sangiinH2.end, localH2.start);
    houseOfCouncillors = (slice.match(/<figure\b/gi) ?? []).length;
  }

  const localSlice = html.slice(localH2.end, candH2.start);
  const candSlice = html.slice(
    candH2.end,
    komonH2 ? komonH2.start : html.length,
  );

  const tokenRe =
    /(<h2\b[^>]*>[\s\S]*?<\/h2>)|(<p\b[^>]*>\s*<strong\b[^>]*>[\s\S]*?<\/strong>\s*<\/p>)|(<figure\b[^>]*>[\s\S]*?<\/figure>(?:\s*<p\b[^>]*>(?!\s*<strong\b)([\s\S]*?)<\/p>)?)/gi;

  let currentBlock = "";
  let currentPref = "";
  const seenUrls = new Set<string>();
  const members: ReiwaLocalMemberRecord[] = [];
  const blockCounts = new Map<string, number>();
  const blockOrder: string[] = [];
  const prefCounts = new Map<string, number>();

  for (const m of localSlice.matchAll(tokenRe)) {
    const h2Tok = m[1];
    const prefTok = m[2];
    const figTok = m[3];
    const siblingParagraph = m[4] ?? "";

    if (h2Tok) {
      const heading = normalizeText(h2Tok);
      if (heading && !heading.includes("れいわの自治体議員")) {
        currentBlock = heading;
        currentPref = "";
        if (!blockCounts.has(currentBlock)) {
          blockOrder.push(currentBlock);
          blockCounts.set(currentBlock, 0);
        }
      }
      continue;
    }

    if (prefTok) {
      currentPref = normalizeText(prefTok);
      continue;
    }

    if (figTok) {
      const hrefMatch = figTok.match(/href=["']([^"']+)["']/i);
      const profileUrl = normalizeReiwaProfileUrl(hrefMatch?.[1] ?? "");
      if (!profileUrl || seenUrls.has(profileUrl)) continue;
      seenUrls.add(profileUrl);

      const capMatch = figTok.match(
        /<figcaption\b[^>]*>([\s\S]*?)<\/figcaption>/i,
      );
      const figCaption = normalizeText(capMatch?.[1] ?? "");
      const assemblyLabel = figCaption || normalizeText(siblingParagraph);
      const prefecture = resolvePrefectureFromContext(
        assemblyLabel,
        currentPref,
        currentBlock,
      );
      if (!prefecture || !currentBlock) {
        return null;
      }

      members.push({
        profileUrl,
        slug: extractReiwaProfileSlug(profileUrl),
        prefecture,
        block: currentBlock,
        assemblyLabel,
      });
      blockCounts.set(currentBlock, (blockCounts.get(currentBlock) ?? 0) + 1);
      prefCounts.set(prefecture, (prefCounts.get(prefecture) ?? 0) + 1);
    }
  }

  const minLocal = options.minimumExpectedLocalMembers ??
    REIWA_MINIMUM_EXPECTED_LOCAL_MEMBERS;
  if (members.length < minLocal) {
    return null;
  }

  members.sort((a, b) => a.profileUrl.localeCompare(b.profileUrl));
  const candidates = parseScheduledCandidateSlice(candSlice);
  const blocks: ReiwaBlockTally[] = blockOrder.map((block) => ({
    block,
    count: blockCounts.get(block) ?? 0,
  }));
  const prefectures: ReiwaPrefectureTally[] = Array.from(prefCounts.entries())
    .map(([prefecture, count]) => ({ prefecture, count }))
    .sort((a, b) =>
      b.count - a.count || a.prefecture.localeCompare(b.prefecture, "ja")
    );

  return {
    sourceUrl,
    localMembers: members.length,
    scheduledCandidates: candidates.length,
    houseOfRepresentatives,
    houseOfCouncillors,
    activePrefectureCount: prefectures.length,
    blocks,
    prefectures,
    members,
    candidates,
  };
}

export async function hashReiwaSnapshot(
  snapshot: ReiwaMemberSnapshot,
): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(stableStringify(snapshot)),
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

export function computeReiwaDiff(
  previous: ReiwaMemberSnapshot,
  current: ReiwaMemberSnapshot,
): ReiwaSnapshotDiff {
  const prevPrefMap = new Map(
    previous.prefectures.map((p) => [p.prefecture, p.count]),
  );
  const currPrefMap = new Map(
    current.prefectures.map((p) => [p.prefecture, p.count]),
  );
  const allPrefs = Array.from(
    new Set([...prevPrefMap.keys(), ...currPrefMap.keys()]),
  );
  const prefectureDeltas: ReiwaPrefectureDelta[] = allPrefs
    .map((prefecture) => {
      const before = prevPrefMap.get(prefecture) ?? 0;
      const after = currPrefMap.get(prefecture) ?? 0;
      return { prefecture, before, after, delta: after - before };
    })
    .filter((d) => d.delta !== 0)
    .sort((a, b) =>
      Math.abs(b.delta) - Math.abs(a.delta) ||
      a.prefecture.localeCompare(b.prefecture, "ja")
    );

  const prevMemberMap = new Map(
    previous.members.map((m) => [m.profileUrl, m]),
  );
  const currMemberMap = new Map(
    current.members.map((m) => [m.profileUrl, m]),
  );
  const addedMembers = current.members.filter((m) =>
    !prevMemberMap.has(m.profileUrl)
  );
  const removedMembers = previous.members.filter((m) =>
    !currMemberMap.has(m.profileUrl)
  );

  const prevCandMap = new Map(
    previous.candidates.map((c) => [c.profileUrl, c]),
  );
  const currCandMap = new Map(
    current.candidates.map((c) => [c.profileUrl, c]),
  );
  const addedCandidates = current.candidates.filter((c) =>
    !prevCandMap.has(c.profileUrl)
  );
  const removedCandidates = previous.candidates.filter((c) =>
    !currCandMap.has(c.profileUrl)
  );

  const hasChanges = stableStringify(previous) !== stableStringify(current);

  return {
    hasChanges,
    localMembersDelta: current.localMembers - previous.localMembers,
    scheduledCandidatesDelta: current.scheduledCandidates -
      previous.scheduledCandidates,
    activePrefectureDelta: current.activePrefectureCount -
      previous.activePrefectureCount,
    prefectureDeltas,
    addedMembers,
    removedMembers,
    addedCandidates,
    removedCandidates,
  };
}

export function buildReiwaTrackerCandidateMetadata(
  current: ReiwaMemberSnapshot,
  previous: ReiwaMemberSnapshot | null,
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
  const diff = computeReiwaDiff(previous, current);
  if (!diff.hasChanges) return null;

  const prefChangeLines = diff.prefectureDeltas.slice(0, 5).map((d) =>
    `・${d.prefecture}: ${formatCount(d.before)}→${formatCount(d.after)}人 (${signed(d.delta)})`
  );

  const zeroPrefGap = 47 - current.activePrefectureCount;
  const leadLines = [
    "れいわ新選組 地方議員データ集計・更新",
    "",
    `取得日時: ${options.observedAt}`,
    `現職自治体議員: ${formatCount(previous.localMembers)}→${formatCount(current.localMembers)}人 (${signed(diff.localMembersDelta)})`,
    `在籍都道府県: ${current.activePrefectureCount}/47県 (${signed(diff.activePrefectureDelta)})・未進出 ${zeroPrefGap}県`,
    `公認候補予定者: ${formatCount(previous.scheduledCandidates)}→${formatCount(current.scheduledCandidates)}件・国会議員 衆${current.houseOfRepresentatives}/参${current.houseOfCouncillors}`,
  ];
  if (prefChangeLines.length > 0) {
    leadLines.push("", "増減のあった都道府県:", ...prefChangeLines);
  }
  leadLines.push(
    "",
    "数字はれいわ新選組公式サイト掲載の所属一覧から自動集計した実測値です。",
  );
  const lead = leadLines.join("\n");

  const memberLines = (
    title: string,
    items: readonly ReiwaLocalMemberRecord[],
  ): string[] => {
    if (items.length === 0) return [];
    const shown = items.slice(0, 10).map((m) =>
      `・${m.assemblyLabel || m.prefecture} (${m.slug})`
    );
    if (items.length > 10) {
      shown.push(`…ほか ${items.length - 10}人`);
    }
    return [`${title} (${items.length}人):`, ...shown];
  };

  const candLines = (
    title: string,
    items: readonly ReiwaScheduledCandidateRecord[],
  ): string[] => {
    if (items.length === 0) return [];
    return [
      `${title} (${items.length}件):`,
      ...items.slice(0, 5).map((c) => `・${c.caption || c.slug}`),
    ];
  };

  const topPrefs = current.prefectures.slice(0, 8).map((p, idx) =>
    `${idx + 1}. ${p.prefecture}: ${formatCount(p.count)}人`
  );

  const reply1 = [
    "れいわ新選組 自治体議員 異動・都道府県別内訳",
    "",
    ...memberLines("新規掲載", diff.addedMembers),
    ...memberLines("掲載終了", diff.removedMembers),
    ...candLines("公認候補予定者 追加", diff.addedCandidates),
    ...candLines("公認候補予定者 更新・終了", diff.removedCandidates),
    "",
    "議員数上位都道府県:",
    ...topPrefs,
  ].join("\n").replace(/\n{3,}/g, "\n\n");

  const targetUrl = options.targetUrl ??
    "https://my-web-app-b67f4.web.app/local-election-700?utm_source=x&utm_medium=data_report&utm_campaign=first_user_growth&utm_content=reiwa_member_tracker";
  const reply2 = [
    "れいわ新選組公式サイト（所属構成員一覧）の定点観測レポートです。",
    `公式出典: ${current.sourceUrl}`,
    `ダッシュボード: ${targetUrl}`,
  ].join("\n");

  const common = buildXPostCandidateMetadata({
    action: "x.post",
    text: lead,
    replyTexts: [reply1, reply2],
    source: REIWA_DATASET_SOURCE,
    route: "local-election-intelligence.reiwaMemberTracker",
    variant: REIWA_TRACKER_VARIANT,
    contentKind: REIWA_TRACKER_VARIANT,
    contentArchetype: "data_report",
    linkInReply: true,
    ownerUserId: "service_role",
  }, {
    candidateKey: `reiwa-member-tracker:${
      options.previousSnapshotHash.slice(0, 12)
    }:${options.snapshotHash.slice(0, 12)}`,
    candidateType: REIWA_TRACKER_VARIANT,
    sourceKind: "reiwa_member_snapshot",
    sourceUrls: [current.sourceUrl],
    createdBy: REIWA_DATASET_SOURCE,
    now: new Date(options.observedAt),
  });

  return {
    ...common,
    dataset: REIWA_DATASET,
    dataset_source: REIWA_DATASET_SOURCE,
    dataset_version: options.datasetVersion,
    snapshot_observation_id: options.snapshotObservationId,
    dataset_snapshot_hash: options.snapshotHash,
    observed_at: options.observedAt,
    requires_human_approval: true,
    auto_publish: false,
    user_id: "service_role",
    reiwa_summary: {
      local_members: current.localMembers,
      scheduled_candidates: current.scheduledCandidates,
      active_prefecture_count: current.activePrefectureCount,
      local_members_delta: diff.localMembersDelta,
    },
  };
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNonNegativeInt(value: unknown): number | null {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0
    ? value
    : null;
}

function parseReiwaSnapshotRecord(
  value: unknown,
): ReiwaMemberSnapshot | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const r = value as JsonRecord;
  const localMembers = asNonNegativeInt(r.localMembers);
  const scheduledCandidates = asNonNegativeInt(r.scheduledCandidates);
  const houseOfRepresentatives = asNonNegativeInt(r.houseOfRepresentatives);
  const houseOfCouncillors = asNonNegativeInt(r.houseOfCouncillors);
  const activePrefectureCount = asNonNegativeInt(r.activePrefectureCount);
  if (
    typeof r.sourceUrl !== "string" ||
    localMembers === null ||
    scheduledCandidates === null ||
    houseOfRepresentatives === null ||
    houseOfCouncillors === null ||
    activePrefectureCount === null ||
    !Array.isArray(r.blocks) ||
    !Array.isArray(r.prefectures) ||
    !Array.isArray(r.members) ||
    !Array.isArray(r.candidates)
  ) {
    return null;
  }

  const blocks: ReiwaBlockTally[] = [];
  for (const item of r.blocks) {
    if (!item || typeof item !== "object" || Array.isArray(item)) return null;
    const b = item as JsonRecord;
    const count = asNonNegativeInt(b.count);
    if (typeof b.block !== "string" || count === null) return null;
    blocks.push({ block: b.block, count });
  }

  const prefectures: ReiwaPrefectureTally[] = [];
  for (const item of r.prefectures) {
    if (!item || typeof item !== "object" || Array.isArray(item)) return null;
    const p = item as JsonRecord;
    const count = asNonNegativeInt(p.count);
    if (typeof p.prefecture !== "string" || count === null) return null;
    prefectures.push({ prefecture: p.prefecture, count });
  }

  const members: ReiwaLocalMemberRecord[] = [];
  for (const item of r.members) {
    if (!item || typeof item !== "object" || Array.isArray(item)) return null;
    const m = item as JsonRecord;
    if (
      typeof m.profileUrl !== "string" || typeof m.prefecture !== "string" ||
      typeof m.block !== "string"
    ) {
      return null;
    }
    members.push({
      profileUrl: m.profileUrl,
      slug: asString(m.slug),
      prefecture: m.prefecture,
      block: m.block,
      assemblyLabel: asString(m.assemblyLabel),
    });
  }

  const candidates: ReiwaScheduledCandidateRecord[] = [];
  for (const item of r.candidates) {
    if (!item || typeof item !== "object" || Array.isArray(item)) return null;
    const c = item as JsonRecord;
    if (typeof c.profileUrl !== "string") return null;
    candidates.push({
      profileUrl: c.profileUrl,
      slug: asString(c.slug),
      caption: asString(c.caption),
    });
  }

  return {
    sourceUrl: r.sourceUrl,
    localMembers,
    scheduledCandidates,
    houseOfRepresentatives,
    houseOfCouncillors,
    activePrefectureCount,
    blocks,
    prefectures,
    members,
    candidates,
  };
}

export async function persistReiwaSnapshot(
  store: LocalElectionHubStore,
  snapshot: ReiwaMemberSnapshot,
  observedAt = new Date().toISOString(),
): Promise<PersistReiwaSnapshotResult> {
  const snapshotHash = await hashReiwaSnapshot(snapshot);
  const datasetVersion = `v${REIWA_SNAPSHOT_SCHEMA_VERSION}-${
    snapshotHash.slice(0, 16)
  }`;
  const latestRow = await store.getLatestSnapshot(REIWA_DATASET);
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
      dataset: REIWA_DATASET,
      dataset_source: REIWA_DATASET_SOURCE,
      dataset_version: datasetVersion,
      dataset_schema_version: REIWA_SNAPSHOT_SCHEMA_VERSION,
      snapshot_hash: snapshotHash,
      previous_snapshot_id: previousSnapshotId,
      previous_snapshot_hash: previousSnapshotHash,
      observed_at: observedAt,
      snapshot,
      is_baseline: previousRow === null,
      created_by: REIWA_DATASET_SOURCE,
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
    ? parseReiwaSnapshotRecord(previousRow.metadata.snapshot)
    : null;
  if (!previousSnapshot || !previousSnapshotId || !previousSnapshotHash) {
    return {
      dataset: REIWA_DATASET,
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

  const diff = computeReiwaDiff(previousSnapshot, snapshot);
  const candidateMetadata = buildReiwaTrackerCandidateMetadata(
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
      dataset: REIWA_DATASET,
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
    dataset: REIWA_DATASET,
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
