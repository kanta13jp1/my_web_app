export type McpClientRegistrationResult =
  | {
    ok: true;
    row: Record<string, unknown>;
    response: Record<string, unknown>;
  }
  | { ok: false; status: number; error: string };

const DEFAULT_GRANT_TYPES = ["authorization_code"];
const ALLOWED_GRANT_TYPES = new Set(["authorization_code", "refresh_token"]);
const ALLOWED_SCOPES = new Set([
  "all",
  "read",
  "create",
  "wbs.tasks.list",
  "feature_request.create",
  "user_tasks.list",
]);

function asStringArray(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.flatMap((item) =>
      typeof item === "string" ? [item.trim()] : []
    ).filter(Boolean);
  }
  if (typeof value === "string") {
    return value.split(/\s+/).map((item) => item.trim()).filter(Boolean);
  }
  return [];
}

function unique(values: string[]): string[] {
  return [...new Set(values)];
}

function isLoopbackHostname(hostname: string): boolean {
  return ["localhost", "127.0.0.1", "::1", "[::1]"].includes(
    hostname.toLowerCase(),
  );
}

function normalizeRedirectUris(value: unknown): string[] | null {
  const uris = unique(asStringArray(value)).slice(0, 10);
  if (uris.length === 0) return null;

  const normalized: string[] = [];
  for (const raw of uris) {
    try {
      const url = new URL(raw);
      if (url.username || url.password || url.hash) return null;
      if (url.protocol !== "https:" && !isLoopbackHostname(url.hostname)) {
        return null;
      }
      if (url.protocol !== "https:" && url.protocol !== "http:") return null;
      normalized.push(url.toString());
    } catch {
      return null;
    }
  }
  return normalized;
}

function normalizeGrantTypes(value: unknown): string[] {
  const requested = unique(asStringArray(value));
  const grantTypes = requested.length > 0 ? requested : DEFAULT_GRANT_TYPES;
  return grantTypes.filter((grantType) => ALLOWED_GRANT_TYPES.has(grantType));
}

function normalizeScopes(value: unknown): string[] {
  const requested = unique(asStringArray(value));
  const scopes = requested.length > 0 ? requested : ["read"];
  return scopes.filter((scope) => ALLOWED_SCOPES.has(scope));
}

function randomBase64Url(bytes: number): string {
  const data = new Uint8Array(bytes);
  crypto.getRandomValues(data);
  let binary = "";
  for (const byte of data) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/g,
    "",
  );
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function normalizeIp(raw: string): string | null {
  const first = raw.split(",")[0]?.trim() ?? "";
  if (!first) return null;
  if (/^[0-9.]+$/.test(first)) return first;
  if (/^[0-9a-fA-F:]+$/.test(first)) return first;
  return null;
}

export function mcpRegistrationClientIp(req: Request): string | null {
  return normalizeIp(
    req.headers.get("x-forwarded-for") ??
      req.headers.get("cf-connecting-ip") ??
      "",
  );
}

export async function buildMcpClientRegistration(
  body: Record<string, unknown>,
  req: Request,
): Promise<McpClientRegistrationResult> {
  const redirectUris = normalizeRedirectUris(body.redirect_uris);
  if (!redirectUris) {
    return {
      ok: false,
      status: 400,
      error: "redirect_uris must include at least one https or loopback URI",
    };
  }

  const grantTypes = normalizeGrantTypes(body.grant_types);
  if (grantTypes.length === 0) {
    return { ok: false, status: 400, error: "unsupported grant_types" };
  }

  const scopes = normalizeScopes(body.scope ?? body.scopes);
  if (scopes.length === 0) {
    return { ok: false, status: 400, error: "unsupported scopes" };
  }

  const clientId = `mcp_${crypto.randomUUID()}`;
  const clientSecret = `mcp_secret_${randomBase64Url(32)}`;
  const issuedAt = Math.floor(Date.now() / 1000);
  const clientName = String(body.client_name ?? "MCP Client").trim().slice(
    0,
    120,
  );

  const row = {
    client_id: clientId,
    client_secret_hash: await sha256Hex(clientSecret),
    client_name: clientName,
    redirect_uris: redirectUris,
    grant_types: grantTypes,
    scopes,
    created_by_ip: mcpRegistrationClientIp(req),
  };

  return {
    ok: true,
    row,
    response: {
      client_id: clientId,
      client_secret: clientSecret,
      client_id_issued_at: issuedAt,
      client_secret_expires_at: 0,
      client_name: clientName,
      redirect_uris: redirectUris,
      grant_types: grantTypes,
      scope: scopes.join(" "),
      token_endpoint_auth_method: "client_secret_post",
    },
  };
}
