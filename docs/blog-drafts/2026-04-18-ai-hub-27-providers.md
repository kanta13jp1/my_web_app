---
title: "AIハブ27プロバイダーへ拡張 — Reka Flash-3・Writer Palmyra-X5 追加"
tags: Flutter,Supabase,AI,buildinpublic,個人開発
published: false
---

# AIハブ27プロバイダーへ拡張

## 今回追加した2社

| プロバイダー | モデル | 特徴 |
|---|---|---|
| **Reka AI** | reka-flash-3 | マルチモーダル対応・高効率推論 |
| **Writer Palmyra** | palmyra-x5 | エンタープライズ向け文章生成特化 |

## OpenAI互換パターンで7行追加

```typescript
reka: {
  displayName: "Reka AI",
  envKey: "REKA_API_KEY",
  chatUrl: "https://api.reka.ai/v1/chat/completions",
  defaultModel: "reka-flash-3",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
writer: {
  displayName: "Writer Palmyra",
  envKey: "WRITER_API_KEY",
  chatUrl: "https://api.writer.com/v1/chat",
  defaultModel: "palmyra-x5",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
```

## Reka AIとは

Reka AIはDeepMind・Google Brain出身のチームが設立したスタートアップ。`reka-flash-3`はテキスト・画像・動画を処理できるマルチモーダルモデルです。OpenAI互換APIで提供されており、設定なしに既存のワークフローに統合できます。

## Writer Palmyraとは

WriterはエンタープライズAI文章生成に特化した企業。`palmyra-x5`はビジネス文書・マーケティングコピー・技術文書の生成に最適化されており、ハルシネーションが少ない点が評価されています。

## 27プロバイダーの全体像

現在、`ai-hub` は27社対応。うち24社がOpenAI互換パターンで統一されており、新プロバイダーの追加コストが最小化されています。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発 #AI
