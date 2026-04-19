-- Cerebrium 初期コンテンツシード (2026-04-19)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('cerebrium', 'overview', 'Cerebrium 概要',
$$Cerebrium は **serverless GPU/CPU プラットフォーム**。AI ワークロード (LLM/voice agent/video モデル/embedding 等) を sub-second cold start で deploy できる "Vercel for AI" 的な位置付け。

すべての endpoint が **OpenAI 互換** (`/chat/completions` + `/embedding`) で drop-in 可能。multi-region で低遅延推論を実現。

## 主要サービス
- **Serverless GPU/CPU**: H100 / A100 / RTX 4090 / CPU を関数単位で課金
- **OpenAI 互換 endpoints**: `/chat/completions` + `/embedding` 自動公開
- **Voice Agents**: real-time speech-to-speech 専用最適化
- **Video Models**: stable-diffusion-video 等の動画生成
- **Multi-region**: us-east / eu-west / ap-southeast

## 強み
- **Sub-second cold start**: serverless でも遅延なし
- **OpenAI compat**: 既存 SDK そのまま
- **instant autoscaling**: 0 → 1000 RPS まで自動
- **multi-region**: 地理分散で低レイテンシ
- **flexible pricing**: 使った GPU 秒数のみ$$,
'https://www.cerebrium.ai/', '2026-04-19', 1),

('cerebrium', 'models', 'Cerebrium モデル・GPU 一覧 (2026)',
$$## GPU/CPU 提供ラインナップ

| ハード | 用途 | 課金単位 |
| :--- | :--- | :--- |
| **H100** | 大規模 LLM | GPU 秒 |
| **A100 80GB** | 標準推論 | GPU 秒 |
| **A100 40GB** | 軽量推論 | GPU 秒 |
| **RTX 4090** | 実験 | GPU 秒 |
| **CPU (vCPU)** | 軽量処理 | CPU 秒 |

## 提供モデル例 (custom deploy 可)

| モデル | 用途 |
| :--- | :--- |
| Llama 3.3 70B | 汎用推論 |
| Whisper Large v3 | STT |
| Stable Diffusion XL | 画像生成 |
| Stable Video Diffusion | 動画生成 |
| Custom Pytorch / Onnx / TensorRT | 任意モデル deploy |

## 特徴的な機能
- **OpenAI compat endpoints**: 既存 SDK の base_url 切替で動く
- **sub-second cold start**: container pre-warming + snapshot
- **instant autoscaling**: 0→1000 RPS in seconds
- **VPC + persistent storage**: enterprise 構成
- **billing transparency**: 秒単位の課金履歴$$,
'https://docs.cerebrium.ai/', '2026-04-19', 2),

('cerebrium', 'api', 'Cerebrium API 入門',
$$## Cerebrium OpenAI 互換 endpoint の始め方

```python
# OpenAI SDK そのまま (drop-in)
from openai import OpenAI

client = OpenAI(
    api_key="<CEREBRIUM_API_KEY>",
    base_url="https://api.cerebrium.ai/v1",
)

response = client.chat.completions.create(
    model="meta-llama/Llama-3.3-70B-Instruct",
    messages=[
        {"role": "user", "content": "こんにちは!"}
    ],
)
print(response.choices[0].message.content)
```

## Custom model deploy

```python
# cerebrium.toml
[cerebrium.deployment]
name = "my-llama-app"
python_version = "3.11"
hardware = "H100"

[cerebrium.dependencies.pip]
torch = "2.5.0"
transformers = "4.46.0"
```

```bash
cerebrium deploy
```

## Embeddings API

```python
response = client.embeddings.create(
    model="BAAI/bge-large-en-v1.5",
    input=["text 1", "text 2"],
)
```

## 料金 (2026年4月時点)
- **H100 秒単価**: \$0.001167/sec (= \$4.20/hr)
- **A100 秒単価**: \$0.000556/sec (= \$2.00/hr)
- **CPU 秒単価**: \$0.000033/sec (= \$0.12/hr per vCPU)
- **cold start fee**: なし (sub-second 起動)

## 公式リソース
- [Cerebrium Docs](https://docs.cerebrium.ai/)
- [OpenAI compat](https://docs.cerebrium.ai/cerebrium/endpoints/openai-compatible-endpoints)$$,
'https://docs.cerebrium.ai/', '2026-04-19', 3)

ON CONFLICT DO NOTHING;
