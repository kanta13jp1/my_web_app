---
title: "自分株式会社の AI Hub に 4-Tier 自動ルーティングを実装した話"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: false
---

# 自分株式会社の AI Hub に 4-Tier 自動ルーティングを実装した話

## はじめに

自分株式会社の AI Hub に **4-Tier コスト自動ルーティング** (`provider.chat_auto`) を実装しました。

1 つの API 呼び出しで「無料プロバイダーから試し、ダメなら上位 Tier に自動エスカレーション」する仕組みです。

## なぜ自動ルーティングが必要か

33 プロバイダー対応になった AI Hub では「どのプロバイダーを使うか」の選択が課題でした。

- **コスト最適化**: 同じ品質なら安い方が良い
- **可用性確保**: 1 プロバイダーが落ちても自動切り替え
- **ユースケース対応**: タスクの重要度に応じてモデル品質を変えたい

## 4-Tier 構成

```typescript
const TIER_PROVIDERS: Record<Tier, string[]> = {
  free:        ["deepseek", "groq", "cerebras", "siliconflow", "novita_ai"],
  budget:      ["sambanova", "arcee_ai", "minimax", "deepinfra", "together_ai", "fireworks_ai", "moonshot"],
  performance: ["openai", "google", "mistral", "cohere", "perplexity", "nebius", "qwen"],
  premium:     ["anthropic", "openai", "google"],
};
```

| Tier | コスト目安 (1K tokens) | 用途 |
|------|----------------------|------|
| **Free** | $0.0001 | 定型タスク・試作 |
| **Budget** | $0.001 | 一般的な推論 |
| **Performance** | $0.01 | 高品質タスク |
| **Premium** | $0.05 | 最高品質・複雑推論 |

## 自動ルーティングの実装

`provider.chat_auto` アクションの中核ロジック:

```typescript
outerLoop:
for (let ti = startTierIndex; ti < TIER_ORDER.length; ti++) {
  const tier = TIER_ORDER[ti];
  const providers = TIER_PROVIDERS[tier].filter((p) => p in PROVIDER_CONFIGS);
  for (const pid of providers) {
    const result = await callSingleProvider(pid, finalMessages, undefined);
    if (result.ok && result.text) {
      resultText = result.text;
      usedProvider = pid;
      usedTier = tier;
      break outerLoop;
    }
  }
}
```

**ポイント**: Tier 内のプロバイダーを順番に試し、成功したら即座に `break outerLoop` で脱出。
`startTier` を指定すれば特定 Tier から開始できます (デフォルトは `free`)。

## Flutter 側の呼び出し

```dart
final resp = await _supabase.functions.invoke(
  'ai-hub',
  body: {
    'action': 'provider.chat_auto',
    'message': 'こんにちは',
    'tier': 'free',  // 省略時も free から開始
  },
);
// レスポンス例:
// { success: true, provider: "groq", tier: "free", model: "llama-3.3-70b-versatile", text: "..." }
```

使用プロバイダー・Tier・モデルがレスポンスに含まれるため、ユーザーにも透明性があります。

## コスト記録

成功時は `ai_hub_chat_logs` テーブルに記録:

```typescript
await admin.from("ai_hub_chat_logs").insert({
  provider: usedProvider,
  tier: usedTier,
  success: true,
  estimated_cost_usd: TIER_COST_USD_PER_1K[usedTier] * (tokens / 1000),
  model: usedModel,
});
```

これにより「どの Tier が実際に使われているか」を集計して費用を最適化できます。

## まとめ

4-Tier 自動ルーティングにより:
- 無料 Tier が使える限りコスト $0 を維持
- プロバイダー障害時の自動フェイルオーバー
- タスク重要度に応じた品質制御

無料で体験できます: https://my-web-app-b67f4.web.app/

---
#FlutterWeb #Supabase #buildinpublic #個人開発 #AI
