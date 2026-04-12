-- AI21 Labs コンテンツシード
-- AI大学: AI21 Labs プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: Jamba MoEモデルはコンテキスト長256Kで業界トップ / SSM+Transformer融合アーキテクチャが革新的 / エンタープライズNLP特化 / イスラエル発AIリーダー

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('ai21', 'overview', 'AI21 Labs 概要',
$$AI21 Labs は2017年創業のイスラエルのAI企業。**Jamba シリーズ**で知られる革新的なアーキテクチャのLLMを開発しています。SSM (State Space Model) と Transformer を融合した独自の Mamba アーキテクチャを採用し、**256K という業界最長クラスのコンテキスト長**を実現しています。

## 特徴

- **Jamba**: SSM + Transformer ハイブリッドアーキテクチャ (Mamba ベース)。長文理解に革命的な効率性
- **256K コンテキスト**: 長大な法律文書・財務報告書・コードベース全体を一度に処理可能
- **高い推論効率**: 従来 Transformer に比べてメモリ効率が大幅に向上
- **エンタープライズ NLP**: テキスト要約・情報抽出・Q&A に特化したツールセット
- **OpenAI 互換 API**: 既存 SDK のコードをほぼ変更なしで利用可能

## 強み

| 領域 | 内容 |
| :--- | :--- |
| **コンテキスト長** | 256K tokens — 長大文書の一括処理に最適 |
| **アーキテクチャ革新** | SSM+Transformer融合でメモリ・速度効率が飛躍的に向上 |
| **長文要約** | 数百ページの文書を高精度で要約 |
| **情報抽出** | 非構造化テキストからエンティティ・関係を高精度で抽出 |
| **コスト効率** | 長文処理でのKVキャッシュ効率が高く、長コンテキストで他モデルより安価 |

## Jamba アーキテクチャの革新性

```text
従来の Transformer:
┌─────────────────────────────────────┐
│ Attention Layer (O(n²) 計算量)      │  ← 長文で急激にコスト増加
│ FFN Layer                           │
│ ...繰り返し...                     │
└─────────────────────────────────────┘

Jamba (SSM + Transformer 融合):
┌─────────────────────────────────────┐
│ Mamba SSM Layer (O(n) 計算量)       │  ← 長文でも線形コスト
│ Attention Layer (一部のみ)         │
│ MoE FFN Layer                       │
│ ...効率的な構成...                 │
└─────────────────────────────────────┘
```$$,
'https://www.ai21.com/', '2026-04-12', 1),

('ai21', 'models', 'AI21 Labs — 利用可能モデル (2026)',
$$AI21 Labs の主力は Jamba シリーズです。SSM+Transformer融合の革新的アーキテクチャを採用しています。

## Jamba シリーズ

| モデル | コンテキスト | パラメータ | 特徴 |
| :--- | :--- | :--- | :--- |
| **jamba-1.5-large** | 256K | 398B (active: 94B) | 最大・最高精度。長文書処理の最高峰 |
| **jamba-1.5-mini** | 256K | 52B (active: 12B) | 高速・コスト効率重視。256Kを維持 |

## MoE (Mixture of Experts) 構成

Jamba は MoE アーキテクチャを採用。全パラメータのうち活性化されるのは一部のみ:

```text
jamba-1.5-large:
- 総パラメータ: 398B
- 推論時活性化: 94B (全体の24%)
- エキスパート数: 16 (各トークンで8が活性化)
- コンテキスト: 256K tokens

jamba-1.5-mini:
- 総パラメータ: 52B
- 推論時活性化: 12B (全体の23%)
- コンテキスト: 256K tokens
```

## ユースケース別推奨

| ユースケース | 推奨モデル |
| :--- | :--- |
| 法律文書・契約書全文分析 | **jamba-1.5-large** (長文・高精度) |
| 財務報告書 100ページ要約 | **jamba-1.5-large** |
| リアルタイムチャットボット | **jamba-1.5-mini** (高速) |
| コードリポジトリ全体分析 | **jamba-1.5-large** (256K活用) |
| バッチ文書処理 | **jamba-1.5-mini** (コスト効率) |$$,
'https://docs.ai21.com/docs/jamba-models', '2026-04-12', 2),

('ai21', 'api', 'AI21 Labs API 入門',
$$## セットアップ

```bash
pip install ai21
# または OpenAI SDK でも利用可能
pip install openai
```

## Python SDK でテキスト生成

```python
from ai21 import AI21Client

client = AI21Client(api_key="<AI21_API_KEY>")

# Jamba 1.5 Large で長文処理
response = client.chat.completions.create(
    model="jamba-1.5-large",
    messages=[
        {
            "role": "system",
            "content": "あなたは法律文書の分析専門家です。"
        },
        {
            "role": "user",
            "content": "以下の契約書 (256K tokens まで対応) の重要条項を抽出し、リスクポイントを指摘してください。\n\n[契約書本文をここに挿入]"
        }
    ],
    max_tokens=2000,
    temperature=0.3,  # 低めで事実に忠実な出力
)

print(response.choices[0].message.content)
```

## OpenAI 互換エンドポイント

```python
from openai import OpenAI

# AI21 Labs は OpenAI 互換 API を提供
client = OpenAI(
    api_key="<AI21_API_KEY>",
    base_url="https://api.ai21.com/studio/v1"
)

response = client.chat.completions.create(
    model="jamba-1.5-mini",
    messages=[
        {"role": "user", "content": "SSMとTransformerの違いを分かりやすく説明してください。"}
    ],
    max_tokens=500,
)
print(response.choices[0].message.content)
```

## 256K コンテキストを活用した長文要約

```python
from ai21 import AI21Client

client = AI21Client(api_key="<AI21_API_KEY>")

# 長大な PDF をテキスト化して一括要約
def summarize_long_document(document_text: str) -> str:
    """256K コンテキストを活用して長文書を要約する"""

    response = client.chat.completions.create(
        model="jamba-1.5-large",
        messages=[
            {
                "role": "system",
                "content": "与えられた文書を以下の形式で日本語で要約してください:\n"
                           "1. エグゼクティブサマリー (3文以内)\n"
                           "2. 主要ポイント (5〜10箇条)\n"
                           "3. アクションアイテム (あれば)\n"
                           "4. リスク・懸念事項 (あれば)"
            },
            {
                "role": "user",
                "content": f"以下の文書を要約してください:\n\n{document_text}"
            }
        ],
        max_tokens=1500,
        temperature=0.2,
    )

    return response.choices[0].message.content

# 使用例
with open("annual_report_2025.txt", "r", encoding="utf-8") as f:
    doc = f.read()  # 最大 ~200K words まで対応

summary = summarize_long_document(doc)
print(summary)
```

## ストリーミング

```python
from ai21 import AI21Client

client = AI21Client(api_key="<AI21_API_KEY>")

stream = client.chat.completions.create(
    model="jamba-1.5-mini",
    messages=[{"role": "user", "content": "Jamba アーキテクチャの技術的な革新点を詳しく説明してください。"}],
    max_tokens=1000,
    stream=True,
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
```

## 料金 (2026年4月時点, USD)

| モデル | 入力 (1M tokens) | 出力 (1M tokens) |
| :--- | :--- | :--- |
| **Jamba 1.5 Large** | $2.00 | $8.00 |
| **Jamba 1.5 Mini** | $0.20 | $0.40 |

- **256K 長文処理のコスト優位性**: 従来 Transformer モデルは長文でKVキャッシュが急増するため、Jamba は同コンテキスト長でコスト優位
- **無料トライアル**: API登録で初期クレジットが付与$$,
'https://docs.ai21.com/docs/quickstart', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 AI21 Labs 追加 (26社目)',
  'AI21 Labs を AI大学プロバイダーとして追加。Jamba シリーズ (SSM+Transformer融合・MoE・256Kコンテキスト) の革新的アーキテクチャ解説、長文書要約・法務文書分析の実装例を収録。OpenAI互換APIでの利用方法も掲載。AI大学プロバイダー数 25社→26社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
