import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildMcpFeatureRequestPayload,
  buildMcpNoteDeletePayload,
  buildMcpNoteUpdatePayload,
  buildMcpToolCatalog,
  buildMcpWorkerInvokePayload,
  hasMcpWriteConfirmation,
  isMcpWriteTool,
  jibunApiScopesToMcpPermissions,
  mcpActionToToolName,
  mcpConfirmationPhrase,
  mcpRequestedScopes,
} from "./mcp_my_web_app_tools.ts";

Deno.test("MCP tool catalog exposes the prototype + notes CRUD + site operation tools", () => {
  const tools = buildMcpToolCatalog();

  assertEquals(tools.map((tool) => tool.name), [
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
  ]);
  assertEquals(tools[1].write_confirmation_required, true);
  assertEquals(tools[5].write_confirmation_required, true);
  assertEquals(tools[6].read_only_hint, true);
  assertEquals(tools[7].write_confirmation_required, true);
  assertEquals(tools[8].write_confirmation_required, true);
  assertEquals(tools[8].destructive_hint, true);
  assertEquals(tools[11].write_confirmation_required, true);
});

Deno.test("MCP action names map to tool scopes", () => {
  assertEquals(mcpActionToToolName("mcp.wbs.list"), "wbs.tasks.list");
  assertEquals(mcpActionToToolName("mcp.account.me"), "account.me");
  assertEquals(mcpActionToToolName("mcp.notes.update"), "notes.update");
  assertEquals(mcpActionToToolName("mcp.notes.delete"), "notes.delete");
  assertEquals(mcpActionToToolName("mcp.achievements.list"), "achievements.list");
  assertEquals(mcpActionToToolName("mcp.workers.list"), "workers.list");
  assertEquals(mcpActionToToolName("mcp.workers.invoke"), "workers.invoke");
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
  assertEquals(mcpRequestedScopes("public_businesses.reference_list"), [
    "read",
  ]);
  assertEquals(mcpRequestedScopes("account.me"), ["read"]);
  assertEquals(mcpRequestedScopes("notes.delete"), ["create"]);
  assertEquals(isMcpWriteTool("feature_request.create"), true);
  assertEquals(isMcpWriteTool("notes.update"), true);
  assertEquals(isMcpWriteTool("notes.delete"), true);
  assertEquals(isMcpWriteTool("workers.invoke"), true);
  assertEquals(isMcpWriteTool("account.me"), false);
});

Deno.test("jibunApiScopesToMcpPermissions enforces least privilege without wildcard or admin tools", () => {
  const readOnly = jibunApiScopesToMcpPermissions(["notes.read"]);
  assertEquals(readOnly.scopes, [
    "public_businesses.reference_list",
    "notes.list",
    "account.me",
  ]);
  assertEquals(readOnly.aud, [
    "urn:jibun:tool:public_businesses.reference_list",
    "urn:jibun:tool:notes.list",
    "urn:jibun:tool:account.me",
  ]);
  assertEquals(readOnly.scopes.includes("all"), false);
  assertEquals(readOnly.scopes.includes("notes.create"), false);
  assertEquals(readOnly.scopes.includes("feature_request.create"), false);
  assertEquals(readOnly.aud.includes("urn:jibun:tool:*"), false);

  const allJibun = jibunApiScopesToMcpPermissions([
    "notes.read",
    "notes.write",
    "tasks.read",
    "achievements.read",
    "workers.invoke",
  ]);
  assertEquals(allJibun.scopes.includes("feature_request.create"), false);
  assertEquals(allJibun.scopes.includes("workers.invoke"), true);
  assertEquals(allJibun.scopes.includes("achievements.list"), true);
});

Deno.test("write tools require explicit confirmation phrase", () => {
  assertEquals(
    mcpConfirmationPhrase("feature_request.create"),
    "create_feature_request",
  );
  assertEquals(mcpConfirmationPhrase("notes.update"), "update_note");
  assertEquals(mcpConfirmationPhrase("notes.delete"), "delete_note");
  assertEquals(mcpConfirmationPhrase("workers.invoke"), "invoke_worker");
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
  assertEquals(
    hasMcpWriteConfirmation("notes.update", {
      confirm: true,
      confirmation_phrase: "update_note",
    }),
    true,
  );
  assertEquals(
    hasMcpWriteConfirmation("notes.delete", {
      confirm: true,
      confirmation_phrase: "wrong_phrase",
    }),
    false,
  );
  assertEquals(
    hasMcpWriteConfirmation("workers.invoke", {
      confirm: true,
      confirmation_phrase: "invoke_worker",
    }),
    true,
  );
});

Deno.test("feature request and new write payload builders validate input", () => {
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

  assertEquals(buildMcpNoteUpdatePayload({ id: 0, title: "x" }).ok, false);
  assertEquals(buildMcpNoteUpdatePayload({ id: 5 }).ok, false);
  const noteUpd = buildMcpNoteUpdatePayload({ id: 5, title: "Updated" });
  assertEquals(noteUpd.ok, true);

  assertEquals(buildMcpNoteDeletePayload({ id: -1 }).ok, false);
  assertEquals(buildMcpNoteDeletePayload({ id: 42 }).ok, true);

  assertEquals(buildMcpWorkerInvokePayload({ slug: "bad slug!" }).ok, false);
  assertEquals(
    buildMcpWorkerInvokePayload({ slug: "my-worker", payload: "not-object" })
      .ok,
    false,
  );
  const wk = buildMcpWorkerInvokePayload({
    slug: "My-Worker",
    payload: { hello: 1 },
  });
  assertEquals(wk.ok, true);
  if (wk.ok) {
    assertEquals(wk.payload.slug, "my-worker");
  }
});
