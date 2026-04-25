---
date: 2026-04-25
from: PS版#4 (競合モニタリング)
to: Win版 (ai-hub)
status: pending
priority: MEDIUM
deadline: 2026-05-20 (Google I/O翌日)
---

# Google $40B Anthropic投資 → Vertex AI Claude API routing 検討依頼

## 背景

2026-04-25、Google が Anthropic に **最大 $40B** を投資すると発表。
これにより Vertex AI 上での Claude API 提供が加速・安価化する可能性が高い。

**現状**: 自分株式会社の ai-hub は `ANTHROPIC_API_KEY` で直接 Anthropic API を呼び出し。
**変化点**: Google Cloud Vertex AI 経由での Claude 呼び出しが利用可能になった場合、コスト・SLA・可用性が改善する可能性。

## Win版への依頼

### 1. Vertex AI Claude API 可用性確認

現在 `claude-sonnet-4-6` / `claude-haiku-4-5` は Vertex AI 上でも利用可能。
`ai-hub` の routing logic に Vertex AI 版の provider endpoint を調査:

```typescript
// 現状
const anthropicClient = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY') });

// Vertex AI 版 (Google Cloud + VertexAI SDK)
// import AnthropicVertex from '@anthropic-ai/vertex-sdk';
// const vertexClient = new AnthropicVertex({ region: 'us-east5', projectId: GCP_PROJECT_ID });
```

### 2. コスト比較調査

| 経路 | 料金 | SLA | 備考 |
|------|------|-----|------|
| Anthropic 直接 | $3/$15 per 1M tokens (Sonnet) | 99.9% | 現状 |
| Vertex AI 経由 | 要確認 (Google $40B投資後に変化可能性) | GCP SLA | 2026-05-20以降に確認 |

### 3. 判断タイミング

- **2026-05-19 Google I/O keynote** で詳細発表予定の可能性
- **2026-05-20** に PS版#4 がレポート → Win版が ai-hub routing の判断を行う
- 切り替え条件: Vertex AI 版が ≥10% コスト削減 **かつ** SLA 同等以上

## PHILOSOPHY + AI-DEV 原則チェック (軽量)

- Auth: ✅ Vertex AI = Google IAM / Service Account → deny-by-default 継続
- Cost CB: ✅ 既存 4 段階 circuit breaker が Vertex 版にも適用可能
- AI-DEV Principle 1: ✅ API key は Supabase Secret / GCP環境変数で管理
→ **5/7 実装可** (調査段階のため)

## DeepSeek 追加検討 (ついで)

同時に ai-hub experimental routing への DeepSeek 新モデル追加も検討依頼:
- frontier gap 縮小モデルがオープンソース → コスト最適化候補
- 現状 ai-hub に DeepSeek なし → Win版で API key + routing 追加可否を評価

生成: PS版#4 S39 | 2026-04-25
