---
date: 2026-04-20
from: PS版#4 (競合モニタリング / Rule 11 モデルアップグレード追跡)
to: Win版 (ai-hub アーキテクチャ管理)
status: pending
priority: MEDIUM
deadline: 2026-05-15
---

# Amazon Nova 2 Lite 統合依頼 — 1M context 専用ルート追加

## 背景

Amazon が 2026-04 に Nova 2 Lite リリース。**1M context token** をサポートするモデルの中で価格最安水準。長文ドキュメント要約・大量ログ解析など、Claude Opus 4.7 が過剰な場面に最適。

## Nova 2 Lite スペック

| 項目 | 値 |
|------|----|
| モデル ID | `amazon.nova-2-lite-v1:0` (Bedrock) |
| input | $0.30 / 1M tokens |
| output | $2.50 / 1M tokens |
| context | 1,048,576 tokens (1M) |
| built-in | code interpreter + web grounding + remote MCP |
| 提供 | AWS Bedrock (ap-northeast-1 対応予定) |

## 競合モデル比較

| モデル | input | output | context | 用途 |
|-------|-------|--------|---------|------|
| **Gemini 3.1 Flash-Lite** | $0.25 | $1.50 | 1M | バッチ処理 (最安) |
| **Nova 2 Lite** | $0.30 | $2.50 | 1M | AWS 統合 + tool use |
| Claude Haiku 4.5 | ~$0.25 | ~$1.25 | 200K | 汎用高速 |
| Claude Opus 4.7 | $15 | $75 | 200K | 高品質推論 |

**結論**: 1M context が必要で tool use (MCP) 重視なら Nova 2 Lite。
単純バッチなら Gemini 3.1 Flash-Lite が最安。

## 依頼内容

### 1. `ai-hub` に `provider.chat_long_context` action 追加

現状 `provider.chat_auto` は短文向け 4-Tier routing。1M context 必要ケースは別ルートにする:

```typescript
// ai-hub/actions/chat_long_context.ts (新規)
export async function chatLongContext(input: ChatInput): Promise<ChatOutput> {
  // routing:
  // - < 200K tokens → Claude Haiku 4.5
  // - 200K - 1M tokens + tool use → Nova 2 Lite
  // - 200K - 1M tokens + pure text → Gemini 3.1 Flash-Lite
  // - > 1M tokens → エラーで chunking 促す
}
```

### 2. `PROVIDER_CONFIGS` に amazon 追加

`supabase/functions/ai-hub/providers.ts` (または該当ファイル):

```typescript
amazon: {
  baseUrl: 'https://bedrock-runtime.ap-northeast-1.amazonaws.com',
  authMethod: 'aws_sigv4',  // AWS SigV4 署名必要
  defaultModel: 'amazon.nova-2-lite-v1:0',
  models: {
    'nova-2-lite': { input: 0.30, output: 2.50, context: 1_048_576 },
    'nova-2-pro': { input: 0.80, output: 3.20, context: 300_000 },
    'nova-act': { input: 0.50, output: 2.00, context: 128_000, capabilities: ['browser'] },
  },
}
```

### 3. Supabase Secrets に AWS 認証情報追加

```bash
supabase secrets set \
  AWS_ACCESS_KEY_ID=... \
  AWS_SECRET_ACCESS_KEY=... \
  AWS_BEDROCK_REGION=ap-northeast-1
```

### 4. テスト用 EF action

```bash
curl -X POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/ai-hub \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -d '{
    "action": "provider.chat_long_context",
    "input": "<800K token document>",
    "query": "要約してください"
  }'
```

---

## PHILOSOPHY + AI-DEV 原則チェック

**Rule 22 (PHILOSOPHY 9 原則)**:
- 原則 1 (CEO 感): ✅ ユーザーがモデル選択可能
- 原則 6 (資本=時間): ✅ 1M context で長文分割の手間削減
- 原則 4 (6 部署): ✅ 実装方法の問題 (新機能ではない)
→ 3/9 (機能ではなくインフラ改善なので 9 原則の全適用対象外)

**Rule 23 (AI-DEV 7 原則)**:
- Auth: ✅ AWS SigV4 署名ベース
- Deny-default: ✅ 既存 ai-hub の auth 継承
- Observability: ✅ trace_id 継承
- Circuit breaker: ✅ 既存 cost guard 継承
- Memory: — 該当せず
- Checkpoint/Retry: ✅ 既存 retry 継承
- Quality gate: ✅ 既存 sentinel 継承
→ 6/7 実装可

## 参考

- AWS Nova: https://aws.amazon.com/nova/models/
- Nova Act: https://nova.amazon.com/
- Galaxy.ai ベンチマーク: https://blog.galaxy.ai/model/nova-2-lite-v1

---

## 優先度

🟡 **MEDIUM** — 必須ではないが、1M context 用途 (長文要約・競合モニタリングの全文分析) で Gemini + Nova の使い分けができると Rule 11 のコスト最適化が進む。

生成: PS版#4 | 2026-04-20
