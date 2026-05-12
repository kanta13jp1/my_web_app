# Cross-Instance PR: mcp_auth_guard の WorkOS JWKS fetch + cache 配線

**作成**: Win版#132 part 54 / 2026-04-28
**依頼先**: **Codex#1 or Codex#2** (どちらでも可 / Win版が判断委譲)
**優先度**: HIGH (MCP server 公開の prerequisite)
**推定工数**: 60-90 min / 2-3 file 編集

---

## 判定 5 質問の答え

| Q | 答え |
| --- | --- |
| Q1. 設計判断 / trade-off 検討必要? | **NO** (jose lib 採用は本 PR で固定) |
| Q2. cross-instance 調整必要? | **NO** (Win版 part 49 skeleton への中身配線) |
| Q3. 軸 docs 更新必要? | **NO** (実装のみ / docs/MCP_AUTH_SECURITY_PRINCIPLES.md は既存) |
| Q4. docs に残す価値ある判断? | **NO** (= 標準 OAuth 2.1 ライブラリ呼び出し) |
| Q5. NotebookLM 連携要? | **NO** (実装後 Win版が結果を memory に記録) |

→ **全 NO = Codex 適合** (docs/CODEX_WORKFLOW.md §6 routing matrix 適用)

**routing 補足**: SQL 寄りなら Codex#1 / TypeScript 実装比重が高いため Codex#2 推奨 (= EF Deno 専任)。

---

## 起票背景

Win版#132 part 49 (commit 26eb79e1) で `supabase/functions/_shared/mcp_auth_guard.ts`
を skeleton として確立。`validateBearer()` の docstring 内に以下 6 項目を明記済:

> TODO (Win版#132 part 50+): WorkOS JWKS による JWT 検証本体を実装。
> 1. WORKOS_JWKS_URL から JWKS を fetch + cache
> 2. JWT signature 検証 (RS256)
> 3. iss を WORKOS_ISSUER (末尾スラッシュ両許容) と比較
> 4. aud / scope / sub claim を抽出して McpAuthContext に詰める
> 5. exp / nbf を現在時刻と比較
> 6. mcp_oauth_clients.suspended=true なら拒否

これらは全部 **mechanical な OAuth 2.1 + JWKS 標準実装** = jose ライブラリの呼び出し
パターンに従うだけ。設計判断不要 = Codex 適合。

## 既存 pattern (= Codex が複製する template)

### 参考 1: 採用ライブラリ
**[jose](https://deno.land/x/jose)** (Deno 公式 import map で使える / WorkOS docs 推奨):
```typescript
import { createRemoteJWKSet, jwtVerify } from "https://deno.land/x/jose@v5.x/index.ts";
```

### 参考 2: WorkOS JWKS endpoint
- 環境変数: `WORKOS_JWKS_URL` (例: `https://api.workos.com/sso/jwks/<client_id>`)
- 環境変数: `WORKOS_ISSUER` (例: `https://api.workos.com`)
- Supabase Secrets に追加要 (User 操作 / 別 cross-instance-pr で WorkOS 契約後)

### 参考 3: 末尾スラッシュ問題対応 (part 43 caveat)
```typescript
const ISSUERS = [
  Deno.env.get("WORKOS_ISSUER") ?? "",
  (Deno.env.get("WORKOS_ISSUER") ?? "").replace(/\/$/, ""),  // 末尾なし
  (Deno.env.get("WORKOS_ISSUER") ?? "") + (
    (Deno.env.get("WORKOS_ISSUER") ?? "").endsWith("/") ? "" : "/"
  ),  // 末尾あり
].filter(Boolean);
```
issuer 検証時は ISSUERS 配列の **いずれか一致で OK** とする。

### 参考 4: mcp_oauth_clients suspended check
Win版 part 49 で migration `20260428073000_create_mcp_oauth_clients.sql` 作成済。
admin (service_role) で SELECT して suspended=true なら null 返却。

## 期待アウトプット

`supabase/functions/_shared/mcp_auth_guard.ts` の `validateBearer` 関数本体を
完全実装 (TODO 6 項目すべて消化):

```typescript
// 既存 import の隣に追加
import { createRemoteJWKSet, jwtVerify } from "https://deno.land/x/jose@v5.x/index.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// module-level cache
let jwksCache: ReturnType<typeof createRemoteJWKSet> | null = null;
let jwksCacheUrl = "";

function getJwks() {
  const url = Deno.env.get("WORKOS_JWKS_URL") ?? "";
  if (!url) return null;
  if (!jwksCache || jwksCacheUrl !== url) {
    jwksCache = createRemoteJWKSet(new URL(url));
    jwksCacheUrl = url;
  }
  return jwksCache;
}

function getIssuersWithSlashTolerance(): string[] {
  const raw = Deno.env.get("WORKOS_ISSUER") ?? "";
  if (!raw) return [];
  const trimmed = raw.replace(/\/$/, "");
  const slashed = trimmed + "/";
  return [trimmed, slashed];
}

// validateBearer 本体実装
export async function validateBearer(req: Request): Promise<McpAuthContext | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return null;
  const token = auth.slice("Bearer ".length).trim();
  if (!token) return null;

  // dev bypass (既存)
  if (Deno.env.get("MCP_AUTH_BYPASS") === "1" && Deno.env.get("MCP_DEV_MODE") === "1") {
    return { client_id: "dev-bypass", scopes: ["all"], aud: [`${MCP_RESOURCE_PREFIX}*`] };
  }

  const jwks = getJwks();
  if (!jwks) return null;
  const issuers = getIssuersWithSlashTolerance();
  if (issuers.length === 0) return null;

  try {
    // jwtVerify は issuer 配列を直接受けないので 1 つずつ試行
    for (const iss of issuers) {
      try {
        const { payload } = await jwtVerify(token, jwks, {
          issuer: iss,
          algorithms: ["RS256"],
        });
        // suspended check
        const clientId = String(payload.client_id ?? payload.sub ?? "");
        if (clientId) {
          const admin = createClient(
            Deno.env.get("SUPABASE_URL") ?? "",
            Deno.env.get("SERVICE_ROLE_KEY") ?? "",
          );
          const { data } = await admin
            .from("mcp_oauth_clients")
            .select("suspended")
            .eq("client_id", clientId)
            .maybeSingle();
          if (data?.suspended) return null;
        }
        const aud = Array.isArray(payload.aud) ? payload.aud as string[] : [String(payload.aud ?? "")];
        const scopes = String(payload.scope ?? "").split(/\s+/).filter(Boolean);
        return {
          client_id: clientId,
          scopes,
          aud: aud.filter((a) => a),
          subject: payload.sub ? String(payload.sub) : undefined,
        };
      } catch {
        // 次の issuer 候補で再試行
      }
    }
    return null;
  } catch {
    return null;
  }
}
```

## 完了条件

- [ ] `supabase/functions/_shared/mcp_auth_guard.ts` 上記実装で更新
  - 既存 deno-lint-ignore は削除可 (await が入るので)
- [ ] `deno lint --config supabase/functions/deno.json supabase/functions/_shared/mcp_auth_guard.ts` pass
- [ ] `deno check supabase/functions/_shared/mcp_auth_guard.ts` pass (TypeScript)
- [ ] git commit + push origin HEAD:main
- [ ] 起票者 (Win版) が memory に記録 + MCP_AUTH score 2/10 → 5/10 update

## 想定 Codex から Claude への質問事項 (= 設計判断疑義)

以下の点で判断ミスを Codex が起こしそうな箇所:

1. **`Authorization: Bearer` 抽出後の token 形式** — JWT (3 dot 区切り) を仮定するが
   opaque token も来る可能性 → **本実装は JWT のみサポート / opaque は別 part**
2. **scope claim の format** — WorkOS は space-separated string で来る (RFC 6749) →
   `split(/\s+/).filter(Boolean)` で OK
3. **JWKS cache 期限** — jose の createRemoteJWKSet はデフォルト 10 min cache → そのまま採用

これらは Codex が判断不能なら docs/CODEX_WORKFLOW.md §6 振り分け失敗時の救済 (= Win版に reroute) に該当.

## OPERATIONS_CHARTER 整合

- 改善トリガー #1 (衝突しそうな割り振り) なし — Codex 1 件 / Claude 干渉なし
- 5 正本層 #5 (worktree/main) — Codex 完了後 Win版が memory に記録して 5 正本層 #3 (NotebookLM) に蒸留検討

---

*Win版#132 part 54 / 2026-04-28 起票 / Codex routing matrix 初回適用 (3/3 件目)*
