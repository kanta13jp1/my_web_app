---
title: "自分株式会社のAIハブが25プロバイダーに拡張 — Qwen/Inflection/AllenAI/HuggingFace/MiniMax追加"
tags: Flutter,Supabase,AI,buildinpublic,個人開発
published: true
---

# 自分株式会社のAIハブが25プロバイダーに拡張

## 今回のアップデート

`ai-hub` Edge Function が **25プロバイダー対応**になりました。前回の20社から、さらに5社追加：

| プロバイダー | 特徴 | 代表モデル |
|---|---|---|
| **Alibaba Qwen** | 中国系、DashScope国際版 | qwen-plus |
| **Inflection Pi** | Pi AIのAPI提供 | inflection_3_pi |
| **Allen AI (OLMo)** | 非営利・完全オープン研究 | OLMo-2-0325-32B-Instruct |
| **Hugging Face** | 最大のオープンモデルHub | meta-llama/Llama-3.3-70B |
| **MiniMax** | 中国系マルチモーダル (音声+動画) | MiniMax-Text-01 |

## OpenAI互換パターンの威力

25社のうち24社が同じ `OPENAI_COMPAT_BODY` 関数で対応できます：

```typescript
const OPENAI_COMPAT_BODY = (messages: unknown[], model: string) => ({
  model,
  messages,
  max_tokens: 1000,
  temperature: 0.7,
});

// 1社追加 = 7行のconfig
huggingface: {
  displayName: "Hugging Face",
  envKey: "HUGGINGFACE_TOKEN",
  chatUrl: "https://api-inference.huggingface.co/v1/chat/completions",
  defaultModel: "meta-llama/Llama-3.3-70B-Instruct",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
```

新しいプロバイダーが OpenAI 互換APIを提供していれば、追加コストはほぼゼロです。

## 注目の2社

**Hugging Face**: 50万以上のモデルをホストする最大のオープンモデルプラットフォーム。Inference APIで任意のモデルを呼べるため、「1行でモデル変更」が可能です。

**MiniMax**: 香港上場の中国系AI企業。Text-01は最大100万トークンコンテキストに対応し、音声・動画生成も統合したマルチモーダルプラットフォームです。

## BYOKフローの全体像

現在、各プロバイダーのAPIキーは Supabase Secrets に設定することで即本番稼働します。UIの `AIプロバイダーステータス` ページで全25社の設定状況を確認できます：

- `implemented` — APIキー設定済み・稼働中
- `apiKeyRequired` — コード完了・APIキー待ち
- `paidPlanRequired` — 有料プラン要

## まとめ

25プロバイダー対応により、ユーザーは自分のAPIキーを持ち込んで好みのAIを選べます。OpenAI互換パターンのおかげで、今後の追加コストは最小限です。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発 #AI
