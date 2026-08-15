import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildArchetypeTopicInteractionLine,
  buildIcpHistoricalExemplarLine,
  buildIcpScopeLine,
  buildTopicLiftLine,
  classifyPostTopic,
  ICP_TARGET_TOPIC,
  normalizeTopicBucket,
  selectIcpCohort,
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

// R28: 楔 (借金・リボ払い) の ICP コホートへスコープする回帰テスト。
Deno.test("classifyPostTopic: 借金・リボは household_finance でなく debt_recovery", () => {
  assertEquals(
    classifyPostTopic("リボ払いの残債を今月2万円繰り上げ返済しました"),
    "debt_recovery",
  );
  assertEquals(classifyPostTopic("完済まであと18ヶ月"), "debt_recovery");
  // 借金語が無い一般家計は従来どおり household_finance。
  assertEquals(
    classifyPostTopic("今月の家計の支出を見直して節約しました"),
    "household_finance",
  );
  // 政治アンカーは引き続き最優先 (実測でリーチを支配するため)。
  assertEquals(
    classifyPostTopic("国民民主党 地方議員集計 返済"),
    "japan_politics",
  );
});

Deno.test("selectIcpCohort: 対象トピックだけを切り出す", () => {
  const rows = [
    { topic: "japan_politics" },
    { topic: "debt_recovery" },
    { topic: "debt_recovery" },
    { topic: "ai_tech" },
  ];
  const sel = selectIcpCohort(rows, (r) => r.topic);
  assertEquals(sel.target, ICP_TARGET_TOPIC);
  assertEquals(sel.rows.length, 2);
  assertEquals(sel.totalCount, 4);
  assert(sel.sufficient);
});

Deno.test("selectIcpCohort: 薄いコホートは sufficient=false (グローバルへ落ちない)", () => {
  const rows = [
    { topic: "japan_politics" },
    { topic: "japan_politics" },
    { topic: "debt_recovery" },
  ];
  const sel = selectIcpCohort(rows, (r) => r.topic);
  assertEquals(sel.rows.length, 1);
  assert(!sel.sufficient, "1 件で勝者を名乗ってはいけない");
  // 空でも同じ (グローバル最大へフォールバックしない)。
  const empty = selectIcpCohort([{ topic: "japan_politics" }], (r) => r.topic);
  assertEquals(empty.rows.length, 0);
  assert(!empty.sufficient);
});

Deno.test("buildIcpScopeLine: 薄いときは他トピックの勝者を真似るなと明示する", () => {
  const thin = buildIcpScopeLine(
    selectIcpCohort([{ topic: "japan_politics" }], (r) => r.topic),
  );
  assert(thin.includes("not enough to name a winner"));
  assert(thin.includes("Do NOT copy"));
  assert(thin.includes("different audience"));

  const ok = buildIcpScopeLine(
    selectIcpCohort(
      [{ topic: "debt_recovery" }, { topic: "debt_recovery" }],
      (r) => r.topic,
    ),
  );
  assert(ok.includes("scoped to topic=debt_recovery"));
  assert(!ok.includes("Do NOT copy"));
});

// R28 fix: 「ICP投稿が1本も無い」と「あるが年齢比較できない」の区別。
// CSV 取込行は historical_benchmark で learningRows から除外されるため、
// 前者としてしか報告されず、次の一手を誤らせていた。
Deno.test("buildIcpScopeLine: 取り込み履歴が無いときは『まず書け』", () => {
  const line = buildIcpScopeLine(
    selectIcpCohort([{ topic: "japan_politics" }], (r) => r.topic),
    0,
  );
  assert(line.includes("No ICP post has been measured at all yet"));
  assert(line.includes("write for the"));
  assert(!line.includes("imported historical"));
});

Deno.test("buildIcpScopeLine: 取り込み履歴があるときは別の次の一手を出す", () => {
  const line = buildIcpScopeLine(
    selectIcpCohort([{ topic: "japan_politics" }], (r) => r.topic),
    7,
  );
  assert(line.includes("7 imported historical ICP post(s) exist"));
  // lifetime cumulative なので年齢正規化ランキングには載せられない、と明示。
  assert(line.includes("lifetime-cumulative"));
  assert(line.includes("audience evidence only"));
  // 次の一手は「書け」ではなく「アプリ経由で投稿して計測を貯めろ」。
  assert(line.includes("post ICP content through the app"));
  assert(!line.includes("No ICP post has been measured at all yet"));
});

Deno.test("buildIcpScopeLine: 十分なら履歴件数に関わらずスコープ宣言のまま", () => {
  const enough = selectIcpCohort(
    [{ topic: "debt_recovery" }, { topic: "debt_recovery" }],
    (r) => r.topic,
  );
  assert(
    buildIcpScopeLine(enough, 9).includes("scoped to topic=debt_recovery"),
  );
  assert(!buildIcpScopeLine(enough, 9).includes("imported historical"));
});

// R29: 取り込んだ ICP 履歴を「順位付けせず手本として」渡す。
type Ex = { c: number; i: number | null; t: string };
const exLine = (rows: Ex[]) =>
  buildIcpHistoricalExemplarLine(
    rows,
    (r) => r.c,
    (r) => r.i,
    (r) => r.t,
  );

Deno.test("buildIcpHistoricalExemplarLine: 履歴が無ければ沈黙", () => {
  assertEquals(exLine([]), null);
});

Deno.test("buildIcpHistoricalExemplarLine: 全件0クリックなら『効いていない』と言う", () => {
  const line = exLine([
    { c: 0, i: 120, t: "残債を減らした話" },
    { c: 0, i: 80, t: "リボの利息を計算した" },
  ]);
  assert(line !== null);
  // 「手本が無い」と「手本はあるが効いていない」を混ぜない。
  assert(line!.includes("none of them produced a single url click"));
  assert(line!.includes("fresh test"));
  assert(!line!.includes("copy their structure"));
});

Deno.test("buildIcpHistoricalExemplarLine: クリック降順で手本を出す", () => {
  const line = exLine([
    { c: 1, i: 300, t: "低クリック" },
    { c: 9, i: 4000, t: "高クリック" },
    { c: 0, i: 50, t: "ゼロ" },
    { c: 4, i: 900, t: "中クリック" },
  ]);
  assert(line !== null);
  assert(line!.indexOf("高クリック") < line!.indexOf("中クリック"));
  assert(!line!.includes("ゼロ"), "0クリックは手本にしない");
  assert(line!.includes("2/4") === false);
  assert(line!.includes("3/4 posts got >=1 click"));
  // 順位の主張はしない = ランキングから除外されている旨を必ず添える。
  assert(line!.includes("NOT age-normalized"));
  assert(line!.includes("excluded"));
  assert(line!.includes("copy their structure, not their rank"));
});
