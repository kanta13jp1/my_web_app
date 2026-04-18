---
title: "自分株式会社の AI大学が88社対応に — DeepInfra と Nebius AI Studio を追加"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: true
---

# 自分株式会社の AI大学が88社対応に — DeepInfra と Nebius AI Studio を追加

## はじめに

自分株式会社の **AI大学** 機能が、ついに **88プロバイダー対応** に到達しました。

今回は推論インフラ特化の2社を正式に追加しました:

- **DeepInfra** — 200+ オープンモデルを業界最安値クラスで提供
- **Nebius AI Studio** — 旧 Yandex グループが欧州で展開する高性能 AI クラウド

## AI大学とは

AI大学は、主要 AI プロバイダー・モデルを **ゲーミフィケーション形式で学習できる機能**です。

各プロバイダーについて:
- 📖 **概要** (overview) — 会社・サービスの特徴
- 🤖 **モデル** (models) — 主要モデルのスペック比較
- 🔌 **API** (api) — 実際の利用方法・エンドポイント

クイズに答えて正解数・ストリーク日数を競うランキングシステムも搭載しています。

## DeepInfra の特徴

DeepInfra は**コスト効率が圧倒的**なオープンモデル推論プラットフォームです。

```
エンドポイント: https://api.deepinfra.com/v1/openai/chat/completions
デフォルトモデル: meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo
Tier: Budget (4-Tier 自動ルーティング)
```

Llama 3.1 70B を GPT-4o の **10分の1以下のコスト**で利用でき、自分株式会社では Budget Tier に分類しています。

## Nebius AI Studio の特徴

Nebius は**欧州 GDPR 準拠**の高性能 AI クラウドです。

```
エンドポイント: https://api.studio.nebius.com/v1/chat/completions
デフォルトモデル: meta-llama/Llama-3.3-70B-Instruct
Tier: Performance (4-Tier 自動ルーティング)
```

旧 Yandex の AI 研究チームが運営。Llama 3.3 70B (Llama 3.1 の後継モデル) で高品質な推論を提供します。

## 4-Tier 自動ルーティングとの連携

自分株式会社の AI Hub には **4段階コスト自動ルーティング** (`provider.chat_auto`) が実装されています:

| Tier | プロバイダー例 | 用途 |
|------|-------------|------|
| Free | DeepSeek, Groq, SiliconFlow, **DeepInfra** | コスト0円タスク |
| Budget | Together AI, Fireworks, Moonshot | 低コスト推論 |
| Performance | OpenAI, Google, Mistral, **Nebius** | 高品質タスク |
| Premium | Claude, GPT-4o, Gemini Ultra | 最高品質タスク |

DeepInfra (Free→Budget) と Nebius (Performance) がルーティング対象に加わったことで、**コスト最適化の選択肢がさらに広がりました**。

## 88社への道のり

AI大学は今年4月に急速に拡大してきました:

| 日付 | プロバイダー数 | 主な追加 |
|------|-------------|---------|
| 4月上旬 | 9社 | Google, OpenAI, Anthropic など主要LLM |
| 4月中旬 | 54社 | 中国・欧州・特化型プロバイダー |
| 4月17日 | 77社 | 動画AI (Runway/Suno/Luma/Kling) |
| 4月18日 | **88社** | SiliconFlow, Novita AI, **DeepInfra, Nebius** |

## まとめ

AI大学 88社対応で、主要 AI プロバイダーの網羅率がさらに向上しました。
無料で体験できます: https://my-web-app-b67f4.web.app/

次回は **90社突破** を目指します。

---
#FlutterWeb #Supabase #buildinpublic #個人開発 #AI大学
