-- IBM watsonx コンテンツシード
-- AI大学: IBM プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: 企業向けAI最大手の一角 / watsonx.ai API公開済み / Granite LLM OSS公開 / 金融・医療・製造業での導入実績

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('ibm', 'overview', 'IBM watsonx 概要',
$$IBM は1911年創業の世界最大の IT 企業の一つで、エンタープライズ向け AI プラットフォーム **watsonx** を提供しています。「AI を企業の業務に組み込む」ことに特化しており、金融・医療・製造・公共機関など規制産業での導入実績が豊富です。

**watsonx** は3つのコンポーネントから構成されます:
- **watsonx.ai** — AI モデルのトレーニング・デプロイ・推論プラットフォーム
- **watsonx.data** — ガバナンス付きデータレイク (Apache Iceberg ベース)
- **watsonx.governance** — AI モデルの監査・バイアス検出・規制対応

IBM が独自開発した **Granite** シリーズは Apache 2.0 ライセンスで OSS 公開されており、企業がファインチューニングして自社データに特化させることができます。

## 主要サービス
- **watsonx.ai Studio** — ノーコード/ローコードで AI モデルを構築・デプロイ
- **Granite LLM** — IBM 独自の OSS テキスト生成・コード生成モデル
- **watsonx Assistant** — エンタープライズチャットボット構築プラットフォーム
- **watsonx Orchestrate** — AI エージェントで業務自動化

## 強み
- **規制対応**: HIPAA / GDPR / ISO 27001 対応 — 金融・医療・公共機関で採用可
- **OSS 透明性**: Granite モデルは学習データ・アーキテクチャが完全公開
- **オンプレミス対応**: IBM Cloud / AWS / Azure / オンプレ 全対応
- **エンタープライズ SLA**: 24/7 サポート・SLA保証・専任 CSM$$,
'https://www.ibm.com/watsonx', '2026-04-12', 1),

('ibm', 'models', 'IBM Granite / watsonx モデル一覧 (2026)',
$$## IBM Granite シリーズ (OSS・Apache 2.0)

| モデル | パラメータ | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Granite 3.2 8B Instruct** | 8B | 最新版・128K コンテキスト・多言語 | 汎用テキスト生成 |
| **Granite 3.2 2B Instruct** | 2B | 超軽量・エッジデプロイ対応 | オンデバイス・低レイテンシ |
| **Granite Code 34B** | 34B | コード生成特化・116言語対応 | 開発支援・コードレビュー |
| **Granite Code 8B / 3B** | 8B/3B | 軽量コード生成 | IDE統合・補完 |
| **Granite Guardian** | 3B/8B | 安全フィルタリング・有害コンテンツ検出 | コンプライアンス |

## watsonx.ai 経由で利用可能なサードパーティモデル

| モデル | プロバイダー | 特徴 |
| :--- | :--- | :--- |
| **Meta Llama 3.3 70B** | Meta | 高精度汎用 |
| **Mistral Large** | Mistral | 多言語・高精度 |
| **Mixtral 8x7B** | Mistral | 高効率 MoE |
| **SDXL** | Stability AI | 画像生成 |

## Granite の差別化点

```text
透明性: 学習データ・アーキテクチャ・評価結果を全て公開
安全性: Granite Guardian で有害出力を自動フィルタリング
法的安全: 訓練データの著作権リスクを IBM が保証 (企業採用に有利)
```$$,
'https://huggingface.co/ibm-granite', '2026-04-12', 2),

('ibm', 'api', 'IBM watsonx API 入門',
$$## watsonx.ai API の始め方

[cloud.ibm.com](https://cloud.ibm.com/) でアカウント作成後、無料ライト・プランで即利用できます。

```python
from ibm_watsonx_ai import APIClient, Credentials
from ibm_watsonx_ai.foundation_models import ModelInference

# 認証 (IAM API Key + プロジェクト ID)
credentials = Credentials(
    url="https://jp-tok.ml.cloud.ibm.com",  # 東京リージョン
    api_key="your-ibm-api-key"
)

client = APIClient(credentials)

# Granite 3.2 でテキスト生成
model = ModelInference(
    model_id="ibm/granite-3-2-8b-instruct",
    api_client=client,
    project_id="your-project-id",
    params={
        "max_new_tokens": 512,
        "temperature": 0.7,
        "top_p": 0.9
    }
)

response = model.generate_text(
    prompt="IBM watsonx の強みをエンタープライズ向けに説明してください。"
)
print(response)
```

## OpenAI 互換エンドポイント

```python
from openai import OpenAI

# watsonx は OpenAI 互換 API を提供
client = OpenAI(
    base_url="https://jp-tok.ml.cloud.ibm.com/ml/v1/text/chat",
    api_key="your-ibm-iam-token"
)

response = client.chat.completions.create(
    model="ibm/granite-3-2-8b-instruct",
    messages=[
        {"role": "user", "content": "企業向けAI導入で重要な3つのポイントは？"}
    ],
    max_tokens=512
)
print(response.choices[0].message.content)
```

## Granite Code でコード生成

```python
from ibm_watsonx_ai.foundation_models import ModelInference

model = ModelInference(
    model_id="ibm/granite-34b-code-instruct",
    api_client=client,
    project_id="your-project-id"
)

# コード生成
code = model.generate_text(
    prompt="Python で Supabase から データを取得する関数を書いてください。"
)
print(code)
```

## Hugging Face 経由でローカル実行 (Granite OSS)

```python
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

# Apache 2.0 ライセンス — 商用利用可
model_id = "ibm-granite/granite-3.2-8b-instruct"
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(
    model_id, torch_dtype=torch.bfloat16, device_map="auto"
)

inputs = tokenizer("IBMのAI戦略を教えてください。", return_tensors="pt").to("cuda")
outputs = model.generate(**inputs, max_new_tokens=200)
print(tokenizer.decode(outputs[0], skip_special_tokens=True))
```

## 料金 (2026年4月時点)

| プラン | 料金 | 内容 |
| :--- | :--- | :--- |
| **ライト** | 無料 | Granite モデル無料枠 (50,000 tokens/月) |
| **Essentials** | $0.50〜 / 1K tokens | 従量課金・全モデル利用可 |
| **Standard** | 要見積もり | SLA付き・エンタープライズサポート |

| モデル | 入力 (1M tokens) | 出力 (1M tokens) |
| :--- | :--- | :--- |
| **Granite 3.2 8B** | $0.15 | $0.60 |
| **Granite Code 34B** | $1.20 | $1.20 |
| **Llama 3.3 70B** | $0.90 | $0.90 |

- SDK: `pip install ibm-watsonx-ai` / OSS Granite は `pip install transformers` で利用可
- 東京リージョン (`jp-tok`) 利用可能 — データ主権要件に対応$$,
'https://cloud.ibm.com/apidocs/watsonx-ai', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 IBM watsonx 追加 (16社目)',
  'IBM watsonx (エンタープライズ AI・Granite OSS) を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、日本語コンテンツ、watsonx.ai/data/governance 解説・Granite 3.2/Code OSS・OpenAI互換 API・東京リージョン対応を収録。AI大学プロバイダー数 15社→16社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
