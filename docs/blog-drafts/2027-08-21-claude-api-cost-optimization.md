---
title: "Claude API コスト最適化 — haiku / sonnet 使い分けと Prompt Caching で月70%削減"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# Claude API コスト最適化 — haiku / sonnet 使い分けと Prompt Caching で月70%削減

Claude API のコストが月 $80 → $24 になった。使い分けと Prompt Caching の実装を公開する。

## モデル選択の原則

```
claude-haiku-4-5:    軽量タスク / 高頻度呼び出し (最安)
claude-sonnet-4-6:   複雑推論 / 設計タスク (バランス型)
claude-opus-4-7:     最高精度が必要な場合のみ (最高価)
```

**コスト比 (概算)**:
```
haiku : sonnet : opus = 1 : 5 : 15
```

## タスク別モデル割り当て

```typescript
// Edge Function でモデルを動的に選択
function selectModel(taskType: string): string {
  switch (taskType) {
    case 'cs_reply':          return 'claude-haiku-4-5-20251001';  // CS返信
    case 'competitor_check':  return 'claude-haiku-4-5-20251001';  // 競合チェック
    case 'daily_judgment':    return 'claude-haiku-4-5-20251001';  // デイリー判定
    case 'code_review':       return 'claude-sonnet-4-6';           // コードレビュー
    case 'architecture':      return 'claude-sonnet-4-6';           // 設計判断
    default:                  return 'claude-haiku-4-5-20251001';  // デフォルト最安
  }
}
```

## Prompt Caching で大幅削減

同じ長いシステムプロンプトを毎回送ると、その分のトークンが毎回課金される。Prompt Caching を使うと、キャッシュ済みトークンは **90% オフ**。

```typescript
const response = await anthropic.messages.create({
  model: 'claude-haiku-4-5-20251001',
  max_tokens: 1024,
  system: [
    {
      type: 'text',
      text: LONG_SYSTEM_PROMPT,  // 数千トークンのシステムプロンプト
      cache_control: { type: 'ephemeral' },  // キャッシュを有効化
    },
  ],
  messages: [{ role: 'user', content: userMessage }],
});
```

**効果計算例**:

```
システムプロンプト: 2,000 tokens
1日の呼び出し回数: 100回

キャッシュなし: 2,000 × 100 = 200,000 tokens/日
キャッシュあり: 2,000 (初回) + 2,000 × 0.1 × 99回 = 21,800 tokens/日
削減率: 89%
```

## 入力トークンを削減する

```typescript
// ❌ NG: 不要なコンテキストを全部渡す
const response = await anthropic.messages.create({
  messages: [{
    role: 'user',
    content: `${entireUserHistory}\n\n${question}`,  // 全履歴を渡している
  }],
});

// ✅ OK: 直近の重要なコンテキストのみ
const recentHistory = userHistory.slice(-5);  // 直近5件のみ
const response = await anthropic.messages.create({
  messages: [
    ...recentHistory,
    { role: 'user', content: question },
  ],
});
```

## バッチ処理でスループット最適化

```typescript
// ❌ NG: 1件ずつ逐次処理
for (const item of items) {
  const result = await callClaude(item);  // 100件 × 1秒 = 100秒
}

// ✅ OK: 並列処理 (rate limit の範囲内で)
const BATCH_SIZE = 5;
for (let i = 0; i < items.length; i += BATCH_SIZE) {
  const batch = items.slice(i, i + BATCH_SIZE);
  const results = await Promise.all(batch.map(callClaude));
  // rate limit 回避のため間隔を空ける
  if (i + BATCH_SIZE < items.length) {
    await new Promise(resolve => setTimeout(resolve, 500));
  }
}
```

## コスト監視: GHA で自動アラート

```yaml
# .github/workflows/cost-monitor.yml
on:
  schedule:
    - cron: '0 9 * * *'  # 毎朝9時

jobs:
  check:
    steps:
      - name: Check API usage
        run: |
          USAGE=$(curl -s "https://api.anthropic.com/v1/usage" \
            -H "x-api-key: $ANTHROPIC_API_KEY")
          TOTAL=$(echo $USAGE | jq '.total_tokens')
          if [ $TOTAL -gt 10000000 ]; then
            echo "⚠️ 月間トークン使用量が閾値超過: $TOTAL"
            # Slack 通知 or GitHub Issue 自動作成
          fi
```

## 実際の削減結果

```
施策前 (2026年1月):
  claude-opus: 60% → $62
  claude-sonnet: 30% → $18
  合計: $80/月

施策後 (2026年4月):
  claude-haiku: 80% → $12
  claude-sonnet: 20% → $12 (Prompt Caching あり)
  合計: $24/月
  削減率: 70%
```

## まとめ

```
コスト削減の優先順位:
  1. モデル選択 (haiku にできる処理は全て haiku)
  2. Prompt Caching (同じシステムプロンプトの繰り返し)
  3. 入力トークン削減 (コンテキスト窓を最小化)
  4. バッチ処理 (rate limit 内で並列化)
  5. 使用量監視 (GHA で自動アラート)
```

Claude API は賢く使えば、コストを抑えながら本番品質のプロダクトを作れる。まず「haiku でできることはhaiku で」から始めると、大きく削減できる。
