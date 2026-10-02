import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildAiFeatureRoiDashboard,
  buildAiRouterCostDashboard,
  normalizeAiRouterPreference,
  normalizeAiRoutingTask,
  parseAiFeatureRoiParameterInput,
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

Deno.test("buildAiFeatureRoiDashboard keeps unconfigured estimates honest", () => {
  const dashboard = buildAiFeatureRoiDashboard([
    {
      usage_date: "2026-09-01",
      feature_key: "summary",
      request_count: 4,
      success_count: 3,
      api_cost_usd: 2,
    },
  ]);

  assertEquals(dashboard.currency, "USD");
  assertEquals(dashboard.overall.total_benefit_usd, 0);
  assertEquals(dashboard.overall.net_benefit_usd, -2);
  assertEquals(dashboard.overall.roi_pct, -100);
  assertEquals(dashboard.features[0].parameters.hourly_value_usd, 0);
});

Deno.test("buildAiFeatureRoiDashboard calculates configurable benefit tiers", () => {
  const dashboard = buildAiFeatureRoiDashboard(
    [
      {
        usage_date: "2026-09-01",
        feature_key: "summary",
        request_count: 2,
        success_count: 2,
        api_cost_usd: 10,
      },
      {
        usage_date: "2026-09-02",
        feature_key: "summary",
        request_count: 1,
        success_count: 1,
        api_cost_usd: 5,
      },
    ],
    [{
      feature_key: "Summary",
      minutes_saved_per_success: 30,
      hourly_value_usd: 60,
      direct_cost_saving_usd_per_success: 5,
      avoided_loss_usd_per_success: 2,
      value_created_usd_per_success: 3,
    }],
  );

  assertEquals(dashboard.overall.request_count, 3);
  assertEquals(dashboard.overall.direct_cost_reduction_usd, 105);
  assertEquals(dashboard.overall.avoided_loss_usd, 6);
  assertEquals(dashboard.overall.value_created_usd, 9);
  assertEquals(dashboard.overall.total_benefit_usd, 120);
  assertEquals(dashboard.overall.net_benefit_usd, 105);
  assertEquals(dashboard.overall.roi_pct, 700);
  assertEquals(dashboard.daily_trend.length, 2);
  assertEquals(dashboard.daily_trend[0].roi_pct, 700);
});

Deno.test("buildAiFeatureRoiDashboard leaves zero-cost ROI undefined", () => {
  const dashboard = buildAiFeatureRoiDashboard(
    [{
      usage_date: "2026-09-01",
      feature_key: "translation",
      request_count: 1,
      success_count: 1,
      api_cost_usd: 0,
    }],
    [{
      feature_key: "translation",
      minutes_saved_per_success: 10,
      hourly_value_usd: 30,
      direct_cost_saving_usd_per_success: 0,
      avoided_loss_usd_per_success: 0,
      value_created_usd_per_success: 0,
    }],
  );

  assertEquals(dashboard.overall.total_benefit_usd, 5);
  assertEquals(dashboard.overall.roi_pct, null);
});

Deno.test("parseAiFeatureRoiParameterInput rejects invalid estimates", () => {
  let error: unknown;
  try {
    parseAiFeatureRoiParameterInput({
      feature_key: "summary",
      minutes_saved_per_success: -1,
      hourly_value_usd: 10,
      direct_cost_saving_usd_per_success: 0,
      avoided_loss_usd_per_success: 0,
      value_created_usd_per_success: 0,
    });
  } catch (caught) {
    error = caught;
  }
  assertEquals(error instanceof TypeError, true);
});
