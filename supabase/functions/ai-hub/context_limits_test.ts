import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type CustomDataSourceRow,
  type CustomDataSourceStore,
  estimateContextUnits,
  handleDataSourceRegister,
  handleDataSourceStatus,
  validateMessagesContextBudget,
} from "./context_limits.ts";

function createFakeDataSourceStore(options: {
  plan?: string;
  maxSources?: number;
  maxContextUnits?: number;
  seeded?: CustomDataSourceRow[];
} = {}): CustomDataSourceStore {
  const plan = options.plan ?? "free";
  const maxSources = options.maxSources ?? 2;
  const maxContextUnits = options.maxContextUnits ?? 1_000_000;
  const items = [...(options.seeded ?? [])];

  return {
    async getPlanLimits(_userId: string) {
      return {
        data: { plan, maxSources, maxContextUnits },
        error: null,
      };
    },
    async listSources(userId: string, limit: number) {
      return {
        data: items.filter((item) => item.user_id === userId).slice(0, limit),
        error: null,
      };
    },
    async insertSource(row) {
      const created: CustomDataSourceRow = {
        id: `src-${items.length + 1}`,
        user_id: row.user_id,
        name: row.name,
        source_type: row.source_type,
        estimated_units: row.estimated_units,
        created_at: "2026-11-24T00:00:00Z",
      };
      items.unshift(created);
      return { data: created, error: null };
    },
  };
}

Deno.test("validateMessagesContextBudget allows small prompts and rejects over-limit payloads", () => {
  const small = validateMessagesContextBudget([
    { role: "user", content: "Hello world こんにちは" },
  ], 1000);
  assertEquals(small.allowed, true);
  assertEquals(small.exceededBy, 0);
  assertEquals(estimateContextUnits("abcd"), 1);

  const oversized = validateMessagesContextBudget([
    { role: "user", content: "x".repeat(500) },
  ], 100);
  assertEquals(oversized.allowed, false);
  assertEquals(oversized.estimatedUnits > 100, true);
  assertEquals(oversized.exceededBy > 0, true);
});

Deno.test("handleDataSourceRegister enforces max_sources cap and oversize context check", async () => {
  const store = createFakeDataSourceStore({
    maxSources: 1,
    maxContextUnits: 50,
  });

  const oversized = await handleDataSourceRegister(store, "user-1", {
    name: "Too Huge",
    source_type: "text",
    sample_text: "a".repeat(400),
  });
  assertEquals(oversized.status, 413);

  const first = await handleDataSourceRegister(store, "user-1", {
    name: "Primary Docs",
    source_type: "markdown",
    sample_text: "short doc",
  });
  assertEquals(first.status, 201);
  assertEquals(first.body.limit_reached, true);

  const second = await handleDataSourceRegister(store, "user-1", {
    name: "Overflow Source",
    source_type: "text",
    sample_text: "ok",
  });
  assertEquals(second.status, 409);
  assertEquals(second.body.limit_reached, true);

  const statusRes = await handleDataSourceStatus(store, "user-1");
  assertEquals(statusRes.status, 200);
  assertEquals(statusRes.body.limit_reached, true);
  assertEquals(statusRes.body.remaining, 0);
});
