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
    resource_cost_index: 50,
    efficiency_score: 1.5,
    is_pareto_optimal: true,
  },
  {
    habit_id: "dominated",
    habit_title: "長時間の復習",
    sample_count: 5,
    avg_time_minutes: 40,
    avg_fatigue_score: 5,
    avg_goal_contribution_score: 60,
    resource_cost_index: 90,
    efficiency_score: 0.67,
    is_pareto_optimal: false,
  },
  {
    habit_id: "high-output",
    habit_title: "集中演習",
    sample_count: 6,
    avg_time_minutes: 45,
    avg_fatigue_score: 6,
    avg_goal_contribution_score: 90,
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
  }]);
  assertEquals(result[0].sample_count, 2);
  assertEquals(result[0].avg_time_minutes, 1440);
  assertEquals(result[0].avg_fatigue_score, 10);
  assertEquals(result[0].avg_goal_contribution_score, 100);
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
