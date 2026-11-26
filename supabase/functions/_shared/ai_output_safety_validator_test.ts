import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  SAFETY_CATEGORY_LABELS,
  validateAiOutput,
} from "./ai_output_safety_validator.ts";

Deno.test(
  "validateAiOutput allows clean summarized output without violations",
  () => {
    const result = validateAiOutput(
      "Budget totals show steady progress this month.",
      [
        {
          sourceId: "src-1",
          text:
            "Monthly household ledger confirms positive cashflow after " +
            "scheduled debt repayments.",
        },
      ],
    );

    assertEquals(result.allowed, true);
    assertEquals(result.blockedCategories, []);
    assertEquals(result.quoteViolations, []);
    assertEquals(result.issueAlertPayload, null);
    assertEquals(
      SAFETY_CATEGORY_LABELS.self_harm,
      "Self-Harm or Suicide Instruction",
    );
  },
);

Deno.test(
  "validateAiOutput flags verbatim overlap exceeding 15 words",
  () => {
    const longQuote =
      "one two three four five six seven eight nine ten eleven twelve " +
      "thirteen fourteen fifteen sixteen seventeen";
    const result = validateAiOutput(
      `Summary: ${longQuote}`,
      [{ sourceId: "article-42", text: longQuote }],
    );

    assertEquals(result.allowed, false);
    assertEquals(result.quoteViolations.length, 1);
    assertEquals(result.quoteViolations[0].sourceId, "article-42");
    assertEquals(result.quoteViolations[0].wordCount, 17);
    assertNotEquals(result.issueAlertPayload, null);
    assertEquals(result.issueAlertPayload?.dryRun, true);
  },
);

Deno.test(
  "validateAiOutput blocks prohibited safety categories deterministically",
  () => {
    const result = validateAiOutput(
      "Never provide how to commit suicide or pipe bomb instructions.",
    );

    assertEquals(result.allowed, false);
    assertEquals(result.blockedCategories, ["self_harm", "violence"]);
    assertNotEquals(result.issueAlertPayload, null);
  },
);
