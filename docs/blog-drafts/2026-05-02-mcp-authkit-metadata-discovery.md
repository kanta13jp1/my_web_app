---
title: "MCP サーバーが OAuth Protected Resource Metadata を返すべき理由 — AuthKit と RFC 9728"
emoji: "🔐"
type: "tech"
topics: ["mcp", "oauth", "workos", "supabase", "deno"]
published: true
---

## なぜ MCP サーバーに `.well-known/oauth-protected-resource` が要るのか

自分株式会社では Supabase Edge Function を MCP (Model Context Protocol) サーバーとして公開している。クライアントは Claude / Codex / Cursor / VS Code Continue / 自前ブラウザ拡張など多岐にわたる。これらが「どの認可サーバーで token を取れば良いのか」を自律的に発見できないと、新しい client が増えるたびに「ベアラー token は WorkOS AuthKit から / scope は `tool:ai_chat` 形式 / audience は `urn:jibun:tool:<tool>` を含めて」と運用ドキュメントを配り回るハメになる。

これを避けるための仕様が **RFC 9728 (OAuth 2.0 Protected Resource Metadata)** で、要は「保護リソースが `/.well-known/oauth-protected-resource` を返せば、client はそれを見て authorization_servers と scopes を学習できる」というものだ。MCP の最新ドラフトもこの discovery を前提に組み立てられている。

このエントリは、自分株式会社の Edge Function に protected resource metadata を実装した際の設計メモ。コードは [`supabase/functions/_shared/mcp_auth_guard.ts`](https://github.com/kanta13jp1/my_web_app/blob/main/supabase/functions/_shared/mcp_auth_guard.ts) にある。

## 設計の前提

- **AuthKit (WorkOS)** が ID プロバイダ。WorkOS が JWKS / issuer / SSO 画面を提供。
- **Edge Function (Deno on Supabase)** が保護リソース。1 EF = 複数 MCP tool を載せる「ハブ」構成。
- **Bearer JWT 検証**: `jose` の `jwtVerify` で署名・有効期限・issuer を確認、audience は `urn:jibun:tool:<tool>` resource indicator (RFC 8707) で別軸検証。
- **scope の形**: `all` (super-admin) / `tool:<name>` / `<name>` の 3 種を許容。client SDK の癖に合わせて緩めにパース。

## metadata エンドポイントの形

`isOAuthProtectedResourceMetadataRequest(req)` が `/.well-known/oauth-protected-resource` で終わる pathname を判定し、`buildOAuthProtectedResourceMetadata` が JSON を組み立てる。

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

ポイントを 4 つに絞る。

### 1. `resource` は client 側から見た外向き URL

Supabase の Edge Function は `https://<project>.functions.supabase.co/ai-hub` のような URL で公開されるが、CDN や独自ドメインを挟む場合に変わる。`MCP_RESOURCE_URL` を環境変数で先に許し、なければリクエストの `req.url` から `.well-known` 部分を切り落として算出する。

audience claim と一致させる必要があるので、ここを誤ると「token は valid なのに resource indicator の照合で落ちる」という最も診断しにくい失敗が出る。

### 2. `authorization_servers` は AuthKit URL を最優先

`WORKOS_AUTHKIT_URL` (UI flow を集約する short URL) を最初に並べ、その後ろに `WORKOS_ISSUER` (JWT の `iss`) を続ける。理由は、AuthKit URL は client が「ログイン UI を開く先」として、issuer は「トークンの署名者」として使うためで、両方ないと自前 client では完結しない。

### 3. `audience_checked_by_jwt_verify: false` は事故防止

WorkOS のデフォルト JWT は audience claim を埋めない。`jose.jwtVerify` の `audience` オプションを安易に有効化すると、全 token が拒否される地獄が始まる。代わりに RFC 8707 の `resource` indicator で audience をリクエスト時に明示し、サーバ側で `urn:jibun:tool:<tool>` を含むかをチェックする方針を取った。この事実を metadata に書いておくと、client 実装者が「audience が空なのは正常」と判断できる。

### 4. `issuer_trailing_slash_tolerant: true` は経験則

`https://api.workos.com/user_management/<id>` と `https://api.workos.com/user_management/<id>/` が両方流通する。`getWorkOsIssuers()` で trailing slash を 3 通り許容しているのと整合させるためのフラグ。client 側の SDK でも明示的に rstrip するかどうか分かれるので、metadata で「ゆるい」ことを宣言するのは安全側。

## 401 challenge との連動

仕様上もう 1 つ重要なのは、保護リソースが 401 を返すときに `WWW-Authenticate` ヘッダで metadata の URL を指し示すこと。これにより、metadata の存在を知らない client でも、最初の 401 をきっかけに discovery loop に入れる。実装は `mcp_auth_guard` の challenge 構築に組み込んだ。

```text
WWW-Authenticate: Bearer realm="urn:jibun:tool:ai_chat",
  resource_metadata="https://<host>/ai-hub/.well-known/oauth-protected-resource"
```

実体は `protectedResourceUrl(reqUrl)` で組むので、CDN 配下でも client は正しい場所を見にいける。

## scope と server-side gate のペア

discovery は半分でしかなく、もう半分は「`all` scope を勝手に与えない」サーバ側ゲート。同じ PR で入った `agent_tool_policy_server_gate.sql` が、エージェントロール × tool の許諾マトリクスを DB に持たせて、JWT の scope が DB の許諾より広いケースを 403 で弾く。

「メタデータで宣言した scope は本当にその scope しか使えない」を担保するのは、結局は server 側のチェックである。client が学習できるのはあくまで「scope の存在」であって「権限の境界」ではない。

## 学んだこと

1. **metadata は I/O 契約だ。** 一度公開したら client が依存するので、フィールド名と意味は最初に固める。`token_validation` のような独自拡張は名前空間を切ってもよかった。
2. **trailing slash と audience の罠は実装より運用で焼かれる。** docs に「こうチェックしている」を書ききれていなかった頃は、新規 client 接続のたびに 1 時間溶けた。metadata に書いてからは新規接続が 5 分で済む。
3. **discovery の代償は「嘘をつかない責任」。** metadata が宣言した authorization_servers / scopes と、実 server の挙動が乖離するとデバッグ不可能になる。CI で metadata と code を両方読むスナップショットテストを足す価値がある。

## 参考

- RFC 9728 — OAuth 2.0 Protected Resource Metadata
- RFC 8707 — Resource Indicators for OAuth 2.0
- MCP Authorization (latest draft)
- WorkOS AuthKit — JWKS / issuer 仕様
- 自分株式会社 [`docs/MCP_AUTH_SECURITY_PRINCIPLES.md`](https://github.com/kanta13jp1/my_web_app/blob/main/docs/MCP_AUTH_SECURITY_PRINCIPLES.md) Rule 27
