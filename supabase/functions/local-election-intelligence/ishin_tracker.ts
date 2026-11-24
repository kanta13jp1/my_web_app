// Issue #4026: 日本維新の会 地方議員トラッカー MVP (docs/X_TRACKER_SERIES_PLAYBOOK.md 準拠)
// 公式サイト https://o-ishin.jp/member/ および都道府県別ページ (47県) の静的 HTML から
// 現職地方議員・首長を全量決定的に抽出し（衆参国会議員・選挙区支部長を厳格除外）、
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

export const ISHIN_MEMBER_INDEX_URL = "https://o-ishin.jp/member/";
export const ISHIN_SHUGIIN_URL = "https://o-ishin.jp/member/shugiin/";
export const ISHIN_SANGIIN_URL = "https://o-ishin.jp/member/sangiin/";
export const ISHIN_SIBUCHO_URL = "https://o-ishin.jp/member/sibucho/";
export const ISHIN_DATASET = "ishin_local_members";
export const ISHIN_DATASET_SOURCE = "local-election-intelligence";
export const ISHIN_TRACKER_VARIANT = "ishin_member_tracker";
export const ISHIN_SNAPSHOT_SCHEMA_VERSION = 1;
export const ISHIN_MINIMUM_EXPECTED_PREFECTURES = 47;
export const ISHIN_MINIMUM_EXPECTED_LOCAL_MEMBERS = 400;

export type IshinMemberCategory = "local_assembly" | "governor_mayor";

export interface IshinPrefectureDirectoryEntry {
  prefecture: string;
  sourceUrl: string;
}

export interface IshinMemberRecord {
  detailUrl: string;
  name: string;
  prefecture: string;
  category: IshinMemberCategory;
  roleLabel: string;
  areaLabel: string;
}

export interface IshinPrefecturePageResult {
  prefecture: string;
  sourceUrl: string;
  rawCards: number;
  excludedDietOrBranchCount: number;
  localMembers: IshinMemberRecord[];
}

export interface IshinPrefectureTally {
  prefecture: string;
  sourceUrl: string;
  localAssemblyMembers: number;
  governorsAndMayors: number;
  totalLocalPoliticians: number;
}

export interface IshinMemberSnapshot {
  sourceUrl: string;
  totalRawCards: number;
  excludedDietOrBranchCount: number;
  localAssemblyMembers: number;
  governorsAndMayors: number;
  totalLocalPoliticians: number;
  activePrefectureCount: number;
  blankPrefectures: string[];
  namedRoleCounts: Record<string, number>;
  prefectures: IshinPrefectureTally[];
  members: IshinMemberRecord[];
}

export interface IshinPrefectureDelta {
  prefecture: string;
  before: number;
  after: number;
  delta: number;
}

export interface IshinSnapshotDiff {
  hasChanges: boolean;
  localAssemblyDelta: number;
  governorsAndMayorsDelta: number;
  activePrefectureDelta: number;
  prefectureDeltas: IshinPrefectureDelta[];
  addedMembers: IshinMemberRecord[];
  removedMembers: IshinMemberRecord[];
  addedMayors: IshinMemberRecord[];
  removedMayors: IshinMemberRecord[];
  newlyFilledPrefectures: string[];
  newlyBlankPrefectures: string[];
}

export interface PersistIshinSnapshotResult {
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

export function normalizeIshinDetailUrl(rawHref: string): string {
  const trimmed = decodeHtml(rawHref).trim();
  if (!trimmed) return "";
  let resolved = trimmed;
  if (trimmed.startsWith("/")) {
    resolved = `https://o-ishin.jp${trimmed}`;
  } else if (!/^https?:\/\//i.test(trimmed)) {
    resolved = `https://o-ishin.jp/member/detail/${trimmed}`;
  }
  return resolved.split("#")[0].split("?")[0];
}

export function parseIshinPrefectureDirectory(
  html: string,
): IshinPrefectureDirectoryEntry[] {
  const seen = new Set<string>();
  const entries: IshinPrefectureDirectoryEntry[] = [];
  const optionRe = /<option\b[^>]*value=["']([^"']*)["'][^>]*>([\s\S]*?)<\/option>/gi;
  for (const match of html.matchAll(optionRe)) {
    const rawUrl = decodeHtml(match[1] ?? "").trim();
    const label = normalizeText(match[2] ?? "");
    if (!rawUrl || !label) continue;
    if (rawUrl.includes("99_hirei") || label.includes("比例")) continue;
    if (!/\/member\/\d{2}_[a-z0-9_]+\/?$/i.test(rawUrl)) continue;
    const sourceUrl = rawUrl.startsWith("http")
      ? rawUrl
      : `https://o-ishin.jp${rawUrl}`;
    if (seen.has(label)) continue;
    seen.add(label);
    entries.push({ prefecture: label, sourceUrl });
  }
  if (entries.length !== ISHIN_MINIMUM_EXPECTED_PREFECTURES) {
    return [];
  }
  return entries;
}

export function parseIshinDetailUrls(html: string): Set<string> {
  const urls = new Set<string>();
  const linkRe = /href=["']([^"']*\/member\/detail\/[^"']+)["']/gi;
  for (const match of html.matchAll(linkRe)) {
    const normalized = normalizeIshinDetailUrl(match[1] ?? "");
    if (normalized) {
      urls.add(normalized);
    }
  }
  return urls;
}

export function parseIshinPrefecturePage(
  html: string,
  prefecture: string,
  sourceUrl: string,
  excludedDetailUrls: ReadonlySet<string> = new Set(),
): IshinPrefecturePageResult {
  const sectionMatch = html.match(
    /<h4\b[^>]*class=["'][^"']*h4title[^"']*["'][^>]*>[\s\S]*?<\/h4>\s*<section\b[^>]*class=["'][^"']*search_member01[^"']*["'][^>]*>([\s\S]*?)<\/section>/i,
  );
  const scope = sectionMatch ? sectionMatch[1] : html;
  const cardRe =
    /<div>\s*(?:<img\b[^>]*>\s*)?<dl>([\s\S]*?)<\/dl>\s*<a\b[^>]*href=["']([^"']*\/member\/detail\/[^"']+)["'][^>]*><\/a>\s*<\/div>/gi;
  const liRe = /<li\b[^>]*class=["']([^"']+)["'][^>]*>([\s\S]*?)<\/li>/gi;

  let rawCards = 0;
  let excludedDietOrBranchCount = 0;
  const localMembers: IshinMemberRecord[] = [];
  const seenCardUrls = new Set<string>();

  for (const cardMatch of scope.matchAll(cardRe)) {
    const dlHtml = cardMatch[1] ?? "";
    const detailUrl = normalizeIshinDetailUrl(cardMatch[2] ?? "");
    if (!detailUrl || seenCardUrls.has(detailUrl)) continue;
    seenCardUrls.add(detailUrl);
    rawCards += 1;

    const dtMatch = dlHtml.match(/<dt>([\s\S]*?)<\/dt>/i);
    const dtWithoutReading = (dtMatch?.[1] ?? "").replace(
      /<span\b[^>]*>[\s\S]*?<\/span>/gi,
      "",
    );
    const name = normalizeText(dtWithoutReading);

    const label01: string[] = [];
    const label02: string[] = [];
    const label03: string[] = [];
    const label04: string[] = [];
    const blockLabels: string[] = [];

    for (const liMatch of dlHtml.matchAll(liRe)) {
      const cls = (liMatch[1] ?? "").trim();
      const val = normalizeText(liMatch[2] ?? "");
      if (!val) continue;
      if (cls === "member_label01") label01.push(val);
      else if (cls === "member_label02") label02.push(val);
      else if (cls === "member_label03") label03.push(val);
      else if (cls === "member_label04") label04.push(val);
      else if (cls === "block") blockLabels.push(val);
    }

    const isDiet = excludedDetailUrls.has(detailUrl) ||
      label02.length > 0 ||
      label03.length > 0;
    const isBranchLeader = blockLabels.some((item) => item.includes("支部長"));
    if (isDiet || isBranchLeader) {
      excludedDietOrBranchCount += 1;
      continue;
    }

    if (!name) continue;

    const isMayor = label01.some((item) => item.includes("首長"));
    const category: IshinMemberCategory = isMayor
      ? "governor_mayor"
      : "local_assembly";
    const roleLabel = isMayor ? "首長" : (label01[0] ?? "地方議員");
    const areaLabel = label04[0] ?? "";

    localMembers.push({
      detailUrl,
      name,
      prefecture,
      category,
      roleLabel,
      areaLabel,
    });
  }

  return {
    prefecture,
    sourceUrl,
    rawCards,
    excludedDietOrBranchCount,
    localMembers,
  };
}

export function buildIshinMemberSnapshot(
  prefectureResults: readonly IshinPrefecturePageResult[],
  sourceUrl = ISHIN_MEMBER_INDEX_URL,
  options: { minimumExpectedLocalMembers?: number } = {},
): IshinMemberSnapshot | null {
  if (prefectureResults.length !== ISHIN_MINIMUM_EXPECTED_PREFECTURES) {
    return null;
  }

  const seenPrefectures = new Set<string>();
  const seenMembers = new Set<string>();
  const allMembers: IshinMemberRecord[] = [];
  const tallies: IshinPrefectureTally[] = [];
  const blankPrefectures: string[] = [];
  const roleCountMap = new Map<string, number>();

  let totalRawCards = 0;
  let excludedDietOrBranchCount = 0;
  let localAssemblyMembers = 0;
  let governorsAndMayors = 0;
  let activePrefectureCount = 0;

  for (const page of prefectureResults) {
    if (seenPrefectures.has(page.prefecture)) return null;
    seenPrefectures.add(page.prefecture);
    totalRawCards += page.rawCards;
    excludedDietOrBranchCount += page.excludedDietOrBranchCount;

    let prefLocal = 0;
    let prefMayors = 0;
    for (const member of page.localMembers) {
      if (seenMembers.has(member.detailUrl)) continue;
      seenMembers.add(member.detailUrl);
      allMembers.push(member);
      if (member.category === "governor_mayor") {
        prefMayors += 1;
        governorsAndMayors += 1;
      } else {
        prefLocal += 1;
        localAssemblyMembers += 1;
      }
      roleCountMap.set(
        member.roleLabel,
        (roleCountMap.get(member.roleLabel) ?? 0) + 1,
      );
    }

    if (prefLocal > 0) {
      activePrefectureCount += 1;
    } else {
      blankPrefectures.push(page.prefecture);
    }

    tallies.push({
      prefecture: page.prefecture,
      sourceUrl: page.sourceUrl,
      localAssemblyMembers: prefLocal,
      governorsAndMayors: prefMayors,
      totalLocalPoliticians: prefLocal + prefMayors,
    });
  }

  const minLocal = options.minimumExpectedLocalMembers ??
    ISHIN_MINIMUM_EXPECTED_LOCAL_MEMBERS;
  if (localAssemblyMembers < minLocal) {
    return null;
  }

  allMembers.sort((a, b) => a.detailUrl.localeCompare(b.detailUrl));
  const namedRoleCounts: Record<string, number> = {};
  for (const key of Array.from(roleCountMap.keys()).sort()) {
    namedRoleCounts[key] = roleCountMap.get(key) ?? 0;
  }

  return {
    sourceUrl,
    totalRawCards,
    excludedDietOrBranchCount,
    localAssemblyMembers,
    governorsAndMayors,
    totalLocalPoliticians: localAssemblyMembers + governorsAndMayors,
    activePrefectureCount,
    blankPrefectures,
    namedRoleCounts,
    prefectures: tallies,
    members: allMembers,
  };
}

async function mapWithConcurrency<T, R>(
  items: readonly T[],
  limit: number,
  worker: (item: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let nextIndex = 0;
  async function runWorker(): Promise<void> {
    while (nextIndex < items.length) {
      const idx = nextIndex;
      nextIndex += 1;
      results[idx] = await worker(items[idx]);
    }
  }
  const workerCount = Math.max(1, Math.min(limit, items.length));
  await Promise.all(Array.from({ length: workerCount }, () => runWorker()));
  return results;
}

export async function fetchIshinMemberSnapshot(
  fetchTextFn: (url: string) => Promise<string>,
): Promise<IshinMemberSnapshot> {
  const indexHtml = await fetchTextFn(ISHIN_MEMBER_INDEX_URL);
  const directory = parseIshinPrefectureDirectory(indexHtml);
  if (directory.length !== ISHIN_MINIMUM_EXPECTED_PREFECTURES) {
    throw new Error(
      `Ishin prefecture directory invalid (${directory.length} entries).`,
    );
  }

  const [shugiinHtml, sangiinHtml, sibuchoHtml] = await Promise.all([
    fetchTextFn(ISHIN_SHUGIIN_URL),
    fetchTextFn(ISHIN_SANGIIN_URL),
    fetchTextFn(ISHIN_SIBUCHO_URL),
  ]);
  const excludedDetailUrls = new Set<string>([
    ...parseIshinDetailUrls(shugiinHtml),
    ...parseIshinDetailUrls(sangiinHtml),
    ...parseIshinDetailUrls(sibuchoHtml),
  ]);

  const prefResults = await mapWithConcurrency(
    directory,
    8,
    async (entry): Promise<IshinPrefecturePageResult> => {
      const html = await fetchTextFn(entry.sourceUrl);
      return parseIshinPrefecturePage(
        html,
        entry.prefecture,
        entry.sourceUrl,
        excludedDetailUrls,
      );
    },
  );

  const snapshot = buildIshinMemberSnapshot(prefResults, ISHIN_MEMBER_INDEX_URL);
  if (!snapshot) {
    throw new Error("Ishin local member snapshot failed integrity checks.");
  }
  return snapshot;
}

export async function hashIshinSnapshot(
  snapshot: IshinMemberSnapshot,
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

export function computeIshinDiff(
  previous: IshinMemberSnapshot,
  current: IshinMemberSnapshot,
): IshinSnapshotDiff {
  const prevPrefMap = new Map(
    previous.prefectures.map((p) => [p.prefecture, p.localAssemblyMembers]),
  );
  const prefectureDeltas: IshinPrefectureDelta[] = current.prefectures
    .map((p) => {
      const before = prevPrefMap.get(p.prefecture) ?? 0;
      const after = p.localAssemblyMembers;
      return {
        prefecture: p.prefecture,
        before,
        after,
        delta: after - before,
      };
    })
    .filter((d) => d.delta !== 0)
    .sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta));

  const prevLocalMap = new Map(
    previous.members
      .filter((m) => m.category === "local_assembly")
      .map((m) => [m.detailUrl, m]),
  );
  const currLocalMap = new Map(
    current.members
      .filter((m) => m.category === "local_assembly")
      .map((m) => [m.detailUrl, m]),
  );
  const addedMembers = current.members.filter((m) =>
    m.category === "local_assembly" && !prevLocalMap.has(m.detailUrl)
  );
  const removedMembers = previous.members.filter((m) =>
    m.category === "local_assembly" && !currLocalMap.has(m.detailUrl)
  );

  const prevMayorMap = new Map(
    previous.members
      .filter((m) => m.category === "governor_mayor")
      .map((m) => [m.detailUrl, m]),
  );
  const currMayorMap = new Map(
    current.members
      .filter((m) => m.category === "governor_mayor")
      .map((m) => [m.detailUrl, m]),
  );
  const addedMayors = current.members.filter((m) =>
    m.category === "governor_mayor" && !prevMayorMap.has(m.detailUrl)
  );
  const removedMayors = previous.members.filter((m) =>
    m.category === "governor_mayor" && !currMayorMap.has(m.detailUrl)
  );

  const prevBlankSet = new Set(previous.blankPrefectures);
  const currBlankSet = new Set(current.blankPrefectures);
  const newlyFilledPrefectures = previous.blankPrefectures.filter((p) =>
    !currBlankSet.has(p)
  );
  const newlyBlankPrefectures = current.blankPrefectures.filter((p) =>
    !prevBlankSet.has(p)
  );

  const hasChanges = stableStringify(previous) !== stableStringify(current);

  return {
    hasChanges,
    localAssemblyDelta: current.localAssemblyMembers -
      previous.localAssemblyMembers,
    governorsAndMayorsDelta: current.governorsAndMayors -
      previous.governorsAndMayors,
    activePrefectureDelta: current.activePrefectureCount -
      previous.activePrefectureCount,
    prefectureDeltas,
    addedMembers,
    removedMembers,
    addedMayors,
    removedMayors,
    newlyFilledPrefectures,
    newlyBlankPrefectures,
  };
}

function formatMemberList(
  title: string,
  members: readonly IshinMemberRecord[],
  limit = 10,
): string[] {
  if (members.length === 0) return [];
  const slice = members.slice(0, limit);
  const lines = [
    `${title} (${members.length}人):`,
    ...slice.map((m) =>
      `・${m.name}（${m.prefecture}${m.areaLabel ? ` / ${m.areaLabel}` : ""}）`
    ),
  ];
  if (members.length > limit) {
    lines.push(`…ほか ${members.length - limit}人`);
  }
  return lines;
}

export function buildIshinTrackerCandidateMetadata(
  current: IshinMemberSnapshot,
  previous: IshinMemberSnapshot | null,
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
  const diff = computeIshinDiff(previous, current);
  if (!diff.hasChanges) return null;

  const prefChangeLines = diff.prefectureDeltas.slice(0, 5).map((d) =>
    `・${d.prefecture}: ${formatCount(d.before)}→${formatCount(d.after)}人 (${signed(d.delta)})`
  );

  const alertLine = current.blankPrefectures.length > 0
    ? `🟡 地方議員 0人県 (${current.blankPrefectures.length}県): ${current.blankPrefectures.join("・")}`
    : "全47都道府県に地方議員を擁立済み";

  const leadLines = [
    "日本維新の会 地方議員データ集計・更新",
    "",
    `取得日時: ${options.observedAt}`,
    `現職地方議員: ${formatCount(previous.localAssemblyMembers)}→${formatCount(current.localAssemblyMembers)}人 (${signed(diff.localAssemblyDelta)})`,
    `在籍都道府県: ${current.activePrefectureCount}/47県 (${signed(diff.activePrefectureDelta)})・首長 ${formatCount(current.governorsAndMayors)}人`,
    alertLine,
  ];
  if (prefChangeLines.length > 0) {
    leadLines.push("", "増減のあった都道府県:", ...prefChangeLines);
  }
  leadLines.push(
    "",
    "数字は公式サイト掲載の都道府県別名簿から衆参国会議員・支部長を除いて自動集計した実測値です。",
  );
  const lead = leadLines.join("\n");

  const topPrefs = [...current.prefectures]
    .sort((a, b) => b.localAssemblyMembers - a.localAssemblyMembers)
    .slice(0, 8)
    .map((p, idx) =>
      `${idx + 1}. ${p.prefecture}: ${formatCount(p.localAssemblyMembers)}人${
        p.governorsAndMayors > 0 ? `（+首長${p.governorsAndMayors}）` : ""
      }`
    );

  const reply1Sections: string[] = [
    "日本維新の会 地方議員 異動・上位県サマリ",
    "",
    ...formatMemberList("新規掲載", diff.addedMembers),
    ...formatMemberList("掲載終了", diff.removedMembers),
    ...formatMemberList("首長 新規掲載", diff.addedMayors, 5),
    ...formatMemberList("首長 掲載終了", diff.removedMayors, 5),
  ];
  if (diff.newlyFilledPrefectures.length > 0) {
    reply1Sections.push(
      `空白県解消: ${diff.newlyFilledPrefectures.join("・")}`,
    );
  }
  if (diff.newlyBlankPrefectures.length > 0) {
    reply1Sections.push(
      `新規空白県: ${diff.newlyBlankPrefectures.join("・")}`,
    );
  }
  reply1Sections.push("", "議員数上位都道府県:", ...topPrefs);
  const reply1 = reply1Sections.join("\n").replace(/\n{3,}/g, "\n\n");

  const targetUrl = options.targetUrl ??
    "https://my-web-app-b67f4.web.app/local-election-700?utm_source=x&utm_medium=data_report&utm_campaign=first_user_growth&utm_content=ishin_member_tracker";
  const reply2 = [
    "日本維新の会公式サイト（都道府県別メンバー一覧）の定点観測レポートです。",
    `公式出典: ${current.sourceUrl}`,
    `ダッシュボード: ${targetUrl}`,
  ].join("\n");

  const common = buildXPostCandidateMetadata({
    action: "x.post",
    text: lead,
    replyTexts: [reply1, reply2],
    source: ISHIN_DATASET_SOURCE,
    route: "local-election-intelligence.ishinMemberTracker",
    variant: ISHIN_TRACKER_VARIANT,
    contentKind: ISHIN_TRACKER_VARIANT,
    contentArchetype: "data_report",
    linkInReply: true,
    ownerUserId: "service_role",
  }, {
    candidateKey: `ishin-member-tracker:${
      options.previousSnapshotHash.slice(0, 12)
    }:${options.snapshotHash.slice(0, 12)}`,
    candidateType: ISHIN_TRACKER_VARIANT,
    sourceKind: "ishin_member_snapshot",
    sourceUrls: [current.sourceUrl],
    createdBy: ISHIN_DATASET_SOURCE,
    now: new Date(options.observedAt),
  });

  return {
    ...common,
    dataset: ISHIN_DATASET,
    dataset_source: ISHIN_DATASET_SOURCE,
    dataset_version: options.datasetVersion,
    snapshot_observation_id: options.snapshotObservationId,
    dataset_snapshot_hash: options.snapshotHash,
    observed_at: options.observedAt,
    requires_human_approval: true,
    auto_publish: false,
    user_id: "service_role",
    ishin_summary: {
      local_assembly_members: current.localAssemblyMembers,
      governors_and_mayors: current.governorsAndMayors,
      active_prefecture_count: current.activePrefectureCount,
      local_assembly_delta: diff.localAssemblyDelta,
      added_count: diff.addedMembers.length,
      removed_count: diff.removedMembers.length,
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

function parseIshinSnapshotRecord(
  value: unknown,
): IshinMemberSnapshot | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const r = value as JsonRecord;
  const totalRawCards = asNonNegativeInt(r.totalRawCards);
  const excludedDietOrBranchCount = asNonNegativeInt(
    r.excludedDietOrBranchCount,
  );
  const localAssemblyMembers = asNonNegativeInt(r.localAssemblyMembers);
  const governorsAndMayors = asNonNegativeInt(r.governorsAndMayors);
  const totalLocalPoliticians = asNonNegativeInt(r.totalLocalPoliticians);
  const activePrefectureCount = asNonNegativeInt(r.activePrefectureCount);
  if (
    typeof r.sourceUrl !== "string" ||
    totalRawCards === null ||
    excludedDietOrBranchCount === null ||
    localAssemblyMembers === null ||
    governorsAndMayors === null ||
    totalLocalPoliticians === null ||
    activePrefectureCount === null ||
    !Array.isArray(r.blankPrefectures) ||
    !Array.isArray(r.prefectures) ||
    !Array.isArray(r.members)
  ) {
    return null;
  }

  const blankPrefectures = r.blankPrefectures
    .map((item) => asString(item))
    .filter((item) => item.length > 0);
  const namedRoleCountsRaw = (r.namedRoleCounts &&
      typeof r.namedRoleCounts === "object" &&
      !Array.isArray(r.namedRoleCounts))
    ? (r.namedRoleCounts as JsonRecord)
    : {};
  const namedRoleCounts: Record<string, number> = {};
  for (const [key, val] of Object.entries(namedRoleCountsRaw)) {
    const parsedVal = asNonNegativeInt(val);
    if (parsedVal !== null) namedRoleCounts[key] = parsedVal;
  }

  const prefectures: IshinPrefectureTally[] = [];
  for (const item of r.prefectures) {
    if (!item || typeof item !== "object" || Array.isArray(item)) return null;
    const p = item as JsonRecord;
    const pLocal = asNonNegativeInt(p.localAssemblyMembers);
    const pMayors = asNonNegativeInt(p.governorsAndMayors);
    const pTotal = asNonNegativeInt(p.totalLocalPoliticians);
    if (
      typeof p.prefecture !== "string" || typeof p.sourceUrl !== "string" ||
      pLocal === null || pMayors === null || pTotal === null
    ) {
      return null;
    }
    prefectures.push({
      prefecture: p.prefecture,
      sourceUrl: p.sourceUrl,
      localAssemblyMembers: pLocal,
      governorsAndMayors: pMayors,
      totalLocalPoliticians: pTotal,
    });
  }

  const members: IshinMemberRecord[] = [];
  for (const item of r.members) {
    if (!item || typeof item !== "object" || Array.isArray(item)) return null;
    const m = item as JsonRecord;
    const category = m.category === "governor_mayor"
      ? "governor_mayor"
      : (m.category === "local_assembly" ? "local_assembly" : null);
    if (
      typeof m.detailUrl !== "string" || typeof m.name !== "string" ||
      typeof m.prefecture !== "string" || category === null
    ) {
      return null;
    }
    members.push({
      detailUrl: m.detailUrl,
      name: m.name,
      prefecture: m.prefecture,
      category,
      roleLabel: asString(m.roleLabel),
      areaLabel: asString(m.areaLabel),
    });
  }

  return {
    sourceUrl: r.sourceUrl,
    totalRawCards,
    excludedDietOrBranchCount,
    localAssemblyMembers,
    governorsAndMayors,
    totalLocalPoliticians,
    activePrefectureCount,
    blankPrefectures,
    namedRoleCounts,
    prefectures,
    members,
  };
}

export async function persistIshinSnapshot(
  store: LocalElectionHubStore,
  snapshot: IshinMemberSnapshot,
  observedAt = new Date().toISOString(),
): Promise<PersistIshinSnapshotResult> {
  const snapshotHash = await hashIshinSnapshot(snapshot);
  const datasetVersion = `v${ISHIN_SNAPSHOT_SCHEMA_VERSION}-${
    snapshotHash.slice(0, 16)
  }`;
  const latestRow = await store.getLatestSnapshot(ISHIN_DATASET);
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
      dataset: ISHIN_DATASET,
      dataset_source: ISHIN_DATASET_SOURCE,
      dataset_version: datasetVersion,
      dataset_schema_version: ISHIN_SNAPSHOT_SCHEMA_VERSION,
      snapshot_hash: snapshotHash,
      previous_snapshot_id: previousSnapshotId,
      previous_snapshot_hash: previousSnapshotHash,
      observed_at: observedAt,
      snapshot,
      is_baseline: previousRow === null,
      created_by: ISHIN_DATASET_SOURCE,
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
    ? parseIshinSnapshotRecord(previousRow.metadata.snapshot)
    : null;
  if (!previousSnapshot || !previousSnapshotId || !previousSnapshotHash) {
    return {
      dataset: ISHIN_DATASET,
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

  const diff = computeIshinDiff(previousSnapshot, snapshot);
  const candidateMetadata = buildIshinTrackerCandidateMetadata(
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
      dataset: ISHIN_DATASET,
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
    dataset: ISHIN_DATASET,
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
