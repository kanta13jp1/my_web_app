---
title: "AI エージェントの tool 実行を deny-by-default で止める — サーバー側 scope gate と CEO approval の設計"
emoji: "🛡️"
type: "tech"
topics: ["mcp", "supabase", "deno", "ai-agent", "security"]
published: true
---

## クライアント側 guard だけでは止まらない

自分株式会社では、6 部署 (CEO / CFO / CMO / CHO / CHRO / Legal) を模した AI エージェントが Edge Function 経由で各種 tool (notion.write / slack.send / payment.purchase / mail.external_share …) を呼ぶ。

最初は Flutter 側の `AgentOrg` クラスで「このロールはこの scope しか呼べません」という guard を持っていた。けれど、これは典型的な **client-trust 設計** で、

- 別 client (curl / Codex / Cursor) から直接 EF を叩かれると素通り
- 監査ログがクライアント分散で集まらない
- 「approval された / されてない」状態をサーバー側 DB と突き合わせられない

という穴が空いていた。Rule 27 (`MCP_AUTH_SECURITY_PRINCIPLES.md`) の **#5 Scope (least privilege)** と **#7 Audit (centralized)** を満たすには、サーバー側に **deny-by-default の scope gate** を置かないと話にならない。

このエントリは、自分株式会社の `ai-hub` Edge Function に `agent.tool_policy.evaluate` action と `agent.run` の事前 fail-close gate を追加した時の設計メモ。前回の [MCP AuthKit metadata の話](./2026-05-02-mcp-authkit-metadata-discovery.md) と対構造をなしている (metadata = 契約の宣言 / policy gate = 契約の強制)。

## 9 種類の scope と「高リスク 5 種」

`supabase/functions/_shared/agent_tool_policy.ts` で全 scope を列挙してある:

```ts
export const AGENT_TOOL_SCOPES = [
  "read",
  "suggest",
  "create",
  "update",
  "delete",
  "send",
  "purchase",
  "discount",
  "external_share",
] as const;

export const HIGH_RISK_AGENT_TOOL_SCOPES: readonly AgentToolScope[] = [
  "delete",
  "send",
  "purchase",
  "discount",
  "external_share",
];
```

設計の勘所はこの 2 段階分類:

1. **scope 一覧そのものを enum 化** — 文字列が散らばっていると新規 EF が勝手に独自 scope を作って fleet 全体の least-privilege が破綻する。enum で「承認された scope の母集合」を 1 ファイルに固定。
2. **高リスク 5 種を別配列で定義** — destructive (`delete`) / 外向き通信 (`send`) / 課金 (`purchase` / `discount`) / 第三者共有 (`external_share`) は `requiresApproval` フラグを自動で立て、CEO 承認なしでは流さない。

この 2 段の意図は、「low-risk な `read` / `suggest` / `create` までは fleet 全体で気軽に通す。代わりに金銭・破壊・外部公開に触れる scope は別軸で承認 workflow を回す」という運用判断を、コードレベルで強制したいから。

## 役割ごとのデフォルト scope

scope を一覧化したら、次は「ロールごとに何を許すか」のテーブル。

```ts
export const DEFAULT_AGENT_ROLE_SCOPES: Readonly<
  Record<string, readonly AgentToolScope[]>
> = {
  ceo: AGENT_TOOL_SCOPES,                                  // 全部
  cfo: ["read", "suggest", "create", "update"],            // お金は触れるが purchase/discount は禁止
  cmo: ["read", "suggest", "create", "external_share"],    // SNS 投稿の external_share だけ高リスクを許す
  cho: ["read", "suggest", "create"],                      // 健康関連は低リスクのみ
  chro: ["read", "suggest", "create", "update"],
  legal: ["read", "suggest", "create", "update"],
};
```

ポイントは 2 つ:

- **CMO だけ `external_share` を許す** — 「マーケ部署は SNS への外部投稿が業務」という業務知識を scope 設計に埋め込む。CFO に同じ scope を渡すと「請求書を勝手にツイートする AI」が爆誕する。
- **未登録ロール / null は `["read", "suggest"]` にフォールバック** — `getDefaultAgentRoleScopes` で「知らないロール」は最小権限にする。tenant が独自ロール (`engineer` / `intern` 等) を作っても、明示テーブルに無ければ提案しかできない。

## fail-close 評価ロジック

判定本体はこの形:

```ts
let blockedReason: string | null = null;
if (requestedScopes.length === 0) {
  blockedReason = "empty_requested_scope";
} else if (missingScopes.length > 0) {
  blockedReason = "missing_scope";
} else if (requiresApproval && !hasApproval) {
  blockedReason = "approval_required";
}

return {
  allowed: blockedReason === null,
  ...
};
```

3 つの拒否理由を分けてあるのは、UX 文言と再試行戦略が違うから:

| `blockedReason` | クライアントが取るべき行動 |
| --- | --- |
| `empty_requested_scope` | 呼び出し側のバグ。scope 配列を入れ忘れている。client SDK 側で 400 として握り潰さず、ログに出して開発者に知らせる |
| `missing_scope` | ロールが弱すぎる。承認 workflow ではなく **権限昇格申請** の問題 |
| `approval_required` | scope は持っている。CEO に approval modal を出して `approval.decision = "approved"` を取りに行く |

「全部 403 で返す」だと client は何が悪いか分からず、ユーザーには「AI が壊れた」と見える。理由を分けることで、UX 側で適切な復旧導線を出せる。

`hasApproval` はこの 3 条件 AND:

```ts
const hasApproval = input.approval?.decision === "approved" &&
  Boolean(input.approval.approvedBy?.trim()) &&
  Boolean(input.approval.approvedAt?.trim());
```

`approved` だけ立っていて承認者・時刻が空、というケースはアプリ側のバグで来る。null 安全に倒して fail-close。

## EF endpoint への組み込み: 2 つの形

`ai-hub` には 2 つの呼び方がある。

### 1. `agent.tool_policy.evaluate` — dry-run

```ts
case "agent.tool_policy.evaluate": {
  const gate = await evaluateAgentToolGate(admin, userId!, body);
  return json({
    success: gate.decision.allowed,
    decision: publicPolicyDecision(gate.decision),
    actor_role: gate.actorRole,
    requested_scopes: gate.requestedScopes,
    allowed_scopes: gate.allowedScopes,
    approval: gate.approval,
    audit_logged: gate.auditLogged,
  }, gate.decision.allowed ? 200 : 403);
}
```

UI 側で「ボタンを押す前に、この AI 操作は許されるか?」を問い合わせる用。これがあれば、disabled なボタン + tooltip で理由を見せられる。

### 2. `agent.run` — 実行直前の fail-close

```ts
case "agent.run": {
  const gate = shouldEvaluateToolPolicy
    ? await evaluateAgentToolGate(admin, userId!, body)
    : null;
  if (gate && !gate.decision.allowed) {
    return json({
      success: false,
      error: "agent_tool_policy_denied",
      decision: publicPolicyDecision(gate.decision),
      audit_logged: gate.auditLogged,
    }, 403);
  }
  // ... agent_run_log INSERT (queued)
}
```

実行 queue に積む直前で gate を通す。`shouldEvaluateToolPolicy` で「scope を渡してきた呼び出しのみ評価する」動作にしてあるのは、レガシーな単純チャット呼び出しまで gate を強制すると下位互換が壊れるから。**新規 tool 呼び出しは scope 必須 / 旧 chat-only path は素通し** という移行戦略。

## 監査列を `agent_tool_execution_logs` に追加

migration `20260501210000_agent_tool_policy_server_gate.sql` で監査列を追加した:

```sql
ALTER TABLE public.agent_tool_execution_logs
  ADD COLUMN IF NOT EXISTS actor_role text,
  ADD COLUMN IF NOT EXISTS requested_scopes text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS allowed_scopes text[],
  ADD COLUMN IF NOT EXISTS high_risk_scopes text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS requires_approval boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS approval_decision text,
  ADD COLUMN IF NOT EXISTS approved_by text,
  ADD COLUMN IF NOT EXISTS approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS side_effects text,
  ADD COLUMN IF NOT EXISTS evaluated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_agent_tool_execution_logs_high_risk
  ON public.agent_tool_execution_logs(user_id, created_at DESC)
  WHERE requires_approval = true;
```

ここで効いているのが **partial index** (`WHERE requires_approval = true`)。低リスクな `read` / `suggest` の log が圧倒的多数を占めるので、全部に index を張ると無駄が大きい。「approval が必要だった呼び出しだけ」を高速に引きたい監査ユースケース (CEO ダッシュボード「今週承認待ちの request 一覧」) に最適化してある。

`requested_scopes` を `NOT NULL DEFAULT '{}'` にしてあるのも意図的で、null と空配列を混在させると後段の集計 SQL が歪む。空配列に正規化することで「scope 指定なしで来た不正リクエスト」も `array_length = 0` で集計できる。

## metadata と gate の対構造

| 層 | 責務 | 仕様 |
| --- | --- | --- |
| MCP AuthKit metadata (`/.well-known/oauth-protected-resource`) | client に「使える scope」を**宣言**する | RFC 9728 |
| agent_tool_policy gate | client が宣言された scope を**実際に持っているか強制**する | 自分株式会社内の Rule 27 #5 |

メタデータは **契約**、gate は **強制**。片方だけだと片手落ちで、

- metadata 無し / gate あり → client は scope を学習できない
- metadata あり / gate 無し → client が嘘の scope を申告し放題

両方揃って初めて「fleet で client を増やしても least-privilege が崩れない」体制になる。

## 実装後に気づいた落とし穴

- **`allowedScopes` に `"all"` をフィルタしない** — 当初 `normalizeAgentToolScopes` で `"all"` を弾いてしまっていて、CEO ロールが何も呼べなくなった。`"all"` を含む場合だけ全 scope に展開する分岐を別建てした。
- **`approval` の null 化** — 旧 client が `approval: {}` を送ってくる。`decision` が undefined → `hasApproval = false` で fail-close されるので結果オーライだが、ログ上は「approval 渡したのに弾かれた」に見える。client SDK 側で空 approval は送らないよう修正。
- **`shouldEvaluateToolPolicy` 判定の取り漏れ** — `body.scopes` (snake_case 短縮形) を最初忘れていて、Codex 経由の呼び出しが gate されずに素通りした。client SDK ごとの命名揺れ (`tool_name` / `toolName` / `scopes` / `requested_scopes` / `requestedScopes`) を全部認識する必要がある。

## まとめ

- AI エージェントの tool 実行は **サーバー側の deny-by-default gate** を必ず通す。client guard は補助。
- scope は **enum 化 + 高リスク 5 種を別配列**。役割ごとのデフォルト scope テーブルで「業務知識をコードに埋め込む」。
- 拒否理由は `empty_requested_scope` / `missing_scope` / `approval_required` の 3 種に分け、UX 側で復旧導線を分岐させる。
- 監査列は `requires_approval = true` の partial index で「承認待ち」だけ高速 lookup。
- MCP AuthKit metadata と policy gate は **宣言と強制** の対構造。両方揃って初めて fleet で意味を持つ。

次は同じ scope 配列を [`mcp_my_web_app_tools`](https://github.com/kanta13jp1/my_web_app/blob/main/supabase/functions/_shared/mcp_my_web_app_tools.ts) facade 側でも参照させ、MCP server discovery 経由で client が学習する scope と server-side gate の scope を **同一 source of truth** に統一する予定。

## 参考

- [`supabase/functions/_shared/agent_tool_policy.ts`](https://github.com/kanta13jp1/my_web_app/blob/main/supabase/functions/_shared/agent_tool_policy.ts)
- [`supabase/functions/ai-hub/index.ts`](https://github.com/kanta13jp1/my_web_app/blob/main/supabase/functions/ai-hub/index.ts) (`agent.tool_policy.evaluate` / `agent.run`)
- [`supabase/migrations/20260501210000_agent_tool_policy_server_gate.sql`](https://github.com/kanta13jp1/my_web_app/blob/main/supabase/migrations/20260501210000_agent_tool_policy_server_gate.sql)
- [前編: MCP AuthKit metadata と RFC 9728](./2026-05-02-mcp-authkit-metadata-discovery.md)
