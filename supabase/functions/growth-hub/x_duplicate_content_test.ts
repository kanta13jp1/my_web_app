import {
  assert,
  assertAlmostEquals,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  contentSimilarity,
  DEFAULT_DUPLICATE_RECENT_COUNT,
  DEFAULT_DUPLICATE_THRESHOLD,
  editSimilarity,
  extractPostedTexts,
  findDuplicateContent,
  jaccardSimilarity,
  MAX_DUPLICATE_RECENT_COUNT,
  MIN_DUPLICATE_THRESHOLD,
  normalizeForSimilarity,
  resolveDuplicateGuardConfig,
  type XPostLogRowLike,
} from "./x_duplicate_content.ts";

Deno.test("normalizeForSimilarity strips URLs, punctuation, whitespace and NFKC-folds", () => {
  // 全角英数 → 半角、URL 除去、記号除去、空白除去
  assertEquals(
    normalizeForSimilarity(
      "Ｈｅｌｌｏ  World!!  https://example.com/x?y=1 #tag",
    ),
    "helloworldtag",
  );
  assertEquals(
    normalizeForSimilarity("今日 は、良い 天気。"),
    "今日は良い天気",
  );
  assertEquals(normalizeForSimilarity("   "), "");
  assertEquals(normalizeForSimilarity(null), "");
});

Deno.test("jaccardSimilarity: identical=1, disjoint=0, symmetric", () => {
  assertEquals(jaccardSimilarity("abcd", "abcd"), 1);
  assertEquals(jaccardSimilarity("abcd", "wxyz"), 0);
  assertEquals(
    jaccardSimilarity("abcd", "abce"),
    jaccardSimilarity("abce", "abcd"),
  );
});

Deno.test("editSimilarity: identical=1, both-empty=1, one-char diff is high", () => {
  assertEquals(editSimilarity("abcde", "abcde"), 1);
  assertEquals(editSimilarity("", ""), 1);
  assertAlmostEquals(editSimilarity("abcde", "abcdX"), 0.8, 1e-9);
});

Deno.test("contentSimilarity: exact duplicate scores 1", () => {
  assertEquals(
    contentSimilarity(
      "今日のニュース: AIが世界を変える #自分株式会社",
      "今日のニュース: AIが世界を変える #自分株式会社",
    ),
    1,
  );
});

Deno.test("contentSimilarity: only the trailing URL differs → near duplicate", () => {
  const a =
    "自分株式会社なら21個のアプリが1つに。無料で始めよう https://a.example.com/1";
  const b =
    "自分株式会社なら21個のアプリが1つに。無料で始めよう https://b.example.com/2";
  assert(
    contentSimilarity(a, b) >= DEFAULT_DUPLICATE_THRESHOLD,
    `expected near-duplicate, got ${contentSimilarity(a, b)}`,
  );
});

Deno.test("contentSimilarity: distinct posts score below default threshold", () => {
  const a = "本日のAIトレンド: 大規模モデルの推論コストが急落しています。";
  const b = "週末は資産管理を見直そう。負債の返済計画を立てる3ステップ。";
  assert(
    contentSimilarity(a, b) < DEFAULT_DUPLICATE_THRESHOLD,
    `expected distinct, got ${contentSimilarity(a, b)}`,
  );
});

Deno.test("contentSimilarity: empty-after-normalize is fail-open (0)", () => {
  // URL のみ → 正規化で空 → 誤ブロック回避のため 0
  assertEquals(contentSimilarity("https://x.com/a", "https://x.com/b"), 0);
});

Deno.test("findDuplicateContent: blocks a near-identical candidate", () => {
  const config = { threshold: 0.9, recentCount: 5 };
  const match = findDuplicateContent(
    "自分株式会社は21個のアプリを1つに統合します。無料で使えます。",
    [
      { text: "資産管理で負債を減らす方法を紹介します。", id: "1" },
      {
        text: "自分株式会社は21個のアプリを1つに統合します。無料で使える！",
        id: "2",
        createdAt: "2026-07-04T00:00:00Z",
      },
    ],
    config,
  );
  assert(match !== null, "expected a duplicate match");
  assertEquals(match?.matchedId, "2");
  assertEquals(match?.matchedCreatedAt, "2026-07-04T00:00:00Z");
  assert((match?.similarity ?? 0) >= 0.9);
});

Deno.test("findDuplicateContent: returns null for a genuinely fresh post", () => {
  const config = { threshold: 0.9, recentCount: 5 };
  const match = findDuplicateContent(
    "全く新しい話題: 今日は競馬の予想ロジックをAIで検証しました。",
    [
      { text: "自分株式会社は21個のアプリを1つに統合します。", id: "1" },
      { text: "資産管理で負債を減らす方法を紹介します。", id: "2" },
    ],
    config,
  );
  assertEquals(match, null);
});

Deno.test("findDuplicateContent: picks the highest-similarity match", () => {
  const config = { threshold: 0.8, recentCount: 5 };
  const candidate = "AIが世界を変える。今日のニュースをまとめました。";
  const match = findDuplicateContent(
    candidate,
    [
      { text: "AIが世界を変える。今日のニュースをまとめた。", id: "close" },
      { text: "AIが世界を変える。今日のニュースをまとめました。", id: "exact" },
    ],
    config,
  );
  assertEquals(match?.matchedId, "exact");
  assertEquals(match?.similarity, 1);
});

Deno.test("findDuplicateContent: recentCount=0 disables the guard", () => {
  const match = findDuplicateContent(
    "同じ文面",
    [{ text: "同じ文面", id: "1" }],
    { threshold: 0.9, recentCount: 0 },
  );
  assertEquals(match, null);
});

Deno.test("findDuplicateContent: only compares up to recentCount posts", () => {
  const older = { text: "限定コピーの投稿本文です。", id: "old" };
  const filler = Array.from({ length: 5 }, (_v, i) => ({
    text: `無関係な投稿 ${i} 全然別の話題`,
    id: `f${i}`,
  }));
  // older は先頭から数えて 6 番目 → recentCount=5 なら比較対象外
  const match = findDuplicateContent(
    "限定コピーの投稿本文です。",
    [...filler, older],
    { threshold: 0.9, recentCount: 5 },
  );
  assertEquals(match, null);
});

Deno.test("resolveDuplicateGuardConfig: defaults when unset", () => {
  const cfg = resolveDuplicateGuardConfig({});
  assertEquals(cfg.threshold, DEFAULT_DUPLICATE_THRESHOLD);
  assertEquals(cfg.recentCount, DEFAULT_DUPLICATE_RECENT_COUNT);
});

Deno.test("resolveDuplicateGuardConfig: parses and clamps env values", () => {
  assertEquals(
    resolveDuplicateGuardConfig({ threshold: "0.95", recentCount: "3" }),
    { threshold: 0.95, recentCount: 3 },
  );
  // 下限/上限へクランプ
  assertEquals(
    resolveDuplicateGuardConfig({ threshold: "0.1", recentCount: "999" }),
    {
      threshold: MIN_DUPLICATE_THRESHOLD,
      recentCount: MAX_DUPLICATE_RECENT_COUNT,
    },
  );
  assertEquals(
    resolveDuplicateGuardConfig({ threshold: "5", recentCount: "-4" }),
    { threshold: 1, recentCount: 0 },
  );
  // 不正値 → 既定
  assertEquals(
    resolveDuplicateGuardConfig({ threshold: "abc", recentCount: "" }),
    {
      threshold: DEFAULT_DUPLICATE_THRESHOLD,
      recentCount: DEFAULT_DUPLICATE_RECENT_COUNT,
    },
  );
});

Deno.test("extractPostedTexts: keeps only posted rows with text, newest-first, capped", () => {
  const rows: XPostLogRowLike[] = [
    { id: 1, created_at: "t1", metadata: { status: "posted", text: "A" } },
    { id: 2, created_at: "t2", metadata: { status: "dry_run", text: "B" } },
    { id: 3, created_at: "t3", metadata: { status: "failed", text: "C" } },
    { id: 4, created_at: "t4", metadata: { status: "posted", text: "   " } },
    { id: 5, created_at: "t5", metadata: { status: "posted", text: "D" } },
    {
      id: 6,
      created_at: "t6",
      metadata: { status: "rejected_duplicate", text: "E" },
    },
    { id: 7, created_at: "t7", metadata: { status: "posted", text: "F" } },
  ];
  assertEquals(extractPostedTexts(rows, 10), [
    { text: "A", id: "1", createdAt: "t1" },
    { text: "D", id: "5", createdAt: "t5" },
    { text: "F", id: "7", createdAt: "t7" },
  ]);
  // limit を尊重
  assertEquals(extractPostedTexts(rows, 1), [
    { text: "A", id: "1", createdAt: "t1" },
  ]);
  assertEquals(extractPostedTexts(rows, 0), []);
});

Deno.test("extractPostedTexts: tolerates missing/odd metadata shapes", () => {
  const rows: XPostLogRowLike[] = [
    { id: 1 },
    { id: 2, metadata: null },
    { id: 3, metadata: "nope" },
    { id: 4, metadata: { status: "posted" } }, // text 欠落
    { id: 5, metadata: { status: "posted", text: 123 } }, // text が非文字列
  ];
  assertEquals(extractPostedTexts(rows, 10), []);
});

Deno.test("contentSimilarity: long-form posts stay fast via edit-distance clamp", () => {
  // R24: 選挙集計等の長文(10k-24k字)が x.post を通るようになり、全文
  // Levenshtein は O(n*m) で edge CPU 予算超過(実測 18k×18k ≈ 3.1s)。
  // 先頭スライス近似でも「ほぼ同一の長文テンプレ」は依然 duplicate 検出される
  // こと+完走時間が桁で縮むことを固定する。
  const base = "国民民主党 地方議員集計 2026/07/10 公式地方議員数378人\n"
    .repeat(700);
  const refreshed = base.replaceAll("378人", "381人");
  const start = Date.now();
  const similar = contentSimilarity(base, refreshed);
  const elapsed = Date.now() - start;
  if (!(similar >= 0.9)) {
    throw new Error(`expected near-duplicate, got ${similar}`);
  }
  if (!(elapsed < 1500)) {
    throw new Error(`edit-distance clamp did not keep it fast: ${elapsed}ms`);
  }
  // 別内容の長文は duplicate にならない(clamp が false-positive を作らない)。
  const other =
    "全く別の話題。家計の負債トレンドを月次で検出して翌月の行動を出す。\n"
      .repeat(600);
  if (!(contentSimilarity(base, other) < 0.9)) {
    throw new Error("unrelated long posts must not match");
  }
});
