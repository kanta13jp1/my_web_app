import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  DEFAULT_CLAUDE_HAIKU_MODEL,
  DEFAULT_CLAUDE_SONNET_MODEL,
  mapComplexityToEffort,
  mapEffortToComplexity,
  selectClaudeModelForEffort,
  selectDynamicLlmRoute,
} from "./effort_router.ts";
import { calculateApiCost } from "./task_budget.ts";

Deno.test("Claude routing keeps low and medium work Haiku-first", () => {
  assertEquals(selectClaudeModelForEffort("low"), {
    family: "haiku",
    model: DEFAULT_CLAUDE_HAIKU_MODEL,
    rationale: "low effort remains on the Haiku-first cost lane.",
  });
  assertEquals(selectClaudeModelForEffort("medium").family, "haiku");
});

Deno.test("Claude routing escalates only high and xhigh work to Sonnet", () => {
  assertEquals(selectClaudeModelForEffort("high"), {
    family: "sonnet",
    model: DEFAULT_CLAUDE_SONNET_MODEL,
    rationale: "high effort requires the higher-capability Claude lane.",
  });
  assertEquals(selectClaudeModelForEffort("xhigh").family, "sonnet");
});

Deno.test("Claude routing accepts deployment model IDs, not request metadata", () => {
  assertEquals(
    selectClaudeModelForEffort("low", {
      haikuModel: "  claude-haiku-deployment  ",
      sonnetModel: "claude-sonnet-deployment",
    }).model,
    "claude-haiku-deployment",
  );
  assertEquals(
    selectClaudeModelForEffort("high", {
      haikuModel: "claude-haiku-deployment",
      sonnetModel: "  claude-sonnet-deployment  ",
    }).model,
    "claude-sonnet-deployment",
  );
});

Deno.test("Claude model costs use the current official standard token rates", () => {
  assertEquals(
    calculateApiCost(DEFAULT_CLAUDE_HAIKU_MODEL, 1_000_000, 1_000_000),
    6,
  );
  assertEquals(
    calculateApiCost(DEFAULT_CLAUDE_SONNET_MODEL, 1_000_000, 1_000_000),
    12,
  );
});

Deno.test("dynamic router scales from trivial to critical and honors budget/circuit-breaker", () => {
  assertEquals(mapComplexityToEffort("critical"), "xhigh");
  assertEquals(mapEffortToComplexity("low"), "trivial");

  const routine = selectDynamicLlmRoute({ action: "ai.assistant.chat" });
  assertEquals(routine.tier, "trivial");
  assertEquals(routine.model, "claude-haiku-4-5");

  const critical = selectDynamicLlmRoute({
    action: "ai.notebooklm.distill",
  });
  assertEquals(critical.tier, "critical");
  assertEquals(critical.model, "claude-opus-4-7");

  const downgraded = selectDynamicLlmRoute({
    action: "ai.notebooklm.distill",
    remainingBudgetUsd: 2.0,
    unhealthyModels: ["claude-sonnet-4-6"],
  });
  assertEquals(downgraded.tier, "complex");
  assertEquals(downgraded.downgradedByBudget, true);
  assertEquals(downgraded.model, "gpt-5.4");
});
