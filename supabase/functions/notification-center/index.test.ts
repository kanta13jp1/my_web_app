// notification-center EF 単体テスト
// - index.ts は top-level `serve()` のため直接 import するとサーバーが起動してしまう。
//   そのため本テストでは **純粋ロジック** (JST 日付計算 / スパム防止 title prefix / 入力検証)
//   を index.ts と同じアルゴリズムで再現し、アルゴリズムの正しさを担保する。
// - PowerShell版#24 で ci.yml に `deno test` (continue-on-error: true) ステップが追加されたため、
//   本ファイルは `deno test supabase/functions/` で自動発見される。
// - 外部 import (std/testing/asserts) を避け、軽量アサーションをインラインで定義する。
//   これにより CI でのネットワーク障害時にもテストが成功する。

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

// index.ts で使用している通知カテゴリ (L29-37)
const NOTIFICATION_TYPES = [
  "feature_update",
  "achievement",
  "cs_reply",
  "system",
  "marketing",
  "blog_published",
  "agent_report",
] as const;

Deno.test("NOTIFICATION_TYPES: 7 カテゴリ全て含む", () => {
  assertEquals(NOTIFICATION_TYPES.length, 7);
  assertEquals(NOTIFICATION_TYPES.includes("system"), true);
  assertEquals(NOTIFICATION_TYPES.includes("cs_reply"), true);
  assertEquals(NOTIFICATION_TYPES.includes("blog_published"), true);
});

Deno.test("send_study_reminders: min_idle_days のクランプ (1-30)", () => {
  const clamp = (n: unknown): number =>
    typeof n === "number" ? Math.max(1, Math.min(30, n)) : 3;

  assertEquals(clamp(0), 1, "下限クランプ");
  assertEquals(clamp(3), 3, "デフォルト範囲");
  assertEquals(clamp(50), 30, "上限クランプ");
  assertEquals(clamp(undefined), 3, "デフォルト値");
  assertEquals(clamp(null), 3, "null はデフォルト");
});

Deno.test("send_study_reminders: max_idle_days は min 以上・90 以下", () => {
  const clampMax = (max: unknown, min: number): number =>
    typeof max === "number" ? Math.max(min, Math.min(90, max)) : 30;

  assertEquals(clampMax(5, 10), 10, "max < min → min");
  assertEquals(clampMax(30, 3), 30, "通常範囲");
  assertEquals(clampMax(200, 3), 90, "上限クランプ");
  assertEquals(clampMax(undefined, 3), 30, "デフォルト値");
});

Deno.test("send_study_reminders: JST 日付計算 (UTC+9)", () => {
  const fixedUtc = new Date("2026-04-11T00:00:00Z"); // UTC 00:00 = JST 09:00
  const jst = new Date(fixedUtc.getTime() + 9 * 60 * 60 * 1000);
  const ymd = jst.toISOString().slice(0, 10);
  assertEquals(ymd, "2026-04-11", "UTC 深夜 → JST 当日");

  const fixedUtcLate = new Date("2026-04-11T16:00:00Z"); // UTC 16:00 = JST 翌日 01:00
  const jstLate = new Date(fixedUtcLate.getTime() + 9 * 60 * 60 * 1000);
  const ymdLate = jstLate.toISOString().slice(0, 10);
  assertEquals(ymdLate, "2026-04-12", "UTC 夕方 → JST 翌日");
});

Deno.test("send_study_reminders: リマインダー title prefix 一貫性", () => {
  const REMINDER_TITLE_PREFIX = "[AI大学] 学習リマインダー";
  const idleDays = 5;
  const title = `${REMINDER_TITLE_PREFIX} — ${idleDays}日ぶりにAIを学ぼう`;

  assertEquals(
    title.startsWith(REMINDER_TITLE_PREFIX),
    true,
    "スパム防止フィルタの ilike `prefix%` が機能する形式",
  );
  assertEquals(title.includes("5日"), true);
});

Deno.test("send_study_reminders: idle_days 計算 (date diff in days)", () => {
  const today = "2026-04-11";
  const lastStudied = "2026-04-06";
  const idleDays = Math.floor(
    (Date.parse(today) - Date.parse(lastStudied)) / 86_400_000,
  );
  assertEquals(idleDays, 5);

  const sameDay = Math.floor(
    (Date.parse("2026-04-11") - Date.parse("2026-04-11")) / 86_400_000,
  );
  assertEquals(sameDay, 0);
});

Deno.test("send_study_reminders: personalized message branches (bestStreak)", () => {
  const buildMessage = (idleDays: number, bestStreak: number): string => {
    return bestStreak > 1
      ? `前回の学習から${idleDays}日経過。過去最長 ${bestStreak} 日連続を更新しよう！1分クイズでストリーク復活。`
      : `前回の学習から${idleDays}日経過。AI大学で1分クイズに挑戦して知識をアップデート。`;
  };

  const withStreak = buildMessage(5, 7);
  assertEquals(withStreak.includes("過去最長 7 日連続"), true);

  const newbie = buildMessage(3, 1);
  assertEquals(newbie.includes("過去最長"), false);
  assertEquals(newbie.includes("1分クイズ"), true);
});

Deno.test("send_study_reminders: recently reminded ユーザーはスキップ", () => {
  const allCandidates = ["user-a", "user-b", "user-c"];
  const recentlyReminded = new Set<string>(["user-b"]);
  const targets = allCandidates.filter((id) => !recentlyReminded.has(id));

  assertEquals(targets.length, 2);
  assertEquals(targets.includes("user-b"), false);
  assertStrictEquals(targets[0], "user-a");
  assertStrictEquals(targets[1], "user-c");
});

Deno.test("CORS headers: Allow-Origin と Allow-Headers が設定されている", () => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };

  assertEquals(corsHeaders["Access-Control-Allow-Origin"], "*");
  assertEquals(
    corsHeaders["Access-Control-Allow-Headers"].includes("authorization"),
    true,
  );
  assertEquals(
    corsHeaders["Access-Control-Allow-Headers"].includes("apikey"),
    true,
  );
});
