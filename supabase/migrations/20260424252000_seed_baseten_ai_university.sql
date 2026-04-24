-- Session PS#3-S36: AI大学 167社化 — Baseten 追加
-- 2020 年創業のサーバーレス ML 推論プラットフォーム。
-- 2026-01 Series E $300M (IVP + CapitalG + Nvidia $150M) @ $5B 評価額 / 累計 ~$585M。
-- 週数十億件の LLM コール処理 / YoY 10× 収益成長。
-- OpenAI 互換 Model API + Chains SDK (マルチモデルワークフロー) + Dedicated Deployments。
-- GPU 秒課金: T4 $0.63/h / H100 $6.50/h / B200 $9.98/h / Google Cloud A4 Blackwell で 225% 高効率。
-- Nvidia が $150M 投資: Nvidia DGX Cloud との統合を予定。
-- 既存 166 社の「高性能 ML 推論インフラ (エンタープライズ向け)」軸を埋める。
-- Step 0: 9/9 (Series E $5B / Nvidia $150M / 10× 収益 / OpenAI互換 / Chains SDK / Blackwell 225%)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'baseten',
  'overview',
  'Baseten — エンタープライズ ML 推論インフラ (Nvidia 出資 / $5B 評価)',
  $md$
# Baseten — Production ML Inference Platform

2020 年創業。機械学習モデルを **本番グレードの推論 API** として即座にデプロイできる
サーバーレスプラットフォーム。

2026 年 1 月に **Series E $300M** (IVP + CapitalG 主導 / **Nvidia が $150M** 投資) を完了し、
評価額 **$5B** に到達。累計調達額 **~$585M**。
週数十億件 の LLM コールを処理し、**YoY 10× の収益成長**を達成。

Google Cloud の最新 A4 VM (Nvidia Blackwell) を活用し、
**高スループット推論で 225% のコストパフォーマンス向上** を実現。

## 主要プロダクト

| プロダクト | 説明 |
| :--- | :--- |
| **Model APIs** | Llama・DeepSeek 等 OSS モデルをワンクリックで OpenAI 互換 API として提供 |
| **Dedicated Deployments** | 特定 GPU インスタンスを選択 / 自動スケール設定 / 完全な制御 |
| **Chains SDK** | マルチモデルワークフロー — 各ステップが異なる GPU で並列実行 |

## 強み

- **OpenAI 互換 API** — 既存コードを `base_url` 変更のみで Baseten モデルに切り替え
- **OpenAI 比 50%+ 安価** — 同等モデルをより低コストで提供
- **Chains SDK** — embedding → LLM → reranker を 1 パイプラインで高速実行
- **Nvidia 出資** — DGX Cloud との統合・最新 GPU への優先アクセス
- **Blackwell A4** — Google Cloud との共同最適化で業界最高水準コストパフォーマンス
$md$,
  'https://www.baseten.co/',
  '2026-04-24',
  1
),

(
  'baseten',
  'models',
  'Baseten GPU プラン・Model API 一覧 (2026)',
  $md$
## GPU 価格 (分単位課金)

| GPU | VRAM | 時間単価 | 用途 |
| :--- | :--- | :--- | :--- |
| **T4** | 16 GB | $0.63/h | 軽量推論・コスト重視 |
| **A10G** | 24 GB | $1.21/h | 中規模推論 |
| **A100 (80GB)** | 80 GB | $4.00/h | 大型モデル |
| **H100** | 80 GB | $6.50/h | 高スループット学習・推論 |
| **B200 (Blackwell)** | 192 GB | $9.98/h | 最新世代・最大規模 |

> OpenAI 互換 Model API はトークン課金 (OpenAI 比 50%+ 安価)

## サポートモデル (Model APIs)

| カテゴリ | モデル |
| :--- | :--- |
| **LLM** | Llama 3.1/3.3 / DeepSeek-R1 / Mistral / Qwen |
| **Embedding** | nomic-embed / BGE-M3 / E5-mistral |
| **Vision** | LLaVA / Llama-3.2-Vision |
| **Code** | DeepSeek-Coder / Codestral |

## Chains SDK — マルチモデルワークフロー

```
入力 → [A10G: Embedding] → [H100: LLM] → [A10G: Reranker] → 出力
```

各ステップが独立した GPU で実行 → リソース無駄ゼロ / コスト最適化

## エンタープライズ機能

| 機能 | 説明 |
| :--- | :--- |
| **SLA** | 99.9% 可用性保証 |
| **VPC** | カスタム VPC / プライベートエンドポイント |
| **監査ログ** | SOC2 準拠 / エンタープライズセキュリティ |
| **モデル保護** | カスタムモデルの重みを安全に管理 |
$md$,
  'https://www.baseten.co/pricing/',
  '2026-04-24',
  2
),

(
  'baseten',
  'api',
  'Baseten API 入門',
  $md$
## Baseten の始め方

### OpenAI 互換 Model API

```python
# pip install openai  (OpenAI SDK で Baseten モデルを呼び出し)

from openai import OpenAI

# Baseten の OpenAI 互換エンドポイント
client = OpenAI(
    api_key="YOUR_BASETEN_API_KEY",
    base_url="https://api.baseten.co/v1"
)

# Llama 3.1 を OpenAI API と同じ形式で呼び出し
response = client.chat.completions.create(
    model="llama-3-1-70b-instruct",
    messages=[
        {"role": "system", "content": "AI 大学の優秀な教授として回答してください。"},
        {"role": "user",   "content": "Baseten と Modal の違いは何ですか？"}
    ]
)

print(response.choices[0].message.content)
```

### Chains SDK — マルチモデルパイプライン

```python
from baseten.chains import Chain, Step

# 各ステップを異なる GPU で実行するパイプライン
chain = Chain(
    steps=[
        Step(
            name="embed",
            model="nomic-embed-text",
            gpu="A10G",
        ),
        Step(
            name="generate",
            model="llama-3-1-70b-instruct",
            gpu="H100",
        ),
    ]
)

result = chain.run({"query": "最新の AI ニュースを教えて"})
```

### Dedicated Deployment (カスタムモデル)

```python
import baseten

# カスタムモデルをデプロイ (Truss 形式)
model = baseten.deploy(
    "path/to/your/model",
    model_name="my-custom-llm",
    gpu="A100",
    min_replicas=1,
    max_replicas=10
)

# デプロイ後の API 呼び出し
import requests
response = requests.post(
    f"https://model-{model.model_id}.api.baseten.co/production/predict",
    headers={"Authorization": "Api-Key YOUR_KEY"},
    json={"prompt": "こんにちは、AI 大学！"}
)
```

## クイックスタート

1. [baseten.co](https://www.baseten.co) でアカウント作成
2. `pip install baseten` でインストール
3. Model APIs → Llama 3.1 等をワンクリックでデプロイ
4. OpenAI SDK の `base_url` を変更するだけで既存コードから呼び出し可能
$md$,
  'https://docs.baseten.co/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
