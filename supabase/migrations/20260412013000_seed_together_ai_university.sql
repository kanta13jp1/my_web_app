-- Together AI コンテンツシード
-- AI大学: Together AI プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: オープンソースモデルを高速・低コストで利用できるAPIサービス / LLaMA・Mistral・Qwen等200+モデルに対応 / 微調整(Fine-tuning)サービスも提供

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('together_ai', 'overview', 'Together AI 概要',
$$Together AI は2022年創業のAIインフラ企業。**オープンソースAIモデルを商用レベルで利用できるAPIサービス**を提供しています。Meta LLaMA・Mistral・Qwen・DeepSeek など200以上のモデルに対応し、高速推論・低コストを実現しています。

## 特徴

- **200+ モデル対応**: LLaMA 3・Mistral・Mixtral・Qwen・DeepSeek・Gemma など主要オープンソースモデルを一括提供
- **高速推論**: 独自の FlashAttention最適化で業界最高水準のトークン/秒を実現
- **Fine-tuning**: カスタムデータでモデルを微調整し、専用エンドポイントとして展開可能
- **OpenAI 互換 API**: 既存の OpenAI SDK コードをほぼ変更なしで使用可能
- **コスト優位性**: GPT-4 比で最大10分の1のコストで同等性能のオープンモデルを利用可能

## 強み

| 領域 | 内容 |
| :--- | :--- |
| **モデル選択の自由度** | 200+モデルをAPIで即利用。クローズドモデルへの依存なし |
| **高速推論** | LLaMA 3.1 70B を最大200 tokens/秒で処理 |
| **微調整 (Fine-tuning)** | 自社データでカスタムモデルを作成し専用APIとして公開 |
| **OpenAI 互換** | base_url 変更のみで既存コードが動作 |
| **コスト効率** | 同等性能でプロプライエタリより大幅に低コスト |

## 主要ユーザー

スタートアップ・研究機関・大企業がオープンソースAIを本番環境で使用するための基盤として採用。
モデルの微調整が必要な専門ドメイン（法律・医療・金融等）でも活用されています。$$,
'https://www.together.ai/', '2026-04-12', 1),

('together_ai', 'models', 'Together AI — 利用可能モデル (2026)',
$$Together AI では 200+ のオープンソースモデルを API で利用できます。代表的なモデルを紹介します。

## 最高性能モデル

| モデル | コンテキスト | 特徴 |
| :--- | :--- | :--- |
| **meta-llama/Meta-Llama-3.1-405B-Instruct-Turbo** | 128K | オープンソース最大・GPT-4o比較クラス |
| **meta-llama/Meta-Llama-3.3-70B-Instruct-Turbo** | 128K | 高精度・高速。コスパ最高 |
| **deepseek-ai/DeepSeek-V3** | 64K | コーディング・推論に強い |
| **Qwen/Qwen2.5-72B-Instruct-Turbo** | 32K | 多言語・コード生成 |

## バランス型モデル

| モデル | コンテキスト | 特徴 |
| :--- | :--- | :--- |
| **mistralai/Mixtral-8x7B-Instruct-v0.1** | 32K | MoE構造・高速・コスト効率 |
| **mistralai/Mistral-7B-Instruct-v0.3** | 32K | 軽量・高速 |
| **google/gemma-2-27b-it** | 8K | Google の高品質オープンモデル |

## コーディング特化

| モデル | コンテキスト | 特徴 |
| :--- | :--- | :--- |
| **Qwen/Qwen2.5-Coder-32B-Instruct** | 32K | コーディング特化最高クラス |
| **deepseek-ai/deepseek-coder-v2-instruct** | 128K | DeepSeek コーディング特化 |

## Embedding モデル

| モデル | 次元 | 用途 |
| :--- | :--- | :--- |
| **togethercomputer/m2-bert-80M-8k-retrieval** | 768 | 高速・軽量 RAG |
| **BAAI/bge-large-en-v1.5** | 1024 | 英語高精度 |
| **WhereIsAI/UAE-Large-V1** | 1024 | 汎用・多言語 |

## 推論速度 (参考)

```text
LLaMA 3.3 70B Turbo:  ~180 tokens/秒
LLaMA 3.1 8B Turbo:   ~600 tokens/秒
Mixtral 8x7B:         ~120 tokens/秒
```$$,
'https://docs.together.ai/docs/inference-models', '2026-04-12', 2),

('together_ai', 'api', 'Together AI API 入門',
$$## セットアップ

OpenAI SDK をそのまま使えます。

```bash
pip install openai  # OpenAI SDK で OK
# または Together 専用 SDK
pip install together
```

## OpenAI 互換 API (最も簡単)

```python
from openai import OpenAI

# base_url を Together AI に変更するだけ
client = OpenAI(
    api_key="<TOGETHER_API_KEY>",
    base_url="https://api.together.xyz/v1"
)

# LLaMA 3.3 70B でテキスト生成
response = client.chat.completions.create(
    model="meta-llama/Meta-Llama-3.3-70B-Instruct-Turbo",
    messages=[
        {
            "role": "system",
            "content": "あなたは優秀な日本語アシスタントです。"
        },
        {
            "role": "user",
            "content": "Flutterでレスポンシブなレイアウトを実装するベストプラクティスを教えてください。"
        }
    ],
    max_tokens=512,
    temperature=0.7
)
print(response.choices[0].message.content)
```

## Together 専用 SDK

```python
from together import Together

client = Together(api_key="<TOGETHER_API_KEY>")

# ストリーミング出力
stream = client.chat.completions.create(
    model="meta-llama/Meta-Llama-3.1-405B-Instruct-Turbo",
    messages=[{"role": "user", "content": "日本のAI規制の現状と課題を詳しく説明してください。"}],
    stream=True,
)

for chunk in stream:
    print(chunk.choices[0].delta.content or "", end="", flush=True)
```

## Fine-tuning でカスタムモデルを作成

```python
import together

# 1. 学習データをアップロード (JSONL形式)
file_response = together.Files.upload(file="training_data.jsonl")
file_id = file_response["id"]

# 2. Fine-tuning ジョブを開始
ft_response = together.Finetune.create(
    training_file=file_id,
    model="meta-llama/Meta-Llama-3.1-8B-Instruct-Reference",
    n_epochs=3,
    suffix="my-custom-model"
)

job_id = ft_response["id"]
print(f"Fine-tuning 開始: {job_id}")

# 3. 完了後、カスタムモデルで推論
response = client.chat.completions.create(
    model=f"<YOUR_USERNAME>/Meta-Llama-3.1-8B-my-custom-model",
    messages=[{"role": "user", "content": "カスタムモデルへの質問"}]
)
```

## Embedding でベクトル検索

```python
from openai import OpenAI

client = OpenAI(
    api_key="<TOGETHER_API_KEY>",
    base_url="https://api.together.xyz/v1"
)

# 文書を Embedding 化
response = client.embeddings.create(
    model="togethercomputer/m2-bert-80M-8k-retrieval",
    input=["Flutter WebでSupabaseを使う方法", "Dartの非同期処理"]
)

embeddings = [item.embedding for item in response.data]
print(f"Embedding 次元数: {len(embeddings[0])}")
```

## 料金 (2026年4月時点, USD)

| モデル | 入力 (1M tokens) | 出力 (1M tokens) |
| :--- | :--- | :--- |
| **LLaMA 3.1 405B Turbo** | $5.00 | $5.00 |
| **LLaMA 3.3 70B Turbo** | $0.88 | $0.88 |
| **LLaMA 3.1 8B Turbo** | $0.18 | $0.18 |
| **Mixtral 8x7B** | $0.60 | $0.60 |
| **DeepSeek V3** | $1.25 | $1.25 |

- **無料クレジット**: 新規登録で $5 の無料クレジット
- **Fine-tuning**: 学習コスト $0.30/1M tokens + 推論コスト$$,
'https://docs.together.ai/docs/quickstart', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Together AI 追加 (22社目)',
  'Together AI を AI大学プロバイダーとして追加。200+オープンソースモデル対応・高速推論・Fine-tuning機能・OpenAI互換APIを収録。LLaMA/Mistral/DeepSeek/Qwenの使い方、カスタムモデル作成手順を掲載。AI大学プロバイダー数 21社→22社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
