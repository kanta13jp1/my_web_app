export interface ScheduleOverviewEntry {
  electionName: string;
  prefecture: string;
  voteDate: string;
  detailUrl: string;
}

interface NewKokuminElectionRecord {
  post_id?: unknown;
  pref?: unknown;
  election_name?: unknown;
  vote_day?: unknown;
  period_end_day?: unknown;
}

const GO2SENKYO_SCHEDULE_URL = "https://go2senkyo.com/schedule";
const NEW_KOKUMIN_FORM_URL = "https://local-elections.new-kokumin.jp/form/";

const PREFECTURES = [
  "北海道",
  "青森県",
  "岩手県",
  "宮城県",
  "秋田県",
  "山形県",
  "福島県",
  "茨城県",
  "栃木県",
  "群馬県",
  "埼玉県",
  "千葉県",
  "東京都",
  "神奈川県",
  "新潟県",
  "富山県",
  "石川県",
  "福井県",
  "山梨県",
  "長野県",
  "岐阜県",
  "静岡県",
  "愛知県",
  "三重県",
  "滋賀県",
  "京都府",
  "大阪府",
  "兵庫県",
  "奈良県",
  "和歌山県",
  "鳥取県",
  "島根県",
  "岡山県",
  "広島県",
  "山口県",
  "徳島県",
  "香川県",
  "愛媛県",
  "高知県",
  "福岡県",
  "佐賀県",
  "長崎県",
  "熊本県",
  "大分県",
  "宮崎県",
  "鹿児島県",
  "沖縄県",
] as const;

/**
 * Parses the server-rendered Go2senkyo schedule table. Keeping this parser in
 * a side-effect-free module lets fixtures cover upstream markup changes
 * without importing the Edge Function server.
 */
export function parseGo2SenkyoScheduleHtml(
  html: string,
  baseUrl = GO2SENKYO_SCHEDULE_URL,
): ScheduleOverviewEntry[] {
  const entries: ScheduleOverviewEntry[] = [];
  const seen = new Set<string>();
  let currentVoteDate = "";
  for (const match of html.matchAll(/<tr[^>]*>([\s\S]*?)<\/tr>/gsi)) {
    const rowHtml = match[1] ?? "";
    const cells = [...rowHtml.matchAll(/<td[^>]*>([\s\S]*?)<\/td>/gsi)].map((
      cellMatch,
    ) => cellMatch[1] ?? "");
    if (cells.length < 2) continue;

    const detectedVoteDate = normalizeDate(
      normalizeWhitespace(decodeHtml(stripTags(cells[0]))),
    );
    if (detectedVoteDate !== "") currentVoteDate = detectedVoteDate;

    const electionCell = cells.length >= 3 ? cells[1] : cells[0];
    const prefectureCell = cells.length >= 3 ? cells[2] : cells[1];
    const detailMatch = electionCell.match(
      /<a[^>]+href=["']([^"']*\/local\/senkyo\/[^"']+)["'][^>]*>([\s\S]*?)<\/a>/i,
    );
    if (!detailMatch || currentVoteDate === "") continue;

    const electionName = normalizeWhitespace(
      decodeHtml(stripTags(detailMatch[2] ?? "")),
    ).trim();
    const prefecture = extractPrefectureLabel(
      normalizeWhitespace(decodeHtml(stripTags(prefectureCell))),
    );
    if (electionName === "" || !isPrefectureName(prefecture)) continue;

    const detailUrl = new URL(detailMatch[1], baseUrl).toString();
    const key = `${currentVoteDate}:${prefecture}:${electionName}:${detailUrl}`;
    if (seen.has(key)) continue;
    seen.add(key);
    entries.push({
      electionName,
      prefecture,
      voteDate: currentVoteDate,
      detailUrl,
    });
  }
  return entries;
}

/**
 * The Kokumin application page moved from server-rendered election cards to a
 * JSON array embedded in JavaScript (`var elections = [...]`) in August 2026.
 * Prefer that structured payload, while retaining the legacy card parser for
 * cached and older responses.
 */
export function parseNewKokuminElectionListHtml(
  html: string,
  formBaseUrl = NEW_KOKUMIN_FORM_URL,
): ScheduleOverviewEntry[] {
  const embeddedRecords = parseEmbeddedElectionRecords(html);
  if (embeddedRecords !== null) {
    return embeddedRecords.flatMap((record) =>
      normalizeNewKokuminRecord(record, formBaseUrl)
    );
  }
  return parseRenderedNewKokuminEntries(html, formBaseUrl);
}

function parseEmbeddedElectionRecords(
  html: string,
): NewKokuminElectionRecord[] | null {
  const assignment = /\b(?:const|let|var)\s+elections\s*=\s*/g.exec(html);
  if (!assignment) return null;
  const arrayStart = assignment.index + assignment[0].length;
  if (html[arrayStart] !== "[") return null;

  const json = extractBalancedJsonArray(html, arrayStart);
  if (json === null) return null;
  try {
    const value: unknown = JSON.parse(json);
    return Array.isArray(value)
      ? value.filter(isNewKokuminElectionRecord)
      : null;
  } catch {
    return null;
  }
}

function extractBalancedJsonArray(html: string, start: number): string | null {
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let index = start; index < html.length; index += 1) {
    const char = html[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === "\\") {
        escaped = true;
      } else if (char === '"') {
        inString = false;
      }
      continue;
    }
    if (char === '"') {
      inString = true;
    } else if (char === "[") {
      depth += 1;
    } else if (char === "]") {
      depth -= 1;
      if (depth === 0) return html.slice(start, index + 1);
    }
  }
  return null;
}

function isNewKokuminElectionRecord(
  value: unknown,
): value is NewKokuminElectionRecord {
  return value !== null && typeof value === "object";
}

function normalizeNewKokuminRecord(
  record: NewKokuminElectionRecord,
  formBaseUrl: string,
): ScheduleOverviewEntry[] {
  const prefecture = stringValue(record.pref).trim();
  const electionName = stringValue(record.election_name).trim();
  const voteDate = normalizeDate(stringValue(record.vote_day)) ||
    normalizeDate(stringValue(record.period_end_day));
  if (!isPrefectureName(prefecture) || electionName === "" || voteDate === "") {
    return [];
  }

  const postId = stringValue(record.post_id).trim();
  const detailUrl = postId === ""
    ? ""
    : `${formBaseUrl}?post_id=${encodeURIComponent(postId)}`;
  return [{ electionName, prefecture, voteDate, detailUrl }];
}

function parseRenderedNewKokuminEntries(
  html: string,
  formBaseUrl: string,
): ScheduleOverviewEntry[] {
  const entries: ScheduleOverviewEntry[] = [];
  const prefSectionRegex =
    /<section[^>]+class=["'][^"']*\bpref-section\b[^"']*["'][^>]*>([\s\S]*?)<\/section>/gi;
  for (const sectionMatch of html.matchAll(prefSectionRegex)) {
    const sectionHtml = sectionMatch[1] ?? "";
    const prefTitleMatch = sectionHtml.match(
      /<h2[^>]+class=["'][^"']*pref-section-title[^"']*["'][^>]*>([\s\S]*?)<\/h2>/i,
    );
    const prefecture = normalizeWhitespace(
      decodeHtml(stripTags(prefTitleMatch?.[1] ?? "")),
    ).trim();
    if (!isPrefectureName(prefecture)) continue;

    const itemRegex =
      /<li[^>]+class=["'][^"']*\belection-item\b[^"']*["'][^>]*>([\s\S]*?)<\/li>/gi;
    for (const itemMatch of sectionHtml.matchAll(itemRegex)) {
      const itemHtml = itemMatch[1] ?? "";
      const nameMatch = itemHtml.match(
        /<p[^>]+class=["'][^"']*election-item-name[^"']*["'][^>]*>([\s\S]*?)<\/p>/i,
      );
      const electionName = normalizeWhitespace(
        decodeHtml(stripTags(nameMatch?.[1] ?? "")),
      ).trim();
      if (electionName === "") continue;

      const datesMatch = itemHtml.match(
        /<p[^>]+class=["'][^"']*election-item-dates[^"']*["'][^>]*>([\s\S]*?)<\/p>/i,
      );
      const datesText = normalizeWhitespace(
        decodeHtml(stripTags(datesMatch?.[1] ?? "")),
      );
      const voteDate = extractNewKokuminVoteDate(datesText);
      if (voteDate === "") continue;

      const linkMatch = itemHtml.match(/href=["']([^"']*\/form\/[^"']*)["']/i);
      const detailUrl = linkMatch?.[1]
        ? new URL(decodeHtml(linkMatch[1]), formBaseUrl).toString()
        : "";
      entries.push({ electionName, prefecture, voteDate, detailUrl });
    }
  }
  return entries;
}

function extractNewKokuminVoteDate(datesText: string): string {
  const voteMatch = datesText.match(
    /投開票[：:]\s*(\d{4}年\d{1,2}月\d{1,2}日)/,
  );
  if (voteMatch?.[1]) return normalizeDate(voteMatch[1]);
  const termMatch = datesText.match(
    /任期満了[：:]\s*(\d{4}年\d{1,2}月\d{1,2}日)/,
  );
  return termMatch?.[1] ? normalizeDate(termMatch[1]) : "";
}

function normalizeDate(value: string): string {
  const normalized = toAsciiDigits(value).replace(/\./g, "/").replace(
    /年/g,
    "/",
  ).replace(/月/g, "/").replace(/日/g, "").replace(/\s+/g, "").trim();
  if (normalized === "" || normalized === "---" || normalized === "未定") {
    return "";
  }
  const match = normalized.match(/(20\d{2})[\/-](\d{1,2})[\/-](\d{1,2})/);
  if (!match) return "";
  return `${match[1]}-${match[2].padStart(2, "0")}-${
    match[3].padStart(2, "0")
  }`;
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function isPrefectureName(value: string): boolean {
  return PREFECTURES.includes(value as (typeof PREFECTURES)[number]);
}

function extractPrefectureLabel(value: string): string {
  const normalized = normalizeWhitespace(value).trim();
  return PREFECTURES.find((prefecture) => normalized.includes(prefecture)) ??
    normalized;
}

function stripTags(value: string): string {
  return value.replace(/<[^>]+>/g, " ");
}

function decodeHtml(value: string): string {
  return value.replace(/&nbsp;/g, " ").replace(/&#038;/g, "&").replace(
    /&amp;/g,
    "&",
  ).replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">").replace(/&ensp;/g, " ").replace(/&emsp;/g, " ")
    .replace(/&#x2f;/gi, "/");
}

function normalizeWhitespace(value: string): string {
  return value.replace(/\r/g, "\n").replace(/[ \t\u3000]+/g, " ").replace(
    /\n{2,}/g,
    "\n",
  ).trim();
}

function toAsciiDigits(value: string): string {
  return value.replace(
    /[０-９]/g,
    (digit) => String.fromCharCode(digit.charCodeAt(0) - 0xfee0),
  );
}
