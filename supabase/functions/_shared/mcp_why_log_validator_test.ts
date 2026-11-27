import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  VALIDATION_OUTCOME_LABELS,
  validateReasoningContext,
} from "./mcp_why_log_validator.ts";

Deno.test(
  "validateReasoningContext accepts valid MCP why log payload",
  () => {
    const res = validateReasoningContext({
      availableTools: ["supabase_query", "github_issue_view"],
      selectedTool: "supabase_query",
      reasoningWhy: "Need current table row count before proposing migration.",
      promptSummary: "Check active user rows in workspace.",
      serverName: "supabase-mcp",
      timestamp: "2026-11-26T10:00:00Z",
    });

    assertEquals(res.valid, true);
    assertEquals(res.outcome, "valid");
    assertEquals(res.errors.length, 0);
    assertEquals(VALIDATION_OUTCOME_LABELS.valid, "Valid");
  },
);

Deno.test(
  "validateReasoningContext rejects missing fields and invalid tool choice",
  () => {
    const missing = validateReasoningContext({
      availableTools: ["tool_a"],
      selectedTool: "tool_a",
      reasoningWhy: "Testing missing promptSummary and timestamp.",
      serverName: "mcp-a",
    });
    assertEquals(missing.valid, false);
    assertEquals(missing.outcome, "missing_field");

    const badTool = validateReasoningContext({
      availableTools: ["tool_a"],
      selectedTool: "tool_b",
      reasoningWhy: "Selected tool not listed.",
      promptHash: "sha256:abcd1234",
      serverName: "mcp-a",
      timestamp: "2026-11-26T10:00:00Z",
    });
    assertEquals(badTool.valid, false);
    assertEquals(badTool.outcome, "invalid_selection");
  },
);
