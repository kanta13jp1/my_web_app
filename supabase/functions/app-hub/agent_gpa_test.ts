import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  boundedLimit,
  buildImprovementSuggestions,
  buildRuleBasedGpaEvaluation,
  normalizeSourceType,
} from "./agent_gpa.ts";

Deno.test("normalizeSourceType accepts the three Phase 1 sources", () => {
  assertEquals(normalizeSourceType("executive_chat"), "executive_chat");
  assertEquals(normalizeSourceType("executive_meeting"), "executive_meeting");
  assertEquals(normalizeSourceType("secretary_action"), "secretary_action");
});

Deno.test("normalizeSourceType rejects unknown sources", () => {
  assertThrows(() => normalizeSourceType("workflow_run"));
});

Deno.test("boundedLimit clamps list limits", () => {
  assertEquals(boundedLimit(undefined), 50);
  assertEquals(boundedLimit(0), 1);
  assertEquals(boundedLimit(500), 200);
  assertEquals(boundedLimit("12"), 12);
});

Deno.test("buildRuleBasedGpaEvaluation avoids raw prompt storage", () => {
  const evaluation = buildRuleBasedGpaEvaluation("executive_chat", {
    goal: "Decide the weekly growth focus",
    plan: ["review KPI", "pick one channel"],
    tool_calls: [{ name: "issue.create" }],
    response: "The growth focus is calendar retention.",
    status: "completed",
    prompt: "SECRET prompt body that should not be persisted in rationale",
  });

  assertEquals(evaluation.gpa >= 3, true);
  assertEquals(evaluation.rationale_short.includes("SECRET"), false);
  assertEquals(evaluation.improvement_suggestions, []);
});

Deno.test("buildImprovementSuggestions maps weak axes to action types", () => {
  const suggestions = buildImprovementSuggestions({
    goal_score: 2.0,
    plan_score: 2.4,
    action_score: 1.9,
    consistency_score: 2.3,
  });

  assertEquals(suggestions.map((item) => item.type), [
    "scope_split",
    "prompt_edit",
    "approval_gate",
    "rerun",
  ]);
});
