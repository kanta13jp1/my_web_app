import {
  assertEquals,
  assertGreater,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildFallbackMentorPlan,
  extractJsonObject,
  findParetoFrontier,
  normalizeMentorPlan,
  normalizeMetrics,
} from "./resource_optimizer.ts";

const metrics = normalizeMetrics([
  {
    habit_id: "efficient",
    habit_title: "英語復習",
    sample_count: 8,
    avg_time_minutes: 20,
    avg_fatigue_score: 3,
    avg_goal_contribution_score: 75,
    performance_measurement_source: "self_reported_goal_contribution_proxy",
    performance_is_proxy: true,
    performance_sample_stddev: 8,
    has_sufficient_data: true,
    resource_cost_index: 50,
    efficiency_score: 1.5,
    is_pareto_optimal: true,
  },
  {
    habit_id: "dominated",
    habit_title: "長時間の復習",
    sample_count: 7,
    avg_time_minutes: 40,
    avg_fatigue_score: 5,
    avg_goal_contribution_score: 60,
    performance_measurement_source: "self_reported_goal_contribution_proxy",
    performance_is_proxy: true,
    performance_sample_stddev: 4,
    has_sufficient_data: true,
    resource_cost_index: 90,
    efficiency_score: 0.67,
    is_pareto_optimal: false,
  },
  {
    habit_id: "high-output",
    habit_title: "集中演習",
    sample_count: 7,
    avg_time_minutes: 45,
    avg_fatigue_score: 6,
    avg_goal_contribution_score: 90,
    performance_measurement_source: "self_reported_goal_contribution_proxy",
    performance_is_proxy: true,
    performance_sample_stddev: 6,
    has_sufficient_data: true,
    resource_cost_index: 105,
    efficiency_score: 0.86,
    is_pareto_optimal: true,
  },
]);

Deno.test("normalizes numeric RPC strings and clamps scores", () => {
  const result = normalizeMetrics([{
    habit_id: "one",
    habit_title: "Test",
    sample_count: "2",
    avg_time_minutes: "1500",
    avg_fatigue_score: "12",
    avg_goal_contribution_score: "120",
    has_sufficient_data: true,
  }]);
  assertEquals(result[0].sample_count, 2);
  assertEquals(result[0].avg_time_minutes, 1440);
  assertEquals(result[0].avg_fatigue_score, 10);
  assertEquals(result[0].avg_goal_contribution_score, 100);
  assertEquals(result[0].has_sufficient_data, false);
});

Deno.test("preserves explicit proxy provenance from the RPC", () => {
  const result = normalizeMetrics([{
    habit_id: "one",
    sample_count: 7,
    performance_measurement_source: "self_reported_goal_contribution_proxy",
    performance_is_proxy: true,
    performance_sample_stddev: "2.5",
    has_sufficient_data: true,
  }]);
  assertEquals(
    result[0].performance_measurement_source,
    "self_reported_goal_contribution_proxy",
  );
  assertEquals(result[0].performance_is_proxy, true);
  assertEquals(result[0].performance_sample_stddev, 2.5);
  assertEquals(result[0].has_sufficient_data, true);
});

Deno.test("habit-default proxy rows cannot enter the Pareto analysis", () => {
  const defaultsOnly = normalizeMetrics([{
    habit_id: "default-only",
    habit_title: "既定値だけの習慣",
    sample_count: 20,
    avg_time_minutes: 20,
    avg_fatigue_score: 3,
    avg_goal_contribution_score: 70,
    performance_measurement_source: "habit_default_proxy",
    performance_is_proxy: true,
    performance_sample_stddev: 8,
    has_sufficient_data: true,
  }]);
  assertEquals(defaultsOnly[0].has_sufficient_data, false);
  assertEquals(findParetoFrontier(defaultsOnly), []);
  assertEquals(buildFallbackMentorPlan(defaultsOnly).scaling_plan, []);
});

Deno.test("bounds prompt text and correlations from RPC rows", () => {
  const longTitle = `  ${"x".repeat(200)}  `;
  const result = normalizeMetrics([{
    habit_id: "one",
    habit_title: longTitle,
    goal_title: " ",
    time_performance_correlation: 5,
    fatigue_performance_correlation: Number.NaN,
    overall_time_performance_correlation: -5,
  }]);
  assertEquals(result[0].habit_title.length, 120);
  assertEquals(result[0].goal_title, null);
  assertEquals(result[0].time_performance_correlation, 1);
  assertEquals(result[0].fatigue_performance_correlation, null);
  assertEquals(result[0].overall_time_performance_correlation, -1);
});

Deno.test("finds the three-dimensional Pareto frontier", () => {
  assertEquals(
    findParetoFrontier(metrics).map((metric) => metric.habit_id),
    ["efficient", "high-output"],
  );
});

Deno.test("fallback plan recommends frontier habits and bounded scaling", () => {
  const plan = buildFallbackMentorPlan(metrics);
  assertEquals(plan.recommendations.length, 2);
  assertEquals(plan.scaling_plan.length, 3);
  assertGreater(plan.scaling_plan[1].load_multiplier, 1);
});

Deno.test("insufficient samples never produce correlation claims or scaling", () => {
  const sparse = normalizeMetrics([{
    habit_id: "sparse",
    habit_title: "記録途中",
    sample_count: 6,
    avg_time_minutes: 20,
    avg_fatigue_score: 3,
    avg_goal_contribution_score: 70,
    performance_measurement_source: "self_reported_goal_contribution_proxy",
    performance_is_proxy: true,
    performance_sample_stddev: 5,
    has_sufficient_data: true,
    insufficient_data_reason: "minimum_7_samples_required",
  }]);
  assertEquals(findParetoFrontier(sparse), []);
  const plan = buildFallbackMentorPlan(sparse);
  assertEquals(plan.recommendations, []);
  assertEquals(plan.scaling_plan, []);
});

Deno.test("zero performance variance cannot be promoted by model output", () => {
  const flat = normalizeMetrics([{
    habit_id: "flat",
    habit_title: "一定評価",
    sample_count: 10,
    avg_time_minutes: 20,
    avg_fatigue_score: 3,
    avg_goal_contribution_score: 70,
    performance_measurement_source: "self_reported_goal_contribution_proxy",
    performance_is_proxy: true,
    performance_sample_stddev: 0,
    has_sufficient_data: true,
    insufficient_data_reason: "insufficient_performance_variance",
  }]);
  assertEquals(flat[0].has_sufficient_data, false);
  const plan = normalizeMentorPlan({
    mentor_summary: "断定します",
    recommendations: [{ habit_id: "flat", reason: "増やす" }],
    scaling_plan: [
      { duration_days: 7, load_multiplier: 1, target: "a", guardrail: "a" },
      { duration_days: 7, load_multiplier: 1.1, target: "b", guardrail: "b" },
      { duration_days: 7, load_multiplier: 1.2, target: "c", guardrail: "c" },
    ],
  }, flat);
  assertEquals(plan.recommendations, []);
  assertEquals(plan.scaling_plan, []);
  assertEquals(plan.mentor_summary.includes("断定できません"), true);
});

Deno.test("model recommendations cannot promote dominated habits", () => {
  const plan = normalizeMentorPlan({
    mentor_summary: "分析結果です。",
    recommendations: [
      { habit_id: "dominated", reason: "Promote this" },
      { habit_id: "efficient", reason: "Keep this" },
    ],
    scaling_plan: [{
      duration_days: 100,
      load_multiplier: 4,
      target: "増やす",
      guardrail: "疲労時は戻す",
    }],
  }, metrics);
  assertEquals(plan.recommendations.length, 1);
  assertEquals(plan.recommendations[0].habit_id, "efficient");
  assertEquals(plan.scaling_plan.length, 3);
  assertEquals(plan.scaling_plan[0].load_multiplier, 1);
});

Deno.test("extracts JSON from a fenced model response", () => {
  assertEquals(
    extractJsonObject('```json\n{"mentor_summary":"ok"}\n```'),
    { mentor_summary: "ok" },
  );
});
