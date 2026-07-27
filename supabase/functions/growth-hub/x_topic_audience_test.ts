import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildArchetypeTopicInteractionLine,
  buildTopicLiftLine,
  classifyPostTopic,
  normalizeTopicBucket,
} from "./x_topic_audience.ts";

// 実測 3 コホートの縮約サンプル (同一 data_report 型・topic 違い)。
const POLITICS =
  "国民民主党 地方議員集計 2026/07/14 取得日時: ... 公式地方議員数: 383人";
const AI_TECH =
  "AIコーディングツール定点観測 2026/7/22 Cursor changelog / Devin release notes";
const FINANCE = "家計の定点観測: 今月の支出と給料日サイクルの残高推移";
const PRODUCT = "自分株式会社を5分だけ触ってみてください #buildinpublic";

Deno.test("classifyPostTopic separates the measured cohorts", () => {
  assertEquals(classifyPostTopic(POLITICS), "japan_politics");
  assertEquals(classifyPostTopic(AI_TECH), "ai_tech");
  assertEquals(classifyPostTopic(FINANCE), "household_finance");
  assertEquals(classifyPostTopic(PRODUCT), "product");
  assertEquals(classifyPostTopic("今日は良い天気でした。"), "general");
});

Deno.test("classifyPostTopic prefers the politics anchor when topics mix", () => {
  // 実測でリーチを支配したのは政治アンカー側。AI 語が同居しても politics。
  assertEquals(
    classifyPostTopic("高市内閣のAI政策をChatGPTで整理しました"),
    "japan_politics",
  );
});

Deno.test("normalizeTopicBucket keeps known values and defaults to general", () => {
  assertEquals(normalizeTopicBucket("ai_tech"), "ai_tech");
  assertEquals(normalizeTopicBucket("JAPAN_POLITICS"), "japan_politics");
  assertEquals(normalizeTopicBucket(""), "general");
  assertEquals(normalizeTopicBucket("weird"), "general");
});

type Row = { topic: string; archetype: string; score: number };
const topicLine = (rows: Row[]) =>
  buildTopicLiftLine(rows, (r) => r.topic, (r) => r.score);

Deno.test("buildTopicLiftLine stays silent until two topics have samples", () => {
  assertEquals(topicLine([]), null);
  assertEquals(
    topicLine([
      { topic: "japan_politics", archetype: "data_report", score: 70000 },
      { topic: "japan_politics", archetype: "data_report", score: 66000 },
    ]),
    null,
  );
});

Deno.test("buildTopicLiftLine names the winning audience and the transfer warning", () => {
  const out = topicLine([
    { topic: "japan_politics", archetype: "data_report", score: 73864 },
    { topic: "japan_politics", archetype: "data_report", score: 66000 },
    { topic: "ai_tech", archetype: "data_report", score: 2 },
    { topic: "ai_tech", archetype: "data_report", score: 1 },
  ]);
  assert(out !== null);
  assert(out!.includes("japan_politics avg=69932 (n=2)"));
  assert(out!.includes("ai_tech avg=2 (n=2)"));
  assert(out!.includes("Best measured topic: japan_politics"));
  assert(out!.includes("Pick the topic first"));
});

Deno.test("buildArchetypeTopicInteractionLine exposes the non-transfer", () => {
  const out = buildArchetypeTopicInteractionLine(
    [
      { topic: "japan_politics", archetype: "data_report", score: 73864 },
      { topic: "japan_politics", archetype: "data_report", score: 66000 },
      { topic: "ai_tech", archetype: "data_report", score: 2 },
      { topic: "ai_tech", archetype: "data_report", score: 1 },
    ],
    (r) => r.archetype,
    (r) => r.topic,
    (r) => r.score,
  );
  assert(out !== null);
  assert(out!.includes("data_report: japan_politics=69932 (n=2)"));
  assert(out!.includes("ai_tech=2 (n=2)"));
  assert(out!.includes("does not transfer across topics"));
});

Deno.test("buildArchetypeTopicInteractionLine is silent without a split archetype", () => {
  // 同じ archetype が 1 トピックにしか無ければ交互作用は測れない。
  assertEquals(
    buildArchetypeTopicInteractionLine(
      [
        { topic: "japan_politics", archetype: "data_report", score: 10 },
        { topic: "japan_politics", archetype: "data_report", score: 12 },
        { topic: "ai_tech", archetype: "news_briefing", score: 3 },
        { topic: "ai_tech", archetype: "news_briefing", score: 4 },
      ],
      (r) => r.archetype,
      (r) => r.topic,
      (r) => r.score,
    ),
    null,
  );
});
