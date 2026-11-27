import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  API_USAGE_LOG_SOURCE,
  estimateModelCostUsd,
  extractTokenUsage,
  recordApiUsageLog,
  type UsageLogInsertClient,
} from "./ai_cost_tracker.ts";

Deno.test("extracts Gemini usageMetadata including thinking output", () => {
  const usage = extractTokenUsage("gemini", {
    usageMetadata: {
      promptTokenCount: 2000,
      candidatesTokenCount: 500,
      thoughtsTokenCount: 300,
      totalTokenCount: 2800,
    },
  });

  assertEquals(usage.provider, "gemini");
  assertEquals(usage.usagePresent, true);
  assertEquals(usage.inputUnits, 2000);
  assertEquals(usage.outputUnits, 800);
  assertEquals(usage.totalUnits, 2800);
});

Deno.test("extracts OpenAI and Anthropic usage shapes cleanly", () => {
  const openaiUsage = extractTokenUsage("openai", {
    usage: {
      prompt_tokens: 1500,
      completion_tokens: 500,
      total_tokens: 2000,
    },
  });
  assertEquals(openaiUsage.provider, "openai");
  assertEquals(openaiUsage.inputUnits, 1500);
  assertEquals(openaiUsage.outputUnits, 500);

  const claudeUsage = extractTokenUsage("anthropic", {
    usage: {
      input_tokens: 1000,
      cache_read_input_tokens: 200,
      output_tokens: 400,
    },
  });
  assertEquals(claudeUsage.provider, "anthropic");
  assertEquals(claudeUsage.inputUnits, 1200);
  assertEquals(claudeUsage.outputUnits, 400);
  assertEquals(claudeUsage.totalUnits, 1600);
});

Deno.test("estimates deterministic cost and keeps unknown models null", () => {
  const flash = estimateModelCostUsd({
    model: "gemini-2.5-flash",
    inputUnits: 1_000_000,
    outputUnits: 1_000_000,
  });
  assertEquals(flash.known_pricing, true);
  assertEquals(flash.estimated_cost_usd, 2.8);

  const pro = estimateModelCostUsd({
    model: "gemini-2.5-pro",
    inputUnits: 1_000_000,
    outputUnits: 1_000_000,
  });
  assertEquals(pro.known_pricing, true);
  assertEquals(pro.estimated_cost_usd, 11.25);

  const mini = estimateModelCostUsd({
    model: "gpt-4o-mini",
    inputUnits: 1_000_000,
    outputUnits: 1_000_000,
  });
  assertEquals(mini.known_pricing, true);
  assertEquals(mini.estimated_cost_usd, 0.75);

  const gpt4o = estimateModelCostUsd({
    model: "gpt-4o",
    inputUnits: 1_000_000,
    outputUnits: 1_000_000,
  });
  assertEquals(gpt4o.known_pricing, true);
  assertEquals(gpt4o.estimated_cost_usd, 12.5);

  const haiku = estimateModelCostUsd({
    model: "claude-haiku-4-5-20251001",
    inputUnits: 1_000_000,
    outputUnits: 1_000_000,
  });
  assertEquals(haiku.known_pricing, true);
  assertEquals(haiku.estimated_cost_usd, 6.0);

  const sonnet = estimateModelCostUsd({
    model: "claude-sonnet-4-5",
    inputUnits: 1_000_000,
    outputUnits: 1_000_000,
  });
  assertEquals(sonnet.known_pricing, true);
  assertEquals(sonnet.estimated_cost_usd, 18.0);

  const deepseek = estimateModelCostUsd({
    model: "deepseek-v4-flash",
    inputUnits: 1_000_000,
    outputUnits: 1_000_000,
  });
  assertEquals(deepseek.known_pricing, true);
  assertEquals(deepseek.estimated_cost_usd, 0.42);

  const unknown = estimateModelCostUsd({
    model: "custom-experimental-model",
    inputUnits: 50_000,
    outputUnits: 10_000,
  });
  assertEquals(unknown.known_pricing, false);
  assertEquals(unknown.estimated_cost_usd, null);
  assertStringIncludes(unknown.pricing_disclaimer, "参考単価");
});

Deno.test("recordApiUsageLog writes hub_data and fails open", async () => {
  const inserted: Array<Record<string, unknown>> = [];
  const fakeClient: UsageLogInsertClient = {
    from() {
      return {
        insert(values: Record<string, unknown>) {
          inserted.push(values);
          return {
            select() {
              return {
                single() {
                  return Promise.resolve({
                    data: { id: "log-1" },
                    error: null,
                  });
                },
              };
            },
          };
        },
      };
    },
  };

  const ok = await recordApiUsageLog({
    client: fakeClient,
    userId: "user-123",
    provider: "openai",
    model: "gpt-4o-mini",
    actionName: "improve",
    usage: {
      provider: "openai",
      inputUnits: 10_000,
      outputUnits: 2_000,
      totalUnits: 12_000,
      usagePresent: true,
    },
    recordedAt: "2026-11-26T00:00:00Z",
  });
  assertEquals(ok.recorded, true);
  assertEquals(ok.id, "log-1");
  assertEquals(inserted.length, 1);
  assertEquals(inserted[0].source, API_USAGE_LOG_SOURCE);
  const meta = inserted[0].metadata as Record<string, unknown>;
  assertEquals(meta.user_id, "user-123");
  assertEquals(meta.known_pricing, true);

  const failingClient: UsageLogInsertClient = {
    from() {
      return {
        insert() {
          return {
            select() {
              return {
                single() {
                  return Promise.reject(new Error("db down"));
                },
              };
            },
          };
        },
      };
    },
  };
  const failOpen = await recordApiUsageLog({
    client: failingClient,
    userId: "user-123",
    provider: "gemini",
    model: "gemini-2.5-flash",
    actionName: "summarize",
    usage: {
      provider: "gemini",
      inputUnits: 500,
      outputUnits: 100,
      totalUnits: 600,
      usagePresent: true,
    },
  });
  assertEquals(failOpen.recorded, false);
  assertEquals(failOpen.reason, "db down");
});
