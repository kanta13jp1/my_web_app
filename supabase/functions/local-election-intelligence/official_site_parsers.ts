// Pure official-site parsing helpers. No network, database, or AI calls.
export type RosterKind = "members" | "candidates";

function text(html: string): string {
  return html.replace(/<[^>]+>/g, " ").replace(/&nbsp;/g, " ")
    .replace(/&#0?38;|&amp;/g, "&").replace(/\s+/g, " ").trim();
}

export function parseOfficialPrefectureLinks(
  html: string,
  kind: RosterKind,
  prefectures: readonly string[],
): Map<string, string> {
  const links = new Map<string, string>();
  for (
    const match of html.matchAll(
      /<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi,
    )
  ) {
    const label = text(match[2]);
    const prefecture = prefectures.find((item) =>
      label === item || label.startsWith(`${item}（`) ||
      label.startsWith(`${item} (`)
    );
    if (!prefecture) continue;
    let url: URL;
    try {
      url = new URL(
        match[1].replace(/&#0?38;|&amp;/g, "&"),
        "https://new-kokumin.jp/",
      );
    } catch {
      continue;
    }
    if (url.origin !== "https://new-kokumin.jp") continue;
    const isMemberTag = /^\/member_tag\/[^/]+\/?$/.test(url.pathname);
    const candidateMode = url.searchParams.get("mode") === "candidate";
    const legacyCandidate = url.searchParams.get("post_type") === "election" &&
      url.searchParams.has("prefectures");
    if (
      kind === "candidates"
        ? !(isMemberTag && candidateMode || legacyCandidate)
        : !(isMemberTag && !url.searchParams.has("mode") && !legacyCandidate)
    ) continue;
    links.set(prefecture, url.toString());
  }
  return links;
}

export interface OfficialRosterSection {
  heading: string;
  listHtml: string;
  assemblyLabel: string;
  electionName: string;
}

export function parseOfficialRosterSections(
  html: string,
  kind: RosterKind,
  prefecture: string,
): OfficialRosterSection[] {
  const sections: OfficialRosterSection[] = [];
  const pattern =
    /<h2\b[^>]*class=["'][^"']*\bmember_sec_ttl\b[^"']*["'][^>]*>([\s\S]*?)<\/h2>\s*<ul\b[^>]*class=["'][^"']*\bmember_list\b[^"']*["'][^>]*>([\s\S]*?)<\/ul>/gi;
  for (const match of html.matchAll(pattern)) {
    const heading = text(match[1]).replace(/[（(]\s*\d+\s*名\s*[）)]\s*$/, "")
      .trim();
    const assembly = /(?:都|道|府|県|市|区|町|村)議会議員$/u.test(heading);
    const election = /(?:都|道|府|県|市|区|町|村)議会議員(?:補欠|再)?選挙$/u
      .test(heading);
    const legacyMember = heading.includes(prefecture) &&
      heading.includes("地方自治体議員");
    const legacyCandidate = heading.includes(prefecture) &&
      /候補予定者|予定候補者/u.test(heading);
    if (
      kind === "members"
        ? !(assembly || legacyMember)
        : !(election || legacyCandidate)
    ) continue;
    sections.push({
      heading,
      listHtml: match[2],
      assemblyLabel: assembly ? heading : "",
      electionName: election ? heading : "",
    });
  }
  return sections;
}

export function normalizeConfirmedVoteDate(value: string): string {
  // A term-expiry or announcement date is not a confirmed voting date.
  if (/任期|告示|見込|予定|未定/u.test(value)) return "";
  const match = value.trim().match(
    /^(20\d{2})[年\/-](\d{1,2})[月\/-](\d{1,2})(?:日)?(?:\s*[（(][日月火水木金土](?:曜日)?[）)])?$/u,
  );
  if (!match) return "";
  const [, year, month, day] = match;
  const iso = `${year}-${month.padStart(2, "0")}-${day.padStart(2, "0")}`;
  const date = new Date(`${iso}T00:00:00Z`);
  return Number.isFinite(date.getTime()) &&
      date.toISOString().slice(0, 10) === iso
    ? iso
    : "";
}

export interface OfficialRosterCard {
  name: string;
  kana: string;
  constituency: string;
  assemblyLabel: string;
  electionCountLabel: string;
  electionName: string;
  statusLabel: string;
  voteDate: string;
  detailUrl: string;
}

export function parseOfficialRosterCards(
  html: string,
  kind: RosterKind,
  prefecture: string,
  sourceUrl: string,
): OfficialRosterCard[] {
  const cards = new Map<string, OfficialRosterCard>();
  for (const section of parseOfficialRosterSections(html, kind, prefecture)) {
    for (
      const item of section.listHtml.matchAll(/<li\b[^>]*>([\s\S]*?)<\/li>/gi)
    ) {
      const html = item[1];
      const field = (name: string): string =>
        text(
          html.match(
            new RegExp(
              `<[^>]+class=["'][^"']*\\b${name}\\b[^"']*["'][^>]*>([\\s\\S]*?)<\\/[^>]+>`,
              "i",
            ),
          )?.[1] ?? "",
        );
      const nameLink = html.match(
        /<dt\b[^>]*class=["'][^"']*\bname\b[^"']*["'][^>]*>\s*<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/i,
      );
      if (!nameLink || text(nameLink[2]) === "") continue;
      let detail: URL;
      try {
        detail = new URL(nameLink[1], sourceUrl);
      } catch {
        continue;
      }
      if (
        detail.origin !== "https://new-kokumin.jp" ||
        !/^\/member\/[^/]+\/?$/.test(detail.pathname)
      ) continue;
      const electionName = section.electionName ||
        (kind === "candidates" ? field("times") : "");
      if (
        kind === "candidates" &&
        (!/(都|道|府|県|市|区|町|村)議会議員(?:補欠|再)?選挙/u.test(
          electionName,
        ) || !field("wins"))
      ) continue;
      const card: OfficialRosterCard = {
        name: text(nameLink[2]),
        kana: field("kana"),
        constituency: field("kind"),
        assemblyLabel: field("area") || field("category") ||
          section.assemblyLabel,
        electionCountLabel: field("times"),
        electionName,
        statusLabel: field("wins"),
        voteDate: normalizeConfirmedVoteDate(field("m_category")),
        detailUrl: detail.toString(),
      };
      const key = `${card.detailUrl}::${card.electionName}::${card.voteDate}`;
      if (!cards.has(key)) cards.set(key, card);
    }
  }
  return [...cards.values()];
}

function electionNameKey(value: string): string {
  return value.replace(/[\s　・･()（）「」『』]/gu, "")
    .replace(/投開票|推薦/gu, "").replace(/議会議員/gu, "議")
    .replace(/補選/gu, "補欠").replace(/選挙|選/gu, "")
    .replace(/(補欠)+/gu, "補欠").trim();
}

export function candidateMatchesConfirmedElection(
  candidate: { prefecture: string; electionName: string; voteDate: string },
  target: { prefecture: string; electionName: string; voteDate: string },
): boolean {
  const date = normalizeConfirmedVoteDate(candidate.voteDate);
  const targetDate = normalizeConfirmedVoteDate(target.voteDate);
  const name = electionNameKey(candidate.electionName);
  return date !== "" && targetDate !== "" && date === targetDate &&
    name !== "" &&
    candidate.prefecture.trim() === target.prefecture.trim() &&
    name === electionNameKey(target.electionName);
}

export function unverifiedCandidateDateIssues(
  candidates: Array<{ voteDate: string }>,
): string[] {
  const count =
    candidates.filter((item) =>
      normalizeConfirmedVoteDate(item.voteDate) === ""
    ).length;
  return count ? [`official_candidate_vote_date_unverified:${count}`] : [];
}
