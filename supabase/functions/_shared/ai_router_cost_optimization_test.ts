import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildAiRouterCostDashboard,
  normalizeAiRouterPreference,
  normalizeAiRoutingTask,
} from "./ai_router_cost_optimization.ts";

Deno.test("normalizeAiRoutingTask groups common task aliases", () => {
  assertEquals(normalizeAiRoutingTask("summarize_report"), "summary");
  assertEquals(normalizeAiRoutingTask("translate-ja-en"), "translation");
  assertEquals(normalizeAiRoutingTask("coding-review"), "coding");
  assertEquals(normalizeAiRoutingTask("market analysis"), "analysis");
});

Deno.test("buildAiRouterCostDashboard recommends the best cost-performance model", () => {
  const dashboard = buildAiRouterCostDashboard(
    [
      {
        routing_use_case: "summary",
        provider: "openai",
        model: "gpt-4o-mini",
        success: true,
        estimated_cost_usd: 0.08,
        latency_ms: 900,
        input_chars: 1200,
        output_chars: 800,
        created_at: "2026-07-06T10:00:00Z",
      },
      {
        routing_use_case: "summary",
        provider: "openai",
        model: "gpt-4o-mini",
        success: true,
        estimated_cost_usd: 0.08,
        latency_ms: 1100,
        input_chars: 1000,
        output_chars: 1000,
        created_at: "2026-07-06T10:10:00Z",
      },
      {
        routing_use_case: "summary",
        provider: "anthropic",
        model: "claude",
        success: true,
        estimated_cost_usd: 0.8,
        latency_ms: 700,
        input_chars: 1200,
        output_chars: 800,
        created_at: "2026-07-06T10:20:00Z",
      },
      {
        routing_use_case: "summary",
        provider: "cheap-but-flaky",
        model: "tiny",
        success: false,
        estimated_cost_usd: 0.01,
        latency_ms: 100,
        input_chars: 1200,
        output_chars: 800,
        created_at: "2026-07-06T10:30:00Z",
      },
    ],
    [],
    [],
    new Date("2026-07-07T00:00:00Z"),
  );

  assertEquals(dashboard.tasks.length, 1);
  assertEquals(dashboard.tasks[0].task, "summary");
  assertEquals(dashboard.tasks[0].recommendation?.provider, "openai");
  assertEquals(dashboard.tasks[0].recommendation?.model, "gpt-4o-mini");
  assertEquals(dashboard.tasks[0].candidates.length, 3);
});

Deno.test("buildAiRouterCostDashboard attaches manual task preference", () => {
  const dashboard = buildAiRouterCostDashboard(
    [
      {
        action: "provider.chat_auto",
        routing_use_case: "coding",
        provider: "groq",
        success: true,
        estimated_cost_usd: 0.01,
        latency_ms: 250,
      },
    ],
    [],
    [
      {
        task: "code",
        provider: "groq",
        model: "llama-3",
        is_enabled: true,
        updated_at: "2026-07-07T00:00:00Z",
      },
    ],
  );

  assertEquals(dashboard.tasks[0].preference?.task, "coding");
  assertEquals(dashboard.tasks[0].preference?.provider, "groq");
  assertEquals(dashboard.tasks[0].preference?.model, "llama-3");
});

Deno.test("normalizeAiRouterPreference ignores disabled or blank rows", () => {
  assertEquals(
    normalizeAiRouterPreference({
      task: "summary",
      provider: "openai",
      is_enabled: false,
    }),
    null,
  );
  assertEquals(
    normalizeAiRouterPreference({ task: "summary", provider: "" }),
    null,
  );
});
