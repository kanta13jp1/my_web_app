-- OpenRouter コンテンツシード
-- AI大学: OpenRouter プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: 200+モデル統合APIルーター / 単一エンドポイントで全主要LLMにアクセス / フォールバック・コスト最適化 / 開発者に必須のインフラ

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('openrouter', 'overview', 'OpenRouter 概要',
$$OpenRouter は**マルチモデルAPIルーター**。OpenAI・Anthropic・Google・Meta・DeepSeek など200以上のLLMを**単一のOpenAI互換API**で利用できます。モデル切り替え・コスト比較・自動フォールバックなどの機能で、LLMを使う開発者の必須インフラになっています。

## 特徴

- **単一エンドポイント**: `https://openrouter.ai/api/v1` で全モデルにアクセス (OpenAI SDK互換)
- **200+モデル**: Claude・GPT・Gemini・LLaMA・DeepSeek・Mistral など主要LLM全て
- **コスト比較**: 同一クエリを複数モデルで試してコスト・品質を比較
- **自動フォールバック**: メインモデルがダウン/遅延時に代替モデルへ自動切り替え
- **プロバイダー選択**: 同一モデルの複数ホスティング先から選択 (速度・コスト)

## アーキテクチャ

```text
アプリ → OpenRouter API (openrouter.ai/api/v1)
              ↓ ルーティング
    ┌─────────────────────┐
    │  Claude (Anthropic) │
    │  GPT (OpenAI)       │
    │  Gemini (Google)    │
    │  LLaMA (Meta)       │
    │  DeepSeek           │
    │  Mistral            │
    │  + 200以上 ...      │
    └─────────────────────┘
```

## 主要ユースケース

| ユースケース | 内容 |
| :--- | :--- |
| **コスト最適化** | タスク別にモデルを切り替え (GPT-4oの代わりに安価なモデルを試す) |
| **A/Bテスト** | 複数モデルの回答品質を本番で比較 |
| **フォールバック** | API障害・レート制限時に自動で代替モデルへ切り替え |
| **プロバイダー乗り換え** | コードを変えずにモデルだけ変更 |
| **無料モデル活用** | 無料枠のあるモデルを優先使用 |

## 強み

OpenRouter を使うと、Claude の最新モデルが使えなくなったとき・Anthropic のレート制限に引っかかったとき・コストが高騰したときでも、**1行の変更**で別プロバイダーに切り替えられます。ベンダーロックインを防ぐ「AI基盤の保険」として機能します。$$,
'https://openrouter.ai/docs', '2026-04-12', 1),

('openrouter', 'models', 'OpenRouter — 主要モデルカタログ (2026)',
$$OpenRouter では200以上のモデルを取り扱っています。主要モデルの比較を示します。

## 高性能モデル (有料)

| モデルID | プロバイダー | コンテキスト | 入力$/1M | 出力$/1M |
| :--- | :--- | :--- | :--- | :--- |
| `anthropic/claude-opus-4-6` | Anthropic | 200K | $15.00 | $75.00 |
| `openai/gpt-4o` | OpenAI | 128K | $2.50 | $10.00 |
| `google/gemini-2.5-pro` | Google | 1M | $1.25 | $10.00 |
| `anthropic/claude-sonnet-4-5` | Anthropic | 200K | $3.00 | $15.00 |
| `x-ai/grok-2` | xAI | 32K | $2.00 | $10.00 |

## 高コスパモデル

| モデルID | プロバイダー | コンテキスト | 入力$/1M |
| :--- | :--- | :--- | :--- |
| `deepseek/deepseek-chat` | DeepSeek | 64K | $0.14 |
| `mistralai/mistral-large` | Mistral | 128K | $2.00 |
| `meta-llama/llama-3.3-70b` | Meta | 128K | $0.12 |
| `google/gemini-flash-1.5` | Google | 1M | $0.075 |
| `qwen/qwen-2.5-72b` | Alibaba | 128K | $0.13 |

## 無料モデル (レート制限あり)

| モデルID | 特徴 |
| :--- | :--- |
| `meta-llama/llama-3.2-3b` | Meta 軽量モデル (3B) |
| `mistralai/mistral-7b-instruct` | Mistral 7B |
| `google/gemma-2-9b` | Google Gemma 9B |
| `deepseek/deepseek-r1` | DeepSeek 推論モデル (限定無料) |

## モデル選択のガイドライン

```text
複雑な推論・長文 → claude-opus-4-6 / gemini-2.5-pro
高速・コスト重視 → deepseek-chat / llama-3.3-70b
無料で試す      → llama-3.2-3b / mistral-7b-instruct
コード生成      → claude-sonnet-4-5 / deepseek-v3
日本語対応      → claude-* / gemini-* / qwen-2.5-*
```$$,
'https://openrouter.ai/models', '2026-04-12', 2),

('openrouter', 'api', 'OpenRouter API 入門',
$$## セットアップ

OpenRouter は **OpenAI SDK と完全互換**。base_url を変えるだけで利用可能。

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key="<OPENROUTER_API_KEY>",
)
```

## 基本的なチャット補完

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key="<OPENROUTER_API_KEY>",
)

# Claude を使用
response = client.chat.completions.create(
    model="anthropic/claude-sonnet-4-5",
    messages=[{"role": "user", "content": "Flutterでアニメーションを実装する方法は？"}],
    extra_headers={
        "HTTP-Referer": "https://my-web-app-b67f4.web.app/",  # レート優遇のため推奨
        "X-Title": "自分株式会社",
    },
)
print(response.choices[0].message.content)
```

## モデルを動的に切り替え (フォールバック付き)

```python
from openai import OpenAI
import time

client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key="<OPENROUTER_API_KEY>",
)

# 優先モデルリスト (上から順に試す)
MODELS = [
    "anthropic/claude-sonnet-4-5",  # 第1希望
    "openai/gpt-4o",                # フォールバック1
    "google/gemini-flash-1.5",      # フォールバック2 (安価)
]

def chat_with_fallback(prompt: str) -> str:
    for model in MODELS:
        try:
            response = client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": prompt}],
                timeout=30,
            )
            print(f"使用モデル: {model}")
            return response.choices[0].message.content
        except Exception as e:
            print(f"{model} 失敗: {e}. 次のモデルへ...")
            time.sleep(1)
    raise Exception("全モデルが失敗しました")

result = chat_with_fallback("Supabaseの Row Level Security を説明して")
print(result)
```

## コスト比較 (同一プロンプトを複数モデルで実行)

```python
import asyncio
from openai import AsyncOpenAI

client = AsyncOpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key="<OPENROUTER_API_KEY>",
)

COMPARE_MODELS = [
    ("anthropic/claude-sonnet-4-5", "Claude Sonnet"),
    ("openai/gpt-4o-mini", "GPT-4o mini"),
    ("deepseek/deepseek-chat", "DeepSeek"),
    ("meta-llama/llama-3.3-70b", "LLaMA 3.3 70B"),
]

async def compare_models(prompt: str):
    tasks = [
        client.chat.completions.create(
            model=model_id,
            messages=[{"role": "user", "content": prompt}],
        )
        for model_id, _ in COMPARE_MODELS
    ]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    for (model_id, name), result in zip(COMPARE_MODELS, results):
        if isinstance(result, Exception):
            print(f"{name}: エラー — {result}")
        else:
            tokens = result.usage
            print(f"\n=== {name} (入力:{tokens.prompt_tokens} / 出力:{tokens.completion_tokens}) ===")
            print(result.choices[0].message.content[:200])

asyncio.run(compare_models("自分株式会社の競合優位性を3点挙げてください"))
```

## Supabase Edge Function から利用 (Deno)

```typescript
// OpenRouter を Supabase Edge Function から使用 (OpenAI互換)
const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY")!;

async function callWithFallback(prompt: string): Promise<string> {
  const models = [
    "anthropic/claude-sonnet-4-5",
    "deepseek/deepseek-chat",        // 安価なフォールバック
  ];

  for (const model of models) {
    const res = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://my-web-app-b67f4.web.app/",
      },
      body: JSON.stringify({
        model,
        messages: [{ role: "user", content: prompt }],
        max_tokens: 500,
      }),
    });

    if (res.ok) {
      const data = await res.json();
      return data.choices[0].message.content;
    }
    console.warn(`${model} failed, trying next...`);
  }
  throw new Error("All models failed");
}
```

## 料金・無料枠

| 項目 | 内容 |
| :--- | :--- |
| **アカウント作成** | 無料 ($5クレジット付き) |
| **無料モデル** | 複数モデルが無料利用可 (レート制限あり) |
| **有料モデル** | 各プロバイダーの公式料金 + 小手数料 |
| **支払い** | クレジットカード / 暗号通貨 |$$,
'https://openrouter.ai/docs/quickstart', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 OpenRouter 追加 (29社目)',
  'OpenRouterをAI大学プロバイダーとして追加。200+モデル統合APIルーター・OpenAI互換エンドポイント・自動フォールバック・コスト比較・Supabase Edge Function統合例を収録。AI大学プロバイダー数 28社→29社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
