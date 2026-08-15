export const COMPANY_RUNTIME_QUEUE = "company_agent_runtime";

export type CompanyRuntimeTier = "free" | "budget" | "performance" | "premium";

export type CompanyRuntimeRoutingDecision = {
  routingKey: string;
  baseTier: CompanyRuntimeTier;
  tier: CompanyRuntimeTier;
  reason: string;
  retryBoost: number;
};

const COMPANY_RUNTIME_TIERS: CompanyRuntimeTier[] = [
  "free",
  "budget",
  "performance",
  "premium",
];

export type CompanyRuntimeQueueMessage = {
  msgId: number;
  userId: string;
  companyId: string;
  readCount: number;
};

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function asNonEmptyString(value: unknown): string | null {
  const text = typeof value === "string" ? value.trim() : "";
  return text === "" ? null : text;
}

function asPositiveInteger(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) return null;
  return parsed;
}

export function parseCompanyRuntimeQueueMessages(
  value: unknown,
): CompanyRuntimeQueueMessage[] {
  if (!Array.isArray(value)) return [];

  return value.flatMap((raw) => {
    const row = asRecord(raw);
    const message = asRecord(row?.message);
    const msgId = asPositiveInteger(row?.msg_id ?? row?.message_id);
    const userId = asNonEmptyString(message?.user_id);
    const companyId = asNonEmptyString(message?.company_id);
    if (!msgId || !userId || !companyId) return [];

    return [{
      msgId,
      userId,
      companyId,
      readCount: asPositiveInteger(row?.read_ct) ?? 0,
    }];
  });
}

export function buildCompanyRuntimePrompt(
  company: Record<string, unknown>,
  task: Record<string, unknown>,
  manager: Record<string, unknown> | null,
  tool: Record<string, unknown> | null,
  citationContext = "",
): string {
  const companyMetadata = asRecord(company.metadata) ?? {};
  const taskMetadata = asRecord(task.metadata) ?? {};
  const managerMetadata = asRecord(manager?.metadata) ?? {};
  const toolMetadata = asRecord(tool?.metadata) ?? {};

  const prompt = [
    "You are executing one durable task in an AI company operating system.",
    "Return a concrete work product, not a discussion of how you would work.",
    "Stay within the assigned role and avoid irreversible external actions.",
    "If facts are missing, label assumptions explicitly.",
    "",
    `Company: ${asNonEmptyString(companyMetadata.company_name) ?? "Unknown"}`,
    `Company idea: ${asNonEmptyString(companyMetadata.idea) ?? "Unknown"}`,
    `Offer: ${asNonEmptyString(companyMetadata.offer) ?? "Unknown"}`,
    `Audience: ${asNonEmptyString(companyMetadata.audience) ?? "Unknown"}`,
    `Stage: ${asNonEmptyString(taskMetadata.stage) ?? "general"}`,
    `Manager: ${asNonEmptyString(manager?.display_name) ?? "Chief"} - ${
      asNonEmptyString(manager?.role_title) ?? "Business Manager"
    }`,
    `Manager focus: ${
      asNonEmptyString(managerMetadata.focus) ?? "Own the outcome"
    }`,
    `Tool agent: ${asNonEmptyString(tool?.display_name) ?? "Specialist"} - ${
      asNonEmptyString(tool?.role_title) ?? "Tool Agent"
    }`,
    `Tool focus: ${
      asNonEmptyString(toolMetadata.focus) ?? "Produce the deliverable"
    }`,
    "",
    `Task: ${asNonEmptyString(task.title) ?? "Untitled task"}`,
    `Task brief: ${asNonEmptyString(task.description) ?? "No description"}`,
    "",
    "Required output:",
    "1. Deliverable",
    "2. Evidence or assumptions",
    "3. Next action for the manager",
  ];
  if (citationContext.trim()) {
    prompt.push(
      "",
      "Company research sources:",
      citationContext.trim(),
      "",
      "Use only the sources above for factual claims. Cite concrete claims with bracket references such as [1]. If the sources are insufficient, say so explicitly.",
    );
  }
  return prompt.join("\n");
}

export function companyRuntimeRoutingTier(
  task: Record<string, unknown>,
): CompanyRuntimeTier {
  const metadata = asRecord(task.metadata) ?? {};
  const stage = asNonEmptyString(metadata.stage)?.toLowerCase();
  if (["legal", "gate"].includes(stage ?? "")) return "performance";
  if (stage === "finance") return "budget";
  return "free";
}

function tierIndex(value: unknown): number {
  return COMPANY_RUNTIME_TIERS.indexOf(value as CompanyRuntimeTier);
}

function boundedTier(index: number): CompanyRuntimeTier {
  return COMPANY_RUNTIME_TIERS[
    Math.max(0, Math.min(index, COMPANY_RUNTIME_TIERS.length - 1))
  ];
}

function companyRuntimeRoutingKey(task: Record<string, unknown>): string {
  const metadata = asRecord(task.metadata) ?? {};
  const stage = asNonEmptyString(metadata.stage)?.toLowerCase().replace(
    /[^a-z0-9_-]/g,
    "-",
  ) ||
    "general";
  return `company_builder.${stage}`.slice(0, 120);
}

export function selectCompanyRuntimeRouting(
  task: Record<string, unknown>,
  profile: Record<string, unknown> | null,
): CompanyRuntimeRoutingDecision {
  const baseTier = companyRuntimeRoutingTier(task);
  const metadata = asRecord(task.metadata) ?? {};
  const stage = asNonEmptyString(metadata.stage)?.toLowerCase() ?? "general";
  const profileTierIndex = tierIndex(profile?.current_tier);
  const baseIndex = tierIndex(baseTier);
  const highRiskFloor = ["legal", "gate"].includes(stage) ? baseIndex : 0;
  const selectedIndex = profileTierIndex >= 0 ? profileTierIndex : baseIndex;
  const attemptCount = Math.max(0, Number(task.attempt_count) || 0);
  const retryBoost = Math.max(0, Math.min(attemptCount - 1, 2));
  const finalIndex = Math.max(highRiskFloor, selectedIndex + retryBoost);
  return {
    routingKey: companyRuntimeRoutingKey(task),
    baseTier,
    tier: boundedTier(finalIndex),
    reason: [
      profileTierIndex >= 0
        ? "persisted_outcome_profile"
        : "task_stage_baseline",
      retryBoost > 0 ? `retry_escalation_${retryBoost}` : "no_retry_escalation",
      highRiskFloor > 0 ? "high_risk_floor" : "standard_floor",
    ].join(";"),
    retryBoost,
  };
}

export function nextCompanyRuntimeRoutingProfile(
  profile: Record<string, unknown> | null,
  decision: CompanyRuntimeRoutingDecision,
  success: boolean,
  usedTier: unknown,
): Record<string, unknown> {
  const previousSuccesses = Math.max(
    0,
    Number(profile?.consecutive_successes) || 0,
  );
  const previousFailures = Math.max(
    0,
    Number(profile?.consecutive_failures) || 0,
  );
  const previousEscalations = Math.max(
    0,
    Number(profile?.escalation_count) || 0,
  );
  const previousDowngrades = Math.max(0, Number(profile?.downgrade_count) || 0);
  const usedIndex = tierIndex(usedTier);
  const decisionIndex = tierIndex(decision.tier);
  let currentIndex = usedIndex >= 0 ? usedIndex : decisionIndex;
  let consecutiveSuccesses = success ? previousSuccesses + 1 : 0;
  const consecutiveFailures = success ? 0 : previousFailures + 1;
  let escalationCount = previousEscalations;
  let downgradeCount = previousDowngrades;
  let lastDecision: string;

  if (!success) {
    const escalatedIndex = Math.min(
      COMPANY_RUNTIME_TIERS.length - 1,
      currentIndex + 1,
    );
    if (escalatedIndex > currentIndex) escalationCount += 1;
    currentIndex = escalatedIndex;
    lastDecision = escalatedIndex > decisionIndex
      ? "escalated_after_failure"
      : "failure_at_max_tier";
  } else if (consecutiveSuccesses >= 5) {
    const metadataStage = decision.routingKey.split(".").pop() ?? "general";
    const minimumIndex = ["legal", "gate"].includes(metadataStage)
      ? tierIndex(decision.baseTier)
      : 0;
    const downgradedIndex = Math.max(minimumIndex, currentIndex - 1);
    if (downgradedIndex < currentIndex) {
      currentIndex = downgradedIndex;
      downgradeCount += 1;
      consecutiveSuccesses = 0;
      lastDecision = "downgraded_after_5_successes";
    } else {
      lastDecision = "success_floor_retained";
    }
  } else {
    lastDecision = `success_streak_${consecutiveSuccesses}`;
  }

  return {
    routing_key: decision.routingKey,
    base_tier: decision.baseTier,
    current_tier: boundedTier(currentIndex),
    consecutive_successes: consecutiveSuccesses,
    consecutive_failures: consecutiveFailures,
    escalation_count: escalationCount,
    downgrade_count: downgradeCount,
    last_decision: lastDecision,
  };
}
