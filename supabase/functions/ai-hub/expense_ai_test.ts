import {
  classifyExpenseDeterministic,
  type ExpenseAiDb,
  type ExpenseAiDbQuery,
  handleClassifyExpenseAction,
  handleWeeklySpendingCoachingAction,
} from "./expense_ai.ts";

Deno.test("classifyExpenseDeterministic auto-confirms known subscription", () => {
  const classification = classifyExpenseDeterministic({
    source: "card_csv",
    id: "row-1",
    posted_at: "2026-05-26",
    description: "Spotify subscription",
    amount: 980,
  });

  assertEquals(classification.category, "subscription");
  assertEquals(classification.status, "auto_confirmed");
  assertEquals(classification.confidence >= 0.7, true);
});

Deno.test("handleClassifyExpenseAction stores review queue for unknown rows", async () => {
  const db = new FakeDb();
  const result = await handleClassifyExpenseAction({
    db,
    userId: "user-1",
    body: {
      expenses: [
        {
          source: "bank_csv",
          id: "1",
          posted_at: "2026-05-26",
          description: "mystery vendor",
          amount: 1234,
        },
      ],
    },
  });

  assertEquals(result.review_count, 1);
  assertEquals(db.upserts[0].table, "expense_classifications");
  assertEquals(db.upserts[0].value.status, "needs_review");
});

Deno.test("handleWeeklySpendingCoachingAction builds mentor actions from deltas", async () => {
  const db = new FakeDb();
  const result = await handleWeeklySpendingCoachingAction({
    db,
    userId: "user-1",
    generatedAt: new Date("2026-06-07T00:00:00.000Z"),
    body: {
      current_category_totals: { food: 48000, subscription: 6000 },
      previous_category_totals: { food: 30000, subscription: 6000 },
    },
  });

  assertEquals(result.status, "deterministic_fallback");
  assertEquals(result.actions[0].action_key, "reduce_food");
  assertEquals(db.upserts[0].table, "weekly_spending_coaching_cards");
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

class FakeDb implements ExpenseAiDb {
  upserts: Array<{ table: string; value: Record<string, unknown> }> = [];
  inserts: Array<{ table: string; value: unknown }> = [];

  from(table: string): ExpenseAiDbQuery {
    return new FakeQuery(table, this);
  }
}

class FakeQuery implements ExpenseAiDbQuery {
  constructor(
    private readonly table: string,
    private readonly db: FakeDb,
  ) {}

  select(): ExpenseAiDbQuery {
    return this;
  }

  eq(): ExpenseAiDbQuery {
    return this;
  }

  gte(): ExpenseAiDbQuery {
    return this;
  }

  lt(): ExpenseAiDbQuery {
    return this;
  }

  order(): ExpenseAiDbQuery {
    return this;
  }

  limit(): Promise<{ data: unknown[]; error: null }> {
    return Promise.resolve({ data: [], error: null });
  }

  upsert(value: Record<string, unknown>) {
    this.db.upserts.push({ table: this.table, value });
    return {
      select: () => ({
        single: () => Promise.resolve({ data: { id: "row-1" }, error: null }),
      }),
    };
  }

  insert(value: unknown): Promise<{ data: null; error: null }> {
    this.db.inserts.push({ table: this.table, value });
    return Promise.resolve({ data: null, error: null });
  }
}
