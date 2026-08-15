import { Client } from "npm:@modelcontextprotocol/sdk@1.29.0/client/index.js";
import {
  StreamableHTTPClientTransport,
} from "npm:@modelcontextprotocol/sdk@1.29.0/client/streamableHttp.js";
import type { McpFileConnectorConfig } from "./mcp_external_file.ts";

const MCP_REQUEST_TIMEOUT_MS = 20_000;

function endpointAllowsRequest(
  endpoint: URL,
  input: string | URL | Request,
): boolean {
  const requested = new URL(
    input instanceof Request ? input.url : input.toString(),
  );
  return requested.protocol === "https:" &&
    requested.origin === endpoint.origin;
}

function guardedFetch(endpoint: URL): typeof fetch {
  return async (input, init) => {
    if (!endpointAllowsRequest(endpoint, input)) {
      throw new Error("mcp_connector_request_blocked");
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), MCP_REQUEST_TIMEOUT_MS);
    const upstreamSignal = init?.signal;
    const abort = () => controller.abort();
    upstreamSignal?.addEventListener("abort", abort, { once: true });
    try {
      return await fetch(input, {
        ...init,
        redirect: "error",
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timer);
      upstreamSignal?.removeEventListener("abort", abort);
    }
  };
}

export async function callExternalMcpTool(
  connector: McpFileConnectorConfig,
  toolName: string,
  args: Record<string, unknown>,
): Promise<unknown> {
  const endpoint = new URL(connector.endpointUrl);
  const headers: Record<string, string> = {};
  if (connector.bearerToken) {
    headers.Authorization = `Bearer ${connector.bearerToken}`;
  }
  const transport = new StreamableHTTPClientTransport(endpoint, {
    requestInit: { headers },
    fetch: guardedFetch(endpoint),
  });
  const client = new Client({
    name: "my-web-app-file-search",
    version: "1.0.0",
  });
  try {
    await client.connect(transport);
    const catalog = await client.listTools();
    if (
      !catalog.tools.some((tool: { name: string }) => tool.name === toolName)
    ) {
      throw new Error(`mcp_tool_not_found:${toolName}`);
    }
    const result = await client.callTool({
      name: toolName,
      arguments: args,
    });
    if (result.isError) throw new Error("mcp_tool_reported_error");
    return result;
  } finally {
    try {
      await transport.terminateSession();
    } catch {
      // Stateless and legacy servers may not support explicit termination.
    }
    await client.close().catch(() => undefined);
  }
}
