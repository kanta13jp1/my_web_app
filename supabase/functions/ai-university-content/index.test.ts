// ai-university-content EF 単体テスト
// index.ts は top-level `serve()` を持つため直接 import せず、
// **純粋ロジック** (型変換 / 認証チェック / カテゴリ検証 / 日付検証 / limit クランプ / グルーピング)
// を同アルゴリズムで再現してアルゴリズムの正しさを担保する。
// 外部 import 不使用 — CI でのネットワーク障害時にも成功する軽量テスト。

// ──────────────────────────────────────────
// 軽量アサーションヘルパー
// ──────────────────────────────────────────
function assertEquals<T>(actual: T, expected: T, msg?: string): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error(
      `assertEquals failed: expected ${e}, got ${a}${msg ? ` — ${msg}` : ""}`,
    );
  }
}

function assertStrictEquals<T>(actual: T, expected: T, msg?: string): void {
  if (actual !== expected) {
    throw new Error(
      `assertStrictEquals failed: expected ${String(expected)}, got ${
        String(actual)
      }${msg ? ` — ${msg}` : ""}`,
    );
  }
}

// ──────────────────────────────────────────
// index.ts から抽出した純粋ロジック
// ──────────────────────────────────────────
function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

const VALID_CATEGORIES = new Set([
  "overview",
  "models",
  "api",
  "pricing",
  "news",
  "tutorial",
]);

// ──────────────────────────────────────────
// テスト: asString
// ──────────────────────────────────────────
Deno.test("asString: 文字列は trim して返す", () => {
  assertStrictEquals(asString("  hello  "), "hello");
  assertStrictEquals(asString("google"), "google");
  assertStrictEquals(asString(""), "");
});

Deno.test("asString: 非文字列は空文字を返す", () => {
  assertStrictEquals(asString(null), "");
  assertStrictEquals(asString(undefined), "");
  assertStrictEquals(asString(42), "");
  assertStrictEquals(asString({}), "");
  assertStrictEquals(asString([]), "");
});

// ──────────────────────────────────────────
// テスト: asNumber
// ──────────────────────────────────────────
Deno.test("asNumber: 数値はそのまま返す", () => {
  assertStrictEquals(asNumber(10), 10);
  assertStrictEquals(asNumber(0), 0);
  assertStrictEquals(asNumber(-5, 3), -5);
});

Deno.test("asNumber: 文字列数値をパース", () => {
  assertStrictEquals(asNumber("50"), 50);
  assertStrictEquals(asNumber("0"), 0);
});

Deno.test("asNumber: 非数値はフォールバックを返す", () => {
  assertStrictEquals(asNumber(null, 99), 99);
  assertStrictEquals(asNumber(undefined, 7), 7);
  assertStrictEquals(asNumber("abc", 3), 3);
  assertStrictEquals(asNumber(NaN, 1), 1);
  assertStrictEquals(asNumber(Infinity, 0), 0);
});

// ──────────────────────────────────────────
// テスト: VALID_CATEGORIES
// ──────────────────────────────────────────
Deno.test("VALID_CATEGORIES: 6カテゴリが定義されている", () => {
  assertStrictEquals(VALID_CATEGORIES.size, 6);
  assertEquals([...VALID_CATEGORIES].sort(), [
    "api",
    "models",
    "news",
    "overview",
    "pricing",
    "tutorial",
  ]);
});

Deno.test("VALID_CATEGORIES: 有効・無効カテゴリの判定", () => {
  assertStrictEquals(VALID_CATEGORIES.has("news"), true);
  assertStrictEquals(VALID_CATEGORIES.has("overview"), true);
  assertStrictEquals(VALID_CATEGORIES.has("tutorial"), true);
  assertStrictEquals(VALID_CATEGORIES.has("unknown"), false);
  assertStrictEquals(VALID_CATEGORIES.has(""), false);
});

Deno.test("upsert_news: category 省略時は 'news' がデフォルト", () => {
  const categoryInput = asString(undefined);
  const category = categoryInput === "" ? "news" : categoryInput;
  assertStrictEquals(category, "news");
});

Deno.test("upsert_news: category 指定時はその値を使用", () => {
  const categoryInput = asString("overview");
  const category = categoryInput === "" ? "news" : categoryInput;
  assertStrictEquals(category, "overview");
});

// ──────────────────────────────────────────
// テスト: published_at バリデーション
// ──────────────────────────────────────────
Deno.test("published_at: YYYY-MM-DD 形式のみ受理", () => {
  const valid = (s: string): boolean => /^\d{4}-\d{2}-\d{2}$/.test(s);

  assertStrictEquals(valid("2026-04-12"), true, "正常");
  assertStrictEquals(valid("2026-1-1"), false, "月日が1桁");
  assertStrictEquals(valid("26-04-12"), false, "年が2桁");
  assertStrictEquals(valid("2026/04/12"), false, "スラッシュ区切り");
  assertStrictEquals(valid(""), false, "空文字");
  assertStrictEquals(valid("2026-04-12T00:00:00Z"), false, "ISO フル形式");
});

Deno.test("published_at: 不正な場合は今日の日付にフォールバック", () => {
  const todayPrefix = new Date().toISOString().slice(0, 7); // "YYYY-MM"
  const invalid = "not-a-date";
  const publishedAt = /^\d{4}-\d{2}-\d{2}$/.test(invalid)
    ? invalid
    : new Date().toISOString().slice(0, 10);
  assertStrictEquals(publishedAt.startsWith(todayPrefix), true);
});

// ──────────────────────────────────────────
// テスト: limit クランプ
// ──────────────────────────────────────────
Deno.test("get_all: limit は 1–500 にクランプ", () => {
  const clamp = (v: unknown) =>
    Math.max(1, Math.min(500, asNumber(v, 200)));

  assertStrictEquals(clamp(undefined), 200, "デフォルト 200");
  assertStrictEquals(clamp(0), 1, "下限クランプ");
  assertStrictEquals(clamp(1000), 500, "上限クランプ");
  assertStrictEquals(clamp(100), 100, "正常値");
});

Deno.test("get_by_provider: limit は 1–200 にクランプ", () => {
  const clamp = (v: unknown) =>
    Math.max(1, Math.min(200, asNumber(v, 50)));

  assertStrictEquals(clamp(undefined), 50, "デフォルト 50");
  assertStrictEquals(clamp(0), 1, "下限クランプ");
  assertStrictEquals(clamp(500), 200, "上限クランプ");
  assertStrictEquals(clamp(30), 30, "正常値");
});

// ──────────────────────────────────────────
// テスト: byProvider グルーピング
// ──────────────────────────────────────────
Deno.test("get_all: byProvider でプロバイダー別グルーピング", () => {
  const data = [
    { provider: "google", category: "news", title: "Google news" },
    { provider: "openai", category: "news", title: "OpenAI news" },
    { provider: "google", category: "overview", title: "Google overview" },
  ];

  const byProvider: Record<string, unknown[]> = {};
  for (const row of data) {
    const key = asString((row as Record<string, unknown>).provider);
    if (key === "") continue;
    (byProvider[key] ??= []).push(row);
  }

  assertStrictEquals(Object.keys(byProvider).length, 2, "2 プロバイダー");
  assertStrictEquals(byProvider.google.length, 2, "google: 2件");
  assertStrictEquals(byProvider.openai.length, 1, "openai: 1件");
});

Deno.test("get_all: provider が空文字の行はグルーピングからスキップ", () => {
  const data = [
    { provider: "google", title: "G" },
    { provider: "", title: "empty" },
    { provider: "  ", title: "spaces" }, // trim後も空
  ];

  const byProvider: Record<string, unknown[]> = {};
  for (const row of data) {
    const key = asString((row as Record<string, unknown>).provider);
    if (key === "") continue;
    (byProvider[key] ??= []).push(row);
  }

  assertStrictEquals(Object.keys(byProvider).length, 1);
  assertStrictEquals(byProvider.google.length, 1);
});

// ──────────────────────────────────────────
// テスト: source_url の null 変換
// ──────────────────────────────────────────
Deno.test("upsert_news: source_url 空文字は null に変換", () => {
  const sourceUrl = asString("");
  const dbValue = sourceUrl === "" ? null : sourceUrl;
  assertStrictEquals(dbValue, null);
});

Deno.test("upsert_news: source_url 有効な文字列はそのまま保存", () => {
  const sourceUrl = asString("https://blog.google/");
  const dbValue = sourceUrl === "" ? null : sourceUrl;
  assertStrictEquals(dbValue, "https://blog.google/");
});

// ──────────────────────────────────────────
// テスト: isServiceRoleAuthorized ロジック
// ──────────────────────────────────────────
Deno.test("isServiceRoleAuthorized: SERVICE_ROLE_KEY 未設定は常に false", () => {
  const SERVICE_ROLE_KEY = "";
  const isAuthorized = (authHeader: string) => {
    if (SERVICE_ROLE_KEY === "") return false;
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.slice(7).trim()
      : "";
    return token !== "" && token === SERVICE_ROLE_KEY;
  };

  assertStrictEquals(isAuthorized("Bearer anything"), false);
  assertStrictEquals(isAuthorized(""), false);
});

Deno.test("isServiceRoleAuthorized: 正しいトークンで true", () => {
  const SERVICE_ROLE_KEY: string = "test-service-role-key";
  const isAuthorized = (authHeader: string) => {
    if (SERVICE_ROLE_KEY === "") return false;
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.slice(7).trim()
      : "";
    return token !== "" && token === SERVICE_ROLE_KEY;
  };

  assertStrictEquals(isAuthorized(`Bearer ${SERVICE_ROLE_KEY}`), true);
  assertStrictEquals(isAuthorized("Bearer wrong-key"), false);
  assertStrictEquals(isAuthorized(""), false);
  assertStrictEquals(isAuthorized("Basic test-service-role-key"), false);
});
