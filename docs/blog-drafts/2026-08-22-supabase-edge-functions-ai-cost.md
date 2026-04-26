---
title: "Supabase Edge Functions × AI — 実際のコスト内訳と最適化パターン"
tags: Supabase,AI,個人開発,saas
published: false
---

# Supabase Edge Functions × AI — 実際のコスト内訳と最適化パターン

## 「Edge Functions でAIを動かすとどれだけかかるか」

自分株式会社は Supabase Edge Functions (Deno) 経由で AI API を呼び出す設計になっている。

構築当初は「どれだけコストがかかるか」が全く見えなかった。実際に運用してみてわかったことを数字とともに公開する。

---

## 自分株式会社のAI呼び出しアーキテクチャ

```
Flutter Web
  └→ Supabase Edge Function (Deno)
        ├→ Claude API (Anthropic)
        ├→ Gemini API (Google)
        └→ OpenAI API
```

**なぜ直接呼ばないか**: APIキーをフロントエンドに置きたくない。RLS (Row Level Security) と組み合わせてユーザー単位のレート制限もかけられる。

---

## 実際のコスト内訳 (月間)

### Supabase (Edge Functions)

| プラン | 月額 | Edge Function 呼び出し上限 | 超過料金 |
|--------|------|--------------------------|---------|
| Free | $0 | 500,000回 | なし (停止) |
| Pro | $25 | 2,000,000回 | $2/100万回 |

**実績**: 自分株式会社 Pro プラン。月間 Edge Function 呼び出し約 **150,000回**。Pro プランで余裕あり。

### AI API コスト

| API | 月間トークン数 | 月額コスト |
|-----|--------------|-----------|
| Claude Sonnet 4.6 | 入力 8M + 出力 1.2M | 約 $30 |
| Gemini 1.5 Flash | 入力 12M + 出力 2M | 約 $4 |
| OpenAI GPT-4o mini | 入力 3M + 出力 0.5M | 約 $2 |

**合計**: Supabase $25 + AI API $36 ≒ **月額 $61**

---

## Edge Functions の実行コスト詳細

### コールドスタート問題

Deno Edge Functions はコールドスタートが **200〜500ms** かかる。AI API 呼び出しは既に数秒かかるため、体感への影響は軽微だが、頻繁な呼び出しがない EF は毎回コールドスタートになる。

**対策**: 主要 EF は定期的なウォームアップリクエストを GHA cron で実行。

```yaml
# .github/workflows/keep-warm.yml
- name: Warm up AI functions
  run: |
    curl -s "https://${PROJECT_REF}.supabase.co/functions/v1/ai-assistant?ping=1" \
      -H "Authorization: Bearer $ANON_KEY" &
    curl -s "https://${PROJECT_REF}.supabase.co/functions/v1/daily-judgment?ping=1" \
      -H "Authorization: Bearer $ANON_KEY" &
    wait
```

### タイムアウト制限

Supabase Edge Functions のデフォルトタイムアウトは **150秒**。Claude API で長い出力を生成すると超える場合がある。

**対策**: ストリーミングレスポンスを使う。

```typescript
// Deno EF でストリーミング
const stream = await anthropic.messages.stream({
  model: "claude-sonnet-4-6",
  max_tokens: 2048,
  messages: [{ role: "user", content: prompt }],
});

// ReadableStream として返す
return new Response(stream.toReadableStream(), {
  headers: {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    ...corsHeaders,
  },
});
```

---

## コスト最適化パターン

### 1. Circuit Breaker パターン

AI API がエラーを返したとき、全リクエストを即時遮断して余分なコストを防ぐ。

```typescript
// Supabase DB に circuit_breaker 状態を保存
const { data: breaker } = await supabase
  .from("ai_circuit_breaker")
  .select("state, expires_at")
  .eq("provider", "anthropic")
  .single();

if (breaker?.state === "open" && new Date(breaker.expires_at) > new Date()) {
  return json({ error: "AI service temporarily unavailable" }, 503);
}
```

### 2. キャッシュ戦略

同じプロンプトへの繰り返しリクエストは Supabase DB にキャッシュ。

```typescript
const cacheKey = createHash("sha256").update(prompt).toString();
const { data: cached } = await supabase
  .from("ai_cache")
  .select("response")
  .eq("key", cacheKey)
  .gt("expires_at", new Date().toISOString())
  .single();

if (cached) return json({ result: cached.response, cached: true });
```

**実績**: デイリーレポート系の EF でキャッシュヒット率 **約40%**。同日に複数ユーザーが同じデータを要求するケース。

### 3. モデル選択の階層化

コストの高いモデルと安いモデルを用途で使い分ける。

| 用途 | モデル | 理由 |
|------|--------|------|
| 複雑な判断・戦略 | claude-sonnet-4-6 | 精度優先 |
| 定型レポート生成 | gemini-1.5-flash | コスト優先 |
| タグ付け・分類 | gpt-4o-mini | 速度+コスト |
| バッチ処理 | claude-haiku-4-5 | 大量処理向け |

### 4. プロンプトキャッシング (Anthropic)

Anthropic の Prompt Caching を使うと、システムプロンプトの繰り返し分が **90%オフ**になる。

```typescript
const response = await anthropic.messages.create({
  model: "claude-sonnet-4-6",
  system: [
    {
      type: "text",
      text: LONG_SYSTEM_PROMPT, // 2000トークン以上
      cache_control: { type: "ephemeral" }, // キャッシュ指定
    },
  ],
  messages: [{ role: "user", content: userMessage }],
});
```

**実績**: cs-check EF (カスタマーサポート自動返信) でシステムプロンプトが 3,000 トークン。キャッシュ適用後、入力コスト **63%削減**。

---

## 実装した EF 一覧とコスト寄与

| Edge Function | 月間呼び出し | AI モデル | 月額コスト概算 |
|--------------|-------------|-----------|--------------|
| `ai-assistant` | 1,200回 | claude-sonnet-4-6 | $8 |
| `daily-judgment` | 30回 | claude-sonnet-4-6 | $4 |
| `cs-check` (GHA) | 60回 | claude-sonnet-4-6 + cache | $3 |
| `ai-university-update` | 1,440回 | gemini-1.5-flash | $2 |
| `get-home-dashboard` | 8,000回 | (AI なし) | $0 |
| その他 | 140,000回 | (AI なし) | $0 |

---

## まとめ: Supabase × AI のコスト感

- **月額 $60〜80** で Supabase Pro + Claude/Gemini/OpenAI の個人開発環境が揃う
- Circuit Breaker + キャッシュ + Prompt Caching で **コストを 40〜60% 削減可能**
- ボトルネックは AI API コスト (Supabase 自体は安い)
- コールドスタートは GHA ウォームアップで対処

Supabase Edge Functions は AI バックエンドとして十分実用的。「APIキーをフロントに置きたくない」「RLS でユーザー分離したい」という要件があれば採用価値は高い。

---

## 関連記事

- [litellm で複数AI APIを統合管理する](./2026-08-01-litellm-unified-ai-gateway.md)
- [LangGraph ステートマシンパターン実践](./2026-08-08-langgraph-state-machine-patterns.md)
- [マルチAIワークフローの実際のコスト](./2026-07-25-multi-ai-workflow-real-costs.md)

---

*自分株式会社 — 21社競合のベストを1つに統合するライフマネジメントアプリ*  
*本番: https://my-web-app-b67f4.web.app/*
