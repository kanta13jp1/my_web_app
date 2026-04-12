-- Fireworks AI コンテンツシード
-- AI大学: Fireworks AI プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: オープンソースモデルの高速推論に特化 / LLaMA 3.3 70Bで業界最高水準のトークン/秒 / 画像生成(FLUX/SD)も対応 / Function Calling完全対応

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('fireworks_ai', 'overview', 'Fireworks AI 概要',
$$Fireworks AI は2022年創業の高速AIインフラ企業。**オープンソースモデルの推論速度に特化**し、LLaMA・Mistral・Qwen 等の主要モデルを業界最高水準のスループットで提供します。テキスト生成だけでなく画像生成 (FLUX・Stable Diffusion) や音声認識 (Whisper) もサポートしています。

## 特徴

- **高速推論**: LLaMA 3.1 70B で最大 150+ tokens/秒。Together AI・Replicate より高速なケースが多い
- **Function Calling**: LLaMA・Mistral・Qwen など主要モデルで Function Calling (ツール呼び出し) に完全対応
- **マルチモーダル**: テキスト生成・画像生成・音声認識を単一 API で統合
- **OpenAI 互換**: `base_url` を変更するだけで既存 OpenAI SDK コードが動作
- **サーバーレス & 専有エンドポイント**: 小規模利用はサーバーレス、大規模はデプロイ済み専有モデルで対応

## 強み

| 領域 | 内容 |
| :--- | :--- |
| **推論速度** | 業界トップクラスのトークン/秒。リアルタイムチャット・ストリーミングに最適 |
| **Function Calling** | 主要オープンソースモデルで信頼性高いツール呼び出し対応 |
| **画像生成** | FLUX.1 [dev] / FLUX.1 [schnell] / Stable Diffusion 3 を API で提供 |
| **音声認識** | Whisper v3 / Whisper Large v3 で高精度音声→テキスト |
| **コスト最適化** | サーバーレス課金 + キャッシュで同一プロンプトのコストを大幅削減 |

## 主要ユーザー

スタートアップから大企業まで、低レイテンシが求められるリアルタイム AI アプリケーション（チャットボット・コード補完・音声アシスタント等）で採用されています。$$,
'https://fireworks.ai/', '2026-04-12', 1),

('fireworks_ai', 'models', 'Fireworks AI — 利用可能モデル (2026)',
$$Fireworks AI はテキスト生成・画像生成・音声認識の3カテゴリでモデルを提供しています。

## テキスト生成モデル

| モデル ID | コンテキスト | 特徴 |
| :--- | :--- | :--- |
| **accounts/fireworks/models/llama-v3p3-70b-instruct** | 131K | LLaMA 3.3 70B — 最高速・高精度。推奨メインモデル |
| **accounts/fireworks/models/llama-v3p1-405b-instruct** | 131K | LLaMA 3.1 405B — 最大規模・最高精度 |
| **accounts/fireworks/models/llama-v3p2-3b-instruct** | 131K | LLaMA 3.2 3B — 超高速・低コスト |
| **accounts/fireworks/models/mixtral-8x22b-instruct** | 65K | Mixtral 8x22B MoE — 高精度・コスパ最高 |
| **accounts/fireworks/models/qwen2p5-72b-instruct** | 32K | Qwen 2.5 72B — 多言語・コード生成 |
| **accounts/fireworks/models/deepseek-v3** | 64K | DeepSeek V3 — コーディング特化 |
| **accounts/fireworks/models/gemma2-9b-it** | 8K | Gemma 2 9B — 軽量・高速 |

## 画像生成モデル

| モデル | 特徴 |
| :--- | :--- |
| **accounts/fireworks/models/flux-1-dev-fp8** | FLUX.1 [dev] — 最高品質画像生成 |
| **accounts/fireworks/models/flux-1-schnell-fp8** | FLUX.1 [schnell] — 高速・低コスト画像生成 |
| **accounts/fireworks/models/stable-diffusion-xl-1024-v1-0** | SDXL — 1024px高品質画像生成 |

## 音声認識モデル

| モデル | 特徴 |
| :--- | :--- |
| **whisper-v3** | Whisper Large v3 — 高精度多言語音声認識 |
| **whisper-v3-turbo** | Whisper Turbo — 高速・低コスト |

## 推論速度 (参考)

```text
LLaMA 3.3 70B:  ~150 tokens/秒 (Fireworks)
LLaMA 3.3 70B:  ~120 tokens/秒 (Together AI)
LLaMA 3.3 70B:  ~100 tokens/秒 (Groq)  ← Groq は専用ハードウェアで変動大
```$$,
'https://fireworks.ai/models', '2026-04-12', 2),

('fireworks_ai', 'api', 'Fireworks AI API 入門',
$$## セットアップ

OpenAI SDK をそのまま使えます。

```bash
pip install openai  # OpenAI SDK で OK
# または Fireworks 専用 SDK
pip install fireworks-ai
```

## OpenAI 互換 API (最も簡単)

```python
from openai import OpenAI

# base_url を Fireworks AI に変更するだけ
client = OpenAI(
    api_key="<FIREWORKS_API_KEY>",
    base_url="https://api.fireworks.ai/inference/v1"
)

response = client.chat.completions.create(
    model="accounts/fireworks/models/llama-v3p3-70b-instruct",
    messages=[
        {"role": "system", "content": "あなたは高速・的確な日本語アシスタントです。"},
        {"role": "user", "content": "FlutterでのWidgetライフサイクルを簡潔に説明してください。"}
    ],
    max_tokens=512,
    temperature=0.6
)
print(response.choices[0].message.content)
```

## Function Calling (ツール呼び出し)

```python
from openai import OpenAI
import json

client = OpenAI(
    api_key="<FIREWORKS_API_KEY>",
    base_url="https://api.fireworks.ai/inference/v1"
)

# ツール定義
tools = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "指定した都市の現在の天気を取得する",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "都市名 (例: Tokyo, Osaka)"},
                    "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}
                },
                "required": ["city"]
            }
        }
    }
]

response = client.chat.completions.create(
    model="accounts/fireworks/models/llama-v3p3-70b-instruct",
    messages=[{"role": "user", "content": "東京の天気を摂氏で教えてください"}],
    tools=tools,
    tool_choice="auto"
)

# ツール呼び出し結果を処理
tool_call = response.choices[0].message.tool_calls[0]
args = json.loads(tool_call.function.arguments)
print(f"Function: {tool_call.function.name}, Args: {args}")
```

## 画像生成

```python
import fireworks.client
from fireworks.client.image import ImageInference

fireworks.client.api_key = "<FIREWORKS_API_KEY>"

# FLUX.1 [dev] で画像生成
inference = ImageInference(model="accounts/fireworks/models/flux-1-dev-fp8")
answer = inference.text_to_image(
    prompt="A futuristic Tokyo skyline with cherry blossoms, digital art style",
    cfg_scale=7,
    height=1024,
    width=1024,
    steps=30,
    safety_check=False,
)

# 画像を保存
answer.image.save("output.png")
print("画像生成完了: output.png")
```

## 音声認識 (Whisper)

```python
import requests

with open("audio.mp3", "rb") as audio_file:
    response = requests.post(
        "https://audio-turbo.us-virginia-1.direct.fireworks.ai/v1/audio/transcriptions",
        headers={"Authorization": f"Bearer <FIREWORKS_API_KEY>"},
        files={"file": ("audio.mp3", audio_file, "audio/mpeg")},
        data={"model": "whisper-v3-turbo", "language": "ja"}
    )

print(response.json()["text"])
```

## 料金 (2026年4月時点, USD)

| モデル | 入力 (1M tokens) | 出力 (1M tokens) |
| :--- | :--- | :--- |
| **LLaMA 3.3 70B** | $0.90 | $0.90 |
| **LLaMA 3.1 405B** | $3.00 | $3.00 |
| **LLaMA 3.2 3B** | $0.10 | $0.10 |
| **Mixtral 8x22B** | $1.20 | $1.20 |
| **DeepSeek V3** | $0.90 | $0.90 |

| 画像モデル | 1枚あたり |
| :--- | :--- |
| **FLUX.1 [dev]** | $0.02 |
| **FLUX.1 [schnell]** | $0.004 |

- **無料クレジット**: 新規登録で $1 の無料クレジット
- **キャッシュ割引**: 同一プロンプトの繰り返し呼び出しで最大 80% 割引$$,
'https://docs.fireworks.ai/getting-started/quickstart', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Fireworks AI 追加 (23社目)',
  'Fireworks AI を AI大学プロバイダーとして追加。高速推論特化・Function Calling対応・画像生成(FLUX/SDXL)・音声認識(Whisper)を収録。LLaMA/Mixtral/DeepSeek高速APIの使い方、画像生成・音声認識の実装例を掲載。AI大学プロバイダー数 22社→23社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
