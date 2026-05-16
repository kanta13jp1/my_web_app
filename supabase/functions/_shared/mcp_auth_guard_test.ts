import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildOAuthProtectedResourceMetadata,
  isOAuthProtectedResourceMetadataRequest,
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

Deno.test("OAuth protected resource metadata advertises AuthKit without auth", () => {
  const prevAuthKit = Deno.env.get("WORKOS_AUTHKIT_URL");
  const prevIssuer = Deno.env.get("WORKOS_ISSUER");
  const prevJwks = Deno.env.get("WORKOS_JWKS_URL");
  const prevResource = Deno.env.get("MCP_RESOURCE_URL");
  try {
    Deno.env.set("WORKOS_AUTHKIT_URL", "https://auth.example.com");
    Deno.env.set("WORKOS_ISSUER", "https://issuer.example.com/");
    Deno.env.set("WORKOS_JWKS_URL", "https://issuer.example.com/jwks.json");
    Deno.env.delete("MCP_RESOURCE_URL");

    const req = new Request(
      "https://example.test/functions/v1/memory-search-hub/.well-known/oauth-protected-resource",
    );
    assertEquals(isOAuthProtectedResourceMetadataRequest(req), true);

    const metadata = buildOAuthProtectedResourceMetadata(
      req.url,
      "memory-search-hub",
      ["memory"],
    );
    assertEquals(
      metadata.resource,
      "https://example.test/functions/v1/memory-search-hub",
    );
    assertEquals(metadata.authorization_servers, [
      "https://auth.example.com",
      "https://issuer.example.com/",
      "https://issuer.example.com",
    ]);
    assertEquals(metadata.authkit_url, "https://auth.example.com");
    assertEquals(
      (metadata.token_validation as Record<string, unknown>)
        .audience_checked_by_jwt_verify,
      false,
    );
    assertEquals(
      (metadata.token_validation as Record<string, unknown>)
        .issuer_trailing_slash_tolerant,
      true,
    );
  } finally {
    if (prevAuthKit === undefined) Deno.env.delete("WORKOS_AUTHKIT_URL");
    else Deno.env.set("WORKOS_AUTHKIT_URL", prevAuthKit);
    if (prevIssuer === undefined) Deno.env.delete("WORKOS_ISSUER");
    else Deno.env.set("WORKOS_ISSUER", prevIssuer);
    if (prevJwks === undefined) Deno.env.delete("WORKOS_JWKS_URL");
    else Deno.env.set("WORKOS_JWKS_URL", prevJwks);
    if (prevResource === undefined) Deno.env.delete("MCP_RESOURCE_URL");
    else Deno.env.set("MCP_RESOURCE_URL", prevResource);
  }
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
