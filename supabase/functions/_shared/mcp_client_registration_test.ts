import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildMcpClientRegistration,
  mcpRegistrationClientIp,
} from "./mcp_client_registration.ts";

Deno.test("MCP client registration accepts https redirect URIs", async () => {
  const req = new Request("https://example.test/register", {
    headers: { "x-forwarded-for": "203.0.113.7" },
  });
  const result = await buildMcpClientRegistration({
    client_name: "Claude Desktop",
    redirect_uris: ["https://client.example.com/callback"],
    grant_types: ["authorization_code", "refresh_token"],
    scope: "read create",
  }, req);

  assertEquals(result.ok, true);
  if (result.ok) {
    assertEquals(result.row.client_name, "Claude Desktop");
    assertEquals(result.row.redirect_uris, [
      "https://client.example.com/callback",
    ]);
    assertEquals(result.row.scopes, ["read", "create"]);
    assertEquals(
      result.response.token_endpoint_auth_method,
      "client_secret_post",
    );
  }
});

Deno.test("MCP client registration rejects unsafe redirect URIs", async () => {
  const result = await buildMcpClientRegistration({
    redirect_uris: ["http://evil.example.com/callback"],
  }, new Request("https://example.test/register"));

  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.status, 400);
});

Deno.test("MCP client registration permits loopback localhost", async () => {
  const result = await buildMcpClientRegistration({
    redirect_uris: ["http://localhost:39123/callback"],
  }, new Request("https://example.test/register"));

  assertEquals(result.ok, true);
});

Deno.test("MCP client registration normalizes request IP", () => {
  const req = new Request("https://example.test/register", {
    headers: { "x-forwarded-for": "203.0.113.7, 10.0.0.1" },
  });

  assertEquals(mcpRegistrationClientIp(req), "203.0.113.7");
});
