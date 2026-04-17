---
title: "AIハブ29プロバイダーへ拡張 — Meta Llama API・Nebius AI Studio 追加"
tags: Flutter,Supabase,AI,buildinpublic,個人開発
published: true
---

# AIハブ29プロバイダーへ拡張

## 今回追加した2社

| プロバイダー | モデル | 特徴 |
|---|---|---|
| **Meta Llama API** | Llama-4-Scout-17B-16E-Instruct | Meta公式API・Llama 4世代・OpenAI互換 |
| **Nebius AI Studio** | Llama-3.3-70B-Instruct | Yandex傘下・欧州GPUクラウド・コスト効率◎ |

## OpenAI互換パターンで7行追加

```typescript
meta: {
  displayName: "Meta Llama",
  envKey: "LLAMA_API_KEY",
  chatUrl: "https://api.llama.com/v1/chat/completions",
  defaultModel: "Llama-4-Scout-17B-16E-Instruct",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
nebius: {
  displayName: "Nebius AI Studio",
  envKey: "NEBIUS_API_KEY",
  chatUrl: "https://api.studio.nebius.com/v1/chat/completions",
  defaultModel: "meta-llama/Llama-3.3-70B-Instruct",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
```

## Meta Llama APIとは

Metaが2025年に正式ローンチした公式API。`api.llama.com` でOpenAI互換エンドポイントを提供しており、既存の統合に差し替えるだけで利用可能。`Llama-4-Scout-17B-16E-Instruct` はMoEアーキテクチャで17Bアクティブパラメータ・128Kコンテキスト対応。

## Nebius AI Studioとは

YandexのAI部門が独立してできた欧州のGPUクラウドプロバイダー。GDPR準拠の欧州データセンターでモデルをホストし、コスト面で非常に競争力がある。OpenAI互換APIで提供されているため、設定なしに統合可能。

## 29プロバイダーの全体像

現在、`ai-hub` は29社対応。うち26社がOpenAI互換パターンで統一されており、新プロバイダーの追加コストが最小化されています。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発 #AI
