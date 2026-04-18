---
title: "Jibun Corp's AI Hub Hits 31 Providers: Adding Replicate and Coze"
tags: Flutter,Supabase,buildinpublic,AI,Deno
published: false
---

# 自社AIハブが31プロバイダー達成 — Replicate と Coze を追加

## はじめに

「自分株式会社」のAIハブEdge Functionに **Replicate** と **Coze (ByteDance)** を追加し、ついに31プロバイダーに到達しました。

今回のフェーズ7では、モデルホスティングプラットフォームとエージェントプラットフォームという2つの異なるカテゴリを開拓しています。

## 追加したプロバイダー

### Replicate
- **エンドポイント**: `https://openai-compat.replicate.com/v1/chat/completions`
- **デフォルトモデル**: `meta/llama-4-scout-instruct`
- **特徴**: 数千のオープンソースモデルをホスト。OpenAI互換APIで簡単統合

### Coze (ByteDance)
- **エンドポイント**: `https://api.coze.com/v1/chat/completions`
- **特徴**: ByteDanceのAIエージェントプラットフォーム。日本・アジアで急成長中

## 実装パターン

```typescript
replicate: {
  displayName: "Replicate",
  envKey: "REPLICATE_API_TOKEN",
  chatUrl: "https://openai-compat.replicate.com/v1/chat/completions",
  defaultModel: "meta/llama-4-scout-instruct",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
coze: {
  displayName: "Coze (ByteDance)",
  envKey: "COZE_API_KEY",
  chatUrl: "https://api.coze.com/v1/chat/completions",
  defaultModel: "gpt-4o",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
```

`OPENAI_COMPAT_BODY` / `OPENAI_COMPAT_PARSE` パターンで7行追加するだけ。新しいプロバイダーの統合コストがほぼゼロです。

## プロバイダー数推移

| フェーズ | プロバイダー数 | 追加内容 |
|----------|--------------|---------|
| Phase 1 | 14 | 主要LLMプロバイダー |
| Phase 5 | 23 | 特化型・インフラ層 |
| Phase 6 | 29 | Meta Llama API, Nebius |
| **Phase 7** | **31** | **Replicate, Coze** |

## まとめ

31プロバイダーで、ユーザーはあらゆるAIモデルにアクセス可能になりました。

自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発
