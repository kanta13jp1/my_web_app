import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  inferAssemblyCategory,
  parseOfficialElectionPrefectureLinks,
  parseOfficialScheduledCandidates,
  parsePrefectureMembers,
} from "./official_site_parsers.ts";

Deno.test("inferAssemblyCategory classifies prefectural, municipal, and designated-city assemblies", () => {
  assertEquals(inferAssemblyCategory("東京都議会議員"), "prefectural");
  assertEquals(inferAssemblyCategory("神奈川県議会議員"), "prefectural");
  assertEquals(inferAssemblyCategory("千代田区議会議員"), "municipal");
  assertEquals(inferAssemblyCategory("横浜市会議員"), "municipal");
  assertEquals(inferAssemblyCategory("名古屋市会議員"), "municipal");
  assertEquals(inferAssemblyCategory("国会議員"), "other");
});

Deno.test("parsePrefectureMembers parses current council-grouped HTML and excludes Diet members", () => {
  const html = `
    <section class="member_sec">
      <h2 class="member_sec_ttl">国会議員<span class="member_sec_count">（1名）</span></h2>
      <ul class="member_list">
        <li>
          <dl class="profile">
            <dt class="name"><a href="/member/diet-one">国会 太郎</a></dt>
            <dd><div class="kind">東京都第1区</div></dd>
          </dl>
        </li>
      </ul>
    </section>
    <section class="member_sec">
      <h2 class="member_sec_ttl">東京都議会議員<span class="member_sec_count">（1名）</span></h2>
      <ul class="member_list">
        <li>
          <dl class="profile">
            <dt class="name"><a href="/member/pref-one">都議 花子</a></dt>
            <dd>
              <div class="kana">とぎ はなこ</div>
              <div class="kind">港区</div>
              <div class="times">当選1回</div>
            </dd>
          </dl>
        </li>
      </ul>
    </section>
    <section class="member_sec">
      <h2 class="member_sec_ttl">横浜市会議員<span class="member_sec_count">（1名）</span></h2>
      <ul class="member_list">
        <li>
          <dl class="profile">
            <dt class="name"><a href="/member/city-one">横浜 次郎</a></dt>
            <dd>
              <div class="kana">よこはま じろう</div>
              <div class="kind">西区</div>
              <div class="times">当選2回</div>
            </dd>
          </dl>
        </li>
      </ul>
    </section>
  `;

  const members = parsePrefectureMembers(
    "東京都",
    "https://new-kokumin.jp/member_tag/tokyo",
    html,
  );
  assertEquals(members.length, 2);
  assertEquals(members[0].name, "都議 花子");
  assertEquals(members[0].assemblyCategory, "prefectural");
  assertEquals(members[0].assemblyLabel, "東京都議会議員");
  assertEquals(members[1].name, "横浜 次郎");
  assertEquals(members[1].assemblyCategory, "municipal");
  assertEquals(members[1].assemblyLabel, "横浜市会議員");
});

Deno.test("parsePrefectureMembers retains legacy section heading format", () => {
  const html = `
    <h2 class="member_sec_ttl">東京都の地方自治体議員</h2>
    <ul class="member_list">
      <li>
        <dl class="profile">
          <dt class="name"><a href="/member/legacy-one">従来 三郎</a></dt>
          <dd>
            <div class="kind">東京都渋谷区</div>
            <div class="area">渋谷区議会議員</div>
          </dd>
        </dl>
      </li>
    </ul>
  `;

  const members = parsePrefectureMembers(
    "東京都",
    "https://new-kokumin.jp/member_tag/tokyo",
    html,
  );
  assertEquals(members.length, 1);
  assertEquals(members[0].name, "従来 三郎");
  assertEquals(members[0].assemblyCategory, "municipal");
  assertEquals(members[0].municipality, "渋谷区");
});

Deno.test("parseOfficialElectionPrefectureLinks supports candidate-mode member_tag links and legacy links", () => {
  const html = `
    <ul>
      <li><a href="https://new-kokumin.jp/member_tag/tokyo?mode=candidate">東京都</a></li>
      <li><a href="https://new-kokumin.jp/member_tag/tokyo">東京都</a></li>
      <li><a href="/?post_type=election&prefectures=osaka">大阪府</a></li>
    </ul>
  `;

  const links = parseOfficialElectionPrefectureLinks(html);
  assertEquals(links.size, 2);
  assertEquals(
    links.get("東京都"),
    "https://new-kokumin.jp/member_tag/tokyo?mode=candidate",
  );
  assertEquals(
    links.get("大阪府"),
    "https://new-kokumin.jp/?post_type=election&prefectures=osaka",
  );
});

Deno.test("parseOfficialElectionPrefectureLinks extracts escaped URLs from embedded JSON", () => {
  const html = `
    <script>
      window.__PREF_LINKS__ = {
        "東京都": "https:\\/\\/new-kokumin.jp\\/member_tag\\/tokyo?mode=candidate",
        "比例区": "https:\\/\\/new-kokumin.jp\\/member_tag\\/hirei?mode=candidate",
        "神奈川県": "https:\\/\\/new-kokumin.jp\\/member_tag\\/kanagawa?mode=candidate"
      };
    </script>
  `;

  const links = parseOfficialElectionPrefectureLinks(
    html,
    "https://new-kokumin.jp/election-local",
  );
  assertEquals(links.size, 2);
  assertEquals(
    links.get("東京都"),
    "https://new-kokumin.jp/member_tag/tokyo?mode=candidate",
  );
  assertEquals(
    links.get("神奈川県"),
    "https://new-kokumin.jp/member_tag/kanagawa?mode=candidate",
  );
});

Deno.test("parseOfficialScheduledCandidates parses current election-grouped HTML and excludes national elections", () => {
  const html = `
    <h2 class="member_sec_ttl">衆議院議員選挙<span class="member_sec_count">（1名）</span></h2>
    <ul class="member_list">
      <li>
        <dl class="profile">
          <dt class="name"><a href="/member/nat-one">国政 一郎</a></dt>
          <dd><div class="wins">公認・新人</div></dd>
        </dl>
      </li>
    </ul>
    <h2 class="member_sec_ttl">千代田区議会議員選挙<span class="member_sec_count">（1名）</span></h2>
    <p class="member_sec_schedule_wrap"><span class="member_sec_schedule">任期満了日 2027.04.30／投開票日未定</span></p>
    <ul class="member_list">
      <li>
        <dl class="profile">
          <dt class="name"><a href="/member/cand-one">田中 えりか</a></dt>
          <dd>
            <div class="kana">たなか えりか</div>
            <div class="wins">公認・現職（当選1回）</div>
          </dd>
        </dl>
      </li>
    </ul>
  `;

  const candidates = parseOfficialScheduledCandidates(
    "東京都",
    "https://new-kokumin.jp/member_tag/tokyo?mode=candidate",
    html,
  );
  assertEquals(candidates.length, 1);
  assertEquals(candidates[0].name, "田中 えりか");
  assertEquals(candidates[0].electionName, "千代田区議会議員選挙");
  assertEquals(candidates[0].statusLabel, "公認・現職（当選1回）");
  assertEquals(candidates[0].voteDate, "");
});

Deno.test("parseOfficialScheduledCandidates retains legacy planned-candidate card format", () => {
  const html = `
    <h2 class="member_sec_ttl">東京都の候補予定者</h2>
    <ul class="member_list">
      <li>
        <dl class="profile">
          <dt class="name"><a href="/member/legacy-cand">予定 四郎</a></dt>
          <dd>
            <div class="times">多摩市議会議員補欠選挙</div>
            <div class="m_category">2026年4月12日</div>
            <div class="wins">公認・新人</div>
          </dd>
        </dl>
      </li>
    </ul>
  `;

  const candidates = parseOfficialScheduledCandidates(
    "東京都",
    "https://new-kokumin.jp/?post_type=election&prefectures=tokyo",
    html,
  );
  assertEquals(candidates.length, 1);
  assertEquals(candidates[0].name, "予定 四郎");
  assertEquals(candidates[0].electionName, "多摩市議会議員補欠選挙");
  assertEquals(candidates[0].voteDate, "2026-04-12");
});
