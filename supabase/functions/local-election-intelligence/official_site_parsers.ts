export const OFFICIAL_MEMBER_PAGE_URL = "https://new-kokumin.jp/member";
export const OFFICIAL_LOCAL_MEMBER_PAGE_URL =
  "https://new-kokumin.jp/member-local";
export const OFFICIAL_ELECTION_PAGE_URL = "https://new-kokumin.jp/election";
export const OFFICIAL_LOCAL_ELECTION_PAGE_URL =
  "https://new-kokumin.jp/election-local";

export const JP_LOCAL_ASSEMBLY_MEMBERS = "\u5730\u65b9\u81ea\u6cbb\u4f53\u8b70\u54e1";
export const JP_PLANNED_CANDIDATES = "\u5019\u88dc\u4e88\u5b9a\u8005";
export const JP_UNDECIDED = "\u672a\u5b9a";

export const PREFECTURES = [
  "\u5317\u6d77\u9053",
  "\u9752\u68ee\u770c",
  "\u5ca9\u624b\u770c",
  "\u5bae\u57ce\u770c",
  "\u79cb\u7530\u770c",
  "\u5c71\u5f62\u770c",
  "\u798f\u5cf6\u770c",
  "\u8328\u57ce\u770c",
  "\u6803\u6728\u770c",
  "\u7fa4\u99ac\u770c",
  "\u57fc\u7389\u770c",
  "\u5343\u8449\u770c",
  "\u6771\u4eac\u90fd",
  "\u795e\u5948\u5ddd\u770c",
  "\u65b0\u6f5f\u770c",
  "\u5bcc\u5c71\u770c",
  "\u77f3\u5ddd\u770c",
  "\u798f\u4e95\u770c",
  "\u5c71\u68a8\u770c",
  "\u9577\u91ce\u770c",
  "\u5c90\u961c\u770c",
  "\u9759\u5ca1\u770c",
  "\u611b\u77e5\u770c",
  "\u4e09\u91cd\u770c",
  "\u6ecb\u8cc0\u770c",
  "\u4eac\u90fd\u5e9c",
  "\u5927\u962a\u5e9c",
  "\u5175\u5eab\u770c",
  "\u5948\u826f\u770c",
  "\u548c\u6b4c\u5c71\u770c",
  "\u9ce5\u53d6\u770c",
  "\u5cf6\u6839\u770c",
  "\u5ca1\u5c71\u770c",
  "\u5e83\u5cf6\u770c",
  "\u5c71\u53e3\u770c",
  "\u5fb3\u5cf6\u770c",
  "\u9999\u5ddd\u770c",
  "\u611b\u5a9b\u770c",
  "\u9ad8\u77e5\u770c",
  "\u798f\u5ca1\u770c",
  "\u4f50\u8cc0\u770c",
  "\u9577\u5d0e\u770c",
  "\u718a\u672c\u770c",
  "\u5927\u5206\u770c",
  "\u5bae\u5d0e\u770c",
  "\u9e7f\u5150\u5cf6\u770c",
  "\u6c96\u7e04\u770c",
] as const;

export type AssemblyCategory = "prefectural" | "municipal" | "other";

export interface LocalLegislatorProfile {
  prefecture: string;
  sourceUrl: string;
  detailUrl: string;
  name: string;
  kana: string;
  constituency: string;
  municipality: string;
  assemblyLabel: string;
  assemblyCategory: AssemblyCategory;
  electionCountLabel: string;
  birthDate: string;
  age: number | null;
  gender: string;
  profile: string;
}

export interface OfficialScheduledCandidate {
  prefecture: string;
  electionName: string;
  voteDate: string;
  name: string;
  statusLabel: string;
  detailUrl: string;
  sourceUrl: string;
  xHandle: string;
}

export interface PrefectureDirectoryEntry {
  prefecture: string;
  sourceUrl: string;
  expectedMembers?: number | null;
}

export function stripTags(value: string): string {
  return value.replace(/<[^>]+>/g, " ");
}

export function decodeHtml(value: string): string {
  return value.replace(/&nbsp;/g, " ").replace(/&#038;/g, "&").replace(
    /&amp;/g,
    "&",
  ).replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">").replace(/&ensp;/g, " ").replace(/&emsp;/g, " ")
    .replace(/&#x2f;/gi, "/");
}

export function normalizeWhitespace(value: string): string {
  return value.replace(/\r/g, "\n").replace(/[ \t\u3000]+/g, " ").replace(
    /\n{2,}/g,
    "\n",
  ).trim();
}

export function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function toAsciiDigits(value: string): string {
  return value.replace(
    /[\uff10-\uff19]/g,
    (digit) => String.fromCharCode(digit.charCodeAt(0) - 0xfee0),
  );
}

export function extractIsoDate(value: string): string {
  const normalized = toAsciiDigits(value).replace(/\./g, "/").replace(
    /\u5e74/g,
    "/",
  ).replace(/\u6708/g, "/").replace(/\u65e5/g, "").replace(/\s+/g, "").trim();
  if (normalized === "" || normalized === JP_UNDECIDED) return "";
  const match = normalized.match(/(20\d{2})[\/-](\d{1,2})[\/-](\d{1,2})/);
  if (!match) return normalized.replace(/\//g, "-");
  return `${match[1]}-${match[2].padStart(2, "0")}-${
    match[3].padStart(2, "0")
  }`;
}

export function normalizeOfficialVoteDate(value: string): string {
  return extractIsoDate(value);
}

export function normalizeMemberName(value: string): string {
  return normalizeWhitespace(value).trim();
}

export function isPrefectureName(value: string): boolean {
  return PREFECTURES.includes(value as (typeof PREFECTURES)[number]);
}

export function extractPrefectureLabel(value: string): string {
  const normalized = normalizeWhitespace(value).trim();
  for (const prefecture of PREFECTURES) {
    if (normalized.includes(prefecture)) return prefecture;
  }
  return normalized;
}

export function isLocalElectionName(value: string): boolean {
  return /\u9078\u6319/u.test(value) &&
    !/(\u8846\u8b70\u9662|\u53c2\u8b70\u9662|\u6bd4\u4f8b|\u653f\u515a|\u4ee3\u8868\u9078|\u515a\u5927\u4f1a)/u
      .test(value);
}

export function prefectureSlug(prefecture: string): string {
  if (prefecture === "\u5317\u6d77\u9053") {
    return prefecture;
  }
  return prefecture.replace(/[\u90fd\u5e9c\u770c]$/u, "");
}

export function prefectureLookupKey(prefecture: string): string {
  return prefectureSlug(normalizeWhitespace(prefecture).trim());
}

/**
 * Remove trailing member-count badges such as "（9名）" or "(1名)" from
 * official section headings.
 */
export function stripMemberCountSuffix(heading: string): string {
  return normalizeWhitespace(heading).replace(
    /[（(]\s*\d+\s*\u540d\s*[）)]$/u,
    "",
  ).trim();
}

export function matchMemberListSections(
  html: string,
): Array<{ heading: string; listHtml: string }> {
  const sections: Array<{ heading: string; listHtml: string }> = [];
  const sectionRegex =
    /<h2[^>]*class="[^"]*\bmember_sec_ttl\b[^"]*"[^>]*>([\s\S]*?)<\/h2>(?:(?!<h2\b|<ul[^>]*class="[^"]*\bmember_list\b)[\s\S])*?<ul[^>]*class="[^"]*\bmember_list\b[^"]*"[^>]*>([\s\S]*?)<\/ul>/gsi;
  for (const match of html.matchAll(sectionRegex)) {
    sections.push({
      heading: normalizeWhitespace(decodeHtml(stripTags(match[1] ?? "")))
        .trim(),
      listHtml: match[2] ?? "",
    });
  }
  return sections;
}

export function extractListItems(listHtml: string): string[] {
  const items: string[] = [];
  const itemRegex = /<li\b[^>]*>([\s\S]*?)<\/li>/gsi;
  for (const match of listHtml.matchAll(itemRegex)) {
    items.push(match[1] ?? "");
  }
  return items;
}

export function extractClassText(html: string, className: string): string {
  const pattern = new RegExp(
    `<[^>]+class="[^"]*\\b${
      escapeRegExp(className)
    }\\b[^"]*"[^>]*>([\\s\\S]*?)<\\/[^>]+>`,
    "i",
  );
  return normalizeWhitespace(
    decodeHtml(stripTags(html.match(pattern)?.[1] ?? "")),
  ).trim();
}

export function parseMemberCard(
  cardHtml: string,
  baseUrl: string,
): {
  name: string;
  kana: string;
  constituency: string;
  assemblyLabel: string;
  electionCountLabel: string;
  detailUrl: string;
} {
  const nameLinkMatch = cardHtml.match(
    /<dt[^>]*class="[^"]*\bname\b[^"]*"[^>]*>\s*<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/i,
  );
  return {
    name: normalizeMemberName(decodeHtml(stripTags(nameLinkMatch?.[2] ?? ""))),
    kana: extractClassText(cardHtml, "kana"),
    constituency: extractClassText(cardHtml, "kind"),
    assemblyLabel: extractClassText(cardHtml, "area") ||
      extractClassText(cardHtml, "category"),
    electionCountLabel: extractClassText(cardHtml, "times"),
    detailUrl: nameLinkMatch?.[1]
      ? new URL(nameLinkMatch[1], baseUrl).toString()
      : "",
  };
}

export function inferAssemblyCategory(assemblyLabel: string): AssemblyCategory {
  if (
    /(\u90fd|\u9053|\u5e9c|\u770c)(?:\u8b70\u4f1a|\u4f1a)\u8b70\u54e1/u.test(
      assemblyLabel,
    )
  ) {
    return "prefectural";
  }
  if (
    /(\u5e02|\u533a|\u753a|\u6751)(?:\u8b70\u4f1a|\u4f1a)\u8b70\u54e1/u.test(
      assemblyLabel,
    )
  ) {
    return "municipal";
  }
  return "other";
}

export function extractMunicipality(
  prefecture: string,
  constituency: string,
): string {
  const normalizedPrefecture = prefecture.trim();
  const normalizedConstituency = constituency.trim();
  if (normalizedConstituency === "") {
    return normalizedPrefecture;
  }
  if (
    normalizedPrefecture !== "" &&
    normalizedConstituency.startsWith(normalizedPrefecture)
  ) {
    const sliced = normalizedConstituency.slice(normalizedPrefecture.length)
      .trim();
    return sliced === "" ? normalizedPrefecture : sliced;
  }
  return normalizedConstituency;
}

function extractDirectoryExpectedMembers(
  anchorAttributes: string,
  innerHtml: string,
): number | null {
  const countBadgeMatch = innerHtml.match(
    /<span[^>]*class="[^"]*\blocal_list_count\b[^"]*"[^>]*>([\s\S]*?)<\/span>/i,
  );
  if (countBadgeMatch?.[1]) {
    const digits = toAsciiDigits(decodeHtml(stripTags(countBadgeMatch[1])))
      .trim();
    if (/^\d+$/.test(digits)) {
      return Number.parseInt(digits, 10);
    }
  }
  const ariaMatch = anchorAttributes.match(
    /aria-label="[^"]*[（(]\s*([0-9０-９]+)\s*\u540d\s*[）)]"/i,
  );
  if (ariaMatch?.[1]) {
    const digits = toAsciiDigits(ariaMatch[1]).trim();
    if (/^\d+$/.test(digits)) {
      return Number.parseInt(digits, 10);
    }
  }
  return null;
}

function isGenericLocalMembersSection(heading: string): boolean {
  return heading.includes(JP_LOCAL_ASSEMBLY_MEMBERS) &&
    !heading.includes(JP_PLANNED_CANDIDATES);
}

export function parsePrefectureDirectoryEntries(
  html: string,
): PrefectureDirectoryEntry[] {
  const links = new Map<string, string>();
  const expectedCounts = new Map<string, number>();
  const linkRegex =
    /<a([^>]*\bhref="([^"]*\/member_tag\/[^"]+)"[^>]*)>([\s\S]*?)<\/a>/gsi;
  for (const match of html.matchAll(linkRegex)) {
    const rawAttributes = match[1] ?? "";
    const rawHref = match[2]?.trim() ?? "";
    const innerHtml = match[3] ?? "";
    const rawLabel = normalizeWhitespace(decodeHtml(stripTags(innerHtml)))
      .trim();
    const label = extractPrefectureLabel(rawLabel);
    if (!isPrefectureName(label) || rawHref === "") {
      continue;
    }
    const sourceUrl = new URL(rawHref, OFFICIAL_MEMBER_PAGE_URL).toString();
    const expected = extractDirectoryExpectedMembers(rawAttributes, innerHtml);
    links.set(label, sourceUrl);
    links.set(prefectureLookupKey(label), sourceUrl);
    if (expected !== null) {
      expectedCounts.set(label, expected);
      expectedCounts.set(prefectureLookupKey(label), expected);
    }
  }
  return PREFECTURES.map((prefecture) => ({
    prefecture,
    sourceUrl: links.get(prefecture) ??
      links.get(prefectureLookupKey(prefecture)) ??
      "",
    expectedMembers: expectedCounts.get(prefecture) ??
      expectedCounts.get(prefectureLookupKey(prefecture)) ??
      null,
  }));
}

export function parsePrefectureMembers(
  prefecture: string,
  sourceUrl: string,
  html: string,
): LocalLegislatorProfile[] {
  const sections = matchMemberListSections(html).filter((section) => {
    if (isGenericLocalMembersSection(section.heading)) {
      return true;
    }
    const headingLabel = stripMemberCountSuffix(section.heading);
    return inferAssemblyCategory(headingLabel) !== "other";
  });
  const members: LocalLegislatorProfile[] = [];

  for (const section of sections) {
    const headingLabel = stripMemberCountSuffix(section.heading);
    const isGenericLocalSection = isGenericLocalMembersSection(section.heading);
    for (const cardHtml of extractListItems(section.listHtml)) {
      const card = parseMemberCard(cardHtml, sourceUrl);
      const assemblyLabel = card.assemblyLabel || headingLabel;
      const assemblyCategory = inferAssemblyCategory(assemblyLabel);
      if (
        card.name === "" ||
        (!isGenericLocalSection && assemblyCategory === "other")
      ) {
        continue;
      }
      members.push({
        prefecture,
        sourceUrl,
        detailUrl: card.detailUrl,
        name: card.name,
        kana: card.kana,
        constituency: card.constituency,
        municipality: extractMunicipality(prefecture, card.constituency),
        assemblyLabel,
        assemblyCategory,
        electionCountLabel: card.electionCountLabel,
        birthDate: "",
        age: null,
        gender: "",
        profile: "",
      });
    }
  }

  const unique = new Map<string, LocalLegislatorProfile>();
  for (const member of members) {
    const key = member.detailUrl || `${member.prefecture}:${member.name}`;
    if (!unique.has(key)) {
      unique.set(key, member);
    }
  }
  return [...unique.values()];
}

export function parseOfficialElectionPrefectureLinks(
  html: string,
  baseUrl: string = OFFICIAL_ELECTION_PAGE_URL,
): Map<string, string> {
  const links = new Map<string, string>();
  const patterns = [
    /<a[^>]+href="([^"]*\/member_tag\/[^"]*\?mode=candidate[^"]*)"[^>]*>([\s\S]*?)<\/a>/gsi,
    /<a[^>]+href="([^"]*post_type=election[^"]*prefectures=[^"]+)"[^>]*>([\s\S]*?)<\/a>/gsi,
  ];
  for (const linkRegex of patterns) {
    for (const match of html.matchAll(linkRegex)) {
      const rawLabel = normalizeWhitespace(
        decodeHtml(stripTags(match[2] ?? "")),
      ).trim();
      const label = extractPrefectureLabel(rawLabel);
      const rawHref = match[1]?.trim() ?? "";
      if (!isPrefectureName(label) || rawHref === "") {
        continue;
      }
      if (!links.has(label)) {
        links.set(label, new URL(rawHref, baseUrl).toString());
      }
    }
  }
  const embeddedJsonPattern =
    /"([^"]+)"\s*:\s*"(https?:\\?\/\\?\/[^"]*?member_tag\\?\/[^"]*?\?mode=candidate[^"]*)"/g;
  for (const match of html.matchAll(embeddedJsonPattern)) {
    const rawLabel = normalizeWhitespace(match[1] ?? "").trim();
    const label = extractPrefectureLabel(rawLabel);
    const rawHref = (match[2] ?? "").replace(/\\\//g, "/").trim();
    if (!isPrefectureName(label) || rawHref === "") {
      continue;
    }
    if (!links.has(label)) {
      links.set(label, new URL(rawHref, baseUrl).toString());
    }
  }
  return links;
}

export function parseOfficialScheduledCandidates(
  prefecture: string,
  sourceUrl: string,
  html: string,
): OfficialScheduledCandidate[] {
  const candidates: OfficialScheduledCandidate[] = [];
  const sections = matchMemberListSections(html).filter((section) => {
    if (
      section.heading.includes(prefecture) &&
      section.heading.includes(JP_PLANNED_CANDIDATES)
    ) {
      return true;
    }
    const headingElectionName = stripMemberCountSuffix(section.heading);
    return isLocalElectionName(headingElectionName);
  });

  for (const section of sections) {
    const headingElectionName = stripMemberCountSuffix(section.heading);
    for (const cardHtml of extractListItems(section.listHtml)) {
      const card = parseMemberCard(cardHtml, sourceUrl);
      const electionName = card.electionCountLabel || headingElectionName;
      const voteDate = normalizeOfficialVoteDate(
        extractClassText(cardHtml, "m_category"),
      );
      const statusLabel = extractClassText(cardHtml, "wins");
      if (
        card.name === "" || electionName === "" || statusLabel === "" ||
        !isLocalElectionName(electionName)
      ) {
        continue;
      }
      candidates.push({
        prefecture,
        electionName,
        voteDate,
        name: card.name,
        statusLabel,
        detailUrl: card.detailUrl,
        sourceUrl,
        xHandle: "",
      });
    }
  }
  return candidates;
}
