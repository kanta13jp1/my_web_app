-- Anyscale 初期コンテンツシード (2026-04-19)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('anyscale', 'overview', 'Anyscale 概要',
$$Anyscale は **Ray.io** (オープンソース分散コンピューティングフレームワーク) の商用版を提供する AI/ML インフラ企業。2019 年創業、UC Berkeley RISELab 発。AWS / Azure / GCP に対抗する「どこでも動く ML プラットフォーム」。

2023 年 **Anyscale Endpoints** 発表 — OSS LLM (Llama / Mistral 等) を OpenAI 互換 API で serverless 提供。AWS Partner として生成 AI インフラ大手と競合。

## 主要サービス
- **Anyscale Endpoints**: OpenAI 互換 serverless LLM API
- **Ray Serve**: 自前 LLM デプロイ・fine-tuning
- **Anyscale Jobs**: 分散学習・バッチ推論
- **Ray.io (OSS)**: コア分散フレームワーク (GitHub 31k+ stars)

## 強み
- **Ray ベース**: ML 特化の distributed computing が標準
- **OpenAI 互換**: drop-in replacement
- **fine-tuning サービス**: OSS LLM を自社データで調整
- **マルチクラウド**: AWS/Azure/GCP/on-prem で統一 API
- **OSS コミュニティ**: Ray.io が業界標準$$,
'https://www.anyscale.com/', '2026-04-19', 1),

('anyscale', 'models', 'Anyscale モデル・サービス一覧 (2026)',
$$## Endpoints 提供モデル

| モデル | 用途 |
| :--- | :--- |
| **Llama 3.1 8B** | 軽量 |
| **Llama 3.1 70B** | 標準 |
| **Llama 3.1 405B** | 大規模 |
| **Mistral 7B** | 軽量高速 |
| **Mixtral 8x7B** | MoE |
| **CodeLlama 70B** | コード特化 |

## サービス構成

| サービス | 用途 | 課金 |
| :--- | :--- | :--- |
| **Endpoints** | OpenAI 互換 serverless LLM | token 単位 |
| **Ray Serve** | 自前モデルデプロイ | 時間単位 |
| **Jobs** | 分散学習・バッチ | 時間単位 |
| **Workspaces** | 開発環境 (notebook) | 時間単位 |

## 特徴的な機能
- **Ray 統合**: 分散学習・推論が Ray API で統一
- **Auto-scaling**: 負荷に応じて node 自動追加
- **fine-tuning**: OSS LLM を LoRA でカスタマイズ
- **RAG 統合**: Anyscale + LangChain で RAG 高速化
- **AWS Partner**: AWS GenAI スタックと緊密連携$$,
'https://docs.anyscale.com/', '2026-04-19', 2),

('anyscale', 'api', 'Anyscale API 入門',
$$## Anyscale Endpoints の始め方

```python
# OpenAI SDK そのまま (drop-in)
from openai import OpenAI

client = OpenAI(
    api_key="<ANYSCALE_API_KEY>",
    base_url="https://api.endpoints.anyscale.com/v1",
)

response = client.chat.completions.create(
    model="meta-llama/Meta-Llama-3.1-70B-Instruct",
    messages=[
        {"role": "user", "content": "こんにちは!"}
    ],
)
print(response.choices[0].message.content)
```

## Fine-tuning (LoRA)

```python
# Anyscale SDK で LoRA fine-tuning
from anyscale import finetune

job = finetune(
    base_model="meta-llama/Meta-Llama-3.1-8B",
    training_data="s3://my-bucket/train.jsonl",
    job_name="my-llama-ft",
)
```

## 料金 (2026年4月時点)
- **Endpoints (Llama 3.1 70B)**: \$1.00 / 100万 token
- **Fine-tuning**: モデルサイズ依存 (Llama 8B で \$1.20/hr)
- **Ray Serve**: 利用 GPU 時間単位

## 公式リソース
- [Anyscale Endpoints Docs](https://docs.anyscale.com/endpoints/overview)
- [Ray.io](https://www.ray.io/)$$,
'https://docs.anyscale.com/', '2026-04-19', 3)

ON CONFLICT DO NOTHING;
