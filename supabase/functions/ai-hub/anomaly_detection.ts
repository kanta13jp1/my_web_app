// Issue #2477 [資産管理][第2弾D]: deterministic category-spend anomaly scan.
// 直近3月平均 vs 対象月 ±20% で異常判定し anomaly_detections へ upsert する。
// 金額計算・判定はすべて deterministic。LLM は ai_explanation の生成のみ
// (feature flag OFF default / 失敗しても検知結果には影響しない)。

type UnknownRecord = Record<string, unknown>;

export class AnomalyDetectionError extends Error {
  status: number;
  constructor(message: string, status = 400) {
    super(message);
    this.name = "AnomalyDetectionError";
    this.status = status;
  }
}

export type AnomalyProviderRequest = {
  provider: string;
  model?: string;
  messages: { role: string; content: string }[];
};

export type AnomalyProviderResult = {
  ok: boolean;
  text?: string;
  modelUsed?: string;
  error?: string;
};

export type AnomalyProviderInvoker = (
  request: AnomalyProviderRequest,
) => Promise<AnomalyProviderResult>;

type ListResult = {
  data?: unknown[] | null;
  error?: { message?: string } | null;
};

type MutationResult = {
  error?: { message?: string } | null;
};

export type AnomalyDbQuery = {
  select(columns?: string): AnomalyDbQuery;
  eq(column: string, value: string): AnomalyDbQuery;
  neq(column: string, value: string): AnomalyDbQuery;
  gte(column: string, value: string): AnomalyDbQuery;
  lt(column: string, value: string): AnomalyDbQuery;
  order(
    column: string,
    options?: { ascending?: boolean },
  ): AnomalyDbQuery;
  range(from: number, to: number): Promise<ListResult>;
  upsert(
    value: UnknownRecord,
    options?: { onConflict?: string },
  ): Promise<MutationResult>;
};

export type AnomalyDetectionDb = {
  from(table: string): AnomalyDbQuery;
};

export type AnomalyExpenseRow = {
  posted_at: string;
  amount: number;
  category: string;
  status: string;
};

export type CategoryAnomaly = {
  category: string;
  expected: number;
  actual: number;
  delta: number;
  deviation_ratio: number;
  severity: "low" | "medium" | "high";
  months_averaged: number;
  ai_explanation: string | null;
};

export type SkippedCategory = {
  category: string;
  reason: "no_prior_history" | "no_target_data" | "nonpositive_expected";
};

export type AnomalyScanOutcome = {
  target_month: string;
  window_start: string;
  anomalies: CategoryAnomaly[];
  skipped: SkippedCategory[];
};

export type DetectAnomaliesResult = {
  status: "ok";
  target_month: string;
  anomalies_detected: number;
  anomalies: CategoryAnomaly[];
  skipped: SkippedCategory[];
  explanation_enabled: boolean;
  warnings: string[];
};

const DEFAULT_THRESHOLD_RATIO = 0.2;
const PRIOR_MONTHS = 3;
const EXPLANATION_CAP = 5;
const PAGE_SIZE = 1000;
const JST_OFFSET_MINUTES = 9 * 60;

function pad2(value: number): string {
  return String(value).padStart(2, "0");
}

function monthFirstDay(year: number, monthIndex0: number): string {
  const normalized = new Date(Date.UTC(year, monthIndex0, 1));
  return `${normalized.getUTCFullYear()}-${
    pad2(normalized.getUTCMonth() + 1)
  }-01`;
}

/** monthFirstDay ("YYYY-MM-01") を n ヶ月ずらす。 */
export function addMonths(monthDay: string, n: number): string {
  const [y, m] = monthDay.split("-").map(Number);
  return monthFirstDay(y, m - 1 + n);
}

/**
 * 対象月を決める。requested があれば "YYYY-MM" / "YYYY-MM-01" のみ受理。
 * 省略時は JST での「前の完了月」(当月は集計途中のため既定では対象にしない)。
 */
export function resolveTargetMonth(
  nowIso: string,
  requested?: unknown,
): string {
  if (requested !== undefined && requested !== null && requested !== "") {
    if (typeof requested !== "string") {
      throw new AnomalyDetectionError("target_month must be a string", 400);
    }
    const match = requested.match(/^(\d{4})-(\d{2})(?:-01)?$/);
    if (!match) {
      throw new AnomalyDetectionError(
        "target_month must be YYYY-MM or YYYY-MM-01",
        400,
      );
    }
    const month = Number(match[2]);
    if (month < 1 || month > 12) {
      throw new AnomalyDetectionError("target_month month out of range", 400);
    }
    return `${match[1]}-${match[2]}-01`;
  }
  const now = new Date(nowIso);
  if (Number.isNaN(now.getTime())) {
    throw new AnomalyDetectionError("invalid now timestamp", 500);
  }
  const jst = new Date(now.getTime() + JST_OFFSET_MINUTES * 60 * 1000);
  return monthFirstDay(jst.getUTCFullYear(), jst.getUTCMonth() - 1);
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/** 逸脱率→severity (deterministic tiers): <50% low / <100% medium / それ以上 high */
export function severityFor(
  deviationRatio: number,
): "low" | "medium" | "high" {
  if (deviationRatio < 0.5) return "low";
  if (deviationRatio < 1.0) return "medium";
  return "high";
}

/**
 * カテゴリ別に「直近3月平均 vs 対象月」±threshold で異常を検出する純関数。
 *
 * Deterministic rules (テストが仕様):
 * - status = 'rejected' の行は除外。
 * - expected = 対象月より前の直近3ヶ月のうち「その category に行がある月」の平均。
 *   行が無い月は 0 円ではなく「未記録」として平均から除外する
 *   (記録開始直後の月を 0 扱いすると増加系の偽陽性になるため)。
 * - 前歴 0 ヶ月 → skip (no_prior_history)。
 * - 対象月に行が無い category → skip (no_target_data / 未記録と 0 円を区別できない)。
 * - expected <= 0 → skip (nonpositive_expected / 負・ゼロ基準の比率は誤読を生む)。
 * - |actual - expected| / expected >= threshold (既定 0.2) で異常。
 */
export function computeCategoryAnomalies(options: {
  rows: AnomalyExpenseRow[];
  targetMonth: string;
  thresholdRatio?: number;
}): AnomalyScanOutcome {
  const threshold = options.thresholdRatio ?? DEFAULT_THRESHOLD_RATIO;
  const target = options.targetMonth;
  const windowStart = addMonths(target, -PRIOR_MONTHS);
  const nextMonth = addMonths(target, 1);
  const priorMonths = [-3, -2, -1].map((n) => addMonths(target, n));

  const sums = new Map<string, Map<string, number>>();
  for (const row of options.rows) {
    if (row.status === "rejected") continue;
    if (!row.category) continue;
    const posted = row.posted_at;
    if (posted < windowStart || posted >= nextMonth) continue;
    const month = `${posted.slice(0, 7)}-01`;
    let byMonth = sums.get(row.category);
    if (!byMonth) {
      byMonth = new Map<string, number>();
      sums.set(row.category, byMonth);
    }
    byMonth.set(month, (byMonth.get(month) ?? 0) + row.amount);
  }

  const anomalies: CategoryAnomaly[] = [];
  const skipped: SkippedCategory[] = [];
  const categories = [...sums.keys()].sort();
  for (const category of categories) {
    const byMonth = sums.get(category)!;
    const priorValues = priorMonths
      .filter((m) => byMonth.has(m))
      .map((m) => byMonth.get(m)!);
    if (priorValues.length === 0) {
      skipped.push({ category, reason: "no_prior_history" });
      continue;
    }
    if (!byMonth.has(target)) {
      skipped.push({ category, reason: "no_target_data" });
      continue;
    }
    const expected = priorValues.reduce((a, b) => a + b, 0) /
      priorValues.length;
    if (expected <= 0) {
      skipped.push({ category, reason: "nonpositive_expected" });
      continue;
    }
    const actual = byMonth.get(target)!;
    const delta = actual - expected;
    const deviation = Math.abs(delta) / expected;
    if (deviation < threshold) continue;
    anomalies.push({
      category,
      expected: round2(expected),
      actual: round2(actual),
      delta: round2(delta),
      deviation_ratio: round2(deviation),
      severity: severityFor(deviation),
      months_averaged: priorValues.length,
      ai_explanation: null,
    });
  }

  return {
    target_month: target,
    window_start: windowStart,
    anomalies,
    skipped,
  };
}

export function buildExplanationPrompt(
  anomaly: CategoryAnomaly,
  targetMonth: string,
): { role: string; content: string }[] {
  const direction = anomaly.delta >= 0 ? "増加" : "減少";
  return [
    {
      role: "user",
      content:
        `家計の異常検知結果を1〜2文の日本語で説明してください。数値の再計算や助言の追加はせず、事実の要約のみ。\n` +
        `対象月: ${
          targetMonth.slice(0, 7)
        } / カテゴリ: ${anomaly.category} / ` +
        `直近${anomaly.months_averaged}ヶ月平均: ${anomaly.expected}円 / 当月: ${anomaly.actual}円 / ` +
        `${direction}率: ${Math.round(anomaly.deviation_ratio * 100)}%`,
    },
  ];
}

async function fetchExpenseRows(
  db: AnomalyDetectionDb,
  userId: string,
  windowStart: string,
  nextMonth: string,
): Promise<AnomalyExpenseRow[]> {
  // PostgREST は range 未指定だと既定 max-rows (1000) で無言打ち切りされるため
  // 全件は range ページング + order に一意 id をタイエブレーカとして必ず含める。
  const rows: AnomalyExpenseRow[] = [];
  for (let page = 0; page < 50; page++) {
    const from = page * PAGE_SIZE;
    const { data, error } = await db
      .from("expense_classifications")
      .select("posted_at,amount,category,status")
      .eq("user_id", userId)
      .neq("status", "rejected")
      .gte("posted_at", windowStart)
      .lt("posted_at", nextMonth)
      .order("posted_at", { ascending: true })
      .order("id", { ascending: true })
      .range(from, from + PAGE_SIZE - 1);
    if (error) {
      throw new AnomalyDetectionError(
        `expense_classifications load failed: ${error.message ?? "unknown"}`,
        500,
      );
    }
    const batch = (data ?? []) as UnknownRecord[];
    for (const raw of batch) {
      rows.push({
        posted_at: String(raw.posted_at ?? ""),
        amount: Number(raw.amount ?? 0),
        category: String(raw.category ?? ""),
        status: String(raw.status ?? ""),
      });
    }
    if (batch.length < PAGE_SIZE) break;
  }
  return rows;
}

export async function handleDetectAnomaliesAction(options: {
  db: AnomalyDetectionDb;
  body: UnknownRecord;
  userId: string;
  explanationEnabled?: boolean;
  invokeProvider?: AnomalyProviderInvoker;
  nowIso?: string;
}): Promise<DetectAnomaliesResult> {
  if (!options.userId) {
    throw new AnomalyDetectionError("login required", 401);
  }
  const nowIso = options.nowIso ?? new Date().toISOString();
  const targetMonth = resolveTargetMonth(nowIso, options.body.target_month);
  const nextMonth = addMonths(targetMonth, 1);
  const windowStart = addMonths(targetMonth, -PRIOR_MONTHS);
  const warnings: string[] = [];

  const rows = await fetchExpenseRows(
    options.db,
    options.userId,
    windowStart,
    nextMonth,
  );
  const outcome = computeCategoryAnomalies({ rows, targetMonth });

  const explanationEnabled = options.explanationEnabled === true;
  if (explanationEnabled && options.invokeProvider) {
    for (const anomaly of outcome.anomalies.slice(0, EXPLANATION_CAP)) {
      try {
        const result = await options.invokeProvider({
          provider: "gemini",
          messages: buildExplanationPrompt(anomaly, targetMonth),
        });
        if (result.ok && result.text) {
          anomaly.ai_explanation = result.text.trim().slice(0, 500);
        } else {
          warnings.push(
            `explanation skipped (${anomaly.category}): ${
              result.error ?? "provider returned no text"
            }`,
          );
        }
      } catch (err) {
        warnings.push(
          `explanation failed (${anomaly.category}): ${
            err instanceof Error ? err.message : String(err)
          }`,
        );
      }
    }
  }

  for (const anomaly of outcome.anomalies) {
    // 同一 (user, category, target_month) は upsert で更新のみ。
    // dismissed_at は供給しない = ユーザーの既読/却下を再スキャンで復活させない。
    const { error } = await options.db.from("anomaly_detections").upsert(
      {
        user_id: options.userId,
        target_month: targetMonth,
        category: anomaly.category,
        expected: anomaly.expected,
        actual: anomaly.actual,
        delta: anomaly.delta,
        severity: anomaly.severity,
        ai_explanation: anomaly.ai_explanation,
        detected_at: nowIso,
      },
      { onConflict: "user_id,category,target_month" },
    );
    if (error) {
      throw new AnomalyDetectionError(
        `anomaly_detections upsert failed: ${error.message ?? "unknown"}`,
        500,
      );
    }
  }

  return {
    status: "ok",
    target_month: targetMonth,
    anomalies_detected: outcome.anomalies.length,
    anomalies: outcome.anomalies,
    skipped: outcome.skipped,
    explanation_enabled: explanationEnabled,
    warnings,
  };
}
