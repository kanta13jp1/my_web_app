export type DeviationClassification =
  | "aligned"
  | "benign_ux_abstraction"
  | "hallucination_or_bug"
  | "security_boundary_violation";

export const DEVIATION_CLASSIFICATION_LABELS = {
  aligned: "定義準拠",
  benign_ux_abstraction: "良性UX抽象化（要トリアージ確認）",
  hallucination_or_bug: "ハルシネーション・仕様バグ",
  security_boundary_violation: "セキュリティ境界侵害（即時ブロック）",
} as const satisfies Record<DeviationClassification, string>;

export interface ToolDefinition {
  name: string;
  literalLabel: string;
  allowedParams: readonly string[];
  requiredParams: readonly string[];
  allowSemanticLabelAbstraction?: boolean;
  securityRestrictedParams?: readonly string[];
}

export interface ToolActionLogEntry {
  id: string;
  toolName: string;
  actionLabel?: string;
  params: Record<string, unknown>;
  reasoningNote?: string;
}

export interface ToolDeviationResult {
  entryId: string;
  toolName: string;
  classification: DeviationClassification;
  blocked: boolean;
  requiresTriageReview: boolean;
  reasons: string[];
}

export interface ToolDeviationSummary {
  total: number;
  alignedCount: number;
  benignUxCount: number;
  hallucinationCount: number;
  securityViolationCount: number;
  blockedCount: number;
  results: ToolDeviationResult[];
}

const DANGEROUS_KEY_OR_VALUE_RE = new RegExp(
  [
    "(",
    "bypass_rls|admin_override|drop_table|",
    "raw_sql|exec_shell|disable_auth|exfiltrate",
    ")",
  ].join(""),
  "i",
);

function hasDangerousSignal(entry: ToolActionLogEntry): string | null {
  if (DANGEROUS_KEY_OR_VALUE_RE.test(entry.toolName)) {
    return `dangerous_tool_name:${entry.toolName}`;
  }
  if (
    entry.reasoningNote &&
    DANGEROUS_KEY_OR_VALUE_RE.test(entry.reasoningNote)
  ) {
    return "dangerous_reasoning_signal";
  }
  for (const [key, val] of Object.entries(entry.params)) {
    if (DANGEROUS_KEY_OR_VALUE_RE.test(key)) {
      return `dangerous_param_key:${key}`;
    }
    if (typeof val === "string" && DANGEROUS_KEY_OR_VALUE_RE.test(val)) {
      return `dangerous_param_value:${key}`;
    }
  }
  return null;
}

export function detectToolDeviation(
  entry: ToolActionLogEntry,
  definitions: readonly ToolDefinition[],
): ToolDeviationResult {
  const dangerous = hasDangerousSignal(entry);
  if (dangerous) {
    return {
      entryId: entry.id,
      toolName: entry.toolName,
      classification: "security_boundary_violation",
      blocked: true,
      requiresTriageReview: true,
      reasons: [dangerous],
    };
  }

  const def = definitions.find((item) => item.name === entry.toolName);
  if (!def) {
    return {
      entryId: entry.id,
      toolName: entry.toolName,
      classification: "hallucination_or_bug",
      blocked: true,
      requiresTriageReview: true,
      reasons: [`unknown_tool:${entry.toolName}`],
    };
  }

  const restricted = new Set(def.securityRestrictedParams ?? []);
  for (const key of Object.keys(entry.params)) {
    if (restricted.has(key)) {
      return {
        entryId: entry.id,
        toolName: entry.toolName,
        classification: "security_boundary_violation",
        blocked: true,
        requiresTriageReview: true,
        reasons: [`restricted_param:${key}`],
      };
    }
  }

  const bugReasons: string[] = [];
  for (const reqKey of def.requiredParams) {
    const val = entry.params[reqKey];
    if (val === undefined || val === null || val === "") {
      bugReasons.push(`missing_required_param:${reqKey}`);
    }
  }

  const allowed = new Set(def.allowedParams);
  for (const key of Object.keys(entry.params)) {
    if (!allowed.has(key)) {
      bugReasons.push(`unexpected_param:${key}`);
    }
  }

  if (bugReasons.length > 0) {
    return {
      entryId: entry.id,
      toolName: entry.toolName,
      classification: "hallucination_or_bug",
      blocked: true,
      requiresTriageReview: true,
      reasons: bugReasons,
    };
  }

  const label = entry.actionLabel?.trim();
  const labelShifted = Boolean(label && label !== def.literalLabel);
  if (labelShifted) {
    if (def.allowSemanticLabelAbstraction === false) {
      return {
        entryId: entry.id,
        toolName: entry.toolName,
        classification: "hallucination_or_bug",
        blocked: true,
        requiresTriageReview: true,
        reasons: ["disallowed_label_abstraction"],
      };
    }
    return {
      entryId: entry.id,
      toolName: entry.toolName,
      classification: "benign_ux_abstraction",
      blocked: false,
      requiresTriageReview: true,
      reasons: [`ux_label_adapted:${label}`],
    };
  }

  return {
    entryId: entry.id,
    toolName: entry.toolName,
    classification: "aligned",
    blocked: false,
    requiresTriageReview: false,
    reasons: [],
  };
}

export function summarizeToolDeviations(
  entries: readonly ToolActionLogEntry[],
  definitions: readonly ToolDefinition[],
): ToolDeviationSummary {
  const results = entries.map((entry) =>
    detectToolDeviation(entry, definitions)
  );
  let alignedCount = 0;
  let benignUxCount = 0;
  let hallucinationCount = 0;
  let securityViolationCount = 0;
  let blockedCount = 0;

  for (const res of results) {
    if (res.blocked) blockedCount += 1;
    switch (res.classification) {
      case "aligned":
        alignedCount += 1;
        break;
      case "benign_ux_abstraction":
        benignUxCount += 1;
        break;
      case "hallucination_or_bug":
        hallucinationCount += 1;
        break;
      case "security_boundary_violation":
        securityViolationCount += 1;
        break;
    }
  }

  return {
    total: results.length,
    alignedCount,
    benignUxCount,
    hallucinationCount,
    securityViolationCount,
    blockedCount,
    results,
  };
}
