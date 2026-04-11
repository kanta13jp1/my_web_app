-- Nvidia AI コンテンツシード
-- AI大学: Nvidia プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: GPU AI インフラの最大手 / NIM OpenAI互換API公開済み / build.nvidia.com で無料体験可 / 企業AI基盤として必須知識

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('nvidia', 'overview', 'Nvidia AI (NIM) 概要',
$$Nvidia は GPU (グラフィックス処理装置) の世界最大メーカーであり、AI 学習・推論インフラの事実上の標準を提供しています。ChatGPT / Gemini / Claude など主要 AI サービスの大半が Nvidia の **H100 / H200 / B200 GPU** で動いています。

2024年に発表した **NVIDIA NIM (Inference Microservices)** は、AI モデルを本番環境に高速デプロイするための最適化コンテナです。OpenAI API と互換性があるため、既存コードをほぼ変更せずに Nvidia 最適化モデルに切り替えられます。

## 主要サービス
- **NVIDIA NIM** — 最適化推論コンテナ (LLaMA / Mistral / Nemotron など 100+ モデル対応)
- **build.nvidia.com** — 無料 API プレイグラウンド (開発者が即体験可能)
- **NVIDIA AI Enterprise** — エンタープライズ向け AI プラットフォーム (サポート・SLA付き)
- **CUDA / cuDNN** — GPU 計算の業界標準ライブラリ
- **NVIDIA Triton** — 本番推論サーバー (Kubernetes 対応)

## 強み
- **業界標準の GPU インフラ**: クラウド (AWS / GCP / Azure) でも Nvidia GPU が主流
- **OpenAI 互換 API**: `base_url` を変更するだけで既存コードがそのまま動く
- **超低レイテンシ**: TensorRT-LLM 最適化で同スペックで 3〜5 倍高速化
- **エンタープライズ対応**: オンプレミス / プライベートクラウドへの完全デプロイが可能
- **最新モデルへの早期アクセス**: Llama 3.1 405B などの量産最適化版が即利用可能$$,
'https://www.nvidia.com/en-us/ai/', '2026-04-12', 1),

('nvidia', 'models', 'Nvidia NIM モデル一覧 (2026)',
$$## NVIDIA 独自モデル (Nemotron シリーズ)

| モデル | パラメータ | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Llama-3.1-Nemotron-70B** | 70B | Meta LLaMA3.1 を Nvidia が強化ファインチューン | 高精度テキスト生成 |
| **Nemotron-4-340B** | 340B | Nvidia 独自大規模モデル・合成データ生成特化 | データ拡張・学習 |
| **NVIDIA Cosmos** | — | 世界モデル (物理シミュレーション・ロボット) | 自律走行・ロボット |
| **NVIDIA Parakeet** | — | 音声認識 (英語特化・高精度) | 文字起こし |

## NIM 経由で利用可能な主要モデル

| モデル | プロバイダー | コンテキスト | 特徴 |
| :--- | :--- | :--- | :--- |
| **Meta Llama 3.3 70B** | Meta | 128K | OSS 最高精度クラス |
| **Mistral Large 2** | Mistral | 128K | 多言語・高精度 |
| **Microsoft Phi-4** | Microsoft | 16K | 小型・高効率 |
| **Google Gemma 3 27B** | Google | 128K | バランス型 |
| **DeepSeek-R1** | DeepSeek | 128K | 推論特化 |

## 画像・マルチモーダル

| モデル | 特徴 |
| :--- | :--- |
| **FLUX.1-dev (NIM)** | 超高品質テキスト→画像 (TensorRT最適化) |
| **SDXL-Turbo (NIM)** | リアルタイム画像生成 (1ステップ推論) |
| **Llama-3.2-11B-Vision** | テキスト+画像理解 |

## TensorRT-LLM 最適化効果

```text
通常実行 vs TensorRT-LLM:
- Llama 3.1 70B: 45 tokens/sec → 180 tokens/sec (4倍高速)
- コスト: 同一GPU で4倍のスループット = 1/4 のコスト
```$$,
'https://build.nvidia.com/explore/discover', '2026-04-12', 2),

('nvidia', 'api', 'Nvidia NIM API 入門',
$$## build.nvidia.com で即体験 (無料)

[build.nvidia.com](https://build.nvidia.com/) でアカウント作成後、無料クレジットで API を体験できます。

```python
from openai import OpenAI

# OpenAI クライアントをそのまま使用 (base_url のみ変更)
client = OpenAI(
    base_url="https://integrate.api.nvidia.com/v1",
    api_key="nvapi-your-api-key"  # build.nvidia.com で取得
)

response = client.chat.completions.create(
    model="meta/llama-3.3-70b-instruct",
    messages=[
        {"role": "user", "content": "Nvidia NIM の強みを日本語で教えてください。"}
    ],
    temperature=0.5,
    max_tokens=1024,
    stream=False
)

print(response.choices[0].message.content)
```

## ストリーミング応答

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://integrate.api.nvidia.com/v1",
    api_key="nvapi-your-api-key"
)

# ストリーミングで高速表示
for chunk in client.chat.completions.create(
    model="mistralai/mistral-large-2-instruct",
    messages=[{"role": "user", "content": "量子コンピュータとは何ですか？"}],
    max_tokens=1024,
    stream=True
):
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
```

## ローカル NIM デプロイ (Docker)

```bash
# Nvidia GPU 搭載サーバーで NIM コンテナを起動
docker run -it --rm \
  --gpus all \
  -e NGC_API_KEY="your-ngc-api-key" \
  -v "$LOCAL_NIM_CACHE:/opt/nim/.cache" \
  -p 8000:8000 \
  nvcr.io/nim/meta/llama-3.3-70b-instruct:latest

# 起動後は OpenAI 互換エンドポイントが localhost:8000 で利用可能
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"meta/llama-3.3-70b-instruct","messages":[{"role":"user","content":"Hello!"}]}'
```

## 画像生成 (FLUX.1 NIM)

```python
import requests, base64

response = requests.post(
    "https://ai.api.nvidia.com/v1/genai/black-forest-labs/flux-dev",
    headers={"Authorization": "Bearer nvapi-your-key"},
    json={
        "prompt": "futuristic Japanese city at night, neon lights, ultra realistic",
        "width": 1024,
        "height": 1024,
        "num_inference_steps": 50
    }
)

image_data = base64.b64decode(response.json()["artifacts"][0]["base64"])
with open("nvidia_flux.png", "wb") as f:
    f.write(image_data)
```

## 料金 (2026年4月時点)

| モデル | 入力 (1M tokens) | 出力 (1M tokens) |
| :--- | :--- | :--- |
| **Llama 3.3 70B** | $0.23 | $0.23 |
| **Mistral Large 2** | $2.00 | $6.00 |
| **Nemotron-4-340B** | $4.20 | $4.20 |

- **無料枠**: build.nvidia.com で $25 相当のクレジット (新規アカウント)
- **ローカルNIM**: NGC API Key があれば自社 GPU でゼロ外部通信デプロイ可
- SDK: `pip install openai` (OpenAI互換) / `pip install nvidia-nemo`$$,
'https://build.nvidia.com/docs/nim', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Nvidia NIM 追加 (15社目)',
  'Nvidia (NIM / GPU AI インフラ最大手) を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、日本語コンテンツ、Nemotron/LLaMA/Cosmos モデル・TensorRT-LLM最適化・ローカルNIMデプロイ・OpenAI互換APIを収録。AI大学プロバイダー数 14社→15社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
