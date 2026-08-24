type UnknownRecord = Record<string, unknown>;

type QueryError = { message?: string } | null;

type QueryResult = {
  data?: unknown[] | null;
  error?: QueryError;
  count?: number | null;
};

type CountOptions = {
  count?: "exact";
  head?: boolean;
};

export type DepartmentFinanceSummaryDbQuery = {
  select(
    columns?: string,
    options?: CountOptions,
  ): DepartmentFinanceSummaryDbQuery;
  eq(column: string, value: string): DepartmentFinanceSummaryDbQuery;
  is(column: string, value: null): DepartmentFinanceSummaryDbQuery;
  order(
    column: string,
    options?: { ascending?: boolean },
  ): DepartmentFinanceSummaryDbQuery;
  limit(count: number): Promise<QueryResult>;
  range(from: number, to: number): Promise<QueryResult>;
};

export type DepartmentFinanceSummaryDb = {
  from(table: string): DepartmentFinanceSummaryDbQuery;
};

type BalanceSource = "monthly_snapshot" | "monthly_asset_report" | "none";
type CashflowSource = "monthly_snapshot" | "income_plans" | "none";
type MetricAvailability = "available" | "partial" | "not_recorded";

export type DepartmentFinanceSummaryResult = {
  status: "ok";
  month_key: string;
  as_of: string;
  net_assets: number | null;
  current_month_cashflow: number | null;
  investment_valuation: number;
  anomaly_count: number;
  total_assets: number | null;
  total_liabilities: number | null;
  received_income: number | null;
  paid_expenses: number | null;
  investment_holding_count: number;
  priced_investment_count: number;
  unpriced_investment_count: number;
  availability: {
    net_assets: MetricAvailability;
    current_month_cashflow: MetricAvailability;
    investment_valuation: MetricAvailability;
    anomaly_count: MetricAvailability;
  };
  sources: {
    balance_sheet: BalanceSource;
    cashflow: CashflowSource;
  };
  warnings: string[];
};

export class DepartmentFinanceSummaryActionError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "DepartmentFinanceSummaryActionError";
    this.status = status;
  }
}

const INVESTMENT_PAGE_SIZE = 200;
const INVESTMENT_ROW_CAP = 2000;
const JST_OFFSET_MS = 9 * 60 * 60 * 1000;

export function isDepartmentFinanceSummaryAction(action: string): boolean {
  return action === "department_finance_summary" ||
    action === "ai_hub.department_finance_summary";
}

export function resolveDepartmentFinanceSummaryMonth(
  value: unknown,
  now = new Date(),
): { monthKey: string; monthStart: string } {
  let raw = typeof value === "string" ? value.trim() : "";
  if (!raw) {
    const jst = new Date(now.getTime() + JST_OFFSET_MS);
    raw = `${jst.getUTCFullYear()}-${
      String(jst.getUTCMonth() + 1).padStart(2, "0")
    }`;
  }
  const match = raw.match(/^(\d{4})-(\d{2})(?:-01)?$/);
  if (!match) {
    throw new DepartmentFinanceSummaryActionError(
      "month_key must be YYYY-MM or YYYY-MM-01",
      400,
    );
  }
  const month = Number(match[2]);
  if (month < 1 || month > 12) {
    throw new DepartmentFinanceSummaryActionError(
      "month_key month is invalid",
      400,
    );
  }
  const monthKey = `${match[1]}-${String(month).padStart(2, "0")}`;
  return { monthKey, monthStart: `${monthKey}-01` };
}

export async function handleDepartmentFinanceSummaryAction(options: {
  db: DepartmentFinanceSummaryDb;
  body: UnknownRecord;
  userId: string;
  now?: Date;
}): Promise<DepartmentFinanceSummaryResult> {
  if (!options.userId) {
    throw new DepartmentFinanceSummaryActionError("login required", 401);
  }
  const now = options.now ?? new Date();
  const { monthKey, monthStart } = resolveDepartmentFinanceSummaryMonth(
    options.body.month_key ?? options.body.year_month,
    now,
  );

  const [snapshot, incomePlan, investments, anomalyCount] = await Promise.all([
    readMonthlySnapshot(options.db, options.userId, monthKey),
    readIncomePlan(options.db, options.userId, monthKey),
    readInvestmentValuation(options.db, options.userId),
    readAnomalyCount(options.db, options.userId, monthStart),
  ]);

  const snapshotBalance = balanceFromSnapshot(snapshot);
  const report = snapshotBalance
    ? null
    : await readMonthlyReport(options.db, options.userId, monthStart);
  const reportBalance = balanceFromReport(report);
  const balance = snapshotBalance ?? reportBalance;
  const balanceSource: BalanceSource = snapshotBalance
    ? "monthly_snapshot"
    : reportBalance
    ? "monthly_asset_report"
    : "none";

  const snapshotIncome = readOptionalNumber(snapshot, [
    "monthly_received_income_total",
    "monthlyReceivedIncomeTotal",
  ]);
  const plannedIncome = receivedIncomeFromPlan(incomePlan);
  const receivedIncome = snapshotIncome ?? plannedIncome;
  const cashflowSource: CashflowSource = snapshotIncome !== null
    ? "monthly_snapshot"
    : plannedIncome !== null
    ? "income_plans"
    : "none";
  const paidExpenses = readOptionalNumber(snapshot, [
    "monthly_paid_payment_total",
    "monthlyPaidPaymentTotal",
  ]);
  const cashflow = receivedIncome !== null && paidExpenses !== null
    ? roundYen(receivedIncome - paidExpenses)
    : null;

  const warnings = investments.truncated
    ? [
      `investment valuation is limited to ${INVESTMENT_ROW_CAP} holdings`,
    ]
    : [];
  const investmentAvailability: MetricAvailability =
    investments.holdingCount === 0
      ? "not_recorded"
      : investments.unpricedCount > 0 || investments.truncated
      ? "partial"
      : "available";

  return {
    status: "ok",
    month_key: monthKey,
    as_of: now.toISOString(),
    net_assets: balance?.netAssets ?? null,
    current_month_cashflow: cashflow,
    investment_valuation: investments.valuation,
    anomaly_count: anomalyCount,
    total_assets: balance?.totalAssets ?? null,
    total_liabilities: balance?.totalLiabilities ?? null,
    received_income: receivedIncome === null ? null : roundYen(receivedIncome),
    paid_expenses: paidExpenses === null ? null : roundYen(paidExpenses),
    investment_holding_count: investments.holdingCount,
    priced_investment_count: investments.pricedCount,
    unpriced_investment_count: investments.unpricedCount,
    availability: {
      net_assets: balance ? "available" : "not_recorded",
      current_month_cashflow: cashflow === null ? "not_recorded" : "available",
      investment_valuation: investmentAvailability,
      anomaly_count: "available",
    },
    sources: {
      balance_sheet: balanceSource,
      cashflow: cashflowSource,
    },
    warnings,
  };
}

async function readMonthlySnapshot(
  db: DepartmentFinanceSummaryDb,
  userId: string,
  monthKey: string,
): Promise<UnknownRecord | null> {
  const { data, error } = await db.from("asset_liability_monthly_snapshots")
    .select("payload,month_key,updated_at")
    .eq("user_id", userId)
    .eq("month_key", monthKey)
    .limit(1);
  throwOnQueryError(error, "monthly snapshot read");
  const row = firstRecord(data);
  const payload = asRecord(row?.payload);
  return payload ? { ...payload, month_key: row?.month_key } : null;
}

async function readMonthlyReport(
  db: DepartmentFinanceSummaryDb,
  userId: string,
  monthStart: string,
): Promise<UnknownRecord | null> {
  const { data, error } = await db.from("monthly_asset_reports")
    .select("total_assets,total_liabilities,net_worth,generated_at")
    .eq("user_id", userId)
    .eq("year_month", monthStart)
    .limit(1);
  throwOnQueryError(error, "monthly report read");
  return firstRecord(data);
}

async function readIncomePlan(
  db: DepartmentFinanceSummaryDb,
  userId: string,
  monthKey: string,
): Promise<UnknownRecord | null> {
  const { data, error } = await db.from("asset_liability_income_plans")
    .select("payload,month_key,updated_at")
    .eq("user_id", userId)
    .eq("month_key", monthKey)
    .limit(1);
  throwOnQueryError(error, "income plan read");
  const row = firstRecord(data);
  return asRecord(row?.payload);
}

async function readInvestmentValuation(
  db: DepartmentFinanceSummaryDb,
  userId: string,
): Promise<{
  valuation: number;
  holdingCount: number;
  pricedCount: number;
  unpricedCount: number;
  truncated: boolean;
}> {
  let valuation = 0;
  let holdingCount = 0;
  let pricedCount = 0;
  let unpricedCount = 0;

  for (let from = 0; from < INVESTMENT_ROW_CAP; from += INVESTMENT_PAGE_SIZE) {
    const to = Math.min(
      from + INVESTMENT_PAGE_SIZE - 1,
      INVESTMENT_ROW_CAP - 1,
    );
    const { data, error } = await db.from("investment_assets")
      .select("id,quantity,current_price_jpy")
      .eq("user_id", userId)
      .order("id", { ascending: true })
      .range(from, to);
    throwOnQueryError(error, "investment assets read");
    const rows = toRecords(data);
    for (const row of rows) {
      holdingCount += 1;
      const quantity = readOptionalNumber(row, ["quantity"]);
      const currentPrice = readOptionalNumber(row, ["current_price_jpy"]);
      if (quantity === null || currentPrice === null) {
        unpricedCount += 1;
        continue;
      }
      valuation += quantity * currentPrice;
      pricedCount += 1;
    }
    if (rows.length < to - from + 1) {
      return {
        valuation: roundYen(valuation),
        holdingCount,
        pricedCount,
        unpricedCount,
        truncated: false,
      };
    }
  }

  return {
    valuation: roundYen(valuation),
    holdingCount,
    pricedCount,
    unpricedCount,
    truncated: true,
  };
}

async function readAnomalyCount(
  db: DepartmentFinanceSummaryDb,
  userId: string,
  monthStart: string,
): Promise<number> {
  const { count, error } = await db.from("anomaly_detections")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("target_month", monthStart)
    .is("dismissed_at", null)
    .limit(1);
  throwOnQueryError(error, "anomaly count read");
  if (typeof count !== "number" || !Number.isFinite(count) || count < 0) {
    throw new DepartmentFinanceSummaryActionError(
      "anomaly count read returned an invalid count",
      500,
    );
  }
  return Math.trunc(count);
}

function balanceFromSnapshot(snapshot: UnknownRecord | null): {
  totalAssets: number | null;
  totalLiabilities: number | null;
  netAssets: number;
} | null {
  const totalAssets = readOptionalNumber(snapshot, [
    "total_assets",
    "positive_asset_total",
    "positiveAssetTotal",
  ]);
  const totalLiabilities = readOptionalNumber(snapshot, [
    "total_liabilities",
    "liability_total",
    "liabilityTotal",
  ]);
  const explicitNet = readOptionalNumber(snapshot, ["net_worth", "netWorth"]);
  if (
    explicitNet === null && (totalAssets === null || totalLiabilities === null)
  ) {
    return null;
  }
  const assets = totalAssets === null ? null : roundYen(totalAssets);
  const liabilities = totalLiabilities === null
    ? null
    : roundYen(Math.abs(totalLiabilities));
  return {
    totalAssets: assets,
    totalLiabilities: liabilities,
    netAssets: roundYen(
      explicitNet ?? totalAssets! - Math.abs(totalLiabilities!),
    ),
  };
}

function balanceFromReport(report: UnknownRecord | null): {
  totalAssets: number | null;
  totalLiabilities: number | null;
  netAssets: number;
} | null {
  if (!report) return null;
  const totalAssets = readOptionalNumber(report, ["total_assets"]);
  const totalLiabilities = readOptionalNumber(report, ["total_liabilities"]);
  const explicitNet = readOptionalNumber(report, ["net_worth"]);
  if (
    explicitNet === null && (totalAssets === null || totalLiabilities === null)
  ) {
    return null;
  }
  const assets = totalAssets === null ? null : roundYen(totalAssets);
  const liabilities = totalLiabilities === null
    ? null
    : roundYen(Math.abs(totalLiabilities));
  return {
    totalAssets: assets,
    totalLiabilities: liabilities,
    netAssets: roundYen(
      explicitNet ?? totalAssets! - Math.abs(totalLiabilities!),
    ),
  };
}

function receivedIncomeFromPlan(plan: UnknownRecord | null): number | null {
  if (!plan) return null;
  const rawItems = Array.isArray(plan.income_plans)
    ? plan.income_plans
    : Array.isArray(plan.items)
    ? plan.items
    : null;
  if (!rawItems) return null;
  let total = 0;
  for (const raw of rawItems) {
    const item = asRecord(raw);
    if (!item || item.received !== true) continue;
    const amount = readOptionalNumber(item, ["amount"]);
    if (amount !== null) total += amount;
  }
  return roundYen(total);
}

function throwOnQueryError(error: QueryError | undefined, operation: string) {
  if (!error) return;
  throw new DepartmentFinanceSummaryActionError(
    `${operation} failed: ${error.message ?? "unknown"}`,
    500,
  );
}

function firstRecord(
  value: unknown[] | null | undefined,
): UnknownRecord | null {
  return toRecords(value)[0] ?? null;
}

function toRecords(value: unknown): UnknownRecord[] {
  if (!Array.isArray(value)) return [];
  return value.map(asRecord).filter((item): item is UnknownRecord =>
    item !== null
  );
}

function asRecord(value: unknown): UnknownRecord | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as UnknownRecord
    : null;
}

function readOptionalNumber(
  record: UnknownRecord | null,
  keys: string[],
): number | null {
  if (!record) return null;
  for (const key of keys) {
    const value = record[key];
    if (
      value === null || value === undefined ||
      (typeof value === "string" && value.trim() === "")
    ) continue;
    const numeric = typeof value === "number" ? value : Number(value);
    if (Number.isFinite(numeric)) return numeric;
  }
  return null;
}

function roundYen(value: number): number {
  return Math.round(value);
}
