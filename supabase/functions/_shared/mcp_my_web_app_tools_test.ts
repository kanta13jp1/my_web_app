import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildMcpFeatureRequestPayload,
  buildMcpToolCatalog,
  hasMcpWriteConfirmation,
  isMcpWriteTool,
  mcpActionToToolName,
  mcpConfirmationPhrase,
  mcpRequestedScopes,
} from "./mcp_my_web_app_tools.ts";

Deno.test("MCP tool catalog exposes the three Issue 793 prototype tools", () => {
  const tools = buildMcpToolCatalog();

  assertEquals(tools.map((tool) => tool.name), [
    "wbs.tasks.list",
    "feature_request.create",
    "user_tasks.list",
  ]);
  assertEquals(tools[1].write_confirmation_required, true);
});

Deno.test("MCP action names map to tool scopes", () => {
  assertEquals(mcpActionToToolName("mcp.wbs.list"), "wbs.tasks.list");
  assertEquals(
    mcpActionToToolName("mcp.tool.call", { tool_name: "user_tasks.list" }),
    "user_tasks.list",
  );
  assertEquals(
    mcpActionToToolName("mcp.tool.call", { toolName: "wbs.tasks.list" }),
    "wbs.tasks.list",
  );
  assertEquals(
    mcpActionToToolName("mcp.tool.call", {
      jsonrpc: "2.0",
      method: "tools/call",
      params: { name: "feature_request.create" },
    }),
    "feature_request.create",
  );
  assertEquals(mcpRequestedScopes("feature_request.create"), ["create"]);
  assertEquals(isMcpWriteTool("feature_request.create"), true);
});

Deno.test("write tools require explicit confirmation phrase", () => {
  assertEquals(
    mcpConfirmationPhrase("feature_request.create"),
    "create_feature_request",
  );
  assertEquals(
    hasMcpWriteConfirmation("feature_request.create", { confirm: true }),
    false,
  );
  assertEquals(
    hasMcpWriteConfirmation("feature_request.create", {
      confirm: true,
      confirmation_phrase: "create_feature_request",
    }),
    true,
  );
});

Deno.test("feature request payload normalizes WBS fields", () => {
  const result = buildMcpFeatureRequestPayload({
    title: "MCPから追加要望を作る",
    description: "Claude Apps風の導線から登録する",
    instance: "ps6",
    end_date: "2026-05-10",
  });

  assertEquals(result.ok, true);
  if (result.ok) {
    assertEquals(result.payload.title, "[追加要望] MCPから追加要望を作る");
    assertEquals(result.payload.instance, "ps6");
    assertEquals(result.payload.owner_instance, "ps6");
    assertEquals(result.payload.status, "pending");
    assertEquals(result.payload.planned_end_date, "2026-05-10");
  }
});
