import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildMcpWellKnownMetadata,
  handleMcpWellKnownRequest,
} from "./index.ts";

function withEnv(name: string, value: string | null): () => void {
  const previous = Deno.env.get(name);
  if (value === null) Deno.env.delete(name);
  else Deno.env.set(name, value);
  return () => {
    if (previous === undefined) Deno.env.delete(name);
    else Deno.env.set(name, previous);
  };
}

Deno.test("buildMcpWellKnownMetadata advertises resource and excludes sampling", () => {
  const restoreResource = withEnv(
    "MCP_RESOURCE_URL",
    "https://example.test/mcp",
  );
  const restoreIssuer = withEnv("WORKOS_ISSUER", "https://issuer.example.test");
  const restoreAuthKit = withEnv("WORKOS_AUTHKIT_URL", "");
  try {
    const metadata = buildMcpWellKnownMetadata()!;
    assertEquals(metadata.resource, "https://example.test/mcp");
    assertEquals(metadata.authorization_servers, [
      "https://issuer.example.test",
    ]);
    assertEquals(
      (metadata.capabilities as Record<string, unknown>).sampling,
      false,
    );
  } finally {
    restoreResource();
    restoreIssuer();
    restoreAuthKit();
  }
});

Deno.test("handleMcpWellKnownRequest returns cacheable metadata without auth", async () => {
  const restoreResource = withEnv(
    "MCP_RESOURCE_URL",
    "https://example.test/mcp",
  );
  const restoreIssuer = withEnv("WORKOS_ISSUER", "https://issuer.example.test");
  try {
    const res = await handleMcpWellKnownRequest(
      new Request(
        "https://example.test/functions/v1/mcp-well-known/.well-known/oauth-protected-resource",
      ),
    );
    const body = await res.json();
    assertEquals(res.status, 200);
    assertEquals(res.headers.get("Cache-Control"), "public, max-age=3600");
    assertEquals(body.resource, "https://example.test/mcp");
  } finally {
    restoreResource();
    restoreIssuer();
  }
});

Deno.test("handleMcpWellKnownRequest returns 404 for non metadata paths", async () => {
  const res = await handleMcpWellKnownRequest(
    new Request("https://example.test/functions/v1/mcp-well-known/health"),
  );
  assertEquals(res.status, 404);
});

Deno.test("handleMcpWellKnownRequest fails closed when env is missing", async () => {
  const restoreResource = withEnv("MCP_RESOURCE_URL", null);
  const restoreIssuer = withEnv("WORKOS_ISSUER", null);
  const restoreAuthKit = withEnv("WORKOS_AUTHKIT_URL", null);
  const restoreDomain = withEnv("WORKOS_AUTHKIT_DOMAIN", null);
  try {
    const res = await handleMcpWellKnownRequest(
      new Request(
        "https://example.test/functions/v1/mcp-well-known/.well-known/oauth-protected-resource",
      ),
    );
    assertEquals(res.status, 500);
    assertEquals(await res.json(), { error: "mcp_well_known_not_configured" });
  } finally {
    restoreResource();
    restoreIssuer();
    restoreAuthKit();
    restoreDomain();
  }
});
