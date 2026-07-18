import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  foldVariants,
  hasNamedVariant,
  pickBestVariant,
  pickConfidentVariant,
} from "./x_best_variant.ts";

// 本番で観測された実データ形状: fallback(平均89 n=1) が本命(平均76 n=7)を
// 抑えて勝ち型に昇格していたケース。
const observed = [
  {
    variant: "daily_briefing_fallback",
    averageScore: 89,
    count: 1,
    totalScore: 89,
  },
  { variant: "daily_briefing", averageScore: 76, count: 7, totalScore: 532 },
  {
    variant: "daily_briefing_v2_numbers",
    averageScore: 27,
    count: 1,
    totalScore: 27,
  },
];

Deno.test("foldVariants: _fallback を base へ畳んで再集計する", () => {
  const folded = foldVariants(observed);
  // daily_briefing = (89 + 532)/8 = 77.6 → 78, n=8
  const db = folded.find((v) => v.variant === "daily_briefing");
  assertEquals(db?.count, 8);
  assertEquals(db?.averageScore, 78);
  // v2 はそのまま
  const v2 = folded.find((v) => v.variant === "daily_briefing_v2_numbers");
  assertEquals(v2?.count, 1);
  // daily_briefing_fallback は独立キーとして残らない
  assertEquals(
    folded.some((v) => v.variant === "daily_briefing_fallback"),
    false,
  );
});

Deno.test("foldVariants: unknown / 空を除外", () => {
  const folded = foldVariants([
    { variant: "unknown", averageScore: 999, count: 20 },
    { variant: "", averageScore: 5, count: 1 },
    { variant: "question_post", averageScore: 40, count: 3 },
  ]);
  assertEquals(folded.map((v) => v.variant), ["question_post"]);
});

Deno.test("pickConfidentVariant: n>=2 の畳み込み最上位のみ返す", () => {
  // 畳み込み後 daily_briefing n=8 が唯一 n>=2 → それが勝ち型
  assertEquals(pickConfidentVariant(observed)?.variant, "daily_briefing");
  // 全て n=1 → confident 無し
  assertEquals(
    pickConfidentVariant([
      { variant: "a", averageScore: 90, count: 1 },
      { variant: "b", averageScore: 10, count: 1 },
    ]),
    null,
  );
});

Deno.test("pickBestVariant: 観測データで fallback ではなく base を返す", () => {
  // 旧実装は daily_briefing_fallback を返していた。畳み込みで daily_briefing。
  assertEquals(pickBestVariant(observed), "daily_briefing");
});

Deno.test("pickBestVariant: 全 n=1 は最上位平均へ / 空は fallback", () => {
  assertEquals(
    pickBestVariant([
      { variant: "a", averageScore: 90, count: 1 },
      { variant: "b", averageScore: 10, count: 1 },
    ]),
    "a",
  );
  assertEquals(pickBestVariant([]), "daily_briefing");
  assertEquals(
    pickBestVariant([{ variant: "unknown", count: 9 }]),
    "daily_briefing",
  );
  assertEquals(pickBestVariant([], "question_post"), "question_post");
});

Deno.test("hasNamedVariant: unknown のみ→false / named 混在→true", () => {
  assertEquals(hasNamedVariant([{ variant: "unknown", count: 5 }]), false);
  assertEquals(hasNamedVariant([]), false);
  assertEquals(hasNamedVariant(null), false);
  assertEquals(hasNamedVariant(observed), true);
});
