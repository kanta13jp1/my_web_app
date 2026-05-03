---
title: "Why your MCP server should serve OAuth Protected Resource Metadata — AuthKit + RFC 9728"
published: true
tags: mcp, oauth, workos, supabase
canonical_url: null
---

## The problem: too many clients, too few discovery hooks

We expose Supabase Edge Functions as MCP (Model Context Protocol) servers. The clients that hit them are heterogeneous — Claude Desktop, Codex CLI, Cursor, VS Code Continue, a couple of in-house browser extensions. None of them ship with a hard-coded "use WorkOS AuthKit, scope is `tool:ai_chat`, audience must contain `urn:jibun:tool:<tool>`" recipe. Without a discovery mechanism, every new client needs a hand-written runbook, and every change to the auth setup means another doc revision.

**RFC 9728 (OAuth 2.0 Protected Resource Metadata)** solves this by letting a protected resource publish a JSON document at `/.well-known/oauth-protected-resource`. Clients fetch it, learn the authorization servers and supported scopes, and bootstrap themselves. The current MCP authorization draft is built on top of this.

This post documents the metadata endpoint we shipped today on our Edge Functions — what we put in it, why, and which fields exist purely as scar tissue from real failures. The code lives in [`supabase/functions/_shared/mcp_auth_guard.ts`](https://github.com/kanta13jp1/my_web_app/blob/main/supabase/functions/_shared/mcp_auth_guard.ts).

## Setup

- **AuthKit (WorkOS)** is the identity provider — JWKS, issuer, hosted SSO UI.
- **Edge Function (Deno on Supabase)** is the protected resource. One EF hosts many MCP tools (a "hub" pattern).
- **Bearer JWT verification**: `jose.jwtVerify` checks signature / expiry / issuer. Audience is checked separately via RFC 8707 resource indicators against `urn:jibun:tool:<tool>`.
- **Scope shapes**: we accept `all` (super-admin), `tool:<name>`, and bare `<name>`, because client SDKs disagree on the prefix.

## The endpoint

`isOAuthProtectedResourceMetadataRequest(req)` matches any path ending in `/.well-known/oauth-protected-resource`. `buildOAuthProtectedResourceMetadata` produces the JSON body:

```ts
export const OAUTH_PROTECTED_RESOURCE_PATH =
  "/.well-known/oauth-protected-resource";

export function buildOAuthProtectedResourceMetadata(
  reqUrl: string,
  toolName: string,
  scopes: string[] = [toolName],
): Record<string, unknown> {
  const resource = optionalEnv("MCP_RESOURCE_URL") ||
    protectedResourceUrl(reqUrl);
  return {
    resource,
    resource_name: toolName,
    authorization_servers: getAuthKitAuthorizationServers(),
    scopes_supported: uniqueStrings(["all", toolName, ...scopes]),
    bearer_methods_supported: ["header"],
    resource_signing_alg_values_supported: ["RS256"],
    jwks_uri: optionalEnv("WORKOS_JWKS_URL"),
    authkit_url: optionalEnv("WORKOS_AUTHKIT_URL") ||
      optionalEnv("WORKOS_AUTHKIT_DOMAIN") || null,
    token_validation: {
      audience_checked_by_jwt_verify: false,
      audience_checked_by_resource_indicator: true,
      issuer_trailing_slash_tolerant: true,
    },
  };
}
```

Four design notes worth surfacing.

### 1. `resource` is the externally visible URL

Edge Functions live at `https://<project>.functions.supabase.co/ai-hub`, but real deployments often add a CDN, a custom domain, or a path rewrite in front. We honour `MCP_RESOURCE_URL` first, and fall back to deriving it from the request URL minus the well-known suffix.

This value has to match the audience claim that your verification logic compares against. Get it wrong and you hit the worst class of bug: every token is technically valid, but the resource indicator check fails on the server, so the symptom is a generic 403 with no useful client-side breadcrumb.

### 2. `authorization_servers` puts AuthKit URL first

We list `WORKOS_AUTHKIT_URL` (the short hosted URL that aggregates the login UI) before `WORKOS_ISSUER` (the JWT `iss` value). Clients typically need both: AuthKit URL is where humans go to sign in, issuer is who signs the resulting token. Mixing them up sends users to the wrong page or makes the token verification reject valid tokens.

### 3. `audience_checked_by_jwt_verify: false` is a footgun warning

WorkOS-issued JWTs do not populate the audience claim by default. If a client implementer naively turns on `audience` validation in `jose.jwtVerify`, every token gets rejected. We document the fact that we use RFC 8707 resource indicators in the request instead, so client authors do not waste hours wondering why their "secure" config refuses everything.

### 4. `issuer_trailing_slash_tolerant: true` is empirical scar tissue

`https://api.workos.com/user_management/<id>` and `https://api.workos.com/user_management/<id>/` both circulate in the wild. Our `getWorkOsIssuers()` accepts three variants (raw, no slash, with slash). We expose this leniency in the metadata so client authors know they can be loose too.

## Tying it back to the 401 challenge

The other half of the spec is that protected resources should advertise the metadata URL in their `WWW-Authenticate` header on a 401:

```text
WWW-Authenticate: Bearer realm="urn:jibun:tool:ai_chat",
  resource_metadata="https://<host>/ai-hub/.well-known/oauth-protected-resource"
```

A client that has never heard of metadata can still bootstrap from a single failed request. We compute the URL through `protectedResourceUrl(reqUrl)` so it works behind a CDN.

## Discovery is not authorization

The same PR shipped `agent_tool_policy_server_gate.sql`, a server-side scope gate. It stores an (agent role × tool) approval matrix in Postgres and rejects with 403 when a JWT scope is broader than the row in the matrix.

This matters because metadata only tells clients which scopes *exist*. It does not enforce who is *allowed* to wield them. The policy gate enforces the boundary; the metadata documents the contract.

## Lessons

1. **Metadata is an I/O contract.** Once published, clients depend on it. Lock down field names and semantics before exposing the endpoint, and namespace your custom extensions (we should rename `token_validation` to live under a `x_jibun_*` prefix in v2).
2. **The trailing-slash and audience traps cost more in operations than in code.** Before we documented our checks in metadata, every new client integration ate an hour of synchronous debugging. After: about five minutes.
3. **Discovery comes with a no-lying obligation.** If your published metadata diverges from server behaviour, debugging becomes impossible. Add a CI snapshot test that exercises both the metadata builder and the verifier against the same fixture token.

## References

- RFC 9728 — OAuth 2.0 Protected Resource Metadata
- RFC 8707 — Resource Indicators for OAuth 2.0
- MCP Authorization (latest draft)
- WorkOS AuthKit JWKS / issuer documentation
- Internal: [`docs/MCP_AUTH_SECURITY_PRINCIPLES.md`](https://github.com/kanta13jp1/my_web_app/blob/main/docs/MCP_AUTH_SECURITY_PRINCIPLES.md) Rule 27
