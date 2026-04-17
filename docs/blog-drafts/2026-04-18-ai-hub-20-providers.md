---
title: "自分株式会社のAIハブが20プロバイダーに拡張 — Cerebras超高速推論・中国系AI3社も対応"
tags: Flutter,Supabase,AI,buildinpublic,個人開発
published: false
---

# 自分株式会社のAIハブが20プロバイダーに拡張

## はじめに

自分株式会社のバックエンド（Supabase Edge Function）に実装している `ai-hub` が、今回のアップデートで **20プロバイダー対応**になりました。

今回追加した6社：

| プロバイダー | 特徴 | 代表モデル |
|---|---|---|
| **Cerebras** | 超高速推論 (1000+ tokens/s) | llama-3.3-70b |
| **NVIDIA NIM** | エンタープライズ向けAI推論 | meta/llama-3.1-70b-instruct |
| **Moonshot (Kimi)** | 中国系、長文コンテキスト対応 | moonshot-v1-8k |
| **AI21 Labs** | Jamba SSM+Transformerハイブリッド | jamba-1.5-mini |
| **01.AI (Yi)** | 中国系オープンソースLLM | yi-lightning |
| **Zhipu AI (GLM)** | 中国系、無料枠が充実 | glm-4-flash |

## 実装のポイント

`ai-hub` はすべてのプロバイダーを **OpenAI互換API** で統一しています。

```typescript
const OPENAI_COMPAT_BODY = (messages: unknown[], model: string) => ({
  model,
  messages,
  max_tokens: 1000,
  temperature: 0.7,
});

cerebras: {
  displayName: "Cerebras",
  envKey: "CEREBRAS_API_KEY",
  chatUrl: "https://api.cerebras.ai/v1/chat/completions",
  defaultModel: "llama-3.3-70b",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
```

Google Geminiのみ独自フォーマットですが、他は全員 `OPENAI_COMPAT_BODY` で対応できます。

## Cerebrasが特に注目

Cerebrasは専用シリコン（WSE）を使った**超高速推論**が売り。同じllama-3.3-70bでも、NVIDIA GPUクラスターと比べて**10倍以上速い**ケースがあります。リアルタイム対話アプリには最適です。

## 次のステップ

現在、各プロバイダーのAPIキーは `Supabase Secrets` に追加する必要があります。追加後に即本番稼働します：

```bash
# Supabase CLI でシークレット追加
supabase secrets set CEREBRAS_API_KEY=xxx
supabase secrets set NVIDIA_API_KEY=xxx
# ... 以下同様
```

## まとめ

20プロバイダー対応になったことで、ユーザーは自分のAPIキーを持ち込んで（BYOK）、好きなAIとチャットできるようになります。AIプロバイダーの多様性こそが差別化ポイントです。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発 #AI
