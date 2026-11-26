/**
 * Multi-MCP "Why" Reasoning Context Log Validator (#2814)
 *
 * Validates `reasoning_context` payloads before persistence so every MCP tool
 * selection records availableTools, selectedTool, reasoningWhy, prompt context,
 * serverName, and a valid ISO timestamp.
 */

export type ValidationOutcome =
  | "valid"
  | "missing_field"
  | "invalid_selection"
  | "invalid_timestamp";

export const VALIDATION_OUTCOME_LABELS = {
  valid: "Valid",
  missing_field: "Missing Required Field",
  invalid_selection: "Selected Tool Not In Available Tools",
  invalid_timestamp: "Invalid Timestamp",
} as const satisfies Record<ValidationOutcome, string>;

export interface ReasoningContextLog {
  readonly availableTools: readonly string[];
  readonly selectedTool: string;
  readonly reasoningWhy: string;
  readonly promptHash?: string;
  readonly promptSummary?: string;
  readonly serverName: string;
  readonly timestamp: string;
}

export interface ReasoningValidationResult {
  readonly valid: boolean;
  readonly outcome: ValidationOutcome;
  readonly errors: readonly string[];
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

export function validateReasoningContext(
  payload: unknown,
): ReasoningValidationResult {
  if (
    typeof payload !== "object" ||
    payload === null ||
    Array.isArray(payload)
  ) {
    return {
      valid: false,
      outcome: "missing_field",
      errors: ["reasoning_context must be a JSON object."],
    };
  }

  const record = payload as Record<string, unknown>;
  const errors: string[] = [];

  if (
    !Array.isArray(record.availableTools) ||
    record.availableTools.length === 0 ||
    !record.availableTools.every((item) => isNonEmptyString(item))
  ) {
    errors.push("availableTools must be a non-empty array of strings.");
  }

  if (!isNonEmptyString(record.selectedTool)) {
    errors.push("selectedTool must be a non-empty string.");
  }
  if (!isNonEmptyString(record.reasoningWhy)) {
    errors.push("reasoningWhy must be a non-empty string.");
  }
  if (!isNonEmptyString(record.serverName)) {
    errors.push("serverName must be a non-empty string.");
  }
  if (
    !isNonEmptyString(record.promptHash) &&
    !isNonEmptyString(record.promptSummary)
  ) {
    errors.push("Either promptHash or promptSummary must be non-empty.");
  }
  if (!isNonEmptyString(record.timestamp)) {
    errors.push("timestamp must be a non-empty ISO-8601 string.");
  }

  if (errors.length > 0) {
    return { valid: false, outcome: "missing_field", errors };
  }

  const tools = (record.availableTools as string[]).map((t) => t.trim());
  const selected = (record.selectedTool as string).trim();
  if (!tools.includes(selected)) {
    return {
      valid: false,
      outcome: "invalid_selection",
      errors: [`selectedTool '${selected}' is not in availableTools.`],
    };
  }

  const parsedTime = Date.parse((record.timestamp as string).trim());
  if (Number.isNaN(parsedTime)) {
    return {
      valid: false,
      outcome: "invalid_timestamp",
      errors: ["timestamp must parse as a valid ISO-8601 date-time."],
    };
  }

  return { valid: true, outcome: "valid", errors: [] };
}
