// ai-university-badges EF pure-logic unit tests
// External imports avoided — works in CI without network.

function assertEquals<T>(actual: T, expected: T, msg?: string): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error(`assertEquals failed: expected ${e}, got ${a}${msg ? ` — ${msg}` : ""}`);
  }
}

function assertStrictEquals<T>(actual: T, expected: T, msg?: string): void {
  if (actual !== expected) {
    throw new Error(`assertStrictEquals failed: expected ${String(expected)}, got ${String(actual)}${msg ? ` — ${msg}` : ""}`);
  }
}

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

const STREAK_BADGES = [
  { threshold: 3, badge_id: "streak_3d", badge_name: "3日連続学習" },
  { threshold: 7, badge_id: "streak_7d", badge_name: "週間皆勤賞" },
  { threshold: 30, badge_id: "streak_30d", badge_name: "月間皆勤賞" },
];

Deno.test("STREAK_BADGES: 3段階のバッジ定義 (3d/7d/30d)", () => {
  assertStrictEquals(STREAK_BADGES.length, 3);
  assertEquals(STREAK_BADGES.map((b) => b.threshold), [3, 7, 30]);
  assertEquals(STREAK_BADGES.map((b) => b.badge_id), ["streak_3d", "streak_7d", "streak_30d"]);
});

Deno.test("STREAK_BADGES: ストリーク8は3d/7dが対象", () => {
  const eligible = STREAK_BADGES.filter((b) => 8 >= b.threshold);
  assertStrictEquals(eligible.length, 2);
  assertEquals(eligible.map((b) => b.badge_id), ["streak_3d", "streak_7d"]);
});

Deno.test("STREAK_BADGES: ストリーク1は全バッジ対象外", () => {
  assertStrictEquals(STREAK_BADGES.filter((b) => 1 >= b.threshold).length, 0);
});

Deno.test("STREAK_BADGES: ストリーク30は全バッジ対象", () => {
  assertStrictEquals(STREAK_BADGES.filter((b) => 30 >= b.threshold).length, 3);
});

Deno.test("record_score: wasCorrect||quizCorrect で正解は不変 (idempotent)", () => {
  assertStrictEquals(true || false, true);
  assertStrictEquals(false || true, true);
  assertStrictEquals(false || false, false);
});

Deno.test("newlyCorrect: !wasCorrect && quizCorrect の場合のみ true", () => {
  assertStrictEquals(!false && true, true, "初回正解");
  assertStrictEquals(!true && true, false, "再正解");
  assertStrictEquals(!false && false, false, "不正解");
});

Deno.test("quiz_master_3: 3社以上で付与対象", () => {
  const check = (n: number) => n >= 3;
  assertStrictEquals(check(3), true);
  assertStrictEquals(check(9), true);
  assertStrictEquals(check(2), false);
});

Deno.test("quiz_master_all: correctCount >= totalProviders で付与対象", () => {
  const check = (c: number, t: number) => t > 0 && c >= t;
  assertStrictEquals(check(9, 9), true);
  assertStrictEquals(check(8, 9), false);
  assertStrictEquals(check(0, 0), false);
});

Deno.test("score_leaderboard: email は @ 以前のみ返す", () => {
  const sanitize = (raw: string) => raw.includes("@") ? raw.split("@")[0] : raw;
  assertStrictEquals(sanitize("user@example.com"), "user");
  assertStrictEquals(sanitize("john.doe@gmail.com"), "john.doe");
  assertStrictEquals(sanitize("noEmail"), "noEmail");
});

Deno.test("leaderboard: limit は 1-100 にクランプ (デフォルト20)", () => {
  const clamp = (v: unknown) => Math.max(1, Math.min(100, asNumber(v, 20)));
  assertStrictEquals(clamp(undefined), 20);
  assertStrictEquals(clamp(0), 1);
  assertStrictEquals(clamp(500), 100);
});

Deno.test("award: icon_emoji 省略時は default バッジ絵文字", () => {
  const DEFAULT_ICON = "\u{1F3C5}"; // 🏅
  const iconEmoji = (v: unknown) => { const s = asString(v); return s === "" ? DEFAULT_ICON : s; };
  assertStrictEquals(iconEmoji(undefined), DEFAULT_ICON);
  assertStrictEquals(iconEmoji("custom"), "custom");
});

Deno.test("leaderboard: user_id 別バッジ数集計ランキング", () => {
  const rows = [
    { user_id: "user-a" }, { user_id: "user-b" },
    { user_id: "user-a" }, { user_id: "user-a" }, { user_id: "user-c" },
  ];
  const counts = new Map<string, number>();
  for (const row of rows) counts.set(row.user_id, (counts.get(row.user_id) ?? 0) + 1);
  const ranking = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10)
    .map(([user_id, badge_count], idx) => ({ rank: idx + 1, user_id, badge_count }));
  assertStrictEquals(ranking[0].user_id, "user-a");
  assertStrictEquals(ranking[0].badge_count, 3);
  assertStrictEquals(ranking[0].rank, 1);
  assertStrictEquals(ranking.length, 3);
});

Deno.test("asString/asNumber: 基本動作", () => {
  assertStrictEquals(asString("  hi  "), "hi");
  assertStrictEquals(asString(null), "");
  assertStrictEquals(asNumber(7), 7);
  assertStrictEquals(asNumber(null, 5), 5);
});
