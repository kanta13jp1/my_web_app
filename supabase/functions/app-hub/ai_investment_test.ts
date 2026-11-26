import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  AiInvestmentError,
  handleAiInvestmentAction,
  type AiInvestmentDb,
} from "./ai_investment.ts";
import { AI_INVESTMENT_TREND_SOURCE } from "./ai_investment_ingestor.ts";

class MockAiInvestmentDb implements AiInvestmentDb {
  rows: Array<{
    id: string;
    source: string;
    metadata: Record<string, unknown>;
    created_at: string;
  }> = [];
  private seq = 1;

  from(_table: string) {
    const state: {
      op: "select" | "insert" | "update";
      insertVal?: Record<string, unknown>;
      updateVal?: Record<string, unknown>;
      eqFilters: Array<[string, unknown]>;
      jsonFilters: Array<[string, string]>;
    } = {
      op: "select",
      eqFilters: [],
      jsonFilters: [],
    };

    const execute = () => {
      if (state.op === "insert" && state.insertVal) {
        const created = {
          id: `inv-${this.seq++}`,
          source: String(state.insertVal.source ?? ""),
          metadata: (state.insertVal.metadata ?? {}) as Record<string, unknown>,
          created_at: `2026-05-0${this.seq}T00:00:00Z`,
        };
        this.rows.push(created);
        return { data: created, error: null };
      }

      const matches = this.rows.filter((row) => {
        for (const [col, val] of state.eqFilters) {
          if (col === "id" && row.id !== val) return false;
          if (col === "source" && row.source !== val) return false;
        }
        for (const [expr, expected] of state.jsonFilters) {
          const field = expr.replace("metadata->>", "");
          if (String(row.metadata[field] ?? "") !== expected) {
            return false;
          }
        }
        return true;
      });

      if (state.op === "update" && state.updateVal) {
        if (matches.length === 0) {
          return { data: null, error: null };
        }
        matches[0].metadata = (state.updateVal.metadata ?? {}) as Record<
          string,
          unknown
        >;
        return { data: matches[0], error: null };
      }

      return { data: matches, error: null };
    };

    const builder = {
      select(_columns: string) {
        return builder;
      },
      insert(values: Record<string, unknown>) {
        state.op = "insert";
        state.insertVal = values;
        return builder;
      },
      update(values: Record<string, unknown>) {
        state.op = "update";
        state.updateVal = values;
        return builder;
      },
      eq(col: string, val: unknown) {
        state.eqFilters.push([col, val]);
        return builder;
      },
      filter(col: string, _op: string, val: unknown) {
        state.jsonFilters.push([col, String(val)]);
        return builder;
      },
      order() {
        return builder;
      },
      limit() {
        return builder;
      },
      single() {
        const res = execute();
        return Promise.resolve({
          data: Array.isArray(res.data) ? res.data[0] ?? null : res.data,
          error: res.error,
        });
      },
      maybeSingle() {
        const res = execute();
        return Promise.resolve({
          data: Array.isArray(res.data) ? res.data[0] ?? null : res.data,
          error: res.error,
        });
      },
      then(onfulfilled?: (value: unknown) => unknown) {
        return Promise.resolve(execute()).then(onfulfilled);
      },
    };
    return builder;
  }
}

Deno.test(
  "ai_investment.seed_defaults is idempotent and enforces needs_verification",
  async () => {
    const db = new MockAiInvestmentDb();
    const first = await handleAiInvestmentAction({
      action: "ai_investment.seed_defaults",
      admin: db,
      body: {},
      userId: "user-1",
    });

    assertEquals(first.already_seeded, false);
    assertEquals(first.seeded_count, 3);
    assertEquals(db.rows.length, 3);
    assertEquals(db.rows[0].source, AI_INVESTMENT_TREND_SOURCE);
    assertEquals(db.rows[0].metadata.verification_status, "needs_verification");
    assertEquals(db.rows[0].metadata.requires_manual_verification, true);

    const second = await handleAiInvestmentAction({
      action: "ai_investment.seed_defaults",
      admin: db,
      body: {},
      userId: "user-1",
    });
    assertEquals(second.already_seeded, true);
    assertEquals(second.seeded_count, 0);
    assertEquals(db.rows.length, 3);
  },
);

Deno.test(
  "ai_investment.ingest normalizes, dedups, and forces needs_verification",
  async () => {
    const db = new MockAiInvestmentDb();
    const ingestRes = await handleAiInvestmentAction({
      action: "ai_investment.ingest",
      admin: db,
      body: {
        items: [
          {
            company_name: "Alpha Reasoning Corp",
            round_stage: "Series B",
            amount_usd: 55_000_000,
            announced_at: "2026-05-10T00:00:00Z",
            source_name: "Official Blog",
            source_url: "https://example.com/alpha",
            verification_status: "verified",
          },
          {
            company_name: "Alpha Reasoning Corp",
            round_stage: "Series B",
            amount_usd: 55_000_000,
            announced_at: "2026-05-10T00:00:00Z",
            source_name: "Duplicate Feed",
            source_url: "https://example.com/alpha",
          },
        ],
      },
      userId: "user-1",
    });

    assertEquals(ingestRes.ingested_count, 1);
    assertEquals(ingestRes.skipped_duplicates, 1);
    const records = ingestRes.records as Array<Record<string, unknown>>;
    assertEquals(records.length, 1);
    assertEquals(records[0].verification_status, "needs_verification");
    assertEquals(records[0].verification_label, "要検証");
    assertEquals(records[0].quarter, "2026-Q2");
  },
);

Deno.test(
  "ai_investment.verify_entry enforces user isolation and updates verification",
  async () => {
    const db = new MockAiInvestmentDb();
    await handleAiInvestmentAction({
      action: "ai_investment.ingest",
      admin: db,
      body: {
        company_name: "Beta Model Labs",
        round_stage: "Series A",
        announced_at: "2026-04-22T00:00:00Z",
        source_url: "https://example.org/beta",
      },
      userId: "user-1",
    });

    const targetId = db.rows[0].id;
    await assertRejects(
      () =>
        handleAiInvestmentAction({
          action: "ai_investment.verify_entry",
          admin: db,
          body: { id: targetId, decision: "verified" },
          userId: "user-2",
        }),
      AiInvestmentError,
      "not found",
    );

    const verified = await handleAiInvestmentAction({
      action: "ai_investment.verify_entry",
      admin: db,
      body: {
        id: targetId,
        decision: "verified",
        verification_note: "Verified against official announcement URL",
      },
      userId: "user-1",
    });
    const rec = verified.record as Record<string, unknown>;
    assertEquals(rec.verification_status, "verified");
    assertEquals(rec.verification_label, "確認済み");
    assertEquals(rec.requires_manual_verification, false);
    assertEquals(rec.verified_by, "user-1");

    const listed = await handleAiInvestmentAction({
      action: "ai_investment.list",
      admin: db,
      body: { quarter: "2026-Q2", verification_status: "verified" },
      userId: "user-1",
    });
    assertEquals((listed.records as unknown[]).length, 1);
  },
);

Deno.test("ai_investment requires authenticated userId", async () => {
  const db = new MockAiInvestmentDb();
  await assertRejects(
    () =>
      handleAiInvestmentAction({
        action: "ai_investment.list",
        admin: db,
        body: {},
        userId: "",
      }),
    AiInvestmentError,
    "Unauthorized",
  );
});
