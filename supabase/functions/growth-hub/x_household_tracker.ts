// 匿名家計トラッカーの定期投稿用・純ロジック。
//
// クライアントは asset_pref_mirror に allowlist 済みの件数/給料日設定だけを
// 保存し、このモジュールが公開本文を再構築する。完成本文・金額・口座名を
// クライアントから受け取らないことで、cron 経路でも公開面を固定する。

export const HOUSEHOLD_TRACKER_MIRROR_KEY =
  "household_tracker_publish_snapshot";
export const HOUSEHOLD_TRACKER_CONSENT_MIRROR_KEY =
  "household_tracker_publish_consent";

export type HouseholdTrackerMirror = {
  observedAt: Date;
  monitoredAccounts: number;
  balanceIncreasing: number;
  negativeAmortization: number;
  slowPayoff: number;
  criticalCount: number;
  warningCount: number;
  salaryDay: number;
  salaryDayConfigured: boolean;
};

export type HouseholdTrackerReport = {
  available: boolean;
  reason?: string;
  text?: string;
  observedAt?: string;
};

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function safeCount(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isInteger(parsed) || parsed < 0 || parsed > 999) return null;
  return parsed;
}

export function parseHouseholdTrackerMirror(
  raw: unknown,
): HouseholdTrackerMirror | null {
  const value = asRecord(raw);
  if (value.schema_version !== 1) return null;
  const observedAt = new Date(String(value.observed_at ?? ""));
  const monitoredAccounts = safeCount(value.monitored_accounts);
  const balanceIncreasing = safeCount(value.balance_increasing);
  const negativeAmortization = safeCount(value.negative_amortization);
  const slowPayoff = safeCount(value.slow_payoff);
  const criticalCount = safeCount(value.critical_count);
  const warningCount = safeCount(value.warning_count);
  const salaryDay = Number(value.salary_day);
  if (
    !Number.isFinite(observedAt.getTime()) || monitoredAccounts === null ||
    balanceIncreasing === null || negativeAmortization === null ||
    slowPayoff === null || criticalCount === null || warningCount === null ||
    !Number.isInteger(salaryDay) || salaryDay < 1 || salaryDay > 28
  ) {
    return null;
  }
  return {
    observedAt,
    monitoredAccounts,
    balanceIncreasing,
    negativeAmortization,
    slowPayoff,
    criticalCount,
    warningCount,
    salaryDay,
    salaryDayConfigured: value.salary_day_configured === true,
  };
}

export function parseHouseholdTrackerConsent(raw: unknown): boolean | null {
  const value = asRecord(raw);
  if (value.schema_version !== 1 || typeof value.enabled !== "boolean") {
    return null;
  }
  return value.enabled;
}

export function anonymizedHouseholdCount(value: number): string {
  const safe = Math.max(0, Math.trunc(value));
  if (safe === 0) return "0件";
  if (safe < 3) return "1〜2件";
  if (safe < 6) return "3〜5件";
  if (safe < 11) return "6〜10件";
  return "11件以上";
}

type DateParts = { year: number; month: number; day: number };

function jstParts(date: Date): DateParts {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "numeric",
    day: "numeric",
  }).formatToParts(date);
  const read = (type: string) =>
    Number(parts.find((part) => part.type === type)?.value ?? "0");
  return { year: read("year"), month: read("month"), day: read("day") };
}

function dateLabel(date: Date): string {
  const { year, month, day } = jstParts(date);
  return `${year}/${String(month).padStart(2, "0")}/${
    String(day).padStart(2, "0")
  }`;
}

export function daysUntilSalaryDay(now: Date, salaryDay: number): number {
  const { year, month, day } = jstParts(now);
  const today = Date.UTC(year, month - 1, day);
  let next = Date.UTC(year, month - 1, salaryDay);
  if (next < today) next = Date.UTC(year, month, salaryDay);
  return Math.round((next - today) / 86_400_000);
}

export function salaryCyclePhase(now: Date, salaryDay: number): string {
  const remaining = daysUntilSalaryDay(now, salaryDay);
  if (remaining <= 3) return "給料日まで3日以内";
  if (remaining <= 7) return "給料日まで1週間以内";
  if (remaining <= 14) return "給料日まで1〜2週間";
  return "給料日まで2週間超";
}

export function buildHouseholdTrackerReport(
  raw: unknown,
  now: Date,
  maxAgeDays = 8,
): HouseholdTrackerReport {
  const snapshot = parseHouseholdTrackerMirror(raw);
  if (snapshot === null) {
    return { available: false, reason: "invalid_snapshot" };
  }
  if (!snapshot.salaryDayConfigured) {
    return { available: false, reason: "salary_day_not_configured" };
  }
  const ageMs = now.getTime() - snapshot.observedAt.getTime();
  if (ageMs < -15 * 60 * 1000) {
    return { available: false, reason: "snapshot_from_future" };
  }
  if (ageMs > maxAgeDays * 86_400_000) {
    return { available: false, reason: "stale_snapshot" };
  }

  const totalFindings = snapshot.balanceIncreasing +
    snapshot.negativeAmortization + snapshot.slowPayoff;
  const reportDate = dateLabel(now);
  const text = [
    `家計トラッカー ${reportDate}（自分株式会社・匿名集計）`,
    "",
    `集計日: ${dateLabel(snapshot.observedAt)}`,
    `トレンド検出口座: ${anonymizedHouseholdCount(snapshot.monitoredAccounts)}`,
    `負債トレンド検出: ${anonymizedHouseholdCount(totalFindings)}`,
    `内訳: 残高増加 ${
      anonymizedHouseholdCount(snapshot.balanceIncreasing)
    } / ` +
    `利息超過 ${anonymizedHouseholdCount(snapshot.negativeAmortization)} / ` +
    `長期化 ${anonymizedHouseholdCount(snapshot.slowPayoff)}`,
    snapshot.criticalCount > 0 || snapshot.warningCount > 0
      ? `アラート: 🔴${anonymizedHouseholdCount(snapshot.criticalCount)} / ` +
        `🟡${anonymizedHouseholdCount(snapshot.warningCount)}`
      : "アラート: なし",
    `給料日サイクル: ${salaryCyclePhase(now, snapshot.salaryDay)}`,
    "",
    "※金額・口座名・給料日の絶対日は非公開。件数は幅表示。",
  ].join("\n");

  return {
    available: true,
    text,
    observedAt: snapshot.observedAt.toISOString(),
  };
}
