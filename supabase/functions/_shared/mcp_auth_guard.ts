// MCP Auth Guard — 自分株式会社 MCP server 公開時の認可・スコープ検証
//
// docs/MCP_AUTH_SECURITY_PRINCIPLES.md 10 原則のうち以下を実装する基盤層:
//   #2 Bearer Token Validation Deny-by-Default
//   #5 Resource Indicators (RFC 8707) で Scope 最小化
//   #7 Audit Log + Anomaly Detection (mcp_audit_log への記録呼び出し点)
//   #8 OAuth 2.1 + PKCE (token 検証で aud / iss / scope を確認する point)
//
// WorkOS JWKS による JWT 検証本体をここで配線する。
// mcp_audit_log への INSERT は logMcpInvocation() 側の後続配線で扱う。
//
// ソース: NotebookLM Notebook 1b808a60-85d6-49f7-ab80-0e90a43cf1d8
// "Streamlining MCP Authentication with WorkOS AuthKit"
// (RFC 7591 Dynamic Client Registration / RFC 8707 Resource Indicators /
//  arXiv "Security Analysis of the MCP Specification and Prompt Injection
//  Vulnerabilities in Tool-Integrated LLM Agents")

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  createRemoteJWKSet,
  type JWTPayload,
  jwtVerify,
} from "https://deno.land/x/jose@v5.9.6/index.ts";

/**
 * Bearer 検証成功時に MCP EF へ渡されるコンテキスト。
 * - `client_id`: DCR (mcp_oauth_clients テーブル) で発行された client_id
 * - `scopes`: token に含まれる scope claim (空配列なら scope なし扱い)
 * - `aud`: RFC 8707 Resource Indicator の audience 配列
 *          (e.g. ["urn:jibun:tool:judgment", "urn:jibun:tool:vision"])
 * - `subject`: token sub (任意 / WorkOS では organization-bound user id)
 */
export interface McpAuthContext {
  client_id: string;
  scopes: string[];
  aud: string[];
  subject?: string;
}

/**
 * MCP server tool の resource URN naming 規則。validateBearer の `aud` チェックで
 * 使用する。`requireScope(ctx, "judgment")` は内部で `urn:jibun:tool:judgment` を
 * 構築して `ctx.aud` に含まれるかを判定する。
 */
export const MCP_RESOURCE_PREFIX = "urn:jibun:tool:";
export const OAUTH_PROTECTED_RESOURCE_PATH =
  "/.well-known/oauth-protected-resource";

export function toolResourceUrn(tool: string): string {
  return `${MCP_RESOURCE_PREFIX}${tool}`;
}

function trimTrailingSlash(value: string): string {
  return value.replace(/\/+$/, "");
}

function optionalEnv(name: string): string {
  return (Deno.env.get(name) ?? "").trim();
}

function uniqueStrings(values: string[]): string[] {
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))];
}

let jwksCache: ReturnType<typeof createRemoteJWKSet> | null = null;
let jwksCacheUrl = "";
let adminClientCache: SupabaseClient | null = null;
let adminClientCacheKey = "";

function getWorkOsJwks(): ReturnType<typeof createRemoteJWKSet> | null {
  const url = optionalEnv("WORKOS_JWKS_URL");
  if (!url) return null;

  try {
    if (!jwksCache || jwksCacheUrl !== url) {
      jwksCache = createRemoteJWKSet(new URL(url));
      jwksCacheUrl = url;
    }
    return jwksCache;
  } catch {
    return null;
  }
}

function getWorkOsIssuers(): string[] {
  const raw = optionalEnv("WORKOS_ISSUER");
  if (!raw) return [];

  const withoutTrailingSlash = trimTrailingSlash(raw);
  const candidates = [
    raw,
    withoutTrailingSlash,
    withoutTrailingSlash ? `${withoutTrailingSlash}/` : "",
  ];

  return uniqueStrings(candidates);
}

function getAuthKitAuthorizationServers(): string[] {
  const authKitUrl = optionalEnv("WORKOS_AUTHKIT_URL") ||
    optionalEnv("WORKOS_AUTHKIT_DOMAIN");
  return uniqueStrings([
    authKitUrl,
    ...getWorkOsIssuers(),
  ]);
}

function protectedResourceUrl(reqUrl: string): string {
  const url = new URL(reqUrl);
  if (url.pathname.endsWith(`${OAUTH_PROTECTED_RESOURCE_PATH}/`)) {
    url.pathname = url.pathname.slice(
      0,
      -(OAUTH_PROTECTED_RESOURCE_PATH.length + 1),
    );
  } else if (url.pathname.endsWith(OAUTH_PROTECTED_RESOURCE_PATH)) {
    url.pathname = url.pathname.slice(0, -OAUTH_PROTECTED_RESOURCE_PATH.length);
  }
  url.search = "";
  url.hash = "";
  return trimTrailingSlash(url.toString());
}

export function isOAuthProtectedResourceMetadataRequest(req: Request): boolean {
  const { pathname } = new URL(req.url);
  return pathname.endsWith(OAUTH_PROTECTED_RESOURCE_PATH) ||
    pathname.endsWith(`${OAUTH_PROTECTED_RESOURCE_PATH}/`);
}

export function buildOAuthProtectedResourceMetadata(
  reqUrl: string,
  toolName: string,
  scopes: string[] = [toolName],
): Record<string, unknown> {
  const resource = optionalEnv("MCP_RESOURCE_URL") ||
    protectedResourceUrl(reqUrl);
  const metadata: Record<string, unknown> = {
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

  return Object.fromEntries(
    Object.entries(metadata).filter(([, value]) =>
      value !== "" &&
      value !== null &&
      (!Array.isArray(value) || value.length > 0)
    ),
  );
}

function getAdminClient(): SupabaseClient | null {
  const url = (Deno.env.get("SUPABASE_URL") ?? "").trim();
  const key = (Deno.env.get("SERVICE_ROLE_KEY") ?? "").trim();
  if (!url || !key) return null;

  const cacheKey = `${url}\n${key}`;
  if (!adminClientCache || adminClientCacheKey !== cacheKey) {
    adminClientCache = createClient(url, key, {
      auth: { persistSession: false },
    });
    adminClientCacheKey = cacheKey;
  }
  return adminClientCache;
}

function stringClaim(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function getClientId(payload: JWTPayload): string | null {
  return stringClaim(payload.client_id) ?? stringClaim(payload.sub);
}

function getScopes(payload: JWTPayload): string[] {
  const scope = payload.scope;
  if (typeof scope === "string") {
    return scope.split(/\s+/).map((item) => item.trim()).filter(Boolean);
  }
  if (Array.isArray(scope)) {
    return scope
      .flatMap((item) => typeof item === "string" ? item.split(/\s+/) : [])
      .map((item) => item.trim())
      .filter(Boolean);
  }
  return [];
}

function getAudiences(payload: JWTPayload): string[] {
  const { aud } = payload;
  if (typeof aud === "string") return aud.trim() ? [aud.trim()] : [];
  if (Array.isArray(aud)) {
    return aud.flatMap((item) =>
      typeof item === "string" && item.trim() ? [item.trim()] : []
    );
  }
  return [];
}

async function isClientAllowed(clientId: string): Promise<boolean> {
  const admin = getAdminClient();
  if (!admin) return false;

  const { data, error } = await admin
    .from("mcp_oauth_clients")
    .select("suspended")
    .eq("client_id", clientId)
    .maybeSingle();

  if (error || !data) return false;
  return data.suspended !== true;
}

/**
 * Authorization: Bearer <jwt> ヘッダーを検証して MCP コンテキストを返す。
 *
 * Deny-by-default: token なし / 検証失敗 / 期限切れ / issuer ミスマッチ /
 * 末尾スラッシュ問題 等で **すべて null を返す**。呼び出し側は `if (!ctx)` で
 * 即座に 401 応答すること。
 *
 * env `MCP_AUTH_BYPASS=1` なら synthetic context を返す developer-only stub。
 * 通常経路では:
 *   1. WORKOS_JWKS_URL から JWKS を fetch + jose cache
 *   2. JWT signature 検証 (RS256)
 *   3. iss を WORKOS_ISSUER (末尾スラッシュ両許容) と比較
 *   4. aud / scope / sub claim を抽出して McpAuthContext に詰める
 *   5. exp / nbf を現在時刻と比較 (jose jwtVerify)
 *   6. mcp_oauth_clients.suspended=true なら拒否
 *
 * @returns null = 401 / それ以外 = {client_id, scopes, aud, subject}
 */
export async function validateBearer(
  req: Request,
): Promise<McpAuthContext | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return null;
  const token = auth.slice("Bearer ".length).trim();
  if (!token) return null;

  // Developer bypass — 本番環境では Supabase Secrets に MCP_AUTH_BYPASS を
  // 設定しないこと (production safety)
  if (
    Deno.env.get("MCP_AUTH_BYPASS") === "1" &&
    Deno.env.get("MCP_DEV_MODE") === "1"
  ) {
    return {
      client_id: "dev-bypass",
      scopes: ["all"],
      aud: [`${MCP_RESOURCE_PREFIX}*`],
    };
  }

  if (token.split(".").length !== 3) return null;

  const jwks = getWorkOsJwks();
  const issuers = getWorkOsIssuers();
  if (!jwks || issuers.length === 0) return null;

  for (const issuer of issuers) {
    try {
      const { payload } = await jwtVerify(token, jwks, {
        algorithms: ["RS256"],
        issuer,
      });
      const clientId = getClientId(payload);
      if (!clientId) return null;
      if (!await isClientAllowed(clientId)) return null;

      return {
        client_id: clientId,
        scopes: getScopes(payload),
        aud: getAudiences(payload),
        subject: stringClaim(payload.sub) ?? undefined,
      };
    } catch {
      // Try the slash-tolerant issuer variant before denying.
    }
  }

  return null;
}

/**
 * `ctx` が指定 tool への呼び出しを許可されているか判定 (RFC 8707 Resource
 * Indicator の aud check + scope check)。
 *
 * - `*` audience (e.g. `urn:jibun:tool:*`) は wildcard として全 tool を許可
 *   (= dev-bypass / admin token 用 / production の通常 token には付与しない)
 * - exact match: `urn:jibun:tool:judgment` で tool="judgment" を許可
 * - scope に "all" or 該当 tool 名が含まれていれば許可
 *
 * @returns true = 許可 / false = 403 を返すべき
 */
export function requireScope(ctx: McpAuthContext, tool: string): boolean {
  if (!tool) return false;
  const targetUrn = toolResourceUrn(tool);
  const wildcardUrn = `${MCP_RESOURCE_PREFIX}*`;

  const audAllows = ctx.aud.includes(targetUrn) ||
    ctx.aud.includes(wildcardUrn);
  if (!audAllows) return false;

  if (ctx.scopes.includes("all")) return true;
  if (ctx.scopes.includes(tool)) return true;

  return false;
}

/**
 * MCP tool 呼び出しを mcp_audit_log テーブルに 1 行 INSERT する補助関数。
 *
 * 呼び出し側 EF の try/finally で必ず呼ぶことを前提とした design (例外時も log)。
 * 本 commit 時点では console.log のみ — Supabase service role での INSERT 実装は
 * mcp_audit_log migration 適用後の後続 commit で配線。
 *
 * 呼び出し例:
 *   await logMcpInvocation(ctx, "judgment.get", { date: "2026-04-28" }, 200, req);
 */
function normalizeRequestIp(raw: string): string | null {
  const first = raw.split(",")[0]?.trim() ?? "";
  if (!first) return null;
  if (/^[0-9.]+$/.test(first)) return first;
  if (/^[0-9a-fA-F:]+$/.test(first)) return first;
  return null;
}

function toAuditJson(value: unknown): unknown {
  if (value == null) return null;
  try {
    return JSON.parse(JSON.stringify(value));
  } catch {
    return { unserializable: String(value).slice(0, 500) };
  }
}

export async function logMcpInvocation(
  ctx: McpAuthContext | null,
  toolName: string,
  requestArgs: unknown,
  responseStatus: number,
  req: Request,
): Promise<void> {
  const ip = req.headers.get("x-forwarded-for") ??
    req.headers.get("cf-connecting-ip") ?? "";
  const admin = getAdminClient();
  if (admin) {
    const { error } = await admin.from("mcp_audit_log").insert({
      client_id: ctx?.client_id ?? "anonymous",
      tool_name: toolName || "unknown",
      request_args: toAuditJson(requestArgs),
      response_status: responseStatus,
      request_ip: normalizeRequestIp(ip),
    });
    if (!error) return;
    console.warn("[mcp-audit] insert failed", error.message);
  }

  console.log(
    "[mcp-audit]",
    JSON.stringify({
      client_id: ctx?.client_id ?? "anonymous",
      tool_name: toolName,
      response_status: responseStatus,
      ip: normalizeRequestIp(ip),
      args_preview: typeof requestArgs === "string"
        ? requestArgs.slice(0, 200)
        : JSON.stringify(requestArgs).slice(0, 200),
    }),
  );
}
