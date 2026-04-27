// MCP Auth Guard — 自分株式会社 MCP server 公開時の認可・スコープ検証 skeleton
//
// docs/MCP_AUTH_SECURITY_PRINCIPLES.md 10 原則のうち以下を実装する基盤層:
//   #2 Bearer Token Validation Deny-by-Default
//   #5 Resource Indicators (RFC 8707) で Scope 最小化
//   #7 Audit Log + Anomaly Detection (mcp_audit_log への記録呼び出し点)
//   #8 OAuth 2.1 + PKCE (token 検証で aud / iss / scope を確認する point)
//
// **本 commit 時点ではシグネチャ確立 + 仮実装のみ** (Win版#132 part 49 / 段階的実装)。
// WorkOS JWKS による JWT 検証本体は後続 commit で配線する。
//
// ソース: NotebookLM Notebook 1b808a60-85d6-49f7-ab80-0e90a43cf1d8
// "Streamlining MCP Authentication with WorkOS AuthKit"
// (RFC 7591 Dynamic Client Registration / RFC 8707 Resource Indicators /
//  arXiv "Security Analysis of the MCP Specification and Prompt Injection
//  Vulnerabilities in Tool-Integrated LLM Agents")

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

export function toolResourceUrn(tool: string): string {
  return `${MCP_RESOURCE_PREFIX}${tool}`;
}

/**
 * Authorization: Bearer <jwt> ヘッダーを検証して MCP コンテキストを返す。
 *
 * Deny-by-default: token なし / 検証失敗 / 期限切れ / issuer ミスマッチ /
 * 末尾スラッシュ問題 等で **すべて null を返す**。呼び出し側は `if (!ctx)` で
 * 即座に 401 応答すること。
 *
 * 本 commit (Win版#132 part 49) 時点では env `MCP_AUTH_BYPASS=1` なら synthetic
 * context を返す developer-only stub。本実装は後続:
 *   1. WORKOS_JWKS_URL から JWKS を fetch + cache
 *   2. JWT signature 検証 (RS256)
 *   3. iss を WORKOS_ISSUER (末尾スラッシュ両許容) と比較
 *   4. aud / scope / sub claim を抽出して McpAuthContext に詰める
 *   5. exp / nbf を現在時刻と比較
 *   6. mcp_oauth_clients.suspended=true なら拒否
 *
 * @returns null = 401 / それ以外 = {client_id, scopes, aud, subject}
 */
// deno-lint-ignore require-await -- skeleton state; JWT verify (await) wired in part 50+
export async function validateBearer(req: Request): Promise<McpAuthContext | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return null;
  const token = auth.slice("Bearer ".length).trim();
  if (!token) return null;

  // Developer bypass — 本番環境では Supabase Secrets に MCP_AUTH_BYPASS を
  // 設定しないこと (production safety)
  if (Deno.env.get("MCP_AUTH_BYPASS") === "1" && Deno.env.get("MCP_DEV_MODE") === "1") {
    return {
      client_id: "dev-bypass",
      scopes: ["all"],
      aud: [`${MCP_RESOURCE_PREFIX}*`],
    };
  }

  // TODO (Win版#132 part 50+): WorkOS JWKS による JWT 検証本体を実装。
  // 現段階では deny-by-default 厳守 = 検証経路が無いので拒否。
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

  const audAllows =
    ctx.aud.includes(targetUrn) || ctx.aud.includes(wildcardUrn);
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
// deno-lint-ignore require-await -- skeleton state; supabase INSERT (await) wired in part 50+
export async function logMcpInvocation(
  ctx: McpAuthContext | null,
  toolName: string,
  requestArgs: unknown,
  responseStatus: number,
  req: Request,
): Promise<void> {
  const ip = req.headers.get("x-forwarded-for") ?? req.headers.get("cf-connecting-ip") ?? "";
  // TODO (Win版#132 part 50+): supabase service role で
  // INSERT INTO mcp_audit_log (client_id, tool_name, request_args, response_status,
  //                            request_ip, invoked_at)
  // VALUES ($1, $2, $3, $4, $5, now());
  console.log("[mcp-audit]", JSON.stringify({
    client_id: ctx?.client_id ?? "anonymous",
    tool_name: toolName,
    response_status: responseStatus,
    ip: ip.split(",")[0]?.trim() || null,
    args_preview: typeof requestArgs === "string"
      ? requestArgs.slice(0, 200)
      : JSON.stringify(requestArgs).slice(0, 200),
  }));
}
