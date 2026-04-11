-- Hugging Face コンテンツシード
-- AI大学: Hugging Face プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: OSS AIモデルのデファクトハブ / Inference API 公開済み / 開発者コミュニティ最大 / 日本でも高知名度

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('huggingface', 'overview', 'Hugging Face 概要',
$$Hugging Face は2016年にニューヨークで創業された AI モデルハブ・ツールキット企業です。GitHub に例えるなら「AI モデルの GitHub」として、世界中の研究者・企業が公開した **100万以上の AI モデル** をホスティングし、誰でも無料でダウンロード・利用できます。

**Transformers ライブラリ** は自然言語処理・画像・音声・マルチモーダルモデルを統一インターフェースで扱える OSS で、PyTorch / TensorFlow 両対応。AI 開発者の必須ツールとして世界標準の地位を確立しています。

## 主要サービス
- **Hub (huggingface.co)** — 100万+ モデル・50万+ データセット・30万+ デモ (Space) を公開
- **Inference API** — Hub 上のモデルを API 経由でクラウド実行 (無料枠あり)
- **Inference Endpoints** — モデルを専用エンドポイントとしてデプロイ (有料)
- **Transformers** — BERT / GPT / LLaMA / Stable Diffusion などを統一 API で利用
- **Datasets** — 50万+ の学習用データセット
- **Spaces** — Gradio / Streamlit でデモアプリを公開するプラットフォーム

## 強み
- **最大のモデルコレクション**: LLaMA / Mistral / Falcon / SDXL など主要 OSS モデル全てが入手可能
- **無料利用可能**: 多くのモデルは商用ライセンスで無料利用可能
- **コミュニティ駆動**: 日々数千のモデル・データセット・デモが追加される
- **企業採用多数**: Google / Meta / Mistral / Stability AI 等がモデルを公式配布
- **日本語対応モデル**: rinna / cyberagent / llm-jp など国産モデルも多数$$,
'https://huggingface.co/', '2026-04-12', 1),

('huggingface', 'models', 'Hugging Face 主要モデル一覧 (2026)',
$$## 大規模言語モデル (LLM)

| モデル | 提供元 | パラメータ | 特徴 |
| :--- | :--- | :--- | :--- |
| **Meta-Llama-3.3-70B** | Meta | 70B | 最高OSS精度クラス・商用可 |
| **Mistral-7B / Mixtral-8x7B** | Mistral AI | 7B / 47B | 高効率・商用可 |
| **Falcon-180B** | TII | 180B | Apache 2.0・大規模 |
| **Phi-4** | Microsoft | 14B | 小型高精度・商用可 |
| **Gemma 3** | Google | 1B/4B/12B/27B | 軽量・商用可 |
| **Qwen2.5-72B** | Alibaba | 72B | 多言語・中国語・商用可 |

## 日本語特化モデル

| モデル | 提供元 | 特徴 |
| :--- | :--- | :--- |
| **rinna/japanese-gpt-neox-3.6b** | rinna | 日本語特化 GPT-NeoX |
| **cyberagent/calm3-22b-chat** | CyberAgent | 日本語チャット 22B |
| **llm-jp/llm-jp-3-13b** | LLM-jp | 研究用・日本語高精度 |
| **elyza/Llama-3-ELYZA-JP-8B** | ELYZA | LLaMA3 日本語ファインチューン |

## 画像・マルチモーダル

| モデル | 特徴 |
| :--- | :--- |
| **stabilityai/stable-diffusion-3.5** | 最高品質画像生成 |
| **black-forest-labs/FLUX.1** | 超高品質テキスト→画像 |
| **openai/whisper-large-v3** | 多言語音声認識 (Apache 2.0) |
| **facebook/seamless-m4t-v2** | 音声翻訳 (100言語) |$$,
'https://huggingface.co/models', '2026-04-12', 2),

('huggingface', 'api', 'Hugging Face API 入門',
$$## Hugging Face Inference API の始め方

[huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) でトークンを取得後、無料枠で即利用できます。

```python
import requests

HF_TOKEN = "your-hf-token"
API_URL = "https://api-inference.huggingface.co/models/meta-llama/Meta-Llama-3.3-70B-Instruct"

response = requests.post(
    API_URL,
    headers={"Authorization": f"Bearer {HF_TOKEN}"},
    json={
        "inputs": "Hugging Face の強みを日本語で説明してください。",
        "parameters": {"max_new_tokens": 512, "temperature": 0.7}
    }
)
print(response.json()[0]["generated_text"])
```

## transformers ライブラリ (ローカル実行)

```python
from transformers import pipeline

# 日本語テキスト生成 (ローカル実行)
generator = pipeline(
    "text-generation",
    model="cyberagent/calm3-22b-chat",
    device_map="auto"  # GPU があれば自動利用
)

result = generator(
    "AIモデルのハブとして有名なサービスは？",
    max_new_tokens=200,
    do_sample=True,
    temperature=0.7
)
print(result[0]["generated_text"])
```

## InferenceClient (推奨・OpenAI 互換)

```python
from huggingface_hub import InferenceClient

client = InferenceClient(
    model="meta-llama/Meta-Llama-3.3-70B-Instruct",
    token="your-hf-token"
)

# OpenAI 互換インターフェース
response = client.chat_completion(
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Hugging Faceとは何ですか？"}
    ],
    max_tokens=500
)
print(response.choices[0].message.content)
```

## 画像生成 (FLUX.1 / Stable Diffusion)

```python
from huggingface_hub import InferenceClient
from PIL import Image
import io

client = InferenceClient(token="your-hf-token")

# FLUX.1 で画像生成
image_bytes = client.text_to_image(
    "a beautiful Japanese garden with cherry blossoms",
    model="black-forest-labs/FLUX.1-dev"
)
image = Image.open(io.BytesIO(image_bytes))
image.save("flux_output.png")
```

## 料金 (2026年4月時点)

| プラン | 料金 | 内容 |
| :--- | :--- | :--- |
| **無料** | $0 | Inference API 制限付き利用・Hub 全モデルDL |
| **Pro** | $9 / 月 | Inference API 優先枠・ZeroGPU |
| **Inference Endpoints** | $0.06〜 / 時間 | 専用デプロイ・SLA保証 |
| **Enterprise Hub** | $20 / ユーザー / 月 | プライベートモデル・SSO・監査ログ |

- SDK: `pip install transformers huggingface_hub` / `npm install @huggingface/inference`
- ほとんどのモデルは**重みを無料ダウンロード可能** (ライセンスにより商用可)$$,
'https://huggingface.co/docs/inference-providers/en/index', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Hugging Face 追加 (14社目)',
  'Hugging Face (OSS AI モデルハブ最大) を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、日本語コンテンツ、100万+モデル・transformers ライブラリ・InferenceClient OpenAI互換・日本語モデル一覧 (rinna/ELYZA/CyberAgent) を収録。AI大学プロバイダー数 13社→14社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
