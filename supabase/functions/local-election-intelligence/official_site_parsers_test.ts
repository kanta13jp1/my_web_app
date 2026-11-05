import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  candidateMatchesConfirmedElection,
  normalizeConfirmedVoteDate,
  parseOfficialPrefectureLinks,
  parseOfficialRosterCards,
  parseOfficialRosterSections,
  unverifiedCandidateDateIssues,
} from "./official_site_parsers.ts";

const fixture = (name: string) => Deno.readTextFileSync(new URL(`./fixtures/${name}`, import.meta.url));
const prefectures = ["東京都", "北海道", "青森県", "神奈川県"];

Deno.test("current official candidate links retain candidate mode", () => {
  const links = parseOfficialPrefectureLinks(fixture("official-candidate-links.html"), "candidates", prefectures);
  assertEquals(links.get("東京都"), "https://new-kokumin.jp/member_tag/tokyo?mode=candidate");
  assertEquals(links.size, 4);
});

Deno.test("current member links do not become candidate links", () => {
  const html = fixture("official-member-links.html");
  assertEquals(parseOfficialPrefectureLinks(html, "members", prefectures).size, 4);
  assertEquals(parseOfficialPrefectureLinks(html, "candidates", prefectures).size, 0);
  assertEquals(parseOfficialPrefectureLinks(fixture("official-candidate-links.html"), "members", prefectures).size, 0);
});

Deno.test("links support old query URLs and HTML entities", () => {
  const html = `<a href="/?post_type=election&amp;prefectures=tokyo">東京都</a>`;
  assertEquals(parseOfficialPrefectureLinks(html, "candidates", prefectures).get("東京都"),
    "https://new-kokumin.jp/?post_type=election&prefectures=tokyo");
});

Deno.test("links reject foreign origins and malformed URLs", () => {
  const html = `<a href="https://evil.example/member_tag/tokyo?mode=candidate">東京都</a>
    <a href="http://[invalid">東京都</a>`;
  assertEquals(parseOfficialPrefectureLinks(html, "candidates", prefectures).size, 0);
});

Deno.test("Tokyo municipal headings yield 50 current members, excluding 8 national members", () => {
  const cards = parseOfficialRosterCards(fixture("official-tokyo-members.html"), "members", "東京都",
    "https://new-kokumin.jp/member_tag/tokyo");
  assertEquals(cards.length, 50);
  assertEquals(cards.every((card) => /(?:都|道|府|県|市|区|町|村)議会議員/u.test(card.assemblyLabel)), true);
  assertEquals(cards.some((card) => card.name === "井戸 まさえ"), false);
});

Deno.test("Tokyo candidate headings yield 50 candidates with unknown voting dates", () => {
  const cards = parseOfficialRosterCards(fixture("official-tokyo-candidates.html"), "candidates", "東京都",
    "https://new-kokumin.jp/member_tag/tokyo?mode=candidate");
  assertEquals(cards.length, 50);
  assertEquals(cards.every((card) => card.voteDate === "" && card.electionName.endsWith("選挙")), true);
  assertEquals(unverifiedCandidateDateIssues(cards), ["official_candidate_vote_date_unverified:50"]);
});

Deno.test("roster kinds exclude the other kind's sections", () => {
  assertEquals(parseOfficialRosterSections(fixture("official-tokyo-candidates.html"), "members", "東京都"), []);
  assertEquals(parseOfficialRosterSections(fixture("official-tokyo-members.html"), "candidates", "東京都"), []);
});

Deno.test("legacy prefecture headings remain accepted", () => {
  const html = `<h2 class="member_sec_ttl">東京都 地方自治体議員</h2><ul class="member_list"></ul>`;
  assertEquals(parseOfficialRosterSections(html, "members", "東京都").length, 1);
  assertEquals(parseOfficialRosterSections(html, "members", "北海道").length, 0);
});

Deno.test("card parsing keeps confirmed dates and rejects foreign profiles", () => {
  const item = (href: string) => `<li><dt class="name"><a href="${href}">鈴木 佑馬</a></dt>
    <div class="wins">公認・現職</div><div class="m_category">2026/12/27</div></li>`;
  const html = `<h2 class="member_sec_ttl">西東京市議会議員選挙</h2><ul class="member_list">
    ${item("/member/test")}${item("https://evil.example/member/test")}${item("/member/test")}</ul>`;
  const cards = parseOfficialRosterCards(html, "candidates", "東京都", "https://new-kokumin.jp/");
  assertEquals(cards.length, 1);
  assertEquals(cards[0].voteDate, "2026-12-27");
});

for (const [raw, expected] of [
  ["2026/11/4", "2026-11-04"], ["2026年12月27日", "2026-12-27"],
  ["2024-02-29", "2024-02-29"], ["2026/12/27（日）", "2026-12-27"],
  ["2026/2/29", ""], ["2026/13/1", ""], ["2026/4/31", ""],
  ["任期満了日2027/4/30", ""], ["2026/12/20告示", ""],
  ["2027/4/11予定", ""], ["未定", ""], ["", ""],
]) {
  Deno.test(`confirmed voting date: ${raw || "empty"}`, () => {
    assertEquals(normalizeConfirmedVoteDate(raw), expected);
  });
}

const candidate = { prefecture: "東京都", electionName: "千代田区議会議員選挙", voteDate: "" };
Deno.test("undated candidates do not match same-name 2023 or 2027 elections", () => {
  for (const voteDate of ["2023-04-23", "2027-04-25"]) {
    assertEquals(candidateMatchesConfirmedElection(candidate, { ...candidate, voteDate }), false);
  }
});

Deno.test("matching requires the same confirmed date, prefecture and election", () => {
  const dated = { ...candidate, voteDate: "2026-12-27" };
  assertEquals(candidateMatchesConfirmedElection(dated, { ...dated, electionName: "千代田区議選" }), true);
  assertEquals(candidateMatchesConfirmedElection(dated, { ...dated, voteDate: "2027-12-27" }), false);
  assertEquals(candidateMatchesConfirmedElection(dated, { ...dated, electionName: "千代田区議会議員補欠選挙" }), false);
  assertEquals(candidateMatchesConfirmedElection(dated, { ...dated, prefecture: "北海道" }), false);
  assertEquals(candidateMatchesConfirmedElection(dated, { ...dated, voteDate: "" }), false);
});

Deno.test("verified voting dates do not add persistence issues", () => {
  assertEquals(unverifiedCandidateDateIssues([{ voteDate: "2026-12-27" }]), []);
});
