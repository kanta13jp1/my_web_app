import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildAccountAcquisitionLine,
  buildAnalyticsImportMetadata,
  parseXAnalyticsCsv,
  splitCsvRows,
  type XAnalyticsCsvRow,
} from "./x_analytics_import.ts";

// 実 CSV (account_analytics_content_2026-04-27_2026-07-25.csv) の縮約サンプル。
// Date 列が引用符内にカンマを含む点が素朴な split(",") を壊す実際の形。
const SAMPLE_CSV = [
  "Post id,Date,Post text,Post Link,Impressions,Likes,Engagements,Bookmarks,Shares,New follows,Replies,Reposts,Profile visits,Detail Expands,URL Clicks,Hashtag Clicks,Permalink Clicks",
  '2074000000000000001,"Tue, Jul 14, 2026",国民民主党 地方議員集計 2026/07/14,https://x.com/kanta13jp1/status/2074000000000000001,122978,12,300,0,0,0,0,0,129,200,66,0,0',
  '2073000000000000002,"Sun, Jul 13, 2026",女系天皇は認めないと言いつつ,https://x.com/kanta13jp1/status/2073000000000000002,57000,2500,4000,0,0,3,44,575,0,0,0,0,0',
  '2079000000000000003,"Wed, Jul 22, 2026",この定点観測はアプリ内のAIツール監視cronが毎日生成しています。,https://x.com/kanta13jp1/status/2079000000000000003,17,0,0,0,0,0,0,0,0,0,0,0,0',
].join("\n");

Deno.test("splitCsvRows keeps quoted commas and embedded newlines in one field", () => {
  const rows = splitCsvRows('a,"b,c",d\n1,"line1\nline2",3\n');
  assertEquals(rows.length, 2);
  assertEquals(rows[0], ["a", "b,c", "d"]);
  assertEquals(rows[1], ["1", "line1\nline2", "3"]);
});

Deno.test("splitCsvRows unescapes doubled quotes and drops blank rows", () => {
  const rows = splitCsvRows('a,b\n"he said ""hi""",2\n\n\n');
  assertEquals(rows.length, 2);
  assertEquals(rows[1][0], 'he said "hi"');
});

Deno.test("parseXAnalyticsCsv reads the real export shape", () => {
  const rows = parseXAnalyticsCsv(SAMPLE_CSV);
  assertEquals(rows.length, 3);
  const [dataReport, viral, tracker] = rows;
  assertEquals(dataReport.postId, "2074000000000000001");
  assertEquals(dataReport.date, "Tue, Jul 14, 2026");
  assertEquals(dataReport.impressions, 122978);
  assertEquals(dataReport.urlClicks, 66);
  assertEquals(dataReport.profileVisits, 129);
  // 到達も共感も大きいがクリック 0 の投稿。
  assertEquals(viral.likes, 2500);
  assertEquals(viral.urlClicks, 0);
  assertEquals(tracker.impressions, 17);
});

Deno.test("parseXAnalyticsCsv tolerates column reordering and unknown columns", () => {
  const csv = [
    "Date,URL Clicks,Post id,Impressions,Some New Column",
    '"Tue, Jul 14, 2026",66,2074000000000000001,122978,ignored',
  ].join("\n");
  const rows = parseXAnalyticsCsv(csv);
  assertEquals(rows.length, 1);
  assertEquals(rows[0].urlClicks, 66);
  assertEquals(rows[0].impressions, 122978);
});

Deno.test("parseXAnalyticsCsv rejects malformed, headerless and empty input", () => {
  assertEquals(parseXAnalyticsCsv(""), []);
  assertEquals(parseXAnalyticsCsv("Post id,Impressions"), []);
  // Post id が数値IDでない行は捨てる (合計/注釈行の混入対策)。
  assertEquals(
    parseXAnalyticsCsv("Post id,Impressions\nTotal,999").length,
    0,
  );
  // 必須の Post id 列が無ければ何も取り込まない。
  assertEquals(parseXAnalyticsCsv("Date,Impressions\nx,1"), []);
});

Deno.test("buildAnalyticsImportMetadata keeps imports out of the age-comparable cohort", () => {
  const row = parseXAnalyticsCsv(SAMPLE_CSV)[0];
  const meta = buildAnalyticsImportMetadata(row, {
    userId: "user-1",
    archetype: "data_report",
    observedAt: "2026-07-25T00:00:00Z",
    exportRange: "2026-04-27_2026-07-25",
  });
  // lifetime cumulative なので勝ち exemplar ランキングには入れない。
  assertEquals(meta.learning_cohort, "historical_benchmark");
  assertEquals(meta.metric_observation_kind, "lifetime_cumulative");
  assertEquals(meta.metric_provenance, "x_analytics_csv");
  assertEquals(meta.historical_benchmark_impressions, 122978);
  assertEquals(meta.content_archetype, "data_report");
  const latest = meta.latest_metrics as Record<string, unknown>;
  assertEquals(latest.url_clicks, 66);
  assertEquals(latest.profile_clicks, 129);
});

Deno.test("buildAccountAcquisitionLine reports the click concentration", () => {
  const rows = parseXAnalyticsCsv(SAMPLE_CSV);
  const line = buildAccountAcquisitionLine(rows);
  assert(line !== null);
  assert(line!.includes("url clicks=66"));
  assert(line!.includes("posts with >=1 click=1"));
  assert(line!.includes("100% of all url clicks"));
  assert(line!.includes("Reach alone did not convert"));
});

Deno.test("buildAccountAcquisitionLine stays silent without clicks or samples", () => {
  const rows = parseXAnalyticsCsv(SAMPLE_CSV);
  assertEquals(buildAccountAcquisitionLine(rows.slice(0, 2)), null);
  const zeroClick: XAnalyticsCsvRow[] = rows.map((row) => ({
    ...row,
    urlClicks: 0,
  }));
  assertEquals(buildAccountAcquisitionLine(zeroClick), null);
});
