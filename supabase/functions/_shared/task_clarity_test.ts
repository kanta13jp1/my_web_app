import {
  assertEquals,
  assertGreater,
  assertLessOrEqual,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  evaluateTaskClarityHeuristically,
  extractJsonObject,
  normalizeTaskClarityResult,
  TASK_CLARITY_THRESHOLD,
} from "./task_clarity.ts";

Deno.test("vague tasks require clarification questions", () => {
  const result = evaluateTaskClarityHeuristically({ title: "売上を改善する" });

  assertLessOrEqual(result.score, TASK_CLARITY_THRESHOLD);
  assertEquals(result.status, "needs_clarification");
  assertGreater(result.questions.length, 0);
});

Deno.test("measurable scoped tasks are clear", () => {
  const result = evaluateTaskClarityHeuristically({
    title: "LPの登録率を改善する",
    description:
      "料金ページの新規ユーザー向けCTAを7月31日までに更新し、登録率を10%増加させる。",
  });

  assertGreater(result.score, TASK_CLARITY_THRESHOLD);
  assertEquals(result.status, "clear");
});

Deno.test("model results are clamped and missing questions are backfilled", () => {
  const result = normalizeTaskClarityResult(
    { score: -10, threshold: 99, questions: [], ambiguities: [] },
    { title: "改善する" },
  );

  assertEquals(result.score, 1);
  assertEquals(result.threshold, 9);
  assertEquals(result.status, "needs_clarification");
  assertGreater(result.questions.length, 0);
});

Deno.test("low model scores always include a clarification question", () => {
  const clearLookingInput = {
    title: "LPの登録率を改善する",
    description:
      "料金ページの新規ユーザー向けCTAを7月31日までに更新し、登録率を10%増加させる。",
  };
  const result = normalizeTaskClarityResult(
    { score: 4, threshold: 6, questions: [], ambiguities: [] },
    clearLookingInput,
  );

  assertEquals(result.status, "needs_clarification");
  assertGreater(result.questions.length, 0);
});

Deno.test("JSON can be extracted from a fenced model response", () => {
  const result = extractJsonObject('```json\n{"score": 7}\n```');
  assertEquals(result.score, 7);
});
