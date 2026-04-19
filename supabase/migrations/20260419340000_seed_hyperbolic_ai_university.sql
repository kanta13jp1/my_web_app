-- Hyperbolic Labs 初期コンテンツシード (2026-04-19)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('hyperbolic', 'overview', 'Hyperbolic Labs 概要',
$$Hyperbolic Labs は **分散 GPU クラウド + 検証可能 AI 推論**プラットフォーム。2022 年創業、2024-12 に Series A $12M 調達 (累計 $20M)。

「世界中の遊休 GPU を blockchain ベースで集約する」コンセプトで AWS/GCP より圧倒的に低コストの GPU レンタル + AI 推論を実現。Hyper-dOS という独自分散 OS で global GPU network を一元管理。

## 主要サービス
- **GPU レンタル**: RTX 4090 \$0.50/hr / A100 \$1.80/hr / H100 \$3.20/hr
- **AI Inference API**: Llama / DeepSeek / Qwen 等 OSS モデルを OpenAI 互換 API で
- **Verifiable AI**: zk proof で推論結果の検証可能性
- **Hyper-dOS**: 分散 GPU を統一管理する OS layer

## 強み
- **超低コスト GPU**: AWS/GCP の 1/2 〜 1/4 価格
- **検証可能性 (verifiability)**: zk-snarks で出力改竄を検知
- **データプライバシー**: 推論データは GPU プロバイダーに残らない
- **decentralized**: 単一障害点なし$$,
'https://www.hyperbolic.ai/', '2026-04-19', 1),

('hyperbolic', 'models', 'Hyperbolic Labs モデル・GPU 一覧 (2026)',
$$## GPU 提供ラインナップ

| GPU | 時間単価 | 用途 |
| :--- | :--- | :--- |
| **RTX 4090** | \$0.50/hr | 軽量推論・実験 |
| **A100 80GB** | \$1.80/hr | 標準推論 |
| **H100** | \$3.20/hr | 大規模推論・学習 |

## Inference API 提供モデル

| モデル | 用途 |
| :--- | :--- |
| Llama 3.3 70B | 汎用推論 |
| DeepSeek V3 | コスパ推論 |
| Qwen 2.5 72B | 多言語 |
| Hermes 3 | tool use |
| Reflection 70B | reasoning |

## 特徴的な機能
- **OpenAI 互換 API**: drop-in 可能
- **zk proof 検証**: 推論結果の改竄検知 (verifiable AI)
- **multi-region**: global GPU network から最寄り選択
- **Hyper-dOS**: クラスタ・スケジューラ統合管理$$,
'https://docs.hyperbolic.xyz/', '2026-04-19', 2),

('hyperbolic', 'api', 'Hyperbolic Labs API 入門',
$$## Hyperbolic Inference API の始め方

```python
# OpenAI SDK そのまま (drop-in replacement)
from openai import OpenAI

client = OpenAI(
    api_key="<HYPERBOLIC_API_KEY>",
    base_url="https://api.hyperbolic.xyz/v1",
)

response = client.chat.completions.create(
    model="meta-llama/Meta-Llama-3.3-70B-Instruct",
    messages=[
        {"role": "user", "content": "こんにちは!"}
    ],
)
print(response.choices[0].message.content)
```

## GPU 直接利用

```bash
# Hyperbolic CLI で H100 を 1 時間借りる
hyperbolic-cli launch --gpu h100 --hours 1
```

## 料金 (2026年4月時点)
- **Inference API**: モデル別従量課金 (詳細は公式)
- **GPU レンタル**:
  - RTX 4090: \$0.50/hr
  - A100 80GB: \$1.80/hr
  - H100: \$3.20/hr
  - AWS/GCP の 1/2 〜 1/4 価格

## 公式リソース
- [Hyperbolic Docs](https://docs.hyperbolic.xyz/)
- [Hyperbolic Models](https://app.hyperbolic.xyz/models)$$,
'https://docs.hyperbolic.xyz/', '2026-04-19', 3)

ON CONFLICT DO NOTHING;
