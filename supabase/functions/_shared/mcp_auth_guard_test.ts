import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  logMcpInvocation,
  type McpAuthContext,
  requireScope,
  toolResourceUrn,
} from "./mcp_auth_guard.ts";

Deno.test("toolResourceUrn builds scoped MCP resource names", () => {
  assertEquals(toolResourceUrn("memory"), "urn:jibun:tool:memory");
});

Deno.test("requireScope allows wildcard audience and all scope", () => {
  const ctx: McpAuthContext = {
    client_id: "test-client",
    scopes: ["all"],
    aud: ["urn:jibun:tool:*"],
  };

  assertEquals(requireScope(ctx, "memory"), true);
});

Deno.test("requireScope rejects mismatched audience", () => {
  const ctx: McpAuthContext = {
    client_id: "test-client",
    scopes: ["memory"],
    aud: ["urn:jibun:tool:calendar"],
  };

  assertEquals(requireScope(ctx, "memory"), false);
});

Deno.test("logMcpInvocation falls back safely without Supabase env", async () => {
  const ctx: McpAuthContext = {
    client_id: "test-client",
    scopes: ["all"],
    aud: ["urn:jibun:tool:*"],
  };
  const req = new Request("https://example.test/mcp", {
    headers: { "x-forwarded-for": "203.0.113.10" },
  });

  await logMcpInvocation(ctx, "memory.search", { q: "audit" }, 200, req);
});
