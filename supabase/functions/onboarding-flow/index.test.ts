// onboarding-flow EF 単体テスト
// 対象: ONBOARDING_STEPS 定義 + 進捗計算ロジック (completedSteps / percent / nextStep)
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

// index.ts L25-78 と同一定義
const ONBOARDING_STEPS = [
  {
    key: "welcome",
    order: 1,
    title: "自分株式会社へようこそ",
    required: true,
  },
  {
    key: "profile",
    order: 2,
    title: "プロフィールを設定",
    required: true,
  },
  {
    key: "first_note",
    order: 3,
    title: "最初のノートを作成",
    required: false,
  },
  {
    key: "import",
    order: 4,
    title: "他サービスからインポート",
    required: false,
  },
  {
    key: "ai_assistant",
    order: 5,
    title: "AI アシスタントを試す",
    required: false,
  },
  {
    key: "share",
    order: 6,
    title: "友達に紹介する",
    required: false,
  },
] as const;

Deno.test("ONBOARDING_STEPS: 6 ステップが定義されている", () => {
  assertEquals(ONBOARDING_STEPS.length, 6);
});

Deno.test("ONBOARDING_STEPS: order が連番 (1-6)", () => {
  const orders = ONBOARDING_STEPS.map((s) => s.order);
  assertEquals(orders, [1, 2, 3, 4, 5, 6]);
});

Deno.test("ONBOARDING_STEPS: 必須ステップ (welcome/profile) が2つ", () => {
  const required = ONBOARDING_STEPS.filter((s) => s.required);
  assertEquals(required.length, 2);
  assertEquals(required.map((s) => s.key), ["welcome", "profile"]);
});

Deno.test("ONBOARDING_STEPS: キー重複なし", () => {
  const keys = ONBOARDING_STEPS.map((s) => s.key);
  const unique = new Set(keys);
  assertEquals(unique.size, keys.length);
});

Deno.test("進捗計算: 未ログイン時は completed=0, percent=0", () => {
  const completedCount = 0;
  const totalSteps = ONBOARDING_STEPS.length;
  const percent = Math.round((completedCount / totalSteps) * 100);
  assertEquals(percent, 0);
});

Deno.test("進捗計算: welcome のみ完了 (ログイン直後) → 17%", () => {
  const completedSteps = new Set<string>(["welcome"]);
  const stepsWithProgress = ONBOARDING_STEPS.map((step) => ({
    ...step,
    completed: completedSteps.has(step.key),
  }));
  const completedCount = stepsWithProgress.filter((s) => s.completed).length;
  const percent = Math.round((completedCount / ONBOARDING_STEPS.length) * 100);
  assertEquals(completedCount, 1);
  assertEquals(percent, 17); // Math.round(1/6*100) = 17
});

Deno.test("進捗計算: welcome + profile + first_note 完了 → 50%", () => {
  const completedSteps = new Set<string>(["welcome", "profile", "first_note"]);
  const completedCount = ONBOARDING_STEPS.filter((s) =>
    completedSteps.has(s.key)
  ).length;
  const percent = Math.round((completedCount / ONBOARDING_STEPS.length) * 100);
  assertEquals(percent, 50);
});

Deno.test("進捗計算: 全ステップ完了 → 100% + isComplete=true", () => {
  const completedSteps = new Set<string>(
    ONBOARDING_STEPS.map((s) => s.key),
  );
  const completedCount = ONBOARDING_STEPS.filter((s) =>
    completedSteps.has(s.key)
  ).length;
  const percent = Math.round((completedCount / ONBOARDING_STEPS.length) * 100);
  const isComplete = completedCount === ONBOARDING_STEPS.length;

  assertEquals(completedCount, 6);
  assertEquals(percent, 100);
  assertEquals(isComplete, true);
});

Deno.test("nextStep 判定: 最初の未完了ステップを返す", () => {
  const completedSteps = new Set<string>(["welcome", "profile"]);
  const stepsWithProgress = ONBOARDING_STEPS.map((step) => ({
    ...step,
    completed: completedSteps.has(step.key),
  }));
  const nextStep = stepsWithProgress.find((s) => !s.completed) ?? null;

  assertEquals(nextStep?.key, "first_note");
  assertEquals(nextStep?.order, 3);
});

Deno.test("nextStep 判定: 全完了時は null", () => {
  const stepsWithProgress = ONBOARDING_STEPS.map((step) => ({
    ...step,
    completed: true,
  }));
  const nextStep = stepsWithProgress.find((s) => !s.completed) ?? null;
  assertEquals(nextStep, null);
});

Deno.test("onboarding_completed merge: 既存キーを保持しつつ新規追加", () => {
  const current: Record<string, boolean> = {
    welcome: true,
    profile: true,
  };
  const stepKey = "first_note";
  current[stepKey] = true;

  assertEquals(current.welcome, true);
  assertEquals(current.profile, true);
  assertEquals(current.first_note, true);
  assertEquals(Object.keys(current).length, 3);
});

Deno.test("入力検証: step_key が空/undefined 時は 400 エラー対象", () => {
  const validate = (body: Record<string, unknown>): boolean => {
    return Boolean(body.step_key);
  };

  assertEquals(validate({ step_key: "welcome" }), true);
  assertEquals(validate({ step_key: "" }), false);
  assertEquals(validate({}), false);
  assertEquals(validate({ step_key: null }), false);
});

Deno.test("noteCount null-safety: null/undefined は 0 扱い", () => {
  const hasNotes = (noteCount: number | null | undefined): boolean =>
    (noteCount ?? 0) > 0;

  assertEquals(hasNotes(5), true);
  assertEquals(hasNotes(1), true);
  assertEquals(hasNotes(0), false);
  assertEquals(hasNotes(null), false);
  assertEquals(hasNotes(undefined), false);
});
