import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders, jsonResponse } from "../_shared/edge.ts";

const WELL_KNOWN_PATH = "/.well-known/oauth-protected-resource";
const CACHE_CONTROL = "public, max-age=3600";

function optionalEnv(name: string): string {
  return (Deno.env.get(name) ?? "").trim();
}

function uniqueStrings(values: string[]): string[] {
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))];
}

function isWellKnownRequest(req: Request): boolean {
  const { pathname } = new URL(req.url);
  return pathname === WELL_KNOWN_PATH ||
    pathname.endsWith(`/mcp-well-known${WELL_KNOWN_PATH}`) ||
    pathname.endsWith(WELL_KNOWN_PATH);
}

export function buildMcpWellKnownMetadata(): Record<string, unknown> | null {
  const resource = optionalEnv("MCP_RESOURCE_URL");
  const authorizationServers = uniqueStrings([
    optionalEnv("WORKOS_AUTHKIT_URL"),
    optionalEnv("WORKOS_AUTHKIT_DOMAIN"),
    optionalEnv("WORKOS_ISSUER"),
  ]);

  if (!resource || authorizationServers.length === 0) return null;

  return {
    resource,
    resource_name: "Jibun Inc MCP",
    authorization_servers: authorizationServers,
    scopes_supported: [
      "memory",
      "memory.search",
      "memory.query_route",
      "memory.rank",
      "memory.related",
      "memory.stats",
      "memory.rag.query",
      "rag.query",
    ],
    bearer_methods_supported: ["header"],
    resource_signing_alg_values_supported: ["RS256"],
    token_endpoint_auth_methods_supported: ["none", "client_secret_post"],
    token_validation: {
      resource_indicators_required: true,
      issuer_trailing_slash_tolerant: true,
      pkce_required: true,
    },
    capabilities: {
      tools: true,
      sampling: false,
    },
  };
}

export function handleMcpWellKnownRequest(
  req: Request,
): Response {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "GET" || !isWellKnownRequest(req)) {
    return new Response("Not Found", {
      status: 404,
      headers: {
        ...corsHeaders,
        "Cache-Control": "no-store",
      },
    });
  }

  const metadata = buildMcpWellKnownMetadata();
  if (!metadata) {
    return jsonResponse(
      { error: "mcp_well_known_not_configured" },
      500,
    );
  }

  return new Response(JSON.stringify(metadata), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": CACHE_CONTROL,
    },
  });
}

if (import.meta.main) {
  serve(handleMcpWellKnownRequest);
}
