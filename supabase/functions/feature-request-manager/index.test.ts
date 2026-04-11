// feature-request-manager EF 単体テスト
// 対象: normalizeCategory / buildFeedbackTitle 等の純粋ヘルパー
// (top-level serve() のため index.ts 直接 import は行わず、アルゴリズムを同一コピーして検証)
// 外部 import (std/testing/asserts) を避け、軽量アサーションをインラインで定義する。

function assertEquals<T>(actual: T, expected: T, msg?: string): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error(
      `assertEquals failed: expected ${e}, got ${a}${msg ? ` — ${msg}` : ""}`,
    );
  }
}

type FeedbackCategory = "feature" | "bug" | "other";

// index.ts L391-397 と同一ロジック
function normalizeCategory(raw: unknown): FeedbackCategory {
  const value = String(raw ?? "").trim().toLowerCase();
  if (value === "feature" || value === "bug" || value === "other") {
    return value;
  }
  return "other";
}

// index.ts L399-409 と同一ロジック
function buildFeedbackTitle(
  category: FeedbackCategory,
  content: string,
): string {
  const prefix = category === "bug"
    ? "不具合報告"
    : category === "feature"
    ? "改善要望"
    : "ご意見";
  const firstLine = content.split(/\r?\n/)[0].trim();
  const compact = firstLine.replace(/\s+/g, " ");
  const trimmed = compact.length > 72 ? `${compact.slice(0, 72)}...` : compact;
  return `${prefix}: ${trimmed}`;
}

Deno.test("normalizeCategory: 正常系 3カテゴリ", () => {
  assertEquals(normalizeCategory("feature"), "feature");
  assertEquals(normalizeCategory("bug"), "bug");
  assertEquals(normalizeCategory("other"), "other");
});

Deno.test("normalizeCategory: 大文字・空白正規化", () => {
  assertEquals(normalizeCategory("  Feature  "), "feature");
  assertEquals(normalizeCategory("BUG"), "bug");
  assertEquals(normalizeCategory("Other"), "other");
});

Deno.test("normalizeCategory: 不正値はデフォルト 'other'", () => {
  assertEquals(normalizeCategory(""), "other");
  assertEquals(normalizeCategory(null), "other");
  assertEquals(normalizeCategory(undefined), "other");
  assertEquals(normalizeCategory("unknown"), "other");
  assertEquals(normalizeCategory(123), "other");
  assertEquals(normalizeCategory({ x: 1 }), "other");
});

Deno.test("buildFeedbackTitle: カテゴリ別プレフィックス", () => {
  assertEquals(
    buildFeedbackTitle("bug", "ボタンが押せない"),
    "不具合報告: ボタンが押せない",
  );
  assertEquals(
    buildFeedbackTitle("feature", "ダークモード追加"),
    "改善要望: ダークモード追加",
  );
  assertEquals(
    buildFeedbackTitle("other", "良いサービスですね"),
    "ご意見: 良いサービスですね",
  );
});

Deno.test("buildFeedbackTitle: 改行は1行目のみ採用", () => {
  const title = buildFeedbackTitle(
    "bug",
    "1行目のエラー内容\n2行目の詳細\n3行目",
  );
  assertEquals(title, "不具合報告: 1行目のエラー内容");
});

Deno.test("buildFeedbackTitle: 連続空白を1スペースに圧縮", () => {
  const title = buildFeedbackTitle("feature", "AAA    BBB\t\tCCC");
  assertEquals(title, "改善要望: AAA BBB CCC");
});

Deno.test("buildFeedbackTitle: 72文字超は省略", () => {
  const longContent = "あ".repeat(100);
  const title = buildFeedbackTitle("other", longContent);
  // prefix "ご意見: " (5文字) + "あ" × 72 + "..." (3文字)
  assertEquals(title.length, 5 + 72 + 3);
  assertEquals(title.endsWith("..."), true);
});

Deno.test("buildFeedbackTitle: 72文字以内は省略なし", () => {
  const content = "あ".repeat(72);
  const title = buildFeedbackTitle("other", content);
  assertEquals(title.endsWith("..."), false);
  assertEquals(title, `ご意見: ${content}`);
});

Deno.test("buildFeedbackTitle: 空文字でもクラッシュしない", () => {
  const title = buildFeedbackTitle("other", "");
  assertEquals(title, "ご意見: ");
});

Deno.test("GitHub label 計算: category に応じた bug/enhancement ラベル", () => {
  const buildLabels = (category: FeedbackCategory): string[] => [
    "user-feedback",
    "claude-managed-agents",
    "github-issue-fix",
    category === "bug" ? "bug" : "enhancement",
  ];

  const bugLabels = buildLabels("bug");
  assertEquals(bugLabels.includes("bug"), true);
  assertEquals(bugLabels.includes("enhancement"), false);
  assertEquals(bugLabels.length, 4);

  const featureLabels = buildLabels("feature");
  assertEquals(featureLabels.includes("enhancement"), true);
  assertEquals(featureLabels.includes("bug"), false);

  const otherLabels = buildLabels("other");
  assertEquals(otherLabels.includes("enhancement"), true);
});

Deno.test("vote 加算: null/undefined を 0 扱い", () => {
  const calcNext = (current: number | null | undefined): number =>
    Number(current ?? 0) + 1;

  assertEquals(calcNext(5), 6);
  assertEquals(calcNext(0), 1);
  assertEquals(calcNext(null), 1);
  assertEquals(calcNext(undefined), 1);
});
