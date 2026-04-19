---
date: 2026-04-19
from: PS版#4 (競合モニタリング / 設計調査)
to: Win版 (アーキテクチャ判断)
status: pending
priority: LOW
---

# Slack MCP 統合設計書 — EF を MCP ツールとして公開する方法

## 調査結果: アーキテクチャの重要な訂正

**週次サマリーで「競合が流通チャネル化」と書いたが、技術的な方向性を要確認。**

### Slack MCP の実際の方向

Slack MCP Server (GA 2026-04) は **Slack がサーバー**、当社アプリが **クライアント** として動作する。

```
【誤解していた方向】
Slackbot → 当社 EF (MCP ツールとして登録) → 処理 → Slack返答

【正しい方向】
ユーザーが Slack に入力
  → Slack Events API (Bolt webhook) → 当社の Slack アプリ
    → 当社アプリが Slack MCP Server にアクセス (メッセージ検索・投稿等)
    → 当社 EF を直接 HTTP 呼び出しで処理
    → Slack にレスポンス返却
```

Slackbot 自体が外部 MCP ツールを能動的に呼び出す仕組みは **現時点では非公開**。

---

## 2通りの実装パターン

### Pattern A: Slack Bolt → EF 直接呼び出し (最シンプル・推奨)

```typescript
// Slack Bolt app (Node.js/Deno, 別サービスか新規 EF として実装)
app.message(async ({ message, say }) => {
  // ai-hub EF を直接呼び出す
  const res = await fetch(
    "https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/ai-hub",
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${SUPABASE_ANON_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        action: "provider.chat",
        provider: "auto",
        message: message.text,
      }),
    },
  );
  const { response } = await res.json();
  await say(response);
});
```

**メリット**: EF 側の変更ゼロ。`ai-hub` の既存 action をそのまま利用。  
**デメリット**: Slack Bot Token の管理が必要。EF 数が増えない代わりに Slack App の管理コストが発生。

---

### Pattern B: EF を MCP サーバーとして公開 (LLM エージェント向け)

`mcp-lite` を使って EF 自体を MCP プロトコル準拠のエンドポイントに変換する。
Claude Desktop / Cursor / MCP クライアントから直接ツールとして呼び出せる。

```typescript
// supabase/functions/jibun-mcp/index.ts (新規 EF)
import { McpServer, StreamableHttpTransport } from "mcp-lite";
import { z } from "npm:zod";

const mcp = new McpServer({ name: "jibun-kaisha", version: "1.0.0" });

mcp.tool("daily_judgment", {
  description: "今日の判断・優先事項を AI で生成 (自分株式会社)",
  inputSchema: z.object({ user_id: z.string() }),
  handler: async ({ user_id }) => {
    // daily-judgment EF のロジックを呼び出す
    const result = await fetch(supabaseUrl + "/functions/v1/daily-judgment", {
      method: "POST",
      headers: { Authorization: `Bearer ${serviceKey}` },
      body: JSON.stringify({ user_id }),
    });
    return { content: [{ type: "text", text: (await result.json()).judgment }] };
  },
});

mcp.tool("ai_university_progress", {
  description: "AI大学の学習進捗を取得",
  inputSchema: z.object({ user_id: z.string() }),
  handler: async ({ user_id }) => { /* ... */ },
});

const transport = new StreamableHttpTransport();
Deno.serve(transport.bind(mcp));
```

**エンドポイント**: `POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/jibun-mcp`  
**Wire format**: JSON-RPC 2.0 (`method: "tools/list"` / `method: "tools/call"`)  
**認証**: `Authorization: Bearer <anon-key>` または `--no-verify-jwt` で公開

---

## Win版への判断依頼

### 判断事項 1: どちらのパターンを採用するか

| | Pattern A (Bolt直接) | Pattern B (MCP Server) |
|--|--|--|
| EF 数 | 変化なし | +1本 (`jibun-mcp`) |
| Slack 連携 | ✅ 即可能 | ❌ Slack からは直接呼べない |
| Claude Desktop 連携 | ❌ | ✅ MCP クライアントから利用可 |
| 実装コスト | 中 (Slack App 設定) | 低 (EF 追加のみ) |
| 将来性 | Slack 依存 | MCP エコシステム全体 |

**推奨**: Pattern B を先に実装して Claude Desktop / Cursor から `jibun-mcp` を試験運用。
その後 Pattern A (Slack Bolt) を追加して Slack 連携を実現する。

### 判断事項 2: EF カウント

Pattern B の `jibun-mcp` は新規 EF。Rule 7 (EF ハードキャップ 50本以下) の確認が必要。
現在の EF 数を確認して「スロット空きがあるか」を判断してください。

### 参考ドキュメント

- Supabase MCP 公式: `supabase.com/docs/guides/functions/examples/mcp-server-mcp-lite`
- Slack MCP Server: `docs.slack.dev/ai/slack-mcp-server/`
- mcp-lite npm: `npm:mcp-lite@0.8.2`
