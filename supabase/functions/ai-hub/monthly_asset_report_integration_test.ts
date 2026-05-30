import {
  handleMonthlyAssetReportAction,
  type MonthlyAssetReportDb,
  type MonthlyAssetReportDbQuery,
} from "./monthly_asset_report.ts";

Deno.test("monthly asset report integration keeps provider isolated when feature flag is off", async () => {
  const db = new FakeDb();

  const result = await handleMonthlyAssetReportAction({
    db,
    userId: "user-1",
    body: {
      year_month: "2026-06",
      provider_preference: "gemini",
      snapshot: monthlySnapshot(),
    },
    aiSummaryEnabled: false,
    generatedAt: new Date("2026-06-30T00:00:00.000Z"),
    invokeProvider: () => {
      throw new Error("provider should not be called while flag is off");
    },
  });

  assertEquals(result.status, "feature_flag_off");
  assertEquals(result.ai_enabled, false);
  assertEquals(result.provider, null);
  assertEquals(result.ai_model, "deterministic-fallback");
  assertEquals(db.upserts.length, 1);
  assertEquals(db.upserts[0].table, "monthly_asset_reports");
  assertEquals(db.upserts[0].value.year_month, "2026-06-01");
  assertStringIncludes(
    String(db.upserts[0].value.ai_summary),
    "2026-06 月次資産レポート",
  );
});

Deno.test("monthly asset report integration routes three provider mocks when feature flag is on", async () => {
  const providers = [
    { preference: "gemini", expected: "google", model: "gemini-test" },
    { preference: "gpt", expected: "openai", model: "gpt-test" },
    { preference: "claude", expected: "anthropic", model: "claude-test" },
  ];

  for (const provider of providers) {
    const db = new FakeDb();
    const providerSummary = `${provider.expected} の月次資産レポート要約です`;
    const result = await handleMonthlyAssetReportAction({
      db,
      userId: "user-1",
      body: {
        year_month: "2026-06",
        enable_ai_summary: true,
        provider_preference: provider.preference,
        model: provider.model,
        snapshot: monthlySnapshot(),
      },
      generatedAt: new Date("2026-06-30T00:00:00.000Z"),
      invokeProvider: (request) => {
        assertEquals(request.provider, provider.expected);
        assertEquals(request.model, provider.model);
        assertEquals(request.messages.length, 2);
        assertStringIncludes(
          request.messages[1].content,
          '"total_assets":1200000',
        );
        return Promise.resolve({
          ok: true,
          text: providerSummary,
          modelUsed: `${provider.expected}-mock-model`,
        });
      },
    });

    assertEquals(result.status, "ai_summary_generated");
    assertEquals(result.ai_enabled, true);
    assertEquals(result.provider, provider.expected);
    assertEquals(result.ai_summary, providerSummary);
    assertEquals(result.ai_model, `${provider.expected}-mock-model`);
    assertEquals(db.upserts.length, 1);
    assertEquals(db.upserts[0].value.ai_summary, providerSummary);
  }
});

Deno.test("monthly asset report integration falls back deterministically when provider chat fails", async () => {
  const db = new FakeDb();

  const result = await handleMonthlyAssetReportAction({
    db,
    userId: "user-1",
    body: {
      year_month: "2026-06",
      enable_ai_summary: true,
      provider_preference: "gpt",
      snapshot: monthlySnapshot(),
    },
    generatedAt: new Date("2026-06-30T00:00:00.000Z"),
    invokeProvider: (request) => {
      assertEquals(request.provider, "openai");
      return Promise.resolve({
        ok: false,
        error: "mock provider.chat unavailable",
        isRetriable: false,
      });
    },
  });

  assertEquals(result.status, "deterministic_fallback");
  assertEquals(result.ai_enabled, true);
  assertEquals(result.provider, "openai");
  assertEquals(result.ai_model, "deterministic-fallback");
  assertEquals(result.warnings.length, 1);
  assertStringIncludes(result.warnings[0], "mock provider.chat unavailable");
  assertStringIncludes(
    String(db.upserts[0].value.ai_summary),
    "資産: 1,200,000円",
  );
});

function monthlySnapshot(): Record<string, unknown> {
  return {
    month_key: "2026-06",
    total_assets: 1200000,
    total_liabilities: 450000,
    net_worth: 750000,
    cash_like_total: 300000,
    monthly_scheduled_payment_total: 90000,
    monthly_paid_payment_total: 85000,
    monthly_unpaid_payment_total: 5000,
    monthly_actual_payment_total: 85000,
    monthly_payment_difference_total: -5000,
    overdue_payment_count: 1,
  };
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

function assertStringIncludes(actual: string, expected: string) {
  if (!actual.includes(expected)) {
    throw new Error(
      `Assertion failed: expected ${JSON.stringify(actual)} to include ${
        JSON.stringify(expected)
      }`,
    );
  }
}

class FakeDb implements MonthlyAssetReportDb {
  upserts: { table: string; value: Record<string, unknown> }[] = [];

  from(table: string): MonthlyAssetReportDbQuery {
    return new FakeQuery(table, this);
  }
}

class FakeQuery implements MonthlyAssetReportDbQuery {
  constructor(
    private readonly table: string,
    private readonly db: FakeDb,
  ) {}

  select(): MonthlyAssetReportDbQuery {
    return this;
  }

  eq(): MonthlyAssetReportDbQuery {
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

  limit(): Promise<{ data: unknown[]; error: null }> {
    return Promise.resolve({ data: [], error: null });
  }

  upsert(value: Record<string, unknown>) {
    this.db.upserts.push({ table: this.table, value });
    return {
      select: () => ({
        single: () =>
          Promise.resolve({
            data: { id: "monthly-report-1", ...value },
            error: null,
          }),
      }),
    };
  }
}
