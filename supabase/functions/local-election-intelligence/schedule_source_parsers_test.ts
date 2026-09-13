import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  parseGo2SenkyoScheduleHtml,
  parseNewKokuminElectionListHtml,
} from "./schedule_source_parsers.ts";

Deno.test("Go2senkyo parser accepts the current three-column schedule table", () => {
  const html = `
    <table><tbody>
      <tr>
        <td class="circle"><div class="circle_inner">2026/09/13</div></td>
        <td class="left">
          <a href="https://go2senkyo.com/local/senkyo/28880">
            前橋市議会議員補欠選挙
          </a>
        </td>
        <td><a href="/local/prefecture/10">群馬県</a></td>
      </tr>
    </tbody></table>`;

  assertEquals(parseGo2SenkyoScheduleHtml(html), [{
    electionName: "前橋市議会議員補欠選挙",
    prefecture: "群馬県",
    voteDate: "2026-09-13",
    detailUrl: "https://go2senkyo.com/local/senkyo/28880",
  }]);
});

Deno.test("new-kokumin parser reads the embedded JavaScript JSON dataset", () => {
  const records = [
    {
      post_id: "GUM-001",
      pref: "群馬県",
      election_name: "前橋市議会議員選挙",
      vote_day: "2026/09/13",
      period_end_day: "",
    },
    {
      post_id: "TOK-002",
      pref: "東京都",
      election_name: "多摩市議会議員選挙",
      vote_day: "",
      period_end_day: "2027/04/30",
    },
    {
      post_id: "INVALID",
      pref: "その他",
      election_name: "対象外選挙",
      vote_day: "2026/10/01",
      period_end_day: "",
    },
  ];
  const html = `<script>var elections = ${JSON.stringify(records)};</script>`;

  assertEquals(parseNewKokuminElectionListHtml(html), [
    {
      electionName: "前橋市議会議員選挙",
      prefecture: "群馬県",
      voteDate: "2026-09-13",
      detailUrl: "https://local-elections.new-kokumin.jp/form/?post_id=GUM-001",
    },
    {
      electionName: "多摩市議会議員選挙",
      prefecture: "東京都",
      voteDate: "2027-04-30",
      detailUrl: "https://local-elections.new-kokumin.jp/form/?post_id=TOK-002",
    },
  ]);
});

Deno.test("new-kokumin parser retains the legacy rendered-card fallback", () => {
  const html = `
    <section class="pref-section">
      <h2 class="pref-section-title">東京都</h2>
      <ul class="election-list">
        <li class="election-item">
          <p class="election-item-name">多摩市議会議員選挙</p>
          <p class="election-item-dates">
            告示：2027年4月20日 投開票：2027年4月25日
          </p>
          <a href="/form/?post_id=TOK-003">応募する</a>
        </li>
      </ul>
    </section>`;

  assertEquals(parseNewKokuminElectionListHtml(html), [{
    electionName: "多摩市議会議員選挙",
    prefecture: "東京都",
    voteDate: "2027-04-25",
    detailUrl: "https://local-elections.new-kokumin.jp/form/?post_id=TOK-003",
  }]);
});
