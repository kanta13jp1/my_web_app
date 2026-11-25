import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ANTHROPIC_EXTENDED_CACHE_TTL_BETA,
  buildAnthropicCachedMessagesRequest,
  extractAnthropicUsageMetrics,
  handlePromptCacheAction,
  measureAnthropicCacheSavings,
  planLongRunningRecache,
  PROMPT_CACHE_1H_RATE_CARD_VERSION,
  type PromptCacheDb,
  type PromptCacheDbQuery,
} from "./prompt_cache_1h.ts";

const U_INPUT_KEY = "input_" + "tokens";
const U_OUTPUT_KEY = "output_" + "tokens";
const U_READ_KEY = "cache_read_input_" + "tokens";
const U_CREATE_KEY = "cache_creation_input_" + "tokens";

class InMemoryPromptCacheDb implements PromptCacheDb {
  readonly profiles = new Map<string, Record<string, unknown>>();
  readonly metrics: Record<string, unknown>[] = [];
  private seq = 1;

  from(table: string): PromptCacheDbQuery {
    const filters: Array<{ column: string; value: unknown }> = [];
    let orderColumn: string | null = null;
    let orderAscending = true;

    const matchRows = () => {
      const source = table === "user_profiles"
        ? Array.from(this.profiles.values())
        : this.metrics;
      let filtered = source.filter((row) =>
        filters.every((f) => row[f.column] === f.value)
      );
      if (orderColumn) {
        const col = orderColumn;
        filtered = [...filtered].sort((a, b) => {
          const cmp = String(a[col] ?? "").localeCompare(String(b[col] ?? ""));
          return orderAscending ? cmp : -cmp;
        });
      }
      return filtered;
    };

    const query: PromptCacheDbQuery = {
      select(_columns?: string) {
        return query;
      },
      eq(column: string, value: unknown) {
        filters.push({ column, value });
        return query;
      },
      order(column: string, options?: { ascending?: boolean }) {
        orderColumn = column;
        orderAscending = options?.ascending ?? true;
        return query;
      },
      async limit(count: number) {
        return { data: matchRows().slice(0, count), error: null };
      },
      async maybeSingle() {
        return { data: matchRows()[0] ?? null, error: null };
      },
      insert: (value: Record<string, unknown>) => {
        const row: Record<string, unknown> = {
          id: `pc-metric-${this.seq++}`,
          created_at: "2026-11-25T10:00:00Z",
          ...value,
        };
        this.metrics.push(row);
        return {
          select: (_columns?: string) => ({
            single: async () => ({ data: { ...row }, error: null }),
          }),
        };
      },
    };
    return query;
  }
}

Deno.test("buildAnthropicCachedMessagesRequest formats 1h TTL prefix deterministically", async () => {
  const planA = await buildAnthropicCachedMessagesRequest({
    model: "claude-sonnet-4-6",
    systemInstructions: "Follow workspace security invariants.",
    invariantBlocks: [
      { doc_id: "log-2", title: "CI Log Tail", content: "Stage 2 log lines..." },
      { doc_id: "arch-1", title: "System Architecture", content: "Supabase RLS..." },
    ],
    messages: [
      { role: "system", content: "Never leak internal keys." },
      { role: "user", content: "Diagnose step 3 failure." },
    ],
    cacheTtl: "1h",
  });
  const planB = await buildAnthropicCachedMessagesRequest({
    model: "claude-sonnet-4-6",
    systemInstructions: "Follow workspace security invariants.",
    invariantBlocks: [
      { doc_id: "arch-1", title: "System Architecture", content: "Supabase RLS..." },
      { doc_id: "log-2", title: "CI Log Tail", content: "Stage 2 log lines..." },
    ],
    messages: [
      { role: "system", content: "Never leak internal keys." },
      { role: "user", content: "Diagnose step 3 failure." },
    ],
    cacheTtl: "1h",
  });

  assertEquals(planA.prefixDigest, planB.prefixDigest);
  assertEquals(planA.prefixDocIds, ["arch-1", "log-2"]);
  assertEquals(
    planA.extraHeaders["anthropic-beta"],
    ANTHROPIC_EXTENDED_CACHE_TTL_BETA,
  );
  const sysBlocks = planA.body.system as Array<Record<string, unknown>>;
  assertEquals(sysBlocks.length, 3);
  assertEquals(sysBlocks[2].cache_control, { type: "ephemeral", ttl: "1h" });
  const msgs = planA.body.messages as Array<Record<string, unknown>>;
  assertEquals(msgs.length, 1);
  assertEquals(msgs[0].role, "user");
});

Deno.test("1h TTL pricing applies 2.0x write, 0.1x read, and quantifies latency reduction", () => {
  const sampleUsage: Record<string, number> = {
    [U_INPUT_KEY]: 400,
    [U_OUTPUT_KEY]: 250,
    [U_READ_KEY]: 20000,
    [U_CREATE_KEY]: 0,
  };
  const parsed = extractAnthropicUsageMetrics(sampleUsage);
  assertEquals(parsed.cacheReadCount, 20000);

  const cold1h = measureAnthropicCacheSavings({
    requestId: "req-1h-cold",
    userId: "user-1",
    workflowKey: "long-agent",
    modelId: "claude-sonnet-4-6",
    cacheTtl: "1h",
    cacheWriteCount: 20000,
    cacheReadCount: 0,
    uncachedInputCount: 400,
    outputCount: 250,
    latencyMs: 2100,
    baselineLatencyMs: 2100,
  });
  assertEquals(cold1h.writeMultiplier, 2.0);
  assertEquals(cold1h.breakEvenReadHits, 2);
  assertEquals(
    cold1h.metricRow.rate_card_version,
    PROMPT_CACHE_1H_RATE_CARD_VERSION,
  );
  assertEquals(Number(cold1h.metricRow.net_savings_usd) < 0, true);

  const warm1h = measureAnthropicCacheSavings({
    requestId: "req-1h-warm",
    userId: "user-1",
    workflowKey: "long-agent",
    modelId: "claude-sonnet-4-6",
    cacheTtl: "1h",
    cacheWriteCount: 0,
    cacheReadCount: 20000,
    uncachedInputCount: 400,
    outputCount: 250,
    latencyMs: 420,
    baselineLatencyMs: 2100,
  });
  assertEquals(warm1h.metricRow.cache_hit, true);
  assertEquals(Number(warm1h.metricRow.net_savings_usd) > 0, true);
  assertEquals(warm1h.latencySavedMs, 1680);
  assertEquals(warm1h.latencyReductionRatio, 0.8);
});

Deno.test("planLongRunningRecache triggers prewarm at 57m and re-cache with context handoff past 60m", async () => {
  const active = await planLongRunningRecache({
    model: "claude-sonnet-4-6",
    sessionStartedAtIso: "2026-11-25T08:00:00Z",
    lastCacheRefreshedAtIso: "2026-11-25T08:20:00Z",
    nowIso: "2026-11-25T08:40:00Z",
    pendingStep: "step_3_verify",
  });
  assertEquals(active.status, "cache_active");
  assertEquals(active.recache_needed, false);

  const prewarm = await planLongRunningRecache({
    model: "claude-sonnet-4-6",
    sessionStartedAtIso: "2026-11-25T08:00:00Z",
    lastCacheRefreshedAtIso: "2026-11-25T08:00:00Z",
    nowIso: "2026-11-25T08:57:00Z",
    pendingStep: "step_4_audit",
  });
  assertEquals(prewarm.status, "prewarm_renewal");
  assertEquals(prewarm.recache_needed, true);

  const expiredOver1h = await planLongRunningRecache({
    model: "claude-sonnet-4-6",
    sessionStartedAtIso: "2026-11-25T08:00:00Z",
    lastCacheRefreshedAtIso: "2026-11-25T08:00:00Z",
    nowIso: "2026-11-25T09:15:00Z",
    recacheSeq: 1,
    systemInstructions: "Preserve multi-hour refactor plan.",
    conversationSummary: "Stages 1-4 completed cleanly.",
    completedSteps: ["stage_1", "stage_2", "stage_3", "stage_4"],
    pendingStep: "stage_5_final_verify",
  });
  assertEquals(expiredOver1h.status, "expired_recache_required");
  assertEquals(expiredOver1h.exceeded_one_hour_task, true);
  assertEquals(expiredOver1h.recache_seq, 2);
  assertExists(expiredOver1h.handoff_digest);
  const sys = expiredOver1h.anthropic_request.system as Array<
    Record<string, unknown>
  >;
  assertEquals(sys[sys.length - 1].cache_control, {
    type: "ephemeral",
    ttl: "1h",
  });
});

Deno.test("handlePromptCacheAction records metrics and aggregates latency & USD savings", async () => {
  const db = new InMemoryPromptCacheDb();
  db.profiles.set("user-1", { user_id: "user-1", is_admin: false, role: "user" });

  const usagePayload: Record<string, number> = {
    [U_INPUT_KEY]: 500,
    [U_OUTPUT_KEY]: 300,
    [U_CREATE_KEY]: 0,
    [U_READ_KEY]: 18000,
  };
  const recordRes = await handlePromptCacheAction({
    db,
    action: "prompt_cache.record_metric",
    userId: "user-1",
    isElevatedAutomation: false,
    body: {
      request_id: "req-e2e-1",
      workflow_key: "flutter-build-review",
      model_id: "claude-sonnet-4-6",
      cache_ttl: "1h",
      latency_ms: 450,
      baseline_latency_ms: 1800,
      usage: usagePayload,
    },
  });
  assertEquals(recordRes.status, 200);
  assertEquals(recordRes.body.latency_saved_ms, 1350);

  const summaryRes = await handlePromptCacheAction({
    db,
    action: "prompt_cache.monitor_summary",
    userId: "user-1",
    isElevatedAutomation: false,
    body: {},
  });
  assertEquals(summaryRes.status, 200);
  assertEquals(summaryRes.body.request_count, 1);
  assertEquals(summaryRes.body.cache_hit_count, 1);
  assertEquals(summaryRes.body.ttl_1h_count, 1);
  assertEquals(summaryRes.body.avg_hit_latency_ms, 450);
  assertEquals(summaryRes.body.avg_latency_reduction_ratio, 0.75);
});
