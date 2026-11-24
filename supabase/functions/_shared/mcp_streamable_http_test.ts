import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildMcpInitializeResult,
  formatMcpToolText,
  handleMcpLifecycleRequest,
  isMcpEndpointPath,
  negotiateMcpProtocolVersion,
} from "./mcp_streamable_http.ts";

const SAMPLE_CATALOG = [
  {
    name: "notes.list",
    title: "List Notes",
    description: "Read user notes.",
    inputSchema: { type: "object", properties: {} },
  },
];

Deno.test("negotiateMcpProtocolVersion accepts supported versions and falls back", () => {
  assertEquals(negotiateMcpProtocolVersion("2025-11-25"), "2025-11-25");
  assertEquals(negotiateMcpProtocolVersion("2025-06-18"), "2025-06-18");
  assertEquals(negotiateMcpProtocolVersion("2025-03-26"), "2025-03-26");
  assertEquals(negotiateMcpProtocolVersion("2024-11-05"), "2024-11-05");
  assertEquals(negotiateMcpProtocolVersion("2099-01-01"), "2025-03-26");
  assertEquals(negotiateMcpProtocolVersion(undefined), "2025-03-26");
});

Deno.test("buildMcpInitializeResult exposes tools capability and omits sampling", () => {
  const res = buildMcpInitializeResult({ protocolVersion: "2025-06-18" });
  assertEquals(res.protocolVersion, "2025-06-18");
  const capabilities = res.capabilities as Record<string, unknown>;
  assertEquals("tools" in capabilities, true);
  assertEquals("sampling" in capabilities, false);
  assertEquals(typeof res.instructions, "string");
  assertEquals((res.instructions as string).length > 0, true);
});

Deno.test("isMcpEndpointPath detects /mcp suffix only", () => {
  assertEquals(
    isMcpEndpointPath("https://example.supabase.co/functions/v1/tools-hub/mcp"),
    true,
  );
  assertEquals(
    isMcpEndpointPath(
      "https://example.supabase.co/functions/v1/tools-hub/mcp/",
    ),
    true,
  );
  assertEquals(
    isMcpEndpointPath("https://example.supabase.co/functions/v1/tools-hub"),
    false,
  );
});

Deno.test("handleMcpLifecycleRequest handles initialize, notifications, ping, and tools/list", async () => {
  const url = "https://example.supabase.co/functions/v1/tools-hub/mcp";

  const initBody = {
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: { protocolVersion: "2025-11-25" },
  };
  const initRes = handleMcpLifecycleRequest(
    new Request(url, { method: "POST" }),
    initBody,
    { rawParseFailed: false, action: "", toolCatalog: SAMPLE_CATALOG },
  );
  assertEquals(initRes?.status, 200);
  assertEquals(initRes?.headers.get("MCP-Protocol-Version"), "2025-11-25");
  const initJson = await initRes!.json();
  assertEquals(initJson.id, 1);
  assertEquals(initJson.result.protocolVersion, "2025-11-25");
  assertEquals("sampling" in initJson.result.capabilities, false);

  const notifRes = handleMcpLifecycleRequest(
    new Request(url, { method: "POST" }),
    { jsonrpc: "2.0", method: "notifications/initialized" },
    { rawParseFailed: false, action: "", toolCatalog: SAMPLE_CATALOG },
  );
  assertEquals(notifRes?.status, 202);
  assertEquals(await notifRes!.text(), "");

  const pingRes = handleMcpLifecycleRequest(
    new Request(url, { method: "POST" }),
    { jsonrpc: "2.0", id: 2, method: "ping" },
    { rawParseFailed: false, action: "", toolCatalog: SAMPLE_CATALOG },
  );
  assertEquals(pingRes?.status, 200);
  assertEquals((await pingRes!.json()).result, {});

  const listRes = handleMcpLifecycleRequest(
    new Request(url, { method: "POST" }),
    { jsonrpc: "2.0", id: 3, method: "tools/list", params: {} },
    { rawParseFailed: false, action: "mcp.tools.list", toolCatalog: SAMPLE_CATALOG },
  );
  assertEquals(listRes?.status, 200);
  const listJson = await listRes!.json();
  assertEquals(listJson.result.tools.length, 1);
  assertEquals(listJson.result.tools[0].name, "notes.list");
});

Deno.test("handleMcpLifecycleRequest passes tools/call through and rejects unsupported methods/HTTP verbs", async () => {
  const mcpUrl = "https://example.supabase.co/functions/v1/tools-hub/mcp";
  const baseUrl = "https://example.supabase.co/functions/v1/tools-hub";

  const callPassThrough = handleMcpLifecycleRequest(
    new Request(mcpUrl, { method: "POST" }),
    { jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "notes.list" } },
    { rawParseFailed: false, action: "mcp.tool.call", toolCatalog: SAMPLE_CATALOG },
  );
  assertEquals(callPassThrough, null);

  const unknownMethodRes = handleMcpLifecycleRequest(
    new Request(mcpUrl, { method: "POST" }),
    { jsonrpc: "2.0", id: 5, method: "sampling/createMessage" },
    { rawParseFailed: false, action: "", toolCatalog: SAMPLE_CATALOG },
  );
  assertEquals(unknownMethodRes?.status, 200);
  const unknownJson = await unknownMethodRes!.json();
  assertEquals(unknownJson.error.code, -32601);

  const getMcpRes = handleMcpLifecycleRequest(
    new Request(mcpUrl, { method: "GET" }),
    {},
    { rawParseFailed: false, action: "", toolCatalog: SAMPLE_CATALOG },
  );
  assertEquals(getMcpRes?.status, 405);
  assertEquals(getMcpRes?.headers.get("Allow"), "POST, OPTIONS");

  const deleteMcpRes = handleMcpLifecycleRequest(
    new Request(mcpUrl, { method: "DELETE" }),
    {},
    { rawParseFailed: false, action: "", toolCatalog: SAMPLE_CATALOG },
  );
  assertEquals(deleteMcpRes?.status, 405);

  const badJsonRes = handleMcpLifecycleRequest(
    new Request(mcpUrl, { method: "POST" }),
    {},
    { rawParseFailed: true, action: "", toolCatalog: SAMPLE_CATALOG },
  );
  assertEquals(badJsonRes?.status, 400);
  assertEquals((await badJsonRes!.json()).error.code, -32700);

  const invalidObjRes = handleMcpLifecycleRequest(
    new Request(mcpUrl, { method: "POST" }),
    { hello: "world" },
    { rawParseFailed: false, action: "", toolCatalog: SAMPLE_CATALOG },
  );
  assertEquals(invalidObjRes?.status, 400);
  assertEquals((await invalidObjRes!.json()).error.code, -32600);

  const nonMcpRestPassThrough = handleMcpLifecycleRequest(
    new Request(baseUrl, { method: "POST" }),
    { action: "generate_password" },
    { rawParseFailed: false, action: "generate_password", toolCatalog: SAMPLE_CATALOG },
  );
  assertEquals(nonMcpRestPassThrough, null);
});

Deno.test("formatMcpToolText embeds structured JSON and truncates cleanly", () => {
  const normal = formatMcpToolText("Found 1 note.", { notes: [{ id: 1 }] });
  assertEquals(normal[0].type, "text");
  assertEquals(normal[0].text.includes("Found 1 note."), true);
  assertEquals(normal[0].text.includes('"id": 1'), true);

  const large = formatMcpToolText("Summary", { big: "x".repeat(500) }, 80);
  assertEquals(large[0].text.length <= 80, true);
  assertEquals(large[0].text.endsWith("...(truncated)"), true);
});
