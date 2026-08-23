import {
  type DepartmentFinanceSummaryDb,
  type DepartmentFinanceSummaryDbQuery,
  handleDepartmentFinanceSummaryAction,
  isDepartmentFinanceSummaryAction,
  resolveDepartmentFinanceSummaryMonth,
} from "./department_finance_summary_actions.ts";

type Row = Record<string, unknown>;
type Predicate = (row: Row) => boolean;

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Assertion failed:\nactual:   ${JSON.stringify(actual)}\nexpected: ${
        JSON.stringify(expected)
      }`,
    );
  }
}

type QueryCall = {
  table: string;
  columns: string;
  options?: { count?: "exact"; head?: boolean };
  filters: Array<{ kind: "eq" | "is"; column: string; value: unknown }>;
  range?: [number, number];
  limit?: number;
};

class FakeQuery implements DepartmentFinanceSummaryDbQuery {
  private columns = "";
  private options?: { count?: "exact"; head?: boolean };
  private predicates: Predicate[] = [];
  private filters: QueryCall["filters"] = [];
  private orderColumn = "";
  private ascending = true;

  constructor(
    private readonly table: string,
    private readonly db: FakeDb,
  ) {}

  select(
    columns = "",
    options?: { count?: "exact"; head?: boolean },
  ): DepartmentFinanceSummaryDbQuery {
    this.columns = columns;
    this.options = options;
    return this;
  }

  eq(column: string, value: string): DepartmentFinanceSummaryDbQuery {
    this.filters.push({ kind: "eq", column, value });
    this.predicates.push((row) => String(row[column] ?? "") === value);
    return this;
  }

  is(column: string, value: null): DepartmentFinanceSummaryDbQuery {
    this.filters.push({ kind: "is", column, value });
    this.predicates.push((row) => (row[column] ?? null) === value);
    return this;
  }

  order(
    column: string,
    options?: { ascending?: boolean },
  ): DepartmentFinanceSummaryDbQuery {
    this.orderColumn = column;
    this.ascending = options?.ascending !== false;
    return this;
  }

  limit(count: number) {
    const rows = this.filteredRows();
    this.db.calls.push({
      table: this.table,
      columns: this.columns,
      options: this.options,
      filters: [...this.filters],
      limit: count,
    });
    const error = this.db.errors[this.table];
    if (error) {
      return Promise.resolve({ data: null, error: { message: error } });
    }
    return Promise.resolve({
      data: this.options?.head ? [] : rows.slice(0, count),
      error: null,
      count: this.options?.count === "exact" ? rows.length : null,
    });
  }

  range(from: number, to: number) {
    const rows = this.filteredRows();
    this.db.calls.push({
      table: this.table,
      columns: this.columns,
      options: this.options,
      filters: [...this.filters],
      range: [from, to],
    });
    const error = this.db.errors[this.table];
    if (error) {
      return Promise.resolve({ data: null, error: { message: error } });
    }
    return Promise.resolve({ data: rows.slice(from, to + 1), error: null });
  }

  private filteredRows(): Row[] {
    const rows = (this.db.rows[this.table] ?? []).filter((row) =>
      this.predicates.every((predicate) => predicate(row))
    );
    if (!this.orderColumn) return rows;
    return [...rows].sort((left, right) => {
      const comparison = String(left[this.orderColumn] ?? "").localeCompare(
        String(right[this.orderColumn] ?? ""),
      );
      return this.ascending ? comparison : -comparison;
    });
  }
}

class FakeDb implements DepartmentFinanceSummaryDb {
  calls: QueryCall[] = [];
  errors: Record<string, string> = {};

  constructor(readonly rows: Record<string, Row[]>) {}

  from(table: string): DepartmentFinanceSummaryDbQuery {
    return new FakeQuery(table, this);
  }
}

Deno.test("recognizes the configured ai-hub action identifier", () => {
  assertEquals(
    isDepartmentFinanceSummaryAction("department_finance_summary"),
    true,
  );
  assertEquals(
    isDepartmentFinanceSummaryAction("ai_hub.department_finance_summary"),
    true,
  );
  assertEquals(
    isDepartmentFinanceSummaryAction("department_finance_write"),
    false,
  );
});

Deno.test("month defaults to the current JST month and validates input", () => {
  assertEquals(
    resolveDepartmentFinanceSummaryMonth(
      undefined,
      new Date("2026-07-31T15:30:00.000Z"),
    ),
    { monthKey: "2026-08", monthStart: "2026-08-01" },
  );
  assertEquals(resolveDepartmentFinanceSummaryMonth("2026-06-01"), {
    monthKey: "2026-06",
    monthStart: "2026-06-01",
  });

  let message = "";
  try {
    resolveDepartmentFinanceSummaryMonth("2026-13");
  } catch (error) {
    message = error instanceof Error ? error.message : String(error);
  }
  assert(message.includes("month is invalid"), `unexpected error: ${message}`);
});

Deno.test("builds the four finance KPIs from user-scoped monthly data", async () => {
  const db = new FakeDb({
    asset_liability_monthly_snapshots: [{
      user_id: "user-1",
      month_key: "2026-08",
      payload: {
        positive_asset_total: 2_000_000,
        liability_total: 700_000,
        net_worth: 1_300_000,
        monthly_paid_payment_total: 300_000,
      },
    }],
    monthly_asset_reports: [{
      user_id: "user-1",
      year_month: "2026-08-01",
      total_assets: 1,
      total_liabilities: 1,
      net_worth: 0,
    }],
    asset_liability_income_plans: [{
      user_id: "user-1",
      month_key: "2026-08",
      payload: {
        income_plans: [
          { amount: 500_000, received: true },
          { amount: 200_000, received: false },
        ],
      },
    }],
    investment_assets: [
      {
        id: "holding-1",
        user_id: "user-1",
        quantity: "10",
        current_price_jpy: "1200",
      },
      {
        id: "holding-2",
        user_id: "user-1",
        quantity: "2",
        current_price_jpy: null,
      },
      {
        id: "other-user-holding",
        user_id: "user-2",
        quantity: "99",
        current_price_jpy: "9999",
      },
    ],
    anomaly_detections: [
      {
        id: "active",
        user_id: "user-1",
        target_month: "2026-08-01",
        dismissed_at: null,
      },
      {
        id: "dismissed",
        user_id: "user-1",
        target_month: "2026-08-01",
        dismissed_at: "2026-08-05T00:00:00Z",
      },
      {
        id: "other-month",
        user_id: "user-1",
        target_month: "2026-07-01",
        dismissed_at: null,
      },
    ],
  });

  const result = await handleDepartmentFinanceSummaryAction({
    db,
    body: { month_key: "2026-08" },
    userId: "user-1",
    now: new Date("2026-08-17T01:02:03.000Z"),
  });

  assertEquals(result.net_assets, 1_300_000);
  assertEquals(result.current_month_cashflow, 200_000);
  assertEquals(result.investment_valuation, 12_000);
  assertEquals(result.anomaly_count, 1);
  assertEquals(result.sources, {
    balance_sheet: "monthly_snapshot",
    cashflow: "income_plans",
  });
  assertEquals(result.availability, {
    net_assets: "available",
    current_month_cashflow: "available",
    investment_valuation: "partial",
    anomaly_count: "available",
  });
  assertEquals(result.priced_investment_count, 1);
  assertEquals(result.unpriced_investment_count, 1);
  assert(
    !db.calls.some((call) => call.table === "monthly_asset_reports"),
    "normalized report fallback should not be fetched when a snapshot exists",
  );

  for (const call of db.calls) {
    assert(
      call.filters.some((filter) =>
        filter.kind === "eq" && filter.column === "user_id" &&
        filter.value === "user-1"
      ),
      `${call.table} query was not scoped to the authenticated user`,
    );
  }
  const anomalyCall = db.calls.find((call) =>
    call.table === "anomaly_detections"
  );
  assertEquals(anomalyCall?.columns, "id");
  assertEquals(anomalyCall?.options, { count: "exact", head: true });
  const investmentCall = db.calls.find((call) =>
    call.table === "investment_assets"
  );
  assertEquals(investmentCall?.columns, "id,quantity,current_price_jpy");
});

Deno.test("prefers snapshot income and falls back to a normalized monthly report", async () => {
  const db = new FakeDb({
    asset_liability_monthly_snapshots: [{
      user_id: "user-1",
      month_key: "2026-08",
      payload: {
        monthlyReceivedIncomeTotal: 600_000,
        monthlyPaidPaymentTotal: 100_000,
      },
    }],
    monthly_asset_reports: [{
      user_id: "user-1",
      year_month: "2026-08-01",
      total_assets: "900000",
      total_liabilities: "250000",
      net_worth: "650000",
    }],
    asset_liability_income_plans: [{
      user_id: "user-1",
      month_key: "2026-08",
      payload: { income_plans: [{ amount: 1, received: true }] },
    }],
    investment_assets: [],
    anomaly_detections: [],
  });

  const result = await handleDepartmentFinanceSummaryAction({
    db,
    body: { year_month: "2026-08-01" },
    userId: "user-1",
    now: new Date("2026-08-17T00:00:00.000Z"),
  });

  assertEquals(result.net_assets, 650_000);
  assertEquals(result.current_month_cashflow, 500_000);
  assertEquals(result.sources, {
    balance_sheet: "monthly_asset_report",
    cashflow: "monthly_snapshot",
  });
  assertEquals(result.investment_valuation, 0);
  assertEquals(result.availability.investment_valuation, "not_recorded");
});

Deno.test("does not turn missing finance data into a misleading zero", async () => {
  const db = new FakeDb({
    asset_liability_monthly_snapshots: [],
    monthly_asset_reports: [],
    asset_liability_income_plans: [],
    investment_assets: [],
    anomaly_detections: [],
  });
  const result = await handleDepartmentFinanceSummaryAction({
    db,
    body: { month_key: "2026-08" },
    userId: "user-1",
    now: new Date("2026-08-17T00:00:00.000Z"),
  });

  assertEquals(result.net_assets, null);
  assertEquals(result.current_month_cashflow, null);
  assertEquals(result.investment_valuation, 0);
  assertEquals(result.anomaly_count, 0);
  assertEquals(result.sources, { balance_sheet: "none", cashflow: "none" });
  assertEquals(result.availability.net_assets, "not_recorded");
  assertEquals(result.availability.current_month_cashflow, "not_recorded");
});

Deno.test("pages investment holdings with a stable order", async () => {
  const holdings = Array.from({ length: 201 }, (_, index) => ({
    id: String(index).padStart(4, "0"),
    user_id: "user-1",
    quantity: 1,
    current_price_jpy: 10,
  }));
  const db = new FakeDb({
    asset_liability_monthly_snapshots: [],
    monthly_asset_reports: [],
    asset_liability_income_plans: [],
    investment_assets: holdings,
    anomaly_detections: [],
  });

  const result = await handleDepartmentFinanceSummaryAction({
    db,
    body: { month_key: "2026-08" },
    userId: "user-1",
  });
  assertEquals(result.investment_valuation, 2010);
  assertEquals(result.investment_holding_count, 201);
  assertEquals(
    db.calls.filter((call) => call.table === "investment_assets").map((call) =>
      call.range
    ),
    [[0, 199], [200, 399]],
  );
});

Deno.test("requires login and surfaces database read failures", async () => {
  const emptyDb = new FakeDb({});
  let loginError = "";
  try {
    await handleDepartmentFinanceSummaryAction({
      db: emptyDb,
      body: {},
      userId: "",
    });
  } catch (error) {
    loginError = error instanceof Error ? error.message : String(error);
  }
  assertEquals(loginError, "login required");

  const failingDb = new FakeDb({});
  failingDb.errors.monthly_asset_reports = "permission denied";
  let queryError = "";
  try {
    await handleDepartmentFinanceSummaryAction({
      db: failingDb,
      body: { month_key: "2026-08" },
      userId: "user-1",
    });
  } catch (error) {
    queryError = error instanceof Error ? error.message : String(error);
  }
  assert(
    queryError.includes("monthly report read failed"),
    `unexpected error: ${queryError}`,
  );
});
