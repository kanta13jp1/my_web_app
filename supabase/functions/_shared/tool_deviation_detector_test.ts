import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  detectToolDeviation,
  summarizeToolDeviations,
  type ToolDefinition,
} from "./tool_deviation_detector.ts";

const SAMPLE_DEFS: ToolDefinition[] = [
  {
    name: "ledger.record_expense",
    literalLabel: "Record Expense",
    allowedParams: ["amount", "category", "memo"],
    requiredParams: ["amount", "category"],
    allowSemanticLabelAbstraction: true,
    securityRestrictedParams: ["override_user_id"],
  },
];

Deno.test(
  "detectToolDeviation marks literal match as aligned and unblocked",
  () => {
    const res = detectToolDeviation(
      {
        id: "log-1",
        toolName: "ledger.record_expense",
        actionLabel: "Record Expense",
        params: { amount: 1200, category: "food" },
      },
      SAMPLE_DEFS,
    );

    assertEquals(res.classification, "aligned");
    assertEquals(res.blocked, false);
    assertEquals(res.requiresTriageReview, false);
  },
);

Deno.test(
  "detectToolDeviation classifies UX label adaptation as benign",
  () => {
    const res = detectToolDeviation(
      {
        id: "log-2",
        toolName: "ledger.record_expense",
        actionLabel: "Save Lunch Receipt",
        params: { amount: 950, category: "food", memo: "cafe" },
      },
      SAMPLE_DEFS,
    );

    assertEquals(res.classification, "benign_ux_abstraction");
    assertEquals(res.blocked, false);
    assertEquals(res.requiresTriageReview, true);
  },
);

Deno.test(
  "detectToolDeviation blocks security violations and summarizes triage",
  () => {
    const summary = summarizeToolDeviations(
      [
        {
          id: "log-ok",
          toolName: "ledger.record_expense",
          params: { amount: 500, category: "book" },
        },
        {
          id: "log-bug",
          toolName: "ledger.record_expense",
          params: { amount: 500 },
        },
        {
          id: "log-sec",
          toolName: "ledger.record_expense",
          params: {
            amount: 500,
            category: "book",
            bypass_rls: true,
          },
        },
      ],
      SAMPLE_DEFS,
    );

    assertEquals(summary.total, 3);
    assertEquals(summary.alignedCount, 1);
    assertEquals(summary.hallucinationCount, 1);
    assertEquals(summary.securityViolationCount, 1);
    assertEquals(summary.blockedCount, 2);
  },
);
