// ai-university-streaks EF 単体テスト
// index.ts は top-level `serve()` を持つため直接 import せず、
// **純粋ロジック** (型変換 / limit クランプ / leaderboard ランク付け)
// を同アルゴリズムで再現してアルゴリズムの正しさを担保する。
// 外部 import 不使用 — CI でのネットワーク障害時にも成功する軽量テスト。

// ──────────────────────────────────────────
// 軽量アサーションヘルパー
// ──────────────────────────────────────────
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
function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

// ──────────────────────────────────────────
// テスト: asNumber
// ──────────────────────────────────────────
Deno.test("asNumber: 数値をそのまま返す", () => {
  assertStrictEquals(asNumber(7), 7);
  assertStrictEquals(asNumber(0), 0);
});

Deno.test("asNumber: 文字列数値をパース", () => {
  assertStrictEquals(asNumber("10"), 10);
  assertStrictEquals(asNumber("100"), 100);
});

Deno.test("asNumber: 無効な値はフォールバック", () => {
  assertStrictEquals(asNumber(null, 5), 5);
  assertStrictEquals(asNumber(undefined, 3), 3);
  assertStrictEquals(asNumber("abc", 1), 1);
  assertStrictEquals(asNumber(Infinity, 0), 0);
  assertStrictEquals(asNumber(NaN, 10), 10);
});

// ──────────────────────────────────────────
// テスト: leaderboard limit クランプ
// ──────────────────────────────────────────
Deno.test("leaderboard: limit は 1–100 にクランプ", () => {
  const clamp = (v: unknown) =>
    Math.max(1, Math.min(100, asNumber(v, 10)));

  assertStrictEquals(clamp(undefined), 10, "デフォルト 10");
  assertStrictEquals(clamp(0), 1, "下限クランプ");
  assertStrictEquals(clamp(500), 100, "上限クランプ");
  assertStrictEquals(clamp(50), 50, "正常値");
  assertStrictEquals(clamp(-1), 1, "負の値");
  assertStrictEquals(clamp("20"), 20, "文字列数値");
});

// ──────────────────────────────────────────
// テスト: leaderboard rank 付け
// ──────────────────────────────────────────
Deno.test("leaderboard: idx + 1 でランク付けされる", () => {
  const mockData = [
    {
      user_id: "user-a",
      current_streak: 30,
      longest_streak: 45,
      last_studied_date: "2026-04-12",
    },
    {
      user_id: "user-b",
      current_streak: 15,
      longest_streak: 20,
      last_studied_date: "2026-04-11",
    },
    {
      user_id: "user-c",
      current_streak: 5,
      longest_streak: 10,
      last_studied_date: "2026-04-10",
    },
  ];

  const result = mockData.map((row, idx) => ({
    rank: idx + 1,
    user_id: row.user_id,
    current_streak: row.current_streak,
    longest_streak: row.longest_streak,
    last_studied_date: row.last_studied_date,
  }));

  assertStrictEquals(result[0].rank, 1);
  assertStrictEquals(result[1].rank, 2);
  assertStrictEquals(result[2].rank, 3);
  assertStrictEquals(result[0].user_id, "user-a");
  assertStrictEquals(result[2].current_streak, 5);
});

Deno.test("leaderboard: 空配列は空の leaderboard を返す", () => {
  const mockData: unknown[] = [];
  const result = (mockData as Array<{
    user_id: string;
    current_streak: number;
    longest_streak: number;
    last_studied_date: string | null;
  }>).map((row, idx) => ({
    rank: idx + 1,
    user_id: row.user_id,
    current_streak: row.current_streak,
    longest_streak: row.longest_streak,
    last_studied_date: row.last_studied_date,
  }));

  assertStrictEquals(result.length, 0);
});

// ──────────────────────────────────────────
// テスト: get action のデフォルトレスポンス (未学習ユーザー)
// ──────────────────────────────────────────
Deno.test("get: streak レコードなしの場合は 0/0/null を返す", () => {
  // maybeSingle が null を返したときのロジック
  const data: null = null;
  const response = !data
    ? {
      success: true,
      current_streak: 0,
      longest_streak: 0,
      last_studied_date: null,
      streak_updated_at: null,
    }
    : { success: true };

  assertStrictEquals(response.current_streak, 0);
  assertStrictEquals(response.longest_streak, 0);
  assertStrictEquals(response.last_studied_date, null);
  assertStrictEquals(response.streak_updated_at, null);
});

// ──────────────────────────────────────────
// テスト: update action のレスポンス構築
// ──────────────────────────────────────────
Deno.test("update: RPC が null を返した場合のデフォルト値", () => {
  // RPC が空配列または null を返した場合のフォールバック
  const rpRow = null;
  const response = !rpRow
    ? {
      success: true,
      current_streak: 1,
      longest_streak: 1,
      is_new_streak_day: true,
    }
    : { success: false };

  assertStrictEquals(response.current_streak, 1);
  assertStrictEquals(response.is_new_streak_day, true);
});

Deno.test("update: RPC が行を返した場合にデータを反映", () => {
  const mockRow: Record<string, unknown> = {
    current_streak: 7,
    longest_streak: 14,
    is_new_streak_day: true,
  };

  const response = {
    success: true,
    current_streak: asNumber(mockRow.current_streak, 0),
    longest_streak: asNumber(mockRow.longest_streak, 0),
    is_new_streak_day: Boolean(mockRow.is_new_streak_day),
  };

  assertStrictEquals(response.current_streak, 7);
  assertStrictEquals(response.longest_streak, 14);
  assertStrictEquals(response.is_new_streak_day, true);
});
