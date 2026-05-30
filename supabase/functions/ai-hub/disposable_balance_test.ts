import {
  buildDisposableBalance,
  type DisposableBalanceDb,
  type DisposableBalanceDbQuery,
  handleDisposableBalanceAction,
  nextPaydayFor,
  salaryCycleStartFor,
} from "./disposable_balance.ts";

Deno.test("salary cycle uses next payday after the salary day", () => {
  assertEquals(nextPaydayFor("2026-05-24", 25), "2026-05-25");
  assertEquals(nextPaydayFor("2026-05-25", 25), "2026-06-25");
  assertEquals(salaryCycleStartFor("2026-05-25", 25), "2026-05-25");
});

Deno.test("buildDisposableBalance subtracts fixed costs and debt payments", () => {
  const result = buildDisposableBalance({
    asOfDate: "2026-05-25",
    salaryDay: 25,
    payslips: [
      {
        pay_date: "2026-05-25",
        net_amount: 465108,
        company_name: "Acme",
        confidence: 0.9,
      },
    ],
    recurringExpenses: [
      {
        name: "rent",
        amount: 92400,
        day_of_month: 27,
        category: "housing",
        paused_at: null,
      },
    ],
    debts: [
      {
        name: "student loan",
        principal: 800000,
        monthly_payment: 58000,
        interest_rate: 0.01,
        lender: "school",
        last_updated: "2026-02-01",
        paused_at: null,
      },
    ],
  });

  assertEquals(result.disposable, 314708);
  assertEquals(result.daily_pace, 10490);
  assertEquals(
    result.required_actions[0].action_key,
    "refresh_debt_student_loan",
  );
});

Deno.test("handleDisposableBalanceAction loads tables and persists run", async () => {
  const db = new FakeDb({
    payslips: [
      {
        user_id: "user-1",
        pay_date: "2026-05-25",
        net_amount: 465108,
        company_name: "Acme",
        confidence: 0.92,
      },
    ],
    recurring_expenses: [
      {
        user_id: "user-1",
        name: "Spotify",
        amount: 980,
        day_of_month: 1,
        category: "subscription",
        paused_at: null,
      },
      {
        user_id: "user-1",
        name: "Apple Music",
        amount: 1080,
        day_of_month: 1,
        category: "subscription",
        paused_at: null,
      },
    ],
    debts: [],
  });

  const result = await handleDisposableBalanceAction({
    db,
    userId: "user-1",
    body: { as_of_date: "2026-05-25" },
  });

  assertEquals(result.income, 465108);
  assertEquals(
    result.required_actions.some((action) =>
      action.action_key === "cancel_duplicate_music"
    ),
    true,
  );
  assertEquals(db.upserts[0].table, "disposable_balance_runs");
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

class FakeDb implements DisposableBalanceDb {
  upserts: Array<{ table: string; value: Record<string, unknown> }> = [];
  inserts: Array<{ table: string; value: Record<string, unknown> }> = [];

  constructor(
    private readonly rows: Record<string, Record<string, unknown>[]>,
  ) {}

  from(table: string): DisposableBalanceDbQuery {
    return new FakeQuery(table, this);
  }

  rowsFor(table: string) {
    return this.rows[table] ?? [];
  }
}

class FakeQuery implements DisposableBalanceDbQuery {
  private filters: Array<{ column: string; value: string; op: "eq" | "lte" }> =
    [];
  private orderColumn: string | null = null;
  private ascending = true;

  constructor(
    private readonly table: string,
    private readonly db: FakeDb,
  ) {}

  select(): DisposableBalanceDbQuery {
    return this;
  }

  eq(column: string, value: string): DisposableBalanceDbQuery {
    this.filters.push({ column, value, op: "eq" });
    return this;
  }

  lte(column: string, value: string): DisposableBalanceDbQuery {
    this.filters.push({ column, value, op: "lte" });
    return this;
  }

  order(
    column: string,
    options?: { ascending?: boolean },
  ): DisposableBalanceDbQuery {
    this.orderColumn = column;
    this.ascending = options?.ascending ?? true;
    return this;
  }

  limit(count: number): Promise<{ data: unknown[]; error: null }> {
    let rows = this.db.rowsFor(this.table).filter((row) =>
      this.filters.every((filter) => {
        const value = String(row[filter.column] ?? "");
        return filter.op === "eq"
          ? value === filter.value
          : value <= filter.value;
      })
    );
    if (this.orderColumn) {
      rows = rows.slice().sort((a, b) => {
        const left = String(a[this.orderColumn!] ?? "");
        const right = String(b[this.orderColumn!] ?? "");
        return this.ascending
          ? left.localeCompare(right)
          : right.localeCompare(left);
      });
    }
    return Promise.resolve({ data: rows.slice(0, count), error: null });
  }

  upsert(value: Record<string, unknown>) {
    this.db.upserts.push({ table: this.table, value });
    return {
      select: () => ({
        single: () => Promise.resolve({ data: { id: "run-1" }, error: null }),
      }),
    };
  }

  insert(value: Record<string, unknown>): Promise<{ data: null; error: null }> {
    this.db.inserts.push({ table: this.table, value });
    return Promise.resolve({ data: null, error: null });
  }
}
