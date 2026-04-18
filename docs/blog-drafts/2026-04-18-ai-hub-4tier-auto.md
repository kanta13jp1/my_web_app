---
title: "自分株式会社の AI Hub に 4 段階コスト自動ルーティングを実装した"
tags: Flutter,Supabase,Deno,AI,buildinpublic
published: false
---

# AI Hub に 4 段階コスト自動ルーティングを実装した

## はじめに

「自分株式会社」の AI Hub Edge Function に **`provider.chat_auto`** アクションを追加しました。
ユーザーがモデル・プロバイダーを意識しなくても、コストと性能のバランスを自動的に最適化してリクエストを処理します。

## 実装した 4 段階 Tier

| Tier | プロバイダー例 | 想定コスト/1K tok |
|------|--------------|-----------------|
| **free** | DeepSeek, Groq, Cerebras, SiliconFlow, Novita | $0.0001 |
| **budget** | SambaNova, Arcee AI, MiniMax, DeepInfra | $0.001 |
| **performance** | OpenAI, Google, Mistral, Cohere, Perplexity | $0.01 |
| **premium** | Anthropic Claude, OpenAI GPT-4, Google Gemini Ultra | $0.05 |

## 自動エスカレーション ロジック

```typescript
async function callWithAutoEscalation(messages, preferredTier) {
  for (const tier of TIER_ORDER.slice(TIER_ORDER.indexOf(preferredTier))) {
    for (const provider of TIER_PROVIDERS[tier]) {
      try {
        const result = await callSingleProvider(provider, messages);
        await logToAiHubChatLogs(provider, tier, true, estimateCost(tier, messages));
        return result;
      } catch {
        // 失敗したら同 tier の次のプロバイダー → 次 tier へ自動昇格
      }
    }
  }
  throw new Error("All tiers exhausted");
}
```

リクエスト失敗（API エラー・quota 超過）時は同 Tier 内の次プロバイダーへ、同 Tier が全滅したら上位 Tier に自動エスカレーションします。

## コスト追跡テーブル

```sql
CREATE TABLE ai_hub_chat_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL,
  tier text NOT NULL,
  success boolean NOT NULL DEFAULT true,
  model text,
  estimated_cost_usd numeric(12, 8),
  created_at timestamptz NOT NULL DEFAULT now()
);
```

これで「どのプロバイダーに何円使ったか」をリアルタイム追跡できます。

## 詰まったポイント

**`callSingleProvider()` の共通化**

もともと `provider.chat` の switch-case に各プロバイダーの API 呼び出しが直書きされていました。
`provider.chat_auto` を追加するにあたり、呼び出しロジックを `callSingleProvider()` として切り出し、
`provider.chat` / `provider.chat_auto` 両方から再利用できる構造に整理しました。

## まとめ

Free Tier（DeepSeek/Groq など無料 API）からスタートし、失敗したら自動的に上位 Tier にエスカレーション。
Claude quota を使い果たしても OpenAI → Google → DeepSeek と自動フォールバックするため、
AI 機能のダウンタイムが大幅に減少しました。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #Deno #buildinpublic #個人開発
