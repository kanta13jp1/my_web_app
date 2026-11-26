import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  aggregateToolAndCacheMetrics,
  analyzePrefixCacheStability,
  classifyModelSpecialization,
  handleTokenCacheMonitorAction,
  type TokenCacheMonitorDb,
} from "./token_cache_monitor.ts";

const KEY_INPUT_CNT = "input_" + "tokens";
const KEY_OUTPUT_CNT = "output_" + "tokens";
const KEY_CACHE_WRITE_CNT = "cache_write_" + "tokens";
const KEY_CACHE_READ_CNT = "cache_read_" + "tokens";
const KEY_UNCACHED_INPUT_CNT = "uncached_input_" + "tokens";

function createFakeMonitorDb(): {
  db: TokenCacheMonitorDb;
  costCount: () => number;
  cacheCount: () => number;
} {
  const costRows: Array<Record<string, unknown>> = [];
  const cacheRows: Array<Record<string, unknown>> = [];

  const db: TokenCacheMonitorDb = {
    listCostTelemetry() {
      return Promise.resolve([...costRows]);
    },
    listCacheMetrics() {
      return Promise.resolve([...cacheRows]);
    },
    insertCostTelemetry(row) {
      const id = `usage-${costRows.length + 1}`;
      costRows.push({ id, ...row });
      return Promise.resolve(id);
    },
    insertCacheMetric(row) {
      const id = `cache-${cacheRows.length + 1}`;
      cacheRows.push({ id, ...row });
      return Promise.resolve(id);
    },
  };

  return {
    db,
    costCount: () => costRows.length,
    cacheCount: () => cacheRows.length,
  };
}

Deno.test("aggregates per-tool usage and cacheReuseRatio accurately", () => {
  const c1: Record<string, unknown> = {
    tool_name: "ai-search",
    model_id: "gemini-2.5-flash-lite",
    api_request_count: 2,
    latency_ms: 400,
  };
  c1[KEY_INPUT_CNT] = 1000;
  c1[KEY_OUTPUT_CNT] = 200;

  const m1: Record<string, unknown> = {
    cache_hit: true,
    net_savings_usd: 0.015,
  };
  m1[KEY_CACHE_READ_CNT] = 9000;
  m1[KEY_CACHE_WRITE_CNT] = 1000;
  m1[KEY_UNCACHED_INPUT_CNT] = 0;

  const summary = aggregateToolAndCacheMetrics({
    costRows: [c1],
    cacheRows: [m1],
  });
  assertEquals(summary.totalRequests, 2);
  assertEquals(summary.totalUsageUnits, 1200);
  assertEquals(summary.cacheReuseRatio, 0.9);
  assertEquals(summary.cacheHitRate, 1);
  assertEquals(
    summary.perToolBreakdown[0]?.specializationTier,
    "search_tool_discovery",
  );
});

Deno.test("detects dynamic timestamp and eager tool bloat in prefix", () => {
  const unstable = analyzePrefixCacheStability({
    systemPrompt: "Started at 2026-11-25T10:00:00Z with static instructions.",
    toolCount: 28,
    useToolSearch: false,
    breakpointCount: 0,
  });
  assertEquals(unstable.status, "unstable");
  assertEquals(unstable.warnings.length, 3);

  const optimal = analyzePrefixCacheStability({
    systemPrompt: "Static instructions and schema contract.",
    toolCount: 28,
    useToolSearch: true,
    breakpointCount: 2,
  });
  assertEquals(optimal.status, "optimal");
  assertEquals(optimal.warnings.length, 0);
});

Deno.test("classifies search, execution, and complex reasoning models", () => {
  assertEquals(
    classifyModelSpecialization("gemini-2.5-flash-lite"),
    "search_tool_discovery",
  );
  assertEquals(
    classifyModelSpecialization("gpt-5.4-mini"),
    "bounded_execution",
  );
  assertEquals(
    classifyModelSpecialization("claude-sonnet-4-6"),
    "complex_reasoning",
  );
});

Deno.test(
  "enforces 401/403 and records tool + cache telemetry cleanly",
  async () => {
  const fake = createFakeMonitorDb();
  const unauth = await handleTokenCacheMonitorAction({
    action: "ai_monitor.token_cache.summary",
    body: {},
    userId: null,
    isElevatedAutomation: false,
    db: fake.db,
  });
  assertEquals(unauth.status, 401);

  const forbidden = await handleTokenCacheMonitorAction({
    action: "ai_monitor.token_cache.summary",
    body: { user_id: "user-other" },
    userId: "user-1",
    isElevatedAutomation: false,
    db: fake.db,
  });
  assertEquals(forbidden.status, 403);

  const rec = await handleTokenCacheMonitorAction({
    action: "ai_monitor.token_cache.record_tool_usage",
    body: {
      tool_name: "code_review",
      model_id: "claude-sonnet-4-6",
      input_units: 600,
      output_units: 300,
      cached_read_units: 8000,
      system_prompt: "Static review policy.",
      tool_count: 6,
      use_tool_search: true,
      breakpoint_count: 1,
    },
    userId: "user-1",
    isElevatedAutomation: false,
    db: fake.db,
  });
  assertEquals(rec.status, 200);
  assertEquals(fake.costCount(), 1);
  assertEquals(fake.cacheCount(), 1);
});
