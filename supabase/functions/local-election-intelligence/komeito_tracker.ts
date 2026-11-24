// Issue #4026: 公明党 地方議員トラッカー MVP (docs/X_TRACKER_SERIES_PLAYBOOK.md 準拠)
// 公式ディレクトリ https://www.komei.or.jp/member/ の静的集計表から
// 国会・地方(5区分+男女+推薦)の実数を決定的に抽出し、差分発生時のみ
// HITL 候補キュー (pending_approval) へ data_report 候補を生成する。

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

export const KOMEITO_MEMBER_PAGE_URL = "https://www.komei.or.jp/member/";
export const KOMEITO_SHUGIIN_RESULT_URL =
  "https://www.komei.or.jp/member/result/kokai:1/";
export const KOMEITO_SANGIIN_RESULT_URL =
  "https://www.komei.or.jp/member/result/kokai:2/";
export const KOMEITO_EXPECTED_PREFECTURES = 47;
export const KOMEITO_MINIMUM_LIVE_TOTAL = 2000;
export const KOMEITO_DATASET = "komeito_local_members";
export const KOMEITO_DATASET_SOURCE = "local-election-intelligence";
export const KOMEITO_TRACKER_VARIANT = "komeito_member_tracker";
export const KOMEITO_SNAPSHOT_SCHEMA_VERSION = 2;

export interface KomeitoGenderBreakdown {
  male: number;
  female: number;
  total: number;
  recommended: number;
}

export interface KomeitoPrefectureDirectoryEntry {
  code: string;
  prefecture: string;
  sourceUrl: string;
}

export interface KomeitoPrefectureLiveTally {
  code: string;
  prefecture: string;
  sourceUrl: string;
  totalMembers: number;
}

export interface KomeitoLiveDirectorySummary {
  totalMembers: number;
  houseOfRepresentatives: number;
  houseOfCouncillors: number;
  estimatedLocalMembers: number;
  prefectures: KomeitoPrefectureLiveTally[];
}

export interface KomeitoMemberSnapshot {
  sourceUrl: string;
  asOfDate: string;
  asOfLabel: string;
  totalMembers: number;
  recommendedCount: number;
  national: {
    houseOfRepresentatives: KomeitoGenderBreakdown;
    houseOfCouncillors: KomeitoGenderBreakdown;
    subtotal: KomeitoGenderBreakdown;
  };
  local: {
    prefectural: KomeitoGenderBreakdown;
    designatedCity: KomeitoGenderBreakdown;
    specialWard: KomeitoGenderBreakdown;
    generalCity: KomeitoGenderBreakdown;
    townVillage: KomeitoGenderBreakdown;
    subtotal: KomeitoGenderBreakdown;
  };
  liveDirectory?: KomeitoLiveDirectorySummary;
}

export interface KomeitoTierDelta {
  label: string;
  before: number;
  after: number;
  delta: number;
}

export interface KomeitoPrefectureDelta {
  code: string;
  prefecture: string;
  before: number;
  after: number;
  delta: number;
}

export interface KomeitoSnapshotDiff {
  hasChanges: boolean;
  summaryChanged: boolean;
  liveDirectoryChanged: boolean;
  asOfDateChanged: boolean;
  totalDelta: number;
  localTotalDelta: number;
  nationalTotalDelta: number;
  localFemaleDelta: number;
  recommendedDelta: number;
  liveTotalDelta: number;
  liveEstimatedLocalDelta: number;
  tierDeltas: KomeitoTierDelta[];
  prefectureDeltas: KomeitoPrefectureDelta[];
}

export interface PersistKomeitoSnapshotResult {
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

function normalizeCellText(html: string): string {
  const withLineBreaks = html.replace(/<br\s*\/?>/gi, " ");
  return toAsciiDigits(decodeHtml(stripTags(withLineBreaks)))
    .replace(/\s+/g, " ")
    .trim();
}

function parseIntegerWithComma(raw: string): number | null {
  const cleaned = raw.replace(/,/g, "").trim();
  if (!/^\d+$/.test(cleaned)) return null;
  const parsed = Number.parseInt(cleaned, 10);
  return Number.isSafeInteger(parsed) && parsed >= 0 ? parsed : null;
}

function parseCellCountAndRecommended(
  cellHtml: string,
): { count: number; recommended: number } | null {
  const text = normalizeCellText(cellHtml);
  const match = text.match(
    /^(\d[\d,]*)(?:\s*[（(]\s*(\d[\d,]*)\s*[）)])?$/,
  );
  if (!match) return null;
  const count = parseIntegerWithComma(match[1] ?? "");
  if (count === null) return null;
  const recommended = match[2]
    ? (parseIntegerWithComma(match[2]) ?? 0)
    : 0;
  return { count, recommended };
}

function parseBreakdownTableRows(
  tableHtml: string,
): Map<string, KomeitoGenderBreakdown> {
  const rows = new Map<string, KomeitoGenderBreakdown>();
  const rowRegex = /<tr\b[^>]*>([\s\S]*?)<\/tr>/gsi;
  for (const rowMatch of tableHtml.matchAll(rowRegex)) {
    const rowHtml = rowMatch[1] ?? "";
    const thMatch = rowHtml.match(/<th\b[^>]*>([\s\S]*?)<\/th>/i);
    if (!thMatch) continue;
    const label = normalizeCellText(thMatch[1] ?? "");
    if (!label) continue;

    const cells: string[] = [];
    for (const tdMatch of rowHtml.matchAll(/<td\b[^>]*>([\s\S]*?)<\/td>/gsi)) {
      cells.push(tdMatch[1] ?? "");
    }
    if (cells.length !== 3) continue;

    const male = parseCellCountAndRecommended(cells[0]);
    const female = parseCellCountAndRecommended(cells[1]);
    const total = parseCellCountAndRecommended(cells[2]);
    if (!male || !female || !total) continue;
    if (male.count + female.count !== total.count) continue;

    rows.set(label, {
      male: male.count,
      female: female.count,
      total: total.count,
      recommended: total.recommended,
    });
  }
  return rows;
}

function extractSectionTable(html: string, headingText: string): string | null {
  const pattern = new RegExp(
    `<h3\\b[^>]*>\\s*${headingText}\\s*<\\/h3>(?:(?!<h3\\b)[\\s\\S])*?<table\\b[^>]*>([\\s\\S]*?)<\\/table>`,
    "i",
  );
  return html.match(pattern)?.[1] ?? null;
}

/**
 * Parses the static membership summary table from `https://www.komei.or.jp/member/`.
 * Applies strict arithmetic integrity gates (R28) and returns null whenever
 * markup changes or counts fail cross-checks.
 */
export function parseKomeitoMemberSummaryHtml(
  html: string,
  sourceUrl = KOMEITO_MEMBER_PAGE_URL,
): KomeitoMemberSnapshot | null {
  if (!html || html.trim() === "") return null;

  const dateMatch = html.match(
    /<div\b[^>]*class="[^"]*\bhdg2_02\b[^"]*\bdate\b[^"]*"[^>]*>[\s\S]*?<p\b[^>]*>([\s\S]*?)<\/p>/i,
  );
  if (!dateMatch?.[1]) return null;
  const normalizedDateText = normalizeCellText(dateMatch[1]);
  const jpDateMatch = normalizedDateText.match(
    /(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日/,
  );
  if (!jpDateMatch) return null;
  const year = Number.parseInt(jpDateMatch[1], 10);
  const month = Number.parseInt(jpDateMatch[2], 10);
  const day = Number.parseInt(jpDateMatch[3], 10);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  const asOfDate = `${String(year).padStart(4, "0")}-${
    String(month).padStart(2, "0")
  }-${String(day).padStart(2, "0")}`;
  const asOfLabel = `${year}年${month}月${day}日現在`;

  const totalParagraphMatch = html.match(
    /<p\b[^>]*>\s*<em\b[^>]*class="[^"]*\bem01\b[^"]*"[^>]*>([\s\S]*?)<\/em>([\s\S]*?)<\/p>/i,
  );
  if (!totalParagraphMatch?.[1]) return null;
  const totalDigitsMatch = normalizeCellText(totalParagraphMatch[1]).match(
    /(\d[\d,]*)\s*人/,
  );
  if (!totalDigitsMatch) return null;
  const totalMembers = parseIntegerWithComma(totalDigitsMatch[1]);
  if (totalMembers === null || totalMembers < 500) return null;

  const recommendedMatch = normalizeCellText(totalParagraphMatch[2] ?? "")
    .match(/推薦\s*[：:]\s*(\d[\d,]*)\s*人/);
  const recommendedCount = recommendedMatch?.[1]
    ? (parseIntegerWithComma(recommendedMatch[1]) ?? 0)
    : 0;

  const nationalTableHtml = extractSectionTable(html, "国会議員");
  const localTableHtml = extractSectionTable(html, "地方議員");
  if (!nationalTableHtml || !localTableHtml) return null;

  const nationalRows = parseBreakdownTableRows(nationalTableHtml);
  const localRows = parseBreakdownTableRows(localTableHtml);

  const houseOfRepresentatives = nationalRows.get("衆議院");
  const houseOfCouncillors = nationalRows.get("参議院");
  const nationalSubtotal = nationalRows.get("小計");
  if (!houseOfRepresentatives || !houseOfCouncillors || !nationalSubtotal) {
    return null;
  }
  if (
    houseOfRepresentatives.total + houseOfCouncillors.total !==
      nationalSubtotal.total ||
    houseOfRepresentatives.male + houseOfCouncillors.male !==
      nationalSubtotal.male ||
    houseOfRepresentatives.female + houseOfCouncillors.female !==
      nationalSubtotal.female
  ) {
    return null;
  }

  const prefectural = localRows.get("都道府県会");
  const designatedCity = localRows.get("政令市会");
  const specialWard = localRows.get("特別区会");
  const generalCity = localRows.get("一般市会");
  const townVillage = localRows.get("町村会");
  const localSubtotal = localRows.get("小計");
  if (
    !prefectural || !designatedCity || !specialWard || !generalCity ||
    !townVillage || !localSubtotal
  ) {
    return null;
  }
  if (localSubtotal.total < 500) return null;

  const localTiers = [
    prefectural,
    designatedCity,
    specialWard,
    generalCity,
    townVillage,
  ];
  const localTotalSum = localTiers.reduce((sum, item) => sum + item.total, 0);
  const localMaleSum = localTiers.reduce((sum, item) => sum + item.male, 0);
  const localFemaleSum = localTiers.reduce((sum, item) => sum + item.female, 0);
  if (
    localTotalSum !== localSubtotal.total ||
    localMaleSum !== localSubtotal.male ||
    localFemaleSum !== localSubtotal.female
  ) {
    return null;
  }

  if (nationalSubtotal.total + localSubtotal.total !== totalMembers) {
    return null;
  }

  return {
    sourceUrl,
    asOfDate,
    asOfLabel,
    totalMembers,
    recommendedCount,
    national: {
      houseOfRepresentatives,
      houseOfCouncillors,
      subtotal: nationalSubtotal,
    },
    local: {
      prefectural,
      designatedCity,
      specialWard,
      generalCity,
      townVillage,
      subtotal: localSubtotal,
    },
  };
}

export function parseKomeitoPrefectureDirectory(
  rootHtml: string,
): KomeitoPrefectureDirectoryEntry[] {
  const selectMatch = rootHtml.match(
    /<select\b[^>]*name=["']data\[Member\]\[pref\]["'][^>]*>([\s\S]*?)<\/select>/i,
  );
  if (!selectMatch?.[1]) return [];
  const entries: KomeitoPrefectureDirectoryEntry[] = [];
  const seenCodes = new Set<string>();
  const optionRe = /<option\b[^>]*value=["'](\d{2})["'][^>]*>([\s\S]*?)<\/option>/gi;
  for (const match of selectMatch[1].matchAll(optionRe)) {
    const code = (match[1] ?? "").trim();
    const prefecture = normalizeCellText(match[2] ?? "");
    if (!code || !prefecture || seenCodes.has(code)) continue;
    seenCodes.add(code);
    entries.push({
      code,
      prefecture,
      sourceUrl: `https://www.komei.or.jp/member/result/pref:${code}/`,
    });
  }
  if (entries.length !== KOMEITO_EXPECTED_PREFECTURES) {
    return [];
  }
  return entries;
}

export function parseKomeitoSearchResultCount(resultHtml: string): number | null {
  const match = resultHtml.match(
    /検索結果\s*(?:<em\b[^>]*>)?\s*([0-9０-９,]+)\s*人/i,
  );
  if (!match?.[1]) return null;
  const asciiDigits = toAsciiDigits(match[1]);
  return parseIntegerWithComma(asciiDigits);
}

export function buildKomeitoLiveDirectorySummary(
  tallies: readonly KomeitoPrefectureLiveTally[],
  houseOfRepresentatives: number,
  houseOfCouncillors: number,
): KomeitoLiveDirectorySummary | null {
  if (tallies.length !== KOMEITO_EXPECTED_PREFECTURES) return null;
  if (
    !Number.isSafeInteger(houseOfRepresentatives) ||
    houseOfRepresentatives < 0 ||
    !Number.isSafeInteger(houseOfCouncillors) ||
    houseOfCouncillors < 0
  ) {
    return null;
  }
  const seen = new Set<string>();
  let totalMembers = 0;
  for (const item of tallies) {
    if (seen.has(item.code)) return null;
    if (!Number.isSafeInteger(item.totalMembers) || item.totalMembers < 0) {
      return null;
    }
    seen.add(item.code);
    totalMembers += item.totalMembers;
  }
  if (totalMembers < KOMEITO_MINIMUM_LIVE_TOTAL) return null;
  const estimatedLocalMembers = totalMembers - houseOfRepresentatives -
    houseOfCouncillors;
  if (estimatedLocalMembers < 1500) return null;

  return {
    totalMembers,
    houseOfRepresentatives,
    houseOfCouncillors,
    estimatedLocalMembers,
    prefectures: tallies.map((item) => ({ ...item })),
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

export async function fetchKomeitoMemberSnapshot(
  fetchTextFn: (url: string) => Promise<string>,
): Promise<KomeitoMemberSnapshot> {
  const rootHtml = await fetchTextFn(KOMEITO_MEMBER_PAGE_URL);
  const summary = parseKomeitoMemberSummaryHtml(
    rootHtml,
    KOMEITO_MEMBER_PAGE_URL,
  );
  if (!summary) {
    throw new Error("Komeito official member summary could not be parsed.");
  }

  const directory = parseKomeitoPrefectureDirectory(rootHtml);
  if (directory.length !== KOMEITO_EXPECTED_PREFECTURES) {
    throw new Error(
      `Komeito prefecture directory invalid (${directory.length} entries).`,
    );
  }

  const [shugiinHtml, sangiinHtml] = await Promise.all([
    fetchTextFn(KOMEITO_SHUGIIN_RESULT_URL),
    fetchTextFn(KOMEITO_SANGIIN_RESULT_URL),
  ]);
  const shugiinCount = parseKomeitoSearchResultCount(shugiinHtml);
  const sangiinCount = parseKomeitoSearchResultCount(sangiinHtml);
  if (shugiinCount === null || sangiinCount === null) {
    throw new Error("Komeito Diet result counts could not be parsed.");
  }

  const tallies = await mapWithConcurrency(
    directory,
    8,
    async (entry): Promise<KomeitoPrefectureLiveTally> => {
      const pageHtml = await fetchTextFn(entry.sourceUrl);
      const count = parseKomeitoSearchResultCount(pageHtml);
      if (count === null) {
        throw new Error(
          `Komeito prefecture count could not be parsed for ${entry.prefecture} (${entry.code}).`,
        );
      }
      return {
        code: entry.code,
        prefecture: entry.prefecture,
        sourceUrl: entry.sourceUrl,
        totalMembers: count,
      };
    },
  );

  const liveDirectory = buildKomeitoLiveDirectorySummary(
    tallies,
    shugiinCount,
    sangiinCount,
  );
  if (!liveDirectory) {
    throw new Error("Komeito live directory summary failed integrity checks.");
  }

  return {
    ...summary,
    liveDirectory,
  };
}

export async function hashKomeitoSnapshot(
  snapshot: KomeitoMemberSnapshot,
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

export function computeKomeitoDiff(
  previous: KomeitoMemberSnapshot,
  current: KomeitoMemberSnapshot,
): KomeitoSnapshotDiff {
  const tierPairs: Array<[string, KomeitoGenderBreakdown, KomeitoGenderBreakdown]> = [
    ["都道府県会", previous.local.prefectural, current.local.prefectural],
    ["政令市会", previous.local.designatedCity, current.local.designatedCity],
    ["特別区会", previous.local.specialWard, current.local.specialWard],
    ["一般市会", previous.local.generalCity, current.local.generalCity],
    ["町村会", previous.local.townVillage, current.local.townVillage],
  ];
  const tierDeltas: KomeitoTierDelta[] = tierPairs
    .map(([label, before, after]) => ({
      label,
      before: before.total,
      after: after.total,
      delta: after.total - before.total,
    }))
    .filter((item) => item.delta !== 0);

  const asOfDateChanged = previous.asOfDate !== current.asOfDate;
  const totalDelta = current.totalMembers - previous.totalMembers;
  const localTotalDelta = current.local.subtotal.total -
    previous.local.subtotal.total;
  const nationalTotalDelta = current.national.subtotal.total -
    previous.national.subtotal.total;
  const localFemaleDelta = current.local.subtotal.female -
    previous.local.subtotal.female;
  const recommendedDelta = current.recommendedCount - previous.recommendedCount;

  const summaryProjection = (s: KomeitoMemberSnapshot) => ({
    sourceUrl: s.sourceUrl,
    asOfDate: s.asOfDate,
    asOfLabel: s.asOfLabel,
    totalMembers: s.totalMembers,
    recommendedCount: s.recommendedCount,
    national: s.national,
    local: s.local,
  });
  const summaryChanged = stableStringify(summaryProjection(previous)) !==
    stableStringify(summaryProjection(current));

  const hasBothLiveDirectories = previous.liveDirectory != null &&
    current.liveDirectory != null;
  let prefectureDeltas: KomeitoPrefectureDelta[] = [];
  let liveTotalDelta = 0;
  let liveEstimatedLocalDelta = 0;
  let liveDirectoryChanged = false;

  if (hasBothLiveDirectories) {
    const prevLive = previous.liveDirectory!;
    const currLive = current.liveDirectory!;
    liveDirectoryChanged = stableStringify(prevLive) !==
      stableStringify(currLive);
    liveTotalDelta = currLive.totalMembers - prevLive.totalMembers;
    liveEstimatedLocalDelta = currLive.estimatedLocalMembers -
      prevLive.estimatedLocalMembers;
    const prevByCode = new Map(
      prevLive.prefectures.map((p) => [p.code, p.totalMembers]),
    );
    prefectureDeltas = currLive.prefectures
      .map((p) => {
        const before = prevByCode.get(p.code) ?? 0;
        return {
          code: p.code,
          prefecture: p.prefecture,
          before,
          after: p.totalMembers,
          delta: p.totalMembers - before,
        };
      })
      .filter((d) => d.delta !== 0)
      .sort((a, b) =>
        Math.abs(b.delta) - Math.abs(a.delta) || a.code.localeCompare(b.code)
      );
  }

  const hasChanges = summaryChanged || liveDirectoryChanged;

  return {
    hasChanges,
    summaryChanged,
    liveDirectoryChanged,
    asOfDateChanged,
    totalDelta,
    localTotalDelta,
    nationalTotalDelta,
    localFemaleDelta,
    recommendedDelta,
    liveTotalDelta,
    liveEstimatedLocalDelta,
    tierDeltas,
    prefectureDeltas,
  };
}

export function buildKomeitoTrackerCandidateMetadata(
  current: KomeitoMemberSnapshot,
  previous: KomeitoMemberSnapshot | null,
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
  const diff = computeKomeitoDiff(previous, current);
  if (!diff.hasChanges) return null;

  const prevLocal = previous.local.subtotal.total;
  const currLocal = current.local.subtotal.total;
  const femalePct = currLocal > 0
    ? ((current.local.subtotal.female / currLocal) * 100).toFixed(1)
    : "0.0";

  const tierLines = diff.tierDeltas.length > 0
    ? diff.tierDeltas.map((item) =>
      `・${item.label}: ${formatCount(item.before)}→${formatCount(item.after)}人 (${signed(item.delta)})`
    )
    : [
      `・地方議員内訳: 都道府県会 ${formatCount(current.local.prefectural.total)}人 / 政令市会 ${formatCount(current.local.designatedCity.total)}人 / 一般市会 ${formatCount(current.local.generalCity.total)}人`,
    ];

  const prefLeadLines = diff.prefectureDeltas.slice(0, 5).map((item) =>
    `・${item.prefecture}: ${formatCount(item.before)}→${formatCount(item.after)}人 (${signed(item.delta)})`
  );

  const leadLines = [
    `公明党 地方議員データ更新（${current.asOfLabel}）`,
    "",
    `取得日時: ${options.observedAt}`,
  ];
  if (diff.summaryChanged || diff.localTotalDelta !== 0 || diff.totalDelta !== 0) {
    leadLines.push(
      `地方議員数: ${formatCount(prevLocal)}→${formatCount(currLocal)}人 (${signed(diff.localTotalDelta)})`,
      `所属議員総数: ${formatCount(previous.totalMembers)}→${formatCount(current.totalMembers)}人 (${signed(diff.totalDelta)} / 国会議員 ${formatCount(current.national.subtotal.total)}人・推薦 ${formatCount(current.recommendedCount)}人)`,
      `地方議員の女性比率: ${femalePct}%（女性 ${formatCount(current.local.subtotal.female)}人 / 男性 ${formatCount(current.local.subtotal.male)}人）`,
      "",
      "変化のあった議会区分:",
      ...tierLines,
    );
  }
  if (
    diff.liveDirectoryChanged && previous.liveDirectory && current.liveDirectory
  ) {
    leadLines.push(
      `ライブ名簿総数(47県): ${formatCount(previous.liveDirectory.totalMembers)}→${formatCount(current.liveDirectory.totalMembers)}人 (${signed(diff.liveTotalDelta)} / 推計地方 ${formatCount(current.liveDirectory.estimatedLocalMembers)}人 ${signed(diff.liveEstimatedLocalDelta)})`,
    );
    if (prefLeadLines.length > 0) {
      leadLines.push("", "変化のあった都道府県:", ...prefLeadLines);
    }
  }
  leadLines.push(
    "",
    "数字は公明党公式サイト掲載の所属議員集計・県別検索から自動取得した実測値です。",
  );
  const lead = leadLines.join("\n");

  const recommendedNote = (value: number): string =>
    value > 0 ? `（推薦${value}）` : "";

  const tierBreakdownLines = [
    `都道府県会: ${formatCount(current.local.prefectural.total)}人（男 ${formatCount(current.local.prefectural.male)} / 女 ${formatCount(current.local.prefectural.female)}）${recommendedNote(current.local.prefectural.recommended)}`,
    `政令市会: ${formatCount(current.local.designatedCity.total)}人（男 ${formatCount(current.local.designatedCity.male)} / 女 ${formatCount(current.local.designatedCity.female)}）${recommendedNote(current.local.designatedCity.recommended)}`,
    `特別区会: ${formatCount(current.local.specialWard.total)}人（男 ${formatCount(current.local.specialWard.male)} / 女 ${formatCount(current.local.specialWard.female)}）${recommendedNote(current.local.specialWard.recommended)}`,
    `一般市会: ${formatCount(current.local.generalCity.total)}人（男 ${formatCount(current.local.generalCity.male)} / 女 ${formatCount(current.local.generalCity.female)}）${recommendedNote(current.local.generalCity.recommended)}`,
    `町村会: ${formatCount(current.local.townVillage.total)}人（男 ${formatCount(current.local.townVillage.male)} / 女 ${formatCount(current.local.townVillage.female)}）${recommendedNote(current.local.townVillage.recommended)}`,
    `地方議員小計: ${formatCount(currLocal)}人`,
    `国会議員小計: ${formatCount(current.national.subtotal.total)}人（衆 ${current.national.houseOfRepresentatives.total} / 参 ${current.national.houseOfCouncillors.total}）`,
  ];

  const reply1Lines = [
    `公明党 所属議員 議会別・県別内訳（${current.asOfLabel}）`,
    "",
    ...tierBreakdownLines,
  ];
  if (current.liveDirectory) {
    reply1Lines.push(
      "",
      `ライブ名簿47県合計: ${formatCount(current.liveDirectory.totalMembers)}人（衆 ${current.liveDirectory.houseOfRepresentatives} / 参 ${current.liveDirectory.houseOfCouncillors} / 地方推計 ${formatCount(current.liveDirectory.estimatedLocalMembers)}人）`,
    );
  }
  if (diff.prefectureDeltas.length > 0) {
    reply1Lines.push(
      "",
      "都道府県別差分:",
      ...diff.prefectureDeltas.slice(0, 15).map((item) =>
        `・${item.prefecture}: ${formatCount(item.before)}→${formatCount(item.after)}人 (${signed(item.delta)})`
      ),
    );
  }
  const reply1 = reply1Lines.join("\n");

  const targetUrl = options.targetUrl ??
    "https://my-web-app-b67f4.web.app/local-election-700?utm_source=x&utm_medium=data_report&utm_campaign=first_user_growth&utm_content=komeito_member_tracker";
  const reply2 = [
    "公明党公式サイト（所属議員検索）の定点観測レポートです。",
    `公式出典: ${current.sourceUrl}`,
    `ダッシュボード: ${targetUrl}`,
  ].join("\n");

  const common = buildXPostCandidateMetadata({
    action: "x.post",
    text: lead,
    replyTexts: [reply1, reply2],
    source: KOMEITO_DATASET_SOURCE,
    route: "local-election-intelligence.komeitoMemberTracker",
    variant: KOMEITO_TRACKER_VARIANT,
    contentKind: KOMEITO_TRACKER_VARIANT,
    contentArchetype: "data_report",
    linkInReply: true,
    ownerUserId: "service_role",
  }, {
    candidateKey: `komeito-member-tracker:${
      options.previousSnapshotHash.slice(0, 12)
    }:${options.snapshotHash.slice(0, 12)}`,
    candidateType: KOMEITO_TRACKER_VARIANT,
    sourceKind: "komeito_member_snapshot",
    sourceUrls: [current.sourceUrl],
    createdBy: KOMEITO_DATASET_SOURCE,
    now: new Date(options.observedAt),
  });

  return {
    ...common,
    dataset: KOMEITO_DATASET,
    dataset_source: KOMEITO_DATASET_SOURCE,
    dataset_version: options.datasetVersion,
    snapshot_observation_id: options.snapshotObservationId,
    dataset_snapshot_hash: options.snapshotHash,
    observed_at: options.observedAt,
    requires_human_approval: true,
    auto_publish: false,
    user_id: "service_role",
    komeito_summary: {
      as_of_date: current.asOfDate,
      total_members: current.totalMembers,
      local_members: currLocal,
      national_members: current.national.subtotal.total,
      local_delta: diff.localTotalDelta,
      total_delta: diff.totalDelta,
    },
  };
}

function asBreakdown(value: unknown): KomeitoGenderBreakdown | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const r = value as JsonRecord;
  if (
    typeof r.male !== "number" || typeof r.female !== "number" ||
    typeof r.total !== "number"
  ) {
    return null;
  }
  const recommended = typeof r.recommended === "number" ? r.recommended : 0;
  return {
    male: r.male,
    female: r.female,
    total: r.total,
    recommended,
  };
}

function parseKomeitoLiveDirectoryRecord(
  value: unknown,
): KomeitoLiveDirectorySummary | undefined {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return undefined;
  }
  const r = value as JsonRecord;
  if (
    typeof r.totalMembers !== "number" ||
    !Number.isFinite(r.totalMembers) ||
    typeof r.houseOfRepresentatives !== "number" ||
    !Number.isFinite(r.houseOfRepresentatives) ||
    typeof r.houseOfCouncillors !== "number" ||
    !Number.isFinite(r.houseOfCouncillors) ||
    typeof r.estimatedLocalMembers !== "number" ||
    !Number.isFinite(r.estimatedLocalMembers) ||
    !Array.isArray(r.prefectures) ||
    r.prefectures.length === 0
  ) {
    return undefined;
  }

  const prefectures: KomeitoPrefectureLiveTally[] = [];
  for (const item of r.prefectures) {
    if (!item || typeof item !== "object" || Array.isArray(item)) {
      return undefined;
    }
    const p = item as JsonRecord;
    if (
      typeof p.code !== "string" ||
      typeof p.prefecture !== "string" ||
      typeof p.sourceUrl !== "string" ||
      typeof p.totalMembers !== "number" ||
      !Number.isFinite(p.totalMembers)
    ) {
      return undefined;
    }
    prefectures.push({
      code: p.code,
      prefecture: p.prefecture,
      sourceUrl: p.sourceUrl,
      totalMembers: p.totalMembers,
    });
  }

  return {
    totalMembers: r.totalMembers,
    houseOfRepresentatives: r.houseOfRepresentatives,
    houseOfCouncillors: r.houseOfCouncillors,
    estimatedLocalMembers: r.estimatedLocalMembers,
    prefectures,
  };
}

function parseKomeitoSnapshotRecord(
  value: unknown,
): KomeitoMemberSnapshot | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const r = value as JsonRecord;
  const national = r.national as JsonRecord | undefined;
  const local = r.local as JsonRecord | undefined;
  if (!national || !local) return null;

  const houseOfRepresentatives = asBreakdown(national.houseOfRepresentatives);
  const houseOfCouncillors = asBreakdown(national.houseOfCouncillors);
  const nationalSubtotal = asBreakdown(national.subtotal);
  const prefectural = asBreakdown(local.prefectural);
  const designatedCity = asBreakdown(local.designatedCity);
  const specialWard = asBreakdown(local.specialWard);
  const generalCity = asBreakdown(local.generalCity);
  const townVillage = asBreakdown(local.townVillage);
  const localSubtotal = asBreakdown(local.subtotal);

  if (
    typeof r.sourceUrl !== "string" || typeof r.asOfDate !== "string" ||
    typeof r.asOfLabel !== "string" || typeof r.totalMembers !== "number" ||
    !houseOfRepresentatives || !houseOfCouncillors || !nationalSubtotal ||
    !prefectural || !designatedCity || !specialWard || !generalCity ||
    !townVillage || !localSubtotal
  ) {
    return null;
  }

  const liveDirectory = parseKomeitoLiveDirectoryRecord(r.liveDirectory);

  return {
    sourceUrl: r.sourceUrl,
    asOfDate: r.asOfDate,
    asOfLabel: r.asOfLabel,
    totalMembers: r.totalMembers,
    recommendedCount: typeof r.recommendedCount === "number"
      ? r.recommendedCount
      : 0,
    national: {
      houseOfRepresentatives,
      houseOfCouncillors,
      subtotal: nationalSubtotal,
    },
    local: {
      prefectural,
      designatedCity,
      specialWard,
      generalCity,
      townVillage,
      subtotal: localSubtotal,
    },
    ...(liveDirectory ? { liveDirectory } : {}),
  };
}

function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

export async function persistKomeitoSnapshot(
  store: LocalElectionHubStore,
  snapshot: KomeitoMemberSnapshot,
  observedAt = new Date().toISOString(),
): Promise<PersistKomeitoSnapshotResult> {
  const snapshotHash = await hashKomeitoSnapshot(snapshot);
  const datasetVersion = `v${KOMEITO_SNAPSHOT_SCHEMA_VERSION}-${
    snapshotHash.slice(0, 16)
  }`;
  const latestRow = await store.getLatestSnapshot(KOMEITO_DATASET);
  const isConsecutiveRetry = latestRow != null &&
    readString(latestRow.metadata.snapshot_hash) === snapshotHash;

  let snapshotRow: HubDataRow;
  let snapshotCreated = false;
  let previousSnapshotId: string | null = null;
  let previousSnapshotHash: string | null = null;
  let previousRow: HubDataRow | null = null;

  if (isConsecutiveRetry && latestRow) {
    snapshotRow = latestRow;
    previousSnapshotId = readString(snapshotRow.metadata.previous_snapshot_id) ||
      null;
    previousSnapshotHash =
      readString(snapshotRow.metadata.previous_snapshot_hash) || null;
    if (previousSnapshotId) {
      previousRow = await store.findSnapshotById(previousSnapshotId);
    }
  } else {
    previousRow = latestRow;
    previousSnapshotId = previousRow?.id ?? null;
    previousSnapshotHash = previousRow
      ? readString(previousRow.metadata.snapshot_hash) || null
      : null;
    const insertion = await store.insertSnapshot({
      record_type: "dataset_snapshot",
      dataset: KOMEITO_DATASET,
      dataset_source: KOMEITO_DATASET_SOURCE,
      dataset_version: datasetVersion,
      dataset_schema_version: KOMEITO_SNAPSHOT_SCHEMA_VERSION,
      snapshot_hash: snapshotHash,
      previous_snapshot_id: previousSnapshotId,
      previous_snapshot_hash: previousSnapshotHash,
      observed_at: observedAt,
      snapshot,
      is_baseline: previousRow === null,
      created_by: KOMEITO_DATASET_SOURCE,
      user_id: "service_role",
    });
    snapshotRow = insertion.row;
    snapshotCreated = insertion.created;
    previousSnapshotId = readString(snapshotRow.metadata.previous_snapshot_id) ||
      null;
    previousSnapshotHash =
      readString(snapshotRow.metadata.previous_snapshot_hash) || null;
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
    ? parseKomeitoSnapshotRecord(previousRow.metadata.snapshot)
    : null;
  if (!previousSnapshot || !previousSnapshotId || !previousSnapshotHash) {
    return {
      dataset: KOMEITO_DATASET,
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

  const diff = computeKomeitoDiff(previousSnapshot, snapshot);
  const candidateMetadata = buildKomeitoTrackerCandidateMetadata(
    snapshot,
    previousSnapshot,
    {
      snapshotObservationId: snapshotRow.id,
      snapshotHash,
      previousSnapshotHash,
      datasetVersion,
      observedAt: readString(snapshotRow.metadata.observed_at) || observedAt,
    },
  );
  if (!candidateMetadata) {
    return {
      dataset: KOMEITO_DATASET,
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
    dataset: KOMEITO_DATASET,
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
