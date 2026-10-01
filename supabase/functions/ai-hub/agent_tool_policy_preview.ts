import {
  evaluateAgentToolPolicy,
  parseAgentToolRequestedScopes,
} from "../_shared/agent_tool_policy.ts";

// No database, provider, audit logger or execution capability is accepted here.
// This is a simulation using role defaults, never an execution authorization.
export function previewAgentToolPolicy(body: Record<string, unknown>) {
  const role = typeof body.actor_role === "string" ? body.actor_role : null;
  const decision = evaluateAgentToolPolicy({
    actorRole: role,
    toolName: "preview.only",
    requestedScopes: parseAgentToolRequestedScopes(body.requested_scopes),
  });
  return {
    simulation_only: true,
    audit_logged: false,
    allowed: decision.allowed,
    requires_approval: decision.requiresApproval,
    missing_scopes: decision.missingScopes,
    high_risk_scopes: decision.highRiskScopes,
    blocked_reason: decision.blockedReason,
  };
}
