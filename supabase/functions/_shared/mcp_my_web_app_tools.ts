export const MCP_MY_WEB_APP_TOOL_NAMES = [
  "wbs.tasks.list",
  "feature_request.create",
  "user_tasks.list",
  "public_businesses.reference_list",
  "notes.list",
  "notes.create",
  "account.me",
  "notes.update",
  "notes.delete",
  "achievements.list",
  "workers.list",
  "workers.invoke",
] as const;

export type McpMyWebAppToolName = typeof MCP_MY_WEB_APP_TOOL_NAMES[number];

export type McpToolDefinition = {
  name: McpMyWebAppToolName;
  title: string;
  description: string;
  requested_scopes: string[];
  write_confirmation_required: boolean;
  read_only_hint: boolean;
  destructive_hint: boolean;
  idempotent_hint: boolean;
  open_world_hint: boolean;
  jibun_api_scope: string | null;
  invoke_action: string;
  input_schema: Record<string, unknown>;
};

const MCP_ACTION_TO_TOOL: Record<string, McpMyWebAppToolName> = {
  "mcp.wbs.list": "wbs.tasks.list",
  "mcp.feature_request.create": "feature_request.create",
  "mcp.user_tasks.list": "user_tasks.list",
  "mcp.public_businesses.reference_list": "public_businesses.reference_list",
  "mcp.notes.list": "notes.list",
  "mcp.notes.create": "notes.create",
  "mcp.account.me": "account.me",
  "mcp.notes.update": "notes.update",
  "mcp.notes.delete": "notes.delete",
  "mcp.achievements.list": "achievements.list",
  "mcp.workers.list": "workers.list",
  "mcp.workers.invoke": "workers.invoke",
};

function recordValue(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

export function mcpActionToToolName(
  action: string,
  body: Record<string, unknown> = {},
): McpMyWebAppToolName | null {
  if (action === "mcp.tool.call") {
    const params = recordValue(body.params) ?? {};
    const requested = String(
      body.tool_name ?? body.toolName ?? body.name ?? body.tool ??
        params.name ?? "",
    );
    return isMcpMyWebAppToolName(requested) ? requested : null;
  }
  return MCP_ACTION_TO_TOOL[action] ?? null;
}

export function isMcpMyWebAppToolName(
  value: string,
): value is McpMyWebAppToolName {
  return (MCP_MY_WEB_APP_TOOL_NAMES as readonly string[]).includes(value);
}

export function isMcpWriteTool(toolName: McpMyWebAppToolName): boolean {
  return toolName === "feature_request.create" ||
    toolName === "notes.create" ||
    toolName === "notes.update" ||
    toolName === "notes.delete" ||
    toolName === "workers.invoke";
}

export function mcpRequestedScopes(toolName: McpMyWebAppToolName): string[] {
  if (toolName === "notes.create") return ["create"];
  return isMcpWriteTool(toolName) ? ["create"] : ["read"];
}

export function mcpConfirmationPhrase(
  toolName: McpMyWebAppToolName,
): string | null {
  if (toolName === "feature_request.create") return "create_feature_request";
  if (toolName === "notes.create") return "create_note";
  if (toolName === "notes.update") return "update_note";
  if (toolName === "notes.delete") return "delete_note";
  if (toolName === "workers.invoke") return "invoke_worker";
  return null;
}

export function hasMcpWriteConfirmation(
  toolName: McpMyWebAppToolName,
  body: Record<string, unknown>,
): boolean {
  const phrase = mcpConfirmationPhrase(toolName);
  if (!phrase) return true;
  return body.confirm === true &&
    String(body.confirmation_phrase ?? "").trim() === phrase;
}

export function buildMcpToolCatalog(): McpToolDefinition[] {
  return [
    {
      name: "wbs.tasks.list",
      title: "List WBS Tasks",
      description:
        "Read active WBS tasks by instance, status, and deadline order.",
      requested_scopes: ["read"],
      write_confirmation_required: false,
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: false,
      jibun_api_scope: "tasks.read",
      invoke_action: "mcp.wbs.list",
      input_schema: {
        type: "object",
        properties: {
          instance: {
            type: "string",
            description: "codex, ps6, vscode, user, gha, schedule, or all.",
            default: "codex",
          },
          status: {
            type: "string",
            description: "pending, in_progress, blocked, or completed.",
          },
          include_completed: { type: "boolean", default: false },
          limit: { type: "integer", minimum: 1, maximum: 50, default: 10 },
        },
      },
    },
    {
      name: "feature_request.create",
      title: "Create Feature Request",
      description:
        "Create a WBS-backed additional request after explicit confirmation.",
      requested_scopes: ["create"],
      write_confirmation_required: true,
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: false,
      open_world_hint: false,
      jibun_api_scope: null,
      invoke_action: "mcp.feature_request.create",
      input_schema: {
        type: "object",
        required: ["title", "confirm", "confirmation_phrase"],
        properties: {
          title: { type: "string", minLength: 3 },
          description: { type: "string" },
          instance: { type: "string", default: "codex" },
          priority: {
            type: "string",
            enum: ["low", "medium", "high"],
            default: "medium",
          },
          end_date: { type: "string", format: "date" },
          confirm: { type: "boolean", const: true },
          confirmation_phrase: {
            type: "string",
            const: "create_feature_request",
          },
        },
      },
    },
    {
      name: "user_tasks.list",
      title: "List User Tasks",
      description:
        "Read user-owned WBS tasks with the latest user task report when available.",
      requested_scopes: ["read"],
      write_confirmation_required: false,
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: false,
      jibun_api_scope: "tasks.read",
      invoke_action: "mcp.user_tasks.list",
      input_schema: {
        type: "object",
        properties: {
          include_completed: { type: "boolean", default: false },
          limit: { type: "integer", minimum: 1, maximum: 50, default: 10 },
        },
      },
    },
    {
      name: "public_businesses.reference_list",
      title: "List Public Business References",
      description:
        "Read OpenStreetMap reference places near Fuchu Honmachi 1-chome together with the separate official census aggregate. Ownership type is never inferred.",
      requested_scopes: ["read"],
      write_confirmation_required: false,
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: true,
      jibun_api_scope: "*",
      invoke_action: "mcp.public_businesses.reference_list",
      input_schema: {
        type: "object",
        properties: {
          target_id: {
            type: "string",
            enum: ["fuchu-honmachi-1"],
            default: "fuchu-honmachi-1",
          },
          limit: { type: "integer", minimum: 1, maximum: 50, default: 30 },
        },
      },
    },
    {
      name: "notes.list",
      title: "List Notes",
      description:
        "Read the user's notes with optional full-text search. Returns id, title, content, created_at, updated_at.",
      requested_scopes: ["read"],
      write_confirmation_required: false,
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: false,
      jibun_api_scope: "notes.read",
      invoke_action: "mcp.notes.list",
      input_schema: {
        type: "object",
        properties: {
          q: {
            type: "string",
            description: "Full-text search query (title and content).",
          },
          limit: { type: "integer", minimum: 1, maximum: 50, default: 20 },
        },
      },
    },
    {
      name: "notes.create",
      title: "Create Note",
      description:
        "Create a new note. Requires explicit confirmation to prevent accidental writes.",
      requested_scopes: ["create"],
      write_confirmation_required: true,
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: false,
      open_world_hint: false,
      jibun_api_scope: "notes.write",
      invoke_action: "mcp.notes.create",
      input_schema: {
        type: "object",
        required: ["title", "confirm", "confirmation_phrase"],
        properties: {
          title: { type: "string", minLength: 1, maxLength: 200 },
          content: { type: "string", maxLength: 100000, default: "" },
          confirm: { type: "boolean", const: true },
          confirmation_phrase: { type: "string", const: "create_note" },
        },
      },
    },
    {
      name: "account.me",
      title: "Get Account & Key Info",
      description:
        "Inspect the authenticated user ID, MCP client/API key metadata, and granted scopes.",
      requested_scopes: ["read"],
      write_confirmation_required: false,
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: false,
      jibun_api_scope: "*",
      invoke_action: "mcp.account.me",
      input_schema: {
        type: "object",
        properties: {},
      },
    },
    {
      name: "notes.update",
      title: "Update Note",
      description:
        "Update an existing user-owned note by ID (title and/or content). Requires explicit confirmation.",
      requested_scopes: ["create"],
      write_confirmation_required: true,
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: false,
      jibun_api_scope: "notes.write",
      invoke_action: "mcp.notes.update",
      input_schema: {
        type: "object",
        required: ["id", "confirm", "confirmation_phrase"],
        properties: {
          id: { type: "integer", minimum: 1 },
          title: { type: "string", minLength: 1, maxLength: 200 },
          content: { type: "string", maxLength: 100000 },
          confirm: { type: "boolean", const: true },
          confirmation_phrase: { type: "string", const: "update_note" },
        },
      },
    },
    {
      name: "notes.delete",
      title: "Delete Note",
      description:
        "Delete an existing user-owned note by ID. Destructive action requiring explicit confirmation.",
      requested_scopes: ["create"],
      write_confirmation_required: true,
      read_only_hint: false,
      destructive_hint: true,
      idempotent_hint: true,
      open_world_hint: false,
      jibun_api_scope: "notes.write",
      invoke_action: "mcp.notes.delete",
      input_schema: {
        type: "object",
        required: ["id", "confirm", "confirmation_phrase"],
        properties: {
          id: { type: "integer", minimum: 1 },
          confirm: { type: "boolean", const: true },
          confirmation_phrase: { type: "string", const: "delete_note" },
        },
      },
    },
    {
      name: "achievements.list",
      title: "List Development Achievements",
      description:
        "Read recent development achievements recorded on the site.",
      requested_scopes: ["read"],
      write_confirmation_required: false,
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: false,
      jibun_api_scope: "achievements.read",
      invoke_action: "mcp.achievements.list",
      input_schema: {
        type: "object",
        properties: {
          limit: { type: "integer", minimum: 1, maximum: 100, default: 20 },
        },
      },
    },
    {
      name: "workers.list",
      title: "List Agent Workers",
      description:
        "List user-registered external Agent Workers without exposing signing secrets.",
      requested_scopes: ["read"],
      write_confirmation_required: false,
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: false,
      jibun_api_scope: "workers.invoke",
      invoke_action: "mcp.workers.list",
      input_schema: {
        type: "object",
        properties: {},
      },
    },
    {
      name: "workers.invoke",
      title: "Invoke Agent Worker",
      description:
        "Invoke a registered user Agent Worker by slug with SSRF guard, HMAC signature, and security output scan. Requires explicit confirmation.",
      requested_scopes: ["create"],
      write_confirmation_required: true,
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: false,
      open_world_hint: true,
      jibun_api_scope: "workers.invoke",
      invoke_action: "mcp.workers.invoke",
      input_schema: {
        type: "object",
        required: ["slug", "confirm", "confirmation_phrase"],
        properties: {
          slug: {
            type: "string",
            pattern: "^[a-z0-9][a-z0-9-]{1,63}$",
          },
          payload: {
            type: "object",
            additionalProperties: true,
            default: {},
          },
          confirm: { type: "boolean", const: true },
          confirmation_phrase: { type: "string", const: "invoke_worker" },
        },
      },
    },
  ];
}

export function jibunApiScopesToMcpPermissions(
  apiScopes: readonly string[],
): { scopes: string[]; aud: string[] } {
  const scopes: string[] = [];
  const aud: string[] = [];
  for (const tool of buildMcpToolCatalog()) {
    if (
      tool.jibun_api_scope === "*" ||
      (tool.jibun_api_scope !== null && apiScopes.includes(tool.jibun_api_scope))
    ) {
      scopes.push(tool.name);
      aud.push(`urn:jibun:tool:${tool.name}`);
    }
  }
  return { scopes, aud };
}

export type McpPayloadResult<T = Record<string, unknown>> =
  | { ok: true; payload: T }
  | { ok: false; status: number; error: string };

export type McpFeatureRequestPayloadResult = McpPayloadResult;
export type McpNotePayloadResult = McpPayloadResult<
  { title: string; content: string }
>;
export type McpNoteUpdatePayloadResult = McpPayloadResult<
  { id: number; title?: string; content?: string }
>;
export type McpNoteDeletePayloadResult = McpPayloadResult<{ id: number }>;
export type McpWorkerInvokePayloadResult = McpPayloadResult<
  { slug: string; payload: Record<string, unknown> }
>;

export function buildMcpFeatureRequestPayload(
  body: Record<string, unknown>,
): McpFeatureRequestPayloadResult {
  const rawTitle = String(body.title ?? "").trim();
  if (rawTitle.length < 3) {
    return { ok: false, status: 400, error: "title must be at least 3 chars" };
  }

  const title = rawTitle.startsWith("[追加要望]")
    ? rawTitle
    : `[追加要望] ${rawTitle}`;
  const description = String(body.description ?? "").trim();
  const sourceNote =
    "Created via MCP facade; requires product review before broad rollout.";
  const today = new Date().toISOString().slice(0, 10);

  return {
    ok: true,
    payload: {
      category: String(body.category ?? "ユーザー要望"),
      category_icon: String(body.category_icon ?? "🧩"),
      category_order: Number(body.category_order ?? 0),
      title,
      description: description ? `${description}

${sourceNote}` : sourceNote,
      instance: String(body.instance ?? "codex"),
      owner_instance: String(body.owner_instance ?? body.instance ?? "codex"),
      status: "pending",
      progress: 0,
      priority: String(body.priority ?? "medium"),
      start_date: body.start_date ?? today,
      end_date: body.end_date ?? today,
      planned_start_date: body.planned_start_date ?? body.start_date ?? today,
      planned_end_date: body.planned_end_date ?? body.end_date ?? today,
      remaining_work: String(
        body.remaining_work ??
          "Review request, scope acceptance criteria, then schedule implementation.",
      ),
      milestone_code: body.milestone_code ?? null,
    },
  };
}

export function buildMcpNotePayload(
  body: Record<string, unknown>,
): McpNotePayloadResult {
  const title = String(body.title ?? "").trim();
  if (title.length === 0 || title.length > 200) {
    return { ok: false, status: 400, error: "title is required (1-200 chars)" };
  }
  const content = String(body.content ?? "");
  if (content.length > 100_000) {
    return { ok: false, status: 400, error: "content exceeds 100000 chars" };
  }
  return { ok: true, payload: { title, content } };
}

export function buildMcpNoteUpdatePayload(
  body: Record<string, unknown>,
): McpNoteUpdatePayloadResult {
  const id = Math.floor(Number(body.id ?? 0));
  if (!Number.isFinite(id) || id <= 0) {
    return {
      ok: false,
      status: 400,
      error: "id is required (positive integer)",
    };
  }
  const patch: { id: number; title?: string; content?: string } = { id };
  if (body.title !== undefined) {
    const title = String(body.title).trim();
    if (title.length === 0 || title.length > 200) {
      return {
        ok: false,
        status: 400,
        error: "title must be 1-200 chars when provided",
      };
    }
    patch.title = title;
  }
  if (body.content !== undefined) {
    const content = String(body.content);
    if (content.length > 100_000) {
      return { ok: false, status: 400, error: "content exceeds 100000 chars" };
    }
    patch.content = content;
  }
  if (patch.title === undefined && patch.content === undefined) {
    return {
      ok: false,
      status: 400,
      error: "title or content must be provided",
    };
  }
  return { ok: true, payload: patch };
}

export function buildMcpNoteDeletePayload(
  body: Record<string, unknown>,
): McpNoteDeletePayloadResult {
  const id = Math.floor(Number(body.id ?? 0));
  if (!Number.isFinite(id) || id <= 0) {
    return {
      ok: false,
      status: 400,
      error: "id is required (positive integer)",
    };
  }
  return { ok: true, payload: { id } };
}

export function buildMcpWorkerInvokePayload(
  body: Record<string, unknown>,
): McpWorkerInvokePayloadResult {
  const rawSlug = String(body.slug ?? body.worker ?? "")
    .trim()
    .toLowerCase();
  if (!/^[a-z0-9][a-z0-9-]{1,63}$/.test(rawSlug)) {
    return {
      ok: false,
      status: 400,
      error: "slug must be 2-64 lowercase alphanumeric/hyphen chars",
    };
  }
  const payload = body.payload === undefined ? {} : recordValue(body.payload);
  if (!payload) {
    return {
      ok: false,
      status: 400,
      error: "payload must be an object when provided",
    };
  }
  return { ok: true, payload: { slug: rawSlug, payload } };
}
