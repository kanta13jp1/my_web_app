export const COMPANY_A2A_PROTOCOL_VERSION = "1.0";
export const COMPANY_A2A_CONTENT_TYPE = "application/a2a+json";

type A2AMessageInput = {
  messageId: string;
  contextId: string;
  companyId: string;
  skillId: string;
  text: string;
  rawMessage: Record<string, unknown>;
};

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function boundedString(value: unknown, max: number): string {
  return asString(value).slice(0, max);
}

export function buildCompanyAgentCard(endpoint: string) {
  const baseUrl = endpoint.replace(/\/+$/, "");
  return {
    name: "AI Company Builder",
    description:
      "Durable manager and shared-tool agents for company operations, cited research, and launch execution.",
    supportedInterfaces: [{
      url: `${baseUrl}/a2a`,
      protocolBinding: "HTTP+JSON",
      protocolVersion: COMPANY_A2A_PROTOCOL_VERSION,
    }],
    provider: {
      organization: "my_web_app",
      url: "https://my-web-app-b67f4.web.app/ai-company-builder",
    },
    version: "1.0.0",
    documentationUrl: "https://github.com/kanta13jp1/my_web_app",
    capabilities: {
      streaming: false,
      pushNotifications: false,
      extendedAgentCard: false,
      extensions: [{
        uri: "https://standards.org/extensions/citations/v1",
        description: "Task artifacts include owner-scoped source citations.",
        required: false,
      }],
    },
    securitySchemes: {
      bearerAuth: {
        httpAuthSecurityScheme: {
          description: "Supabase user access token",
          scheme: "Bearer",
          bearerFormat: "JWT",
        },
      },
    },
    securityRequirements: [{ schemes: { bearerAuth: { list: [] } } }],
    defaultInputModes: ["text/plain", "application/json"],
    defaultOutputModes: ["text/plain", "application/json"],
    skills: [
      {
        id: "company-operations",
        name: "Company Operations",
        description:
          "Delegates an operating request through a dedicated manager and reusable tool agent.",
        tags: ["company", "operations", "delegation"],
        examples: ["Create the next paid-pilot outreach experiment."],
        inputModes: ["text/plain"],
        outputModes: ["text/plain", "application/json"],
      },
      {
        id: "cited-research",
        name: "Cited Research",
        description:
          "Uses the selected company's private research corpus and returns source-addressable evidence.",
        tags: ["research", "citations", "rag"],
        examples: ["Compare this offer with the cited competitor pages."],
        inputModes: ["text/plain"],
        outputModes: ["text/plain", "application/json"],
      },
      {
        id: "launch-execution",
        name: "Launch Execution",
        description:
          "Runs a durable launch task with retries, cost telemetry, and kill-switch controls.",
        tags: ["launch", "saas", "durable-task"],
        examples: [
          "Draft the week-one launch brief and measurable exit signal.",
        ],
        inputModes: ["text/plain"],
        outputModes: ["text/plain", "application/json"],
      },
    ],
  };
}

export function requestedA2AVersion(req: Request): string {
  const url = new URL(req.url);
  return asString(req.headers.get("A2A-Version")) ||
    asString(url.searchParams.get("A2A-Version")) || "0.3";
}

export function assertA2AVersion(req: Request): void {
  const version = requestedA2AVersion(req);
  if (version !== COMPANY_A2A_PROTOCOL_VERSION) {
    throw new Error(
      `VersionNotSupportedError: requested ${version}; supported ${COMPANY_A2A_PROTOCOL_VERSION}`,
    );
  }
}

export function parseA2ASendMessage(value: unknown): A2AMessageInput {
  const body = asRecord(value);
  const message = asRecord(body?.message);
  if (!body || !message) throw new Error("message is required");
  if (message.role !== "ROLE_USER") {
    throw new Error("message.role must be ROLE_USER");
  }

  const messageId = boundedString(message.messageId, 200);
  if (!messageId) throw new Error("message.messageId is required");
  const parts = Array.isArray(message.parts) ? message.parts.slice(0, 20) : [];
  const text = parts.map(asRecord).filter((
    part,
  ): part is Record<string, unknown> => part !== null)
    .map((part) => boundedString(part.text, 12_000)).filter(Boolean).join(
      "\n\n",
    )
    .slice(0, 12_000)
    .trim();
  if (!text) throw new Error("At least one text part is required");

  const requestMetadata = asRecord(body.metadata) ?? {};
  const messageMetadata = asRecord(message.metadata) ?? {};
  const companyId = boundedString(
    requestMetadata.companyId ?? requestMetadata.company_id ??
      messageMetadata.companyId ?? messageMetadata.company_id,
    100,
  );
  if (!companyId) throw new Error("metadata.companyId is required");
  const contextId = boundedString(message.contextId, 200) ||
    crypto.randomUUID();
  const skillId = boundedString(
    requestMetadata.skillId ?? requestMetadata.skill_id,
    100,
  ) || "company-operations";
  if (
    !["company-operations", "cited-research", "launch-execution"].includes(
      skillId,
    )
  ) {
    throw new Error("Unsupported A2A skill");
  }

  return {
    messageId,
    contextId,
    companyId,
    skillId,
    text,
    rawMessage: {
      messageId,
      contextId,
      role: "ROLE_USER",
      parts: [{ text }],
    },
  };
}

export function agentTaskStatusToA2A(value: unknown): string {
  switch (asString(value)) {
    case "queued":
      return "TASK_STATE_SUBMITTED";
    case "in_progress":
      return "TASK_STATE_WORKING";
    case "completed":
      return "TASK_STATE_COMPLETED";
    case "failed":
      return "TASK_STATE_FAILED";
    case "cancelled":
      return "TASK_STATE_CANCELED";
    case "blocked":
      return "TASK_STATE_INPUT_REQUIRED";
    default:
      return "TASK_STATE_UNSPECIFIED";
  }
}

export function companyTaskToA2A(
  task: Record<string, unknown>,
  includeArtifacts = true,
): Record<string, unknown> {
  const metadata = asRecord(task.metadata) ?? {};
  const result = asRecord(task.result) ?? {};
  const resultText = asString(result.text);
  const contextId = boundedString(metadata.a2a_context_id, 200);
  const taskId = asString(task.id);
  const mapped: Record<string, unknown> = {
    id: taskId,
    contextId,
    status: {
      state: agentTaskStatusToA2A(task.status),
      timestamp: asString(task.updated_at) || asString(task.created_at) ||
        new Date().toISOString(),
    },
    metadata: {
      companyId: asString(metadata.company_id),
      skillId: asString(metadata.a2a_skill_id) || "company-operations",
      source: "ai-company-builder",
    },
  };
  if (
    includeArtifacts && resultText && asString(task.status) === "completed"
  ) {
    mapped.artifacts = [{
      artifactId: `${taskId}-result`,
      name: asString(task.title) || "Company task result",
      parts: [{ text: resultText, mediaType: "text/plain" }],
      metadata: {
        citations: Array.isArray(result.citations) ? result.citations : [],
      },
      extensions: ["https://standards.org/extensions/citations/v1"],
    }];
  }
  const inputMessage = asRecord(metadata.a2a_message);
  if (inputMessage) mapped.history = [inputMessage];
  return mapped;
}

export function encodeA2APageToken(task: Record<string, unknown>): string {
  const payload = JSON.stringify({
    updatedAt: asString(task.updated_at),
    id: asString(task.id),
  });
  return btoa(payload).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/,
    "",
  );
}

export function decodeA2APageToken(
  value: unknown,
): { updatedAt: string; id: string } | null {
  const token = asString(value);
  if (!token || token.length > 1000) return null;
  try {
    const base64 = token.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    const parsed = asRecord(JSON.parse(atob(padded)));
    const updatedAt = asString(parsed?.updatedAt);
    const id = asString(parsed?.id);
    const parsedDate = new Date(updatedAt);
    if (
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
        .test(id) || Number.isNaN(parsedDate.getTime())
    ) {
      return null;
    }
    return { updatedAt: parsedDate.toISOString(), id };
  } catch {
    return null;
  }
}
