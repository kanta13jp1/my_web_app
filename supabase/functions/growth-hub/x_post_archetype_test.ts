import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildArchetypeLiftLine,
  buildOwnDataFactsLine,
  classifyPostArchetype,
  normalizeArchetypeBucket,
  resolveLoggedArchetype,
} from "./x_post_archetype.ts";

// 2026-07-12 実測 3 連投(A=3.2K / B=517 / C=28)の縮約サンプル。
const DATA_REPORT_SAMPLE = [
  "国民民主党 地方議員集計 2026/07/10",
  "取得日時: 2026-07-10T21:24:10.000",
  "公式地方議員数: 378人",
  "基準340との差分: 38人",
  "700まで残り: 322人",
  "372 → 375:+3",
  "🔴議員不在 1県: 鳥取県",
  "🟡要強化(4人以下) 19県",
  "東京都 地方議員 49人 / 香川県 26人 / 茨城県 22人",
].join("\n");

const NEWS_BRIEFING_SAMPLE = [
  "デイリーブリーフィング — 2026年7月12日朝",
  "1. 【日本政治】皇室典範改正案が衆院通過",
  "2. 【テクノロジー】Apple、OpenAIと元従業員2人を提訴",
].join("\n");

const PRODUCT_PROMO_SAMPLE = [
  "あなたの価値、埋もれていませんか?",
  "自分株式会社で自分の強みを見える化。",
  "https://my-web-app-b67f4.web.app/",
].join("\n");

Deno.test("normalizeArchetypeBucket keeps semantic values, unknown otherwise", () => {
  assertEquals(normalizeArchetypeBucket("data_report"), "data_report");
  assertEquals(normalizeArchetypeBucket("NEWS_BRIEFING"), "news_briefing");
  assertEquals(normalizeArchetypeBucket("product_promo"), "product_promo");
  assertEquals(normalizeArchetypeBucket("general"), "general");
  // 未知値・欠損は unknown(過去データを捨てない)。
  assertEquals(normalizeArchetypeBucket(""), "unknown");
  assertEquals(normalizeArchetypeBucket("weird"), "unknown");
});

Deno.test("classifyPostArchetype detects the measured A/B/C archetypes", () => {
  // A(3.2K): 独自集計データ = 取得日時/差分矢印/アラート/数値密度。
  assertEquals(classifyPostArchetype(DATA_REPORT_SAMPLE), "data_report");
  // B(517): ブリーフィングラベル + 番号付き【…】見出し。
  assertEquals(classifyPostArchetype(NEWS_BRIEFING_SAMPLE), "news_briefing");
  // 純製品プロモ(CmoPage 旧世代型): ニュース構造なし + 製品シグナル。
  assertEquals(classifyPostArchetype(PRODUCT_PROMO_SAMPLE), "product_promo");
  // どのシグナルも無い一般テキスト。
  assertEquals(classifyPostArchetype("今日は良い天気でした。"), "general");
});

Deno.test("classifyPostArchetype does not misfile briefings as data_report", () => {
  // レビュー F1 の実反例: ニュース常用語「集計(速報)」+数値矢印を含む
  // ラベル付きブリーフィングは news_briefing のまま(ラベル最優先)。
  const labeledWithWeakSignals = [
    "デイリーブリーフィング — 2026年7月13日朝",
    "1. 【政治】参院選の集計速報、投票率は前回比で上昇",
    "2. 【市場】日経平均 39,500 → 40,120 と続伸",
  ].join("\n");
  assertEquals(classifyPostArchetype(labeledWithWeakSignals), "news_briefing");
  // ラベル無しでも弱シグナル 2 つ(集計+「あとN日」)では閾値 3 に届かず、
  // 番号付きダイジェスト構造で news_briefing に落ちる。
  const unlabeledElectionNews = [
    "1. 【政治】参院選の集計速報が各局で始まる",
    "2. 【選挙】投開票まであと3日、期日前投票は増加",
  ].join("\n");
  assertEquals(classifyPostArchetype(unlabeledElectionNews), "news_briefing");
});

Deno.test("classifyPostArchetype resolves hybrids by payload precedence", () => {
  // データ密度が高ければ製品名が混ざっても data_report(独自データ軸を最優先)。
  const hybridData = DATA_REPORT_SAMPLE + "\n給料日サイクルでも同じ形式で見る。";
  assertEquals(classifyPostArchetype(hybridData), "data_report");
  // universal 経路のニュース→製品転換型(C)はニュース構造が立つ限り
  // news_briefing に寄せる(B/C の分離は variant / fallback_used 軸が担う)。
  const hybridNews = [
    "今日の見出しは「Apple、OpenAIと元従業員2人を提訴」。",
    "2. 【テクノロジー】提訴の経緯",
    "3. 【家計】給料日サイクルで月初支出を実額把握",
    "https://my-web-app-b67f4.web.app/",
  ].join("\n");
  assertEquals(classifyPostArchetype(hybridNews), "news_briefing");
});

Deno.test("resolveLoggedArchetype prefers stored value, falls back to text", () => {
  // 保存済みの意味値が最優先(本文の再分類はしない)。
  assertEquals(
    resolveLoggedArchetype("product_promo", DATA_REPORT_SAMPLE, []),
    "product_promo",
  );
  // 旧行(フィールド欠落)は リード+リプライ連結から best-effort 分類。
  assertEquals(
    resolveLoggedArchetype("", "国民民主党 地方議員集計 取得日時: 2026-07-10", [
      "372 → 375:+3",
    ]),
    "data_report",
  );
  // 本文まで欠けている行は unknown で保持。
  assertEquals(resolveLoggedArchetype("", "", []), "unknown");
});

type LiftRow = { archetype: string; score: number };

Deno.test("buildArchetypeLiftLine shows n>=2 buckets and recommends the winner", () => {
  const rows: LiftRow[] = [
    { archetype: "data_report", score: 3200 },
    { archetype: "data_report", score: 2800 },
    { archetype: "news_briefing", score: 517 },
    { archetype: "news_briefing", score: 28 },
    // n=1 のバケットは表示しない。
    { archetype: "product_promo", score: 10 },
  ];
  const line = buildArchetypeLiftLine(
    rows,
    (row) => row.archetype,
    (row) => row.score,
  );
  assert(line !== null);
  // Dart 側プロンプトルール(universal_x_share_service)が verbatim 参照する
  // 行ラベルの exact prefix を固定する(クロス言語契約 / レビュー F6)。
  assert(line!.startsWith("Archetype lift (by content archetype): "));
  assert(line!.includes("data_report avg=3000 (n=2)"));
  assert(line!.includes("news_briefing avg=273 (n=2)"));
  assert(!line!.includes("product_promo"));
  assert(line!.includes("Recommendation: structure the next post as data_report"));
});

Deno.test("buildArchetypeLiftLine stays silent or hedged on sparse data", () => {
  // 全バケット n<2 → 行自体を出さない(データ希薄時は沈黙)。
  assertEquals(
    buildArchetypeLiftLine(
      [{ archetype: "data_report", score: 3200 }] as LiftRow[],
      (row) => row.archetype,
      (row) => row.score,
    ),
    null,
  );
  // 比較可能バケットが 1 つだけ → 勝者を強制しない。
  const single = buildArchetypeLiftLine(
    [
      { archetype: "news_briefing", score: 517 },
      { archetype: "news_briefing", score: 28 },
    ] as LiftRow[],
    (row) => row.archetype,
    (row) => row.score,
  );
  assert(single !== null);
  assert(single!.includes("insufficient archetype samples"));
});

type FactRow = { impressions: number | null };

Deno.test("buildOwnDataFactsLine publishes median/best only with >=3 samples", () => {
  const impressionsOf = (row: FactRow) => row.impressions;
  // 実測 2 件では沈黙(ノイズを公開実数として渡さない)。
  assertEquals(
    buildOwnDataFactsLine(
      [{ impressions: 111 }, { impressions: 28 }] as FactRow[],
      impressionsOf,
    ),
    null,
  );
  // 奇数件: 中央値はそのまま。null 行(未計測)は数えない。
  const odd = buildOwnDataFactsLine(
    [
      { impressions: 3200 },
      { impressions: 517 },
      { impressions: 28 },
      { impressions: null },
    ] as FactRow[],
    impressionsOf,
  );
  assert(odd !== null);
  // Dart 側プロンプトルールが verbatim 参照する行ラベルの exact prefix を固定。
  assert(odd!.startsWith("Own measured data ("));
  assert(odd!.includes("measured posts=3"));
  assert(odd!.includes("median impressions=517"));
  assert(odd!.includes("best impressions=3200"));
  // 偶数件: 中央 2 値の平均(四捨五入)。
  const even = buildOwnDataFactsLine(
    [
      { impressions: 10 },
      { impressions: 20 },
      { impressions: 31 },
      { impressions: 40 },
    ] as FactRow[],
    impressionsOf,
  );
  assert(even !== null);
  assert(even!.includes("median impressions=26"));
});
