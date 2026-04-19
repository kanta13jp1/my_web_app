-- Lambda Labs 初期コンテンツシード (2026-04-19)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('lambda_labs', 'overview', 'Lambda Labs 概要',
$$Lambda Labs は AI/ML ワークロード特化の GPU クラウドプロバイダー。2012 年創業、シリコンバレー拠点。元々は研究者向けに NVIDIA GPU を時間貸しする「Lambda Cloud」で有名。

2024 年に **Lambda Inference API** を発表 — 業界最安値級 (Llama 3.3 70B FP8 で $0.20/M tokens) のサーバーレス推論サービス。OpenAI 互換 API を提供し既存コードからの drop-in を狙った。

ただし **2025 年後半に Inference API は wind-down (段階的廃止) 方針**を発表。今後は GPU 直接 (B200/H100) 賃貸モデルに集中する見込み。

## 主要サービス
- **Lambda Cloud (GPU)**: H100 $2.89/hr / B200 $3.49/hr (業界最安値級)
- **Lambda Inference API** (廃止予定): OpenAI 互換 / Llama / DeepSeek / Hermes / Qwen
- **1-Click Clusters**: H100 マルチノードを 1 クリックでプロビジョン
- **オンプレ Lambda Stack**: PyTorch + TensorFlow + ドライバを bundled

## 強み
- **業界最安 GPU レンタル**: cheapest on-demand H100
- **AI 研究者御用達**: 大学・スタートアップで実績多数
- **OpenAI 互換 SDK**: drop-in 可能 (Inference API)
- **Lambda Stack**: NVIDIA ドライバ問題から解放$$,
'https://lambda.ai/', '2026-04-19', 1),

('lambda_labs', 'models', 'Lambda Labs モデル・GPU 一覧 (2026)',
$$## Lambda Inference API 提供モデル (廃止予定)

| モデル | 入力 ($/M) | 出力 ($/M) | 用途 |
| :--- | :--- | :--- | :--- |
| **Llama 3.2 3B** | $0.02 | $0.02 | 軽量推論 |
| **Llama 3.3 70B FP8** | $0.20 | $0.20 | 標準汎用 |
| **Llama 3.1 405B** | $0.90 | $0.90 | 大規模推論 |
| **DeepSeek Chat** | $0.27 | $1.10 | 推論コスパ |
| **Hermes 3 70B** | $0.20 | $0.20 | tool use 強化 |
| **Qwen 2.5 72B** | $0.20 | $0.20 | 多言語 |

## GPU レンタル ラインナップ

| GPU | 時間単価 | VRAM | 用途 |
| :--- | :--- | :--- | :--- |
| **H100** | $2.89/hr | 80GB | LLM 学習・推論 |
| **B200** | $3.49/hr | 192GB | 大規模学習 |
| **A100 40GB** | $1.10/hr | 40GB | 標準 |
| **A100 80GB** | $1.79/hr | 80GB | 大規模推論 |

## 特徴的な機能
- **1-Click Clusters**: H100 を 1 クリックでマルチノード化
- **Lambda Stack**: 1 コマンドで CUDA + PyTorch 環境構築
- **OpenAI compat (Inference API)**: 既存コード drop-in
- **Reserved instances**: 1 年契約で大幅 discount$$,
'https://docs.lambda.ai/', '2026-04-19', 2),

('lambda_labs', 'api', 'Lambda Labs API 入門',
$$## Lambda Inference API の始め方 (廃止予定 — 2025 wind-down 方針)

```python
# OpenAI SDK そのまま (drop-in replacement)
from openai import OpenAI

client = OpenAI(
    api_key="<LAMBDA_API_KEY>",
    base_url="https://api.lambdalabs.com/v1",
)

response = client.chat.completions.create(
    model="llama3.3-70b-instruct-fp8",
    messages=[
        {"role": "user", "content": "こんにちは!"}
    ],
)
print(response.choices[0].message.content)
```

## GPU インスタンス起動 (推奨パス)

```bash
# Lambda Cloud で B200 8 GPU クラスタを起動
lambda-cloud-cli launch \
  --instance-type gpu_8x_b200 \
  --region us-east-1
```

## 料金 (2026年4月時点)
- **Lambda Inference API** (廃止予定):
  - Llama 3.3 70B FP8: $0.20 / 100万 token (業界最安級)
- **Lambda Cloud GPU**:
  - H100 on-demand: $2.89/hr
  - B200 on-demand: $3.49/hr
  - Reserved 1yr で 30〜50% discount

## 注意事項
- **Inference API は wind-down 中** — 新規プロジェクトには Inworld Router / DeepInfra / Together AI を推奨
- GPU 直接利用は引き続き継続$$,
'https://lambda.ai/inference', '2026-04-19', 3)

ON CONFLICT DO NOTHING;
