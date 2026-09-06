import {
  assertEquals,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildAiSystemPrompt } from "./ai_character_preamble.ts";

Deno.test("dynamic AI system prompt includes deterministic UTC context", () => {
  const now = new Date("2026-09-03T09:30:45.123Z");
  const first = buildAiSystemPrompt({
    now,
    outputFormat: "markdown",
    applicationInstructions: "Answer for the admin console.",
  });
  const second = buildAiSystemPrompt({
    now,
    outputFormat: "markdown",
    applicationInstructions: "Answer for the admin console.",
  });

  assertEquals(first, second);
  assertStringIncludes(first, "現在日付 (UTC): 2026-09-03");
  assertStringIncludes(
    first,
    "現在時刻 (UTC, ISO 8601): 2026-09-03T09:30:45.123Z",
  );
  assertStringIncludes(first, "Answer for the admin console.");
  assertStringIncludes(first, "fenced code blocks");
  assertStringIncludes(first, "language tag");
  assertEquals(
    first.indexOf("Answer for the admin console.") <
      first.indexOf("【動的コンテキスト】"),
    true,
  );
});

Deno.test("dynamic AI system prompt selects strict JSON output", () => {
  const prompt = buildAiSystemPrompt({
    now: new Date("2026-01-02T03:04:05.000Z"),
    outputFormat: "json",
  });

  assertStringIncludes(
    prompt,
    "Return valid JSON only, without Markdown fences or commentary.",
  );
  assertEquals(prompt.includes("【アプリ固有指示】"), false);
});

Deno.test("dynamic AI system prompt rejects an invalid clock", () => {
  assertThrows(
    () => buildAiSystemPrompt({ now: new Date("invalid") }),
    TypeError,
    "now must be a valid Date",
  );
});
