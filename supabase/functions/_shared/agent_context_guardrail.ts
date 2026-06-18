export type AgentContextGuardrailCode =
  | "context_escape"
  | "fictional_contract"
  | "impossible_capability"
  | "unsafe_side_effect"
  | "missing_business_context"
  | "abnormal_volume"
  | "unapproved_authority_claim";

export type AgentContextGuardrailSource =
  | "input"
  | "output"
  | "metrics"
  | "context";

export type AgentContextGuardrailSeverity = "medium" | "high" | "critical";

export interface AgentContextGuardrailFinding {
  code: AgentContextGuardrailCode;
  severity: AgentContextGuardrailSeverity;
  source: AgentContextGuardrailSource;
  score: number;
  message: string;
}

export interface AgentContextGuardrailInput {
  operationName: string;
  inputText?: string | null;
  outputText?: string | null;
  expectedContextTags?: readonly string[] | null;
  requestedScopes?: readonly string[] | null;
  approvalState?: "approved" | "pending" | "rejected" | null;
  anomalyThreshold?: number | null;
  metrics?: {
    dailyOperationCount?: number | null;
    maxDailyOperationCount?: number | null;
    amountJpy?: number | null;
    maxAmountJpy?: number | null;
  } | null;
}

export interface AgentContextSafeState {
  resetRequired: boolean;
  action: "allow" | "warn" | "reset_to_safe_default";
  safeMode: "normal" | "limited_read_only";
  allowedScopes: string[];
  reason: string | null;
}

export interface AgentContextMonitoringEvent {
  dashboardChannel: "ai_tool_monitoring";
  eventType: "agent_context_guardrail.triggered";
  severity: AgentContextGuardrailSeverity;
  operationName: string;
  anomalyScore: number;
  threshold: number;
  findingCodes: AgentContextGuardrailCode[];
  suggestedAction: string;
  payload: Record<string, unknown>;
}

export interface AgentContextGuardrailDecision {
  allowed: boolean;
  anomalyScore: number;
  threshold: number;
  findings: AgentContextGuardrailFinding[];
  safeState: AgentContextSafeState;
  monitoringEvent: AgentContextMonitoringEvent | null;
  auditPayload: Record<string, unknown>;
}

const DEFAULT_ANOMALY_THRESHOLD = 5;
const SAFE_DEFAULT_SCOPES = ["read", "suggest"] as const;

const TEXT_RULES: readonly {
  code: AgentContextGuardrailCode;
  severity: AgentContextGuardrailSeverity;
  score: number;
  message: string;
  pattern: RegExp;
}[] = [
  {
    code: "context_escape",
    severity: "high",
    score: 3,
    message:
      "The text tries to override system, developer, or business context.",
    pattern:
      /\b(ignore|override|disregard|forget)\b.{0,80}\b(system|developer|business|policy|scope|context)\b/i,
  },
  {
    code: "fictional_contract",
    severity: "critical",
    score: 5,
    message:
      "The text asserts a binding contract, approval, or obligation without a record.",
    pattern:
      /\b(binding|signed|executed|enforceable|already approved)\b.{0,80}\b(contract|agreement|obligation|terms?)\b/i,
  },
  {
    code: "impossible_capability",
    severity: "critical",
    score: 5,
    message:
      "The text claims impossible verification or production action without required access.",
    pattern:
      /\b(deployed|verified|proved|rotated|transferred)\b.{0,100}\bwithout\b.{0,60}\b(credentials|access|records|network|approval)\b/i,
  },
  {
    code: "unsafe_side_effect",
    severity: "critical",
    score: 5,
    message: "The text attempts a high-risk side effect without approval.",
    pattern:
      /\b(delete|purchase|refund|transfer|send|publish|discount)\b.{0,100}\bwithout\b.{0,60}\b(approval|confirmation|authorization)\b/i,
  },
  {
    code: "unapproved_authority_claim",
    severity: "high",
    score: 3,
    message:
      "The text claims executive or legal approval that must be verified.",
    pattern:
      /\b(ceo|legal|admin|owner)\b.{0,40}\b(approved|authorized|signed off)\b/i,
  },
];

function addFinding(
  findings: AgentContextGuardrailFinding[],
  finding: AgentContextGuardrailFinding,
): void {
  if (
    findings.some((existing) =>
      existing.code === finding.code && existing.source === finding.source &&
      existing.message === finding.message
    )
  ) {
    return;
  }
  findings.push(finding);
}

function scanText(
  text: string | null | undefined,
  source: "input" | "output",
  findings: AgentContextGuardrailFinding[],
): void {
  if (!text?.trim()) return;
  for (const rule of TEXT_RULES) {
    if (rule.pattern.test(text)) {
      addFinding(findings, {
        code: rule.code,
        severity: rule.severity,
        source,
        score: rule.score,
        message: rule.message,
      });
    }
  }
}

function scanContextTags(
  input: AgentContextGuardrailInput,
  findings: AgentContextGuardrailFinding[],
): void {
  const tags = (input.expectedContextTags ?? [])
    .map((tag) => tag.trim().toLowerCase())
    .filter(Boolean);
  if (tags.length === 0) return;

  const corpus = `${input.operationName} ${input.inputText ?? ""} ${
    input.outputText ?? ""
  }`.toLowerCase();
  const matched = tags.some((tag) => corpus.includes(tag));
  if (!matched) {
    addFinding(findings, {
      code: "missing_business_context",
      severity: "medium",
      source: "context",
      score: 2,
      message:
        "The operation does not mention any expected business context tag.",
    });
  }
}

function scanMetrics(
  metrics: AgentContextGuardrailInput["metrics"],
  findings: AgentContextGuardrailFinding[],
): void {
  if (!metrics) return;
  if (
    typeof metrics.dailyOperationCount === "number" &&
    typeof metrics.maxDailyOperationCount === "number" &&
    metrics.dailyOperationCount > metrics.maxDailyOperationCount
  ) {
    addFinding(findings, {
      code: "abnormal_volume",
      severity: "high",
      source: "metrics",
      score: 3,
      message: "Daily operation count exceeded the configured maximum.",
    });
  }

  if (
    typeof metrics.amountJpy === "number" &&
    typeof metrics.maxAmountJpy === "number" &&
    metrics.amountJpy > metrics.maxAmountJpy
  ) {
    addFinding(findings, {
      code: "abnormal_volume",
      severity: "critical",
      source: "metrics",
      score: 5,
      message: "Operation amount exceeded the configured maximum.",
    });
  }
}

function highestSeverity(
  findings: readonly AgentContextGuardrailFinding[],
): AgentContextGuardrailSeverity {
  if (findings.some((finding) => finding.severity === "critical")) {
    return "critical";
  }
  if (findings.some((finding) => finding.severity === "high")) {
    return "high";
  }
  return "medium";
}

function buildSafeState(
  anomalyScore: number,
  threshold: number,
  findings: readonly AgentContextGuardrailFinding[],
): AgentContextSafeState {
  if (anomalyScore >= threshold) {
    return {
      resetRequired: true,
      action: "reset_to_safe_default",
      safeMode: "limited_read_only",
      allowedScopes: [...SAFE_DEFAULT_SCOPES],
      reason: findings.map((finding) => finding.code).join(","),
    };
  }
  if (findings.length > 0) {
    return {
      resetRequired: false,
      action: "warn",
      safeMode: "normal",
      allowedScopes: [],
      reason: findings.map((finding) => finding.code).join(","),
    };
  }
  return {
    resetRequired: false,
    action: "allow",
    safeMode: "normal",
    allowedScopes: [],
    reason: null,
  };
}

function buildMonitoringEvent(
  input: AgentContextGuardrailInput,
  anomalyScore: number,
  threshold: number,
  findings: readonly AgentContextGuardrailFinding[],
): AgentContextMonitoringEvent | null {
  if (anomalyScore < threshold) return null;
  return {
    dashboardChannel: "ai_tool_monitoring",
    eventType: "agent_context_guardrail.triggered",
    severity: highestSeverity(findings),
    operationName: input.operationName,
    anomalyScore,
    threshold,
    findingCodes: findings.map((finding) => finding.code),
    suggestedAction:
      "Reset the operation to read-only safe mode and require human review before retry.",
    payload: {
      operation_name: input.operationName,
      requested_scopes: input.requestedScopes ?? [],
      approval_state: input.approvalState ?? null,
      finding_sources: findings.map((finding) => finding.source),
    },
  };
}

export function evaluateAgentContextGuardrail(
  input: AgentContextGuardrailInput,
): AgentContextGuardrailDecision {
  const findings: AgentContextGuardrailFinding[] = [];
  scanText(input.inputText, "input", findings);
  scanText(input.outputText, "output", findings);
  scanContextTags(input, findings);
  scanMetrics(input.metrics, findings);

  if (
    input.approvalState !== "approved" &&
    findings.some((finding) => finding.code === "unapproved_authority_claim")
  ) {
    addFinding(findings, {
      code: "unapproved_authority_claim",
      severity: "high",
      source: "context",
      score: 3,
      message: "Approval claim is not backed by approved metadata.",
    });
  }

  const threshold = input.anomalyThreshold ?? DEFAULT_ANOMALY_THRESHOLD;
  const anomalyScore = findings.reduce(
    (sum, finding) => sum + finding.score,
    0,
  );
  const safeState = buildSafeState(anomalyScore, threshold, findings);
  const monitoringEvent = buildMonitoringEvent(
    input,
    anomalyScore,
    threshold,
    findings,
  );

  return {
    allowed: !safeState.resetRequired,
    anomalyScore,
    threshold,
    findings,
    safeState,
    monitoringEvent,
    auditPayload: {
      operation_name: input.operationName,
      anomaly_score: anomalyScore,
      threshold,
      reset_required: safeState.resetRequired,
      finding_codes: findings.map((finding) => finding.code),
      monitoring_channel: monitoringEvent?.dashboardChannel ?? null,
    },
  };
}
