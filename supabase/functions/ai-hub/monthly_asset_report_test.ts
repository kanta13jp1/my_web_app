import {
  buildDeterministicMonthlyAssetSummary,
  handleMonthlyAssetReportAction,
  isMonthlyAssetReportAction,
  type MonthlyAssetReportDb,
  type MonthlyAssetReportDbQuery,
  normalizeMonthlyAssetReportMonth,
  normalizeMonthlyAssetReportProvider,
} from "./monthly_asset_report.ts";

Deno.test("normalizeMonthlyAssetReportMonth accepts month and date inputs", () => {
  assertEquals(normalizeMonthlyAssetReportMonth("2026-06"), {
    monthKey: "2026-06",
    yearMonth: "2026-06-01",
  });
  assertEquals(normalizeMonthlyAssetReportMonth("2026-06-18"), {
    monthKey: "2026-06",
    yearMonth: "2026-06-01",
  });
});

Deno.test("normalizeMonthlyAssetReportProvider maps common aliases", () => {
  assertEquals(normalizeMonthlyAssetReportProvider("Claude"), "anthropic");
  assertEquals(normalizeMonthlyAssetReportProvider("GPT"), "openai");
  assertEquals(normalizeMonthlyAssetReportProvider("Gemini"), "google");
  assertEquals(normalizeMonthlyAssetReportProvider("Kimi"), "moonshot");
});

Deno.test("monthly asset report action names are recognized", () => {
  assertEquals(
    isMonthlyAssetReportAction("asset.monthly_report.generate"),
    true,
  );
  assertEquals(
    isMonthlyAssetReportAction("asset_liability.monthly_report.generate"),
    true,
  );
  assertEquals(isMonthlyAssetReportAction("provider.chat"), false);
});

Deno.test("handleMonthlyAssetReportAction writes deterministic report by default", async () => {
  const db = new FakeDb({
    asset_liability_monthly_snapshots: [
      {
        user_id: "user-1",
        month_key: "2026-06",
        payload: {
          positiveAssetTotal: 1200000,
          liabilityTotal: 450000,
          netWorth: 750000,
          cashLikeTotal: 300000,
          monthlyScheduledPaymentTotal: 90000,
          monthlyActualPaymentTotal: 85000,
          monthlyPaymentDifferenceTotal: -5000,
          overduePaymentCount: 1,
        },
      },
    ],
  });

  const result = await handleMonthlyAssetReportAction({
    db,
    userId: "user-1",
    body: { year_month: "2026-06" },
    aiSummaryEnabled: false,
    generatedAt: new Date("2026-06-30T00:00:00.000Z"),
  });

  assertEquals(result.status, "feature_flag_off");
  assertEquals(result.snapshot.total_assets, 1200000);
  assertEquals(result.snapshot.total_liabilities, 450000);
  assertEquals(result.snapshot.net_worth, 750000);
  assertEquals(db.upserts.length, 1);
  assertEquals(db.upserts[0].table, "monthly_asset_reports");
  assertEquals(db.upserts[0].value.year_month, "2026-06-01");
  assertEquals(db.upserts[0].value.ai_model, "deterministic-fallback");
});

Deno.test("handleMonthlyAssetReportAction uses provider when enabled", async () => {
  const db = new FakeDb();
  const result = await handleMonthlyAssetReportAction({
    db,
    userId: "user-1",
    body: {
      year_month: "2026-06",
      provider_preference: "claude",
      snapshot: {
        total_assets: 700000,
        total_liabilities: 200000,
      },
    },
    aiSummaryEnabled: true,
    invokeProvider: (request) => {
      assertEquals(request.provider, "anthropic");
      return Promise.resolve({
        ok: true,
        text: "AI summary",
        modelUsed: "claude-test",
      });
    },
  });

  assertEquals(result.status, "ai_summary_generated");
  assertEquals(result.ai_summary, "AI summary");
  assertEquals(result.ai_model, "claude-test");
  assertEquals(db.upserts[0].value.total_assets, 700000);
  assertEquals(db.upserts[0].value.total_liabilities, 200000);
});

Deno.test("handleMonthlyAssetReportAction falls back when provider fails", async () => {
  const db = new FakeDb();
  const result = await handleMonthlyAssetReportAction({
    db,
    userId: "user-1",
    body: {
      year_month: "2026-06",
      snapshot: { total_assets: 100, total_liabilities: 25 },
    },
    aiSummaryEnabled: true,
    invokeProvider: () =>
      Promise.resolve({
        ok: false,
        error: "apiKeyRequired",
        isRetriable: false,
      }),
  });

  assertEquals(result.status, "deterministic_fallback");
  assertEquals(result.ai_model, "deterministic-fallback");
  assertEquals(result.warnings.length, 1);
});

Deno.test("buildDeterministicMonthlyAssetSummary includes core metrics", () => {
  const summary = buildDeterministicMonthlyAssetSummary({
    month_key: "2026-06",
    total_assets: 1000,
    total_liabilities: 300,
    net_worth: 700,
    cash_like_total: 200,
    monthly_scheduled_payment_total: 50,
    monthly_paid_payment_total: 40,
    monthly_unpaid_payment_total: 10,
    monthly_actual_payment_total: 45,
    monthly_payment_difference_total: -5,
    overdue_payment_count: 0,
    source: "request",
  });

  assertEquals(summary.includes("Assets: 1,000 JPY"), true);
  assertEquals(summary.includes("liabilities: 300 JPY"), true);
  assertEquals(summary.includes("Payment difference: -5 JPY"), true);
});

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Assertion failed:\nactual:   ${JSON.stringify(actual)}\nexpected: ${
        JSON.stringify(expected)
      }`,
    );
  }
}

class FakeDb implements MonthlyAssetReportDb {
  rows: Record<string, Record<string, unknown>[]>;
  upserts: { table: string; value: Record<string, unknown> }[] = [];

  constructor(rows: Record<string, Record<string, unknown>[]> = {}) {
    this.rows = rows;
  }

  from(table: string): MonthlyAssetReportDbQuery {
    return new FakeQuery(table, this);
  }
}

class FakeQuery implements MonthlyAssetReportDbQuery {
  private filters: { column: string; value: string }[] = [];

  constructor(
    private readonly table: string,
    private readonly db: FakeDb,
  ) {}

  select(): MonthlyAssetReportDbQuery {
    return this;
  }

  eq(column: string, value: string): MonthlyAssetReportDbQuery {
    this.filters.push({ column, value });
    return this;
  }

  gte(): MonthlyAssetReportDbQuery {
    return this;
  }

  lt(): MonthlyAssetReportDbQuery {
    return this;
  }

  order(): MonthlyAssetReportDbQuery {
    return this;
  }

  limit(count: number): Promise<{ data: unknown[]; error: null }> {
    const rows = (this.db.rows[this.table] ?? []).filter((row) =>
      this.filters.every((filter) => row[filter.column] === filter.value)
    );
    return Promise.resolve({ data: rows.slice(0, count), error: null });
  }

  upsert(value: Record<string, unknown>) {
    this.db.upserts.push({ table: this.table, value });
    return {
      select: () => ({
        single: () =>
          Promise.resolve({
            data: { id: "report-1", ...value },
            error: null,
          }),
      }),
    };
  }
}
