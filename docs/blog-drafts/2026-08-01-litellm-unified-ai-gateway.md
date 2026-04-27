---
title: "LiteLLM で全AIを1つのAPIに統合する — OpenAI互換ゲートウェイの実践ガイド"
tags: AI,programming,個人開発,api
published: true
---

# LiteLLM で全AIを1つのAPIに統合する — OpenAI互換ゲートウェイの実践ガイド

## 「AIが増えるたびにSDKも増える問題」

Claude API、OpenAI API、Gemini API — それぞれの SDK を個別に実装すると、コードが分散する。

```python
# ❌ 個別SDK実装 → 3種類のコードが必要
from anthropic import Anthropic
from openai import OpenAI
from google.generativeai import GenerativeModel
```

LiteLLM はこの問題を解決するオープンソースのゲートウェイだ。OpenAI 互換の単一インターフェースで、100+ の LLM プロバイダーを切り替えられる。

---

## LiteLLM とは

| 項目 | 内容 |
|------|------|
| 種類 | OSS (MIT License) |
| 対応プロバイダー | 100+ (OpenAI / Anthropic / Gemini / Cohere / Mistral など) |
| インターフェース | OpenAI API 互換 |
| デプロイ方法 | Python パッケージ / Docker (LiteLLM Proxy) |
| 主な用途 | 統一 API / コスト追跡 / フォールバック |

---

## 基本的な使い方

### インストール

```bash
pip install litellm
```

### 統一呼び出し

```python
from litellm import completion

# Claude を呼ぶ
response = completion(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "こんにちは"}]
)

# 同じコードで GPT-4o を呼ぶ (model名だけ変える)
response = completion(
    model="gpt-4o",
    messages=[{"role": "user", "content": "こんにちは"}]
)

# Gemini も同様
response = completion(
    model="gemini/gemini-1.5-pro",
    messages=[{"role": "user", "content": "こんにちは"}]
)
```

コードを変えずに `model` パラメータ1つでプロバイダーを切り替えられる。

---

## フォールバック設定

Claude が 429 (rate limit) のとき GPT-4o に自動切替:

```python
from litellm import completion

response = completion(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "分析して"}],
    fallbacks=["gpt-4o", "gemini/gemini-1.5-pro"],
    context_window_fallback_dict={"claude-sonnet-4-6": "claude-haiku-4-5"}
)
```

本番環境での「API停止で全機能が落ちる」問題を解決できる。

---

## コスト追跡

```python
import litellm

litellm.success_callback = ["langfuse"]  # または独自ハンドラ

response = completion(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "hello"}]
)

# response._hidden_params でコスト確認
print(response._hidden_params["response_cost"])  # $0.00015 など
```

月のトークン消費・コストを自動集計できる。複数プロバイダーのコスト比較に使える。

---

## LiteLLM Proxy: チーム・プロジェクト向け

Docker でプロキシサーバーを立てると、全メンバーが同一エンドポイントを使える:

```yaml
# config.yaml
model_list:
  - model_name: claude-default
    litellm_params:
      model: claude-sonnet-4-6
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: gpt-fallback
    litellm_params:
      model: gpt-4o
      api_key: os.environ/OPENAI_API_KEY

router_settings:
  routing_strategy: least-busy
  fallbacks: [{"claude-default": ["gpt-fallback"]}]
```

```bash
docker run -p 4000:4000 ghcr.io/berriai/litellm:main \
  --config /config.yaml
```

チームメンバーは `http://localhost:4000` を OpenAI エンドポイントとして使うだけ。API キーの管理がサーバー側に集約される。

---

## 自分株式会社での使い方

自分株式会社の EF (Edge Function) では Claude / Gemini のフォールバックを LiteLLM Proxy 経由で実現している:

```typescript
// Supabase Edge Function (Deno)
const response = await fetch("https://litellm-proxy.example.com/v1/chat/completions", {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${Deno.env.get("LITELLM_API_KEY")}`,
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    model: "claude-default",
    messages: [{ role: "user", content: prompt }],
    fallbacks: ["gpt-fallback"]
  })
});
```

Claude quota 超過時も Gemini にフォールバックして機能が継続する。

---

## LiteLLM の注意点

- **ストリーミング**: 実装済みだが、プロバイダーによって挙動が微妙に異なる
- **マルチモーダル**: 画像入力は対応プロバイダーのみ (Claude / GPT-4V / Gemini)
- **レイテンシ**: プロキシ経由で +10-30ms のオーバーヘッド
- **バージョン固定**: LiteLLM のアップデートでプロバイダー API 呼び出しが変わることがある

---

## まとめ

LiteLLM は「AI 乗り換え・フォールバック・コスト管理」を1つのライブラリで解決する。

特に:
- **複数 AI を使い分けている** → 統一インターフェースで管理が楽になる
- **本番で AI 停止リスクが怖い** → フォールバック設定で可用性が上がる
- **月額コストを把握したい** → コスト追跡で見える化できる

個人開発でも複数 AI を使う時代に、LiteLLM は必須に近いツールになっている。

→ [自分株式会社 AI 大学で AI 開発ツールを学ぶ](https://my-web-app-b67f4.web.app/)
