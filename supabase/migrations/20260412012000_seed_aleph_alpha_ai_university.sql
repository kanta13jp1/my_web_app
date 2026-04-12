-- Aleph Alpha コンテンツシード
-- AI大学: Aleph Alpha プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: 欧州AI主権の象徴的企業 / ドイツ政府・EU機関が採用 / GDPR完全準拠 / 説明可能AI (Explainability) に強み

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('aleph_alpha', 'overview', 'Aleph Alpha 概要',
$$Aleph Alpha は2020年にドイツ・ハイデルベルクで設立されたAIスタートアップ。**欧州AIソブリンティ（AI主権）**の代表的企業として、ドイツ連邦政府・EU機関・欧州の主要企業に採用されています。

## 特徴

- **Luminous シリーズ**: テキスト・画像・コードに対応したマルチモーダルモデル
- **Pharia シリーズ**: 次世代の高性能モデル。エンタープライズ向けに最適化
- **説明可能AI (Explainability)**: モデルの推論根拠を可視化できる「AtMan」技術を実装
- **欧州データ主権**: データはドイツ国内のデータセンターのみで処理。EU外への転送なし
- **GDPR完全準拠**: EU一般データ保護規則に完全対応

## 強み

| 領域 | 内容 |
| :--- | :--- |
| **規制対応** | GDPR・NIS2・EUアクト完全準拠。金融・医療・公共機関に最適 |
| **説明可能性** | AtMan技術でモデルの判断根拠をトークン単位で可視化 |
| **ソブリンAI** | データがEU域外に出ない保証。政府・防衛向けプライベートデプロイ可能 |
| **欧州言語** | ドイツ語・フランス語・オランダ語等の欧州言語に特化学習 |
| **エンタープライズ SLA** | 99.9%可用性保証・専用インスタンス・オンプレミスデプロイ対応 |

## 主要採用事例

- **ドイツ連邦政府**: 行政文書処理・市民サービスのAI化
- **欧州宇宙機関 (ESA)**: 衛星データ解析
- **BMW・Siemens**: 製造・エンジニアリング AI支援
- **Deutsche Bank**: 規制準拠のAI活用$$,
'https://aleph-alpha.com/', '2026-04-12', 1),

('aleph_alpha', 'models', 'Aleph Alpha — 利用可能モデル (2026)',
$$Aleph Alpha は Luminous シリーズと次世代 Pharia シリーズを提供しています。

## Pharia シリーズ (次世代・推奨)

| モデル | コンテキスト | 特徴 |
| :--- | :--- | :--- |
| **pharia-1-llm-7b-control** | 4K | 高速・低コスト。指示追従型 |
| **pharia-1-llm-7b-control-aligned** | 4K | セーフティアラインメント強化版 |

## Luminous シリーズ (安定版)

| モデル | パラメータ | コンテキスト | 特徴 |
| :--- | :--- | :--- | :--- |
| **luminous-supreme** | 70B | 2048 | 最大・最高精度。複雑な推論 |
| **luminous-supreme-control** | 70B | 2048 | 指示追従特化。RAG・要約に最適 |
| **luminous-extended** | 30B | 2048 | バランス型。汎用タスク |
| **luminous-extended-control** | 30B | 2048 | 指示追従型バランスモデル |
| **luminous-base** | 13B | 2048 | 軽量・高速。微調整ベースに最適 |

## Embedding モデル

| モデル | 次元 | 用途 |
| :--- | :--- | :--- |
| **luminous-base** (Embedding モード) | 128〜5120 | 意味検索・クラスタリング |

## AtMan — 説明可能AI の例

```python
import aleph_alpha_client

# 推論の根拠（どのトークンに注目したか）を可視化
response = client.explain(
    ExplainRequest(
        prompt=Prompt.from_text("このメールは詐欺ですか？\n\n件名: あなたは100万円当選しました"),
        target=" はい、詐欺の可能性があります",
        control_factor=0.1,
    )
)

# 各入力トークンの寄与度を取得
for item in response.explanations[0].items:
    print(f"'{item.text}': 寄与度 {item.score:.3f}")
```$$,
'https://docs.aleph-alpha.com/docs/introduction/luminous/', '2026-04-12', 2),

('aleph_alpha', 'api', 'Aleph Alpha API 入門',
$$## セットアップ

```bash
pip install aleph-alpha-client
```

## Python SDK でテキスト生成

```python
from aleph_alpha_client import Client, CompletionRequest, Prompt

# クライアント初期化
client = Client(token="<ALEPH_ALPHA_API_KEY>")

# テキスト生成 (Luminous Supreme Control)
response = client.complete(
    CompletionRequest(
        prompt=Prompt.from_text(
            "以下の契約書の重要ポイントを3点に要約してください：\n\n"
            "第1条：本契約は2026年4月1日より発効する。\n"
            "第2条：甲は乙に対し月額100万円の報酬を支払う。\n"
            "第3条：契約期間は1年間とし、自動更新とする。"
        ),
        model="luminous-supreme-control",
        maximum_tokens=200,
        stop_sequences=["###"],
    )
)

print(response.completions[0].completion)
```

## OpenAI 互換 API (Pharia シリーズ)

```python
from openai import OpenAI

# Aleph Alpha Pharia は OpenAI 互換エンドポイントを提供
client = OpenAI(
    api_key="<ALEPH_ALPHA_API_KEY>",
    base_url="https://api.aleph-alpha.com/v1"
)

response = client.chat.completions.create(
    model="pharia-1-llm-7b-control",
    messages=[
        {
            "role": "system",
            "content": "あなたはドイツの法律・規制に詳しいAIアシスタントです。"
        },
        {
            "role": "user",
            "content": "GDPRとAI Actの主な違いを教えてください。"
        }
    ],
    max_tokens=500
)
print(response.choices[0].message.content)
```

## Embedding でセマンティック検索

```python
from aleph_alpha_client import Client, SemanticEmbeddingRequest, Prompt, SemanticRepresentation

client = Client(token="<ALEPH_ALPHA_API_KEY>")

# 文書を Embedding 化
docs = [
    "GDPRは個人データの保護に関するEUの規則です。",
    "AI Actは人工知能システムのリスク分類・規制を定める法律です。",
    "NIS2指令はサイバーセキュリティの基準を強化します。"
]

embeddings = []
for doc in docs:
    response = client.semantic_embed(
        SemanticEmbeddingRequest(
            prompt=Prompt.from_text(doc),
            representation=SemanticRepresentation.Document,
            compress_to_size=128,
        )
    )
    embeddings.append(response.embedding)

# クエリを Embedding 化して類似度検索
query_response = client.semantic_embed(
    SemanticEmbeddingRequest(
        prompt=Prompt.from_text("人工知能の規制について"),
        representation=SemanticRepresentation.Query,
        compress_to_size=128,
    )
)

# コサイン類似度で最も関連する文書を検索
import numpy as np
similarities = [np.dot(query_response.embedding, e) for e in embeddings]
best_match = docs[np.argmax(similarities)]
print(f"最も関連する文書: {best_match}")
```

## 料金 (2026年4月時点, USD)

| モデル | 入力 (1K tokens) | 出力 (1K tokens) |
| :--- | :--- | :--- |
| **Luminous Supreme** | $0.0175 | $0.0175 |
| **Luminous Extended** | $0.0045 | $0.0045 |
| **Luminous Base** | $0.0030 | $0.0030 |
| **Pharia 7B Control** | $0.0010 | $0.0010 |

- **無料トライアル**: 開発者向けに初期クレジット提供
- **エンタープライズ契約**: プライベートデプロイ・オンプレミス・専有インスタンス対応$$,
'https://docs.aleph-alpha.com/docs/introduction/getting-started/', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Aleph Alpha 追加 (21社目)',
  'Aleph Alpha を AI大学プロバイダーとして追加。欧州AI主権・GDPR完全準拠・AtMan説明可能AI技術を中心に、Luminous/Phariaモデル、OpenAI互換API、セマンティック検索実装例を収録。AI大学プロバイダー数 20社→21社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
