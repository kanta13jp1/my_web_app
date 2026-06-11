export type SaasApprovalDecision =
  | "approved"
  | "rejected"
  | "revision_requested";

export const SAAS_APPROVAL_REQUEST_SOURCE = "saas_approval_request";
export const SAAS_APPROVAL_SETTINGS_SOURCE = "saas_approval_settings";

export const SAAS_CONNECTOR_IDS = [
  "slack",
  "discord",
  "notion",
  "asana",
  "gmail",
] as const;

export type SaasConnectorId = typeof SAAS_CONNECTOR_IDS[number];

const EXTERNAL_WRITE_SCOPES = new Set([
  "send",
  "update",
  "delete",
  "purchase",
  "discount",
  "external_share",
]);

export function normalizeSaasApprovalDecision(
  value: unknown,
): SaasApprovalDecision | null {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (
    normalized === "approved" ||
    normalized === "rejected" ||
    normalized === "revision_requested"
  ) {
    return normalized;
  }
  if (normalized === "revise" || normalized === "needs_revision") {
    return "revision_requested";
  }
  return null;
}

export function normalizeSaasConnectorSettings(
  value: unknown,
): Record<SaasConnectorId, boolean> {
  const input = value !== null && typeof value === "object" &&
      !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
  return {
    slack: input.slack !== false,
    discord: input.discord === true,
    notion: input.notion === true,
    asana: input.asana === true,
    gmail: input.gmail === true,
  };
}

export function isSaasConnectorId(value: unknown): value is SaasConnectorId {
  return (SAAS_CONNECTOR_IDS as readonly string[]).includes(
    String(value ?? "").trim().toLowerCase(),
  );
}

export function isExternalWriteScope(value: unknown): boolean {
  return EXTERNAL_WRITE_SCOPES.has(String(value ?? "").trim().toLowerCase());
}

export function externalSaasGateReason(input: {
  connectorEnabled?: boolean | null;
  humanApprovalRequired?: boolean | null;
  actorType?: string | null;
  requestedScopes?: readonly unknown[] | null;
}): "connector_disabled" | "approval_required" | null {
  if (input.connectorEnabled === false) return "connector_disabled";
  const actorType = String(input.actorType ?? "").trim().toLowerCase();
  const scopes = input.requestedScopes ?? [];
  if (
    input.humanApprovalRequired === true ||
    actorType === "ai" ||
    actorType === "agent" ||
    scopes.some(isExternalWriteScope)
  ) {
    return "approval_required";
  }
  return null;
}

export function buildSaasApprovalStatus(
  decision: SaasApprovalDecision,
): string {
  if (decision === "approved") return "approved";
  if (decision === "rejected") return "rejected";
  return "revision_requested";
}
