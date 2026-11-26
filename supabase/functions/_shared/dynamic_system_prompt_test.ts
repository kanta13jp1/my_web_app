import {
  assertEquals,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildDynamicSystemPrompt,
  formatJstIsoTimestamp,
  OUTPUT_FORMAT_RULES,
  validateSystemPromptTemplate,
} from "./dynamic_system_prompt.ts";

Deno.test(
  "buildDynamicSystemPrompt keeps static prefix before dynamic tail",
  () => {
    const first = buildDynamicSystemPrompt({
      now: new Date("2026-11-26T12:00:00.000Z"),
      outputFormat: "markdown",
      staticInstructions: "Summarize {{surface}} metrics concisely.",
      templateVars: { surface: "executive" },
    });
    const second = buildDynamicSystemPrompt({
      now: new Date("2026-11-26T15:30:00.000Z"),
      outputFormat: "markdown",
      staticInstructions: "Summarize {{surface}} metrics concisely.",
      templateVars: { surface: "executive" },
    });

    assertEquals(first.staticPrefix, second.staticPrefix);
    assertEquals(first.prompt.startsWith(first.staticPrefix), true);
    assertEquals(
      first.prompt.indexOf("Summarize executive metrics concisely.") <
        first.prompt.indexOf("【動的コンテキスト】"),
      true,
    );
    assertStringIncludes(
      first.prompt,
      "現在時刻 (UTC, ISO 8601): 2026-11-26",
    );
    assertStringIncludes(
      first.prompt,
      "現在時刻 (JST, ISO 8601): 2026-11-26T21:00:00.000+09:00",
    );
    assertStringIncludes(first.prompt, OUTPUT_FORMAT_RULES.markdown);
  },
);

Deno.test(
  "buildDynamicSystemPrompt formats json_schema with schema name",
  () => {
    const built = buildDynamicSystemPrompt({
      now: new Date("2026-11-26T00:00:00.000Z"),
      outputFormat: "json_schema",
      jsonSchemaName: "ActionPlanV1",
    });

    assertStringIncludes(built.staticPrefix, OUTPUT_FORMAT_RULES.json_schema);
    assertStringIncludes(built.staticPrefix, "Schema: ActionPlanV1");
    assertEquals(built.jstIso, "2026-11-26T09:00:00.000+09:00");
  },
);

Deno.test(
  "validateSystemPromptTemplate catches missing and malformed tokens",
  () => {
    const ok = validateSystemPromptTemplate("Use {{role}} mode.", {
      role: "analyst",
    });
    assertEquals(ok.valid, true);
    assertEquals(ok.errors, []);

    const missing = validateSystemPromptTemplate("Use {{role}} on {{env}}.", {
      role: "analyst",
    });
    assertEquals(missing.valid, false);
    assertEquals(missing.unresolvedPlaceholders, ["env"]);

    const unclosed = validateSystemPromptTemplate("Broken {{role");
    assertEquals(unclosed.valid, false);

    const boundary = validateSystemPromptTemplate("Bad <<<USER_DATA>>>");
    assertEquals(boundary.valid, false);
  },
);

Deno.test(
  "formatJstIsoTimestamp and builder reject invalid Date",
  () => {
    assertThrows(
      () => formatJstIsoTimestamp(new Date("invalid")),
      TypeError,
      "now must be a valid Date",
    );
    assertThrows(
      () => buildDynamicSystemPrompt({ now: new Date("invalid") }),
      TypeError,
      "now must be a valid Date",
    );
  },
);
