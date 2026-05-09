export const AGENT_TOOL_SCOPES = [
  "read",
  "suggest",
  "create",
  "update",
  "delete",
  "send",
  "purchase",
  "discount",
  "external_share",
] as const;

export type AgentToolScope = typeof AGENT_TOOL_SCOPES[number];

export type ApprovalDecision = "approved" | "pending" | "rejected";

export interface AgentToolApproval {
  decision: ApprovalDecision;
  approvedBy?: string | null;
  approvedAt?: string | null;
}

export interface AgentToolPolicyInput {
  actorRole?: string | null;
  toolName: string;
  requestedScopes: readonly string[];
  allowedScopes?: readonly string[] | null;
  approval?: AgentToolApproval | null;
}

export interface AgentToolPolicyDecision {
  allowed: boolean;
  requiresApproval: boolean;
  missingScopes: string[];
  highRiskScopes: AgentToolScope[];
  blockedReason: string | null;
  auditPayload: Record<string, unknown>;
}

export const HIGH_RISK_AGENT_TOOL_SCOPES: readonly AgentToolScope[] = [
  "delete",
  "send",
  "purchase",
  "discount",
  "external_share",
];

const HIGH_RISK_SCOPE_SET = new Set<string>(HIGH_RISK_AGENT_TOOL_SCOPES);

export const DEFAULT_AGENT_ROLE_SCOPES: Readonly<
  Record<string, readonly AgentToolScope[]>
> = {
  ceo: AGENT_TOOL_SCOPES,
  cfo: ["read", "suggest", "create", "update"],
  cmo: ["read", "suggest", "create", "external_share"],
  cho: ["read", "suggest", "create"],
  chro: ["read", "suggest", "create", "update"],
  legal: ["read", "suggest", "create", "update"],
};

export function normalizeAgentToolScopes(
  scopes: readonly string[] | null | undefined,
): AgentToolScope[] {
  const normalized = new Set<AgentToolScope>();
  for (const scope of scopes ?? []) {
    const candidate = scope.trim().toLowerCase();
    if (isAgentToolScope(candidate)) {
      normalized.add(candidate);
    }
  }
  return [...normalized];
}

export function getDefaultAgentRoleScopes(
  actorRole: string | null | undefined,
): readonly AgentToolScope[] {
  const role = actorRole?.trim().toLowerCase() ?? "";
  return DEFAULT_AGENT_ROLE_SCOPES[role] ?? ["read", "suggest"];
}

export function requiresCeoApproval(scopes: readonly string[]): boolean {
  return scopes.some((scope) =>
    HIGH_RISK_SCOPE_SET.has(scope.trim().toLowerCase())
  );
}

export function evaluateAgentToolPolicy(
  input: AgentToolPolicyInput,
): AgentToolPolicyDecision {
  const requestedScopes = normalizeAgentToolScopes(input.requestedScopes);
  const allowedScopes = input.allowedScopes?.includes("all")
    ? [...AGENT_TOOL_SCOPES]
    : normalizeAgentToolScopes(
      input.allowedScopes ?? getDefaultAgentRoleScopes(input.actorRole),
    );

  const missingScopes = requestedScopes.filter((scope) =>
    !allowedScopes.includes(scope)
  );
  const highRiskScopes = requestedScopes.filter((scope) =>
    HIGH_RISK_SCOPE_SET.has(scope)
  );
  const requiresApproval = highRiskScopes.length > 0;
  const hasApproval = input.approval?.decision === "approved" &&
    Boolean(input.approval.approvedBy?.trim()) &&
    Boolean(input.approval.approvedAt?.trim());

  let blockedReason: string | null = null;
  if (requestedScopes.length === 0) {
    blockedReason = "empty_requested_scope";
  } else if (missingScopes.length > 0) {
    blockedReason = "missing_scope";
  } else if (requiresApproval && !hasApproval) {
    blockedReason = "approval_required";
  }

  return {
    allowed: blockedReason === null,
    requiresApproval,
    missingScopes,
    highRiskScopes,
    blockedReason,
    auditPayload: {
      actor_role: input.actorRole ?? null,
      tool_name: input.toolName,
      requested_scopes: requestedScopes,
      allowed_scopes: allowedScopes,
      high_risk_scopes: highRiskScopes,
      approval_decision: input.approval?.decision ?? null,
      approved_by: input.approval?.approvedBy ?? null,
      blocked_reason: blockedReason,
    },
  };
}

function isAgentToolScope(scope: string): scope is AgentToolScope {
  return (AGENT_TOOL_SCOPES as readonly string[]).includes(scope);
}
