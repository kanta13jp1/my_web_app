export const COMPANY_RUNTIME_QUEUE = "company_agent_runtime";

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
): string {
  const companyMetadata = asRecord(company.metadata) ?? {};
  const taskMetadata = asRecord(task.metadata) ?? {};
  const managerMetadata = asRecord(manager?.metadata) ?? {};
  const toolMetadata = asRecord(tool?.metadata) ?? {};

  return [
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
  ].join("\n");
}

export function companyRuntimeRoutingTier(
  task: Record<string, unknown>,
): "free" | "budget" | "performance" {
  const metadata = asRecord(task.metadata) ?? {};
  const stage = asNonEmptyString(metadata.stage)?.toLowerCase();
  if (["legal", "gate"].includes(stage ?? "")) return "performance";
  if (stage === "finance") return "budget";
  return "free";
}
