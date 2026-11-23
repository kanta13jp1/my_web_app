// Streamable HTTP (MCP 2025-03-26 / 2025-06-18 / 2025-11-25) lifecycle helpers
// for Antigravity and standard remote MCP clients connecting to tools-hub.

export const MCP_SUPPORTED_PROTOCOL_VERSIONS = [
  "2025-11-25",
  "2025-06-18",
  "2025-03-26",
  "2024-11-05",
] as const;

export const MCP_DEFAULT_PROTOCOL_VERSION = "2025-03-26";

export const MCP_SERVER_INFO = {
  name: "jibun-inc-mcp",
  title: "自分株式会社 (Jibun Inc) MCP",
  version: "1.0.0",
} as const;

export const MCP_SERVER_INSTRUCTIONS = [
  "自分株式会社 (my_web_app) MCP Server.",
  "Authenticate tools/call requests with Authorization: Bearer jibun_sk_... (issued at /jibun-api) or a WorkOS AuthKit Bearer token.",
  "Available capabilities: account profile (account.me), notes CRUD (notes.list, notes.create, notes.update, notes.delete), WBS & user tasks (wbs.tasks.list, user_tasks.list), development achievements (achievements.list), custom Agent Workers (workers.list, workers.invoke), and public business references (public_businesses.reference_list).",
  "Write/delete/worker-invoke tools enforce explicit confirmation: pass confirm=true and the tool's confirmation_phrase.",
].join(" ");

export const MCP_CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, accept, mcp-protocol-version, mcp-session-id, last-event-id, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Expose-Headers":
    "mcp-protocol-version, mcp-session-id, www-authenticate",
  "Access-Control-Max-Age": "86400",
};

function asPlainRecord(value: unknown): Record<string, unknown> {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function mcpJsonResponse(
  payload: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...MCP_CORS_HEADERS,
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}

export function isMcpEndpointPath(reqUrl: string): boolean {
  try {
    const { pathname } = new URL(reqUrl);
    return pathname.endsWith("/mcp") || pathname.endsWith("/mcp/");
  } catch {
    return false;
  }
}

export function negotiateMcpProtocolVersion(requested?: unknown): string {
  if (typeof requested === "string") {
    const trimmed = requested.trim();
    if (
      (MCP_SUPPORTED_PROTOCOL_VERSIONS as readonly string[]).includes(trimmed)
    ) {
      return trimmed;
    }
  }
  return MCP_DEFAULT_PROTOCOL_VERSION;
}

export function isJsonRpcObject(
  value: unknown,
): value is Record<string, unknown> {
  return value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    (value as Record<string, unknown>).jsonrpc === "2.0" &&
    typeof (value as Record<string, unknown>).method === "string";
}

export function isJsonRpcNotification(body: Record<string, unknown>): boolean {
  if (!isJsonRpcObject(body)) return false;
  return !("id" in body) ||
    body.id === undefined ||
    String(body.method).startsWith("notifications/");
}

export function mcpJsonRpcResult(
  id: unknown,
  result: Record<string, unknown>,
): Record<string, unknown> {
  return {
    jsonrpc: "2.0",
    id: id === undefined ? null : id,
    result,
  };
}

export function mcpJsonRpcError(
  id: unknown,
  code: number,
  message: string,
  data?: unknown,
): Record<string, unknown> {
  const err: Record<string, unknown> = { code, message };
  if (data !== undefined) err.data = data;
  return {
    jsonrpc: "2.0",
    id: id === undefined ? null : id,
    error: err,
  };
}

export function buildMcpInitializeResult(
  params?: Record<string, unknown>,
): Record<string, unknown> {
  const protocolVersion = negotiateMcpProtocolVersion(params?.protocolVersion);
  // MCP-AUTH-27 #10: never declare sampling capability.
  return {
    protocolVersion,
    capabilities: {
      tools: {
        listChanged: false,
      },
    },
    serverInfo: MCP_SERVER_INFO,
    instructions: MCP_SERVER_INSTRUCTIONS,
  };
}

export function formatMcpToolText(
  summary: string,
  structuredContent: unknown,
  maxChars = 48_000,
): Array<{ type: "text"; text: string }> {
  let serialized = "";
  try {
    serialized = JSON.stringify(structuredContent, null, 2) ?? "";
  } catch {
    serialized = String(structuredContent ?? "");
  }
  const combined = serialized ? `${summary}\n\n${serialized}` : summary;
  if (combined.length <= maxChars) {
    return [{ type: "text", text: combined }];
  }
  const suffix = "\n...(truncated)";
  const sliceLen = Math.max(0, maxChars - suffix.length);
  return [{ type: "text", text: `${combined.slice(0, sliceLen)}${suffix}` }];
}

export function handleMcpLifecycleRequest(
  req: Request,
  body: unknown,
  options: {
    rawParseFailed: boolean;
    action: string;
    toolCatalog: Array<Record<string, unknown>>;
  },
): Response | null {
  const onMcpPath = isMcpEndpointPath(req.url);
  const acceptsSse = (req.headers.get("accept") ?? "")
    .toLowerCase()
    .includes("text/event-stream");
  const protocolHeader = negotiateMcpProtocolVersion(
    req.headers.get("mcp-protocol-version"),
  );

  if (req.method === "GET") {
    if (onMcpPath || (options.action === "" && acceptsSse)) {
      return mcpJsonResponse(
        {
          error: "method_not_allowed",
          message:
            "SSE stream is not offered; use POST for Streamable HTTP MCP requests.",
        },
        405,
        {
          Allow: "POST, OPTIONS",
          "MCP-Protocol-Version": protocolHeader,
        },
      );
    }
    return null;
  }

  if (req.method === "DELETE") {
    if (onMcpPath || options.action === "") {
      return mcpJsonResponse(
        {
          error: "method_not_allowed",
          message: "Stateless MCP server does not maintain sessions.",
        },
        405,
        {
          Allow: "POST, OPTIONS",
          "MCP-Protocol-Version": protocolHeader,
        },
      );
    }
    return null;
  }

  if (req.method === "POST" && options.rawParseFailed && onMcpPath) {
    return mcpJsonResponse(
      mcpJsonRpcError(null, -32700, "Parse error: invalid JSON"),
      400,
      { "MCP-Protocol-Version": protocolHeader },
    );
  }

  if (!isJsonRpcObject(body)) {
    if (onMcpPath && req.method === "POST" && options.action === "") {
      return mcpJsonResponse(
        mcpJsonRpcError(
          null,
          -32600,
          "Invalid Request: expected JSON-RPC 2.0 object",
        ),
        400,
        { "MCP-Protocol-Version": protocolHeader },
      );
    }
    return null;
  }

  if (isJsonRpcNotification(body)) {
    return new Response(null, {
      status: 202,
      headers: {
        ...MCP_CORS_HEADERS,
        "MCP-Protocol-Version": protocolHeader,
      },
    });
  }

  const id = "id" in body ? body.id : null;
  const method = String(body.method);

  if (method === "initialize") {
    const params = asPlainRecord(body.params);
    const result = buildMcpInitializeResult(params);
    return mcpJsonResponse(
      mcpJsonRpcResult(id, result),
      200,
      { "MCP-Protocol-Version": String(result.protocolVersion) },
    );
  }

  if (method === "ping") {
    return mcpJsonResponse(
      mcpJsonRpcResult(id, {}),
      200,
      { "MCP-Protocol-Version": protocolHeader },
    );
  }

  if (method === "tools/list") {
    return mcpJsonResponse(
      mcpJsonRpcResult(id, { tools: options.toolCatalog }),
      200,
      { "MCP-Protocol-Version": protocolHeader },
    );
  }

  if (method === "tools/call") {
    return null;
  }

  return mcpJsonResponse(
    mcpJsonRpcError(id, -32601, `Method not found: ${method}`),
    200,
    { "MCP-Protocol-Version": protocolHeader },
  );
}
