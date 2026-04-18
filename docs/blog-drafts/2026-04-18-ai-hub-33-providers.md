---
title: "AI Hub Phase 8: DeepInfra と Liquid AI を追加して33プロバイダー達成"
tags: Flutter,Supabase,buildinpublic,AI,Deno
published: false
---

# AI Hub Phase 8: DeepInfra と Liquid AI を追加して33プロバイダー達成

## Phase 8 で追加した2プロバイダー

**33プロバイダー**に到達。今回は推論インフラ特化の2社。

### DeepInfra
- **エンドポイント**: `https://api.deepinfra.com/v1/openai/chat/completions`
- **デフォルトモデル**: `meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo`
- **選定理由**: 最もコスト効率の高い推論プロバイダーの1つ。数百のオープンモデルを OpenAI 互換エンドポイントで提供。

### Liquid AI
- **エンドポイント**: `https://api.liquid.ai/v1/chat/completions`
- **デフォルトモデル**: `liquid/lfm-40b`
- **選定理由**: Liquid Foundation Models (LFM) はトランスフォーマーを超える新しいアーキテクチャを採用。長文コンテキストタスクに最適。

## 7行パターンで実装

```typescript
deepinfra: {
  displayName: "DeepInfra",
  envKey: "DEEPINFRA_API_KEY",
  chatUrl: "https://api.deepinfra.com/v1/openai/chat/completions",
  defaultModel: "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
liquid: {
  displayName: "Liquid AI",
  envKey: "LIQUID_API_KEY",
  chatUrl: "https://api.liquid.ai/v1/chat/completions",
  defaultModel: "liquid/lfm-40b",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
```

OpenAI 互換フォーマットを使うプロバイダーは7行で追加できる。`OPENAI_COMPAT_BODY` + `OPENAI_COMPAT_PARSE` のペアがすべてを担う。

## フェーズ別プロバイダー数

| フェーズ | 合計 | フォーカス |
|--------|------|----------|
| 1 | 14 | 主要LLM (OpenAI, Anthropic, Google, xAI, DeepSeek) |
| 5 | 23 | 中国系プロバイダー (Moonshot, Qwen, Zhipu, 01.AI) |
| 6 | 29 | エンタープライズ (Reka, Writer, MiniMax, Meta Llama, Nebius) |
| 7 | 31 | プラットフォーム (Replicate, Coze) |
| **8** | **33** | **推論インフラ (DeepInfra, Liquid AI)** |

自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発
