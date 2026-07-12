import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildGrowthDataReport,
  type GrowthReportRow,
} from "./x_growth_data_report.ts";
import { classifyPostArchetype } from "./x_post_archetype.ts";

const NOW = new Date("2026-07-12T03:00:00Z");
const URL = "https://my-web-app-b67f4.web.app/?utm_content=weekly_data_report";

function row(partial: Partial<GrowthReportRow>): GrowthReportRow {
  return {
    archetype: "news_briefing",
    variant: "daily_briefing",
    impressions: null,
    score: 0,
    bookmarkCount: 0,
    text: "hook",
    createdAt: "2026-07-10T00:00:00Z",
    ...partial,
  };
}

const MEASURED_ROWS: GrowthReportRow[] = [
  row({
    archetype: "data_report",
    variant: "local_election_tally",
    impressions: 3200,
    score: 3200,
    text: "国民民主党 地方議員集計 2026/07/10",
    createdAt: "2026-07-10T12:24:00Z",
  }),
  row({
    impressions: 517,
    score: 517,
    text: "デイリーブリーフィング — 2026年7月12日朝",
    createdAt: "2026-07-11T22:00:00Z",
  }),
  row({
    impressions: 28,
    score: 28,
    text: "今日の見出しは「Apple、OpenAIと元従業員2人を提訴」",
    createdAt: "2026-07-12T01:00:00Z",
  }),
];

Deno.test("buildGrowthDataReport refuses to compose from <3 measured rows", () => {
  assertEquals(buildGrowthDataReport([], NOW, URL), null);
  assertEquals(
    buildGrowthDataReport(MEASURED_ROWS.slice(0, 2), NOW, URL),
    null,
  );
  // impressions null の行は実測に数えない。
  assertEquals(
    buildGrowthDataReport(
      [...MEASURED_ROWS.slice(0, 2), row({ impressions: null })],
      NOW,
      URL,
    ),
    null,
  );
});

Deno.test("buildGrowthDataReport composes a post-A style lead from real numbers", () => {
  const report = buildGrowthDataReport(MEASURED_ROWS, NOW, URL);
  assert(report !== null);
  // 主要実数は全て入力行から導出された実測値。
  assert(report!.text.includes("取得日時: 2026-07-12T03:00:00.000Z"));
  assert(report!.text.includes("計測済み投稿数: 3件"));
  assert(report!.text.includes("中央値インプレッション: 517"));
  assert(report!.text.includes("最高インプレッション: 3200"));
  assert(report!.text.includes("基準10,000との差分: -6800"));
  assert(report!.text.includes("10,000まで残り: 6800"));
  assert(report!.text.includes("直近7日の計測対象: 3件"));
  // JST 日付ラベル(UTC 03:00 = JST 12:00 同日)。
  assert(report!.text.includes("X運用実測レポート 2026/7/12"));
  assertEquals(report!.measuredCount, 3);
  assertEquals(report!.medianImpressions, 517);
  assertEquals(report!.bestImpressions, 3200);
});

Deno.test("buildGrowthDataReport output self-classifies as data_report", () => {
  // R23 の教訓の自己整合: このレポート自身が data_report バケットに入り、
  // Archetype lift の実測を自力で蓄積できる形であることを固定する。
  const report = buildGrowthDataReport(MEASURED_ROWS, NOW, URL);
  assert(report !== null);
  const full = [report!.text, ...report!.replyTexts].join("\n");
  assertEquals(classifyPostArchetype(full), "data_report");
});

Deno.test("buildGrowthDataReport replies carry breakdown, top posts, alerts, and final URL", () => {
  const report = buildGrowthDataReport(MEASURED_ROWS, NOW, URL);
  assert(report !== null);
  const [buckets, top, alerts, cta] = report!.replyTexts;
  // 型別実測: n>=2 は平均、n=1 は実測不足表記。
  assert(buckets.includes("投稿の型別実測"));
  assert(buckets.includes("データレポート型 実測不足 (1件)"));
  assert(buckets.includes("ニュース要約型 平均スコア273 (2件)"));
  // 実測上位は impressions 降順。
  assert(top.includes("インプレッション上位"));
  assert(top.indexOf("3200") < top.indexOf("517"));
  // アラート: 実測不足の型が列挙される(直近7日は投稿ありなので🔴なし)。
  assert(alerts.includes("アラート"));
  assert(alerts.includes("🟡 実測不足の型: データレポート型"));
  assert(!alerts.includes("🔴"));
  // URL は最終リプライのみ(link-in-reply の実測勝ち構造)。
  assert(cta.includes(URL));
  assert(!report!.text.includes(URL));
});

Deno.test("buildGrowthDataReport raises alerts for stale weeks and fallback floods", () => {
  const staleRows = MEASURED_ROWS.map((entry) => ({
    ...entry,
    createdAt: "2026-06-01T00:00:00Z",
    variant: "daily_briefing_fallback",
  }));
  const report = buildGrowthDataReport(staleRows, NOW, URL);
  assert(report !== null);
  assert(report!.text.includes("直近7日の計測対象: 0件"));
  const alerts = report!.replyTexts.find((entry) => entry.includes("アラート"))!;
  assert(alerts.includes("🔴 直近7日の計測対象が0件"));
  assert(alerts.includes("🟡 定型文フォールバック比率が高い: 3/3件"));
});

Deno.test("buildGrowthDataReport reports surplus once past the 10K target", () => {
  const winners = MEASURED_ROWS.map((entry, index) => ({
    ...entry,
    impressions: 12000 + index,
    score: 12000 + index,
  }));
  const report = buildGrowthDataReport(winners, NOW, URL);
  assert(report !== null);
  assert(report!.text.includes("基準10,000との差分: +2002"));
  assert(report!.text.includes("10,000まで残り: 0"));
});
