-- Session PS#3-S40: AI大学 176社化 — Patronus AI 追加
-- Meta AI 出身者 (Anand Kannappan + Rebecca Qian) 創業の LLM 自動評価・安全プラットフォーム。
-- 累計 $40.1M (Notable Capital Series A 主導 / Lightspeed / Datadog Ventures)。
-- 業界初: FinanceBench (金融 LLM ベンチマーク) + CopyrightCatcher (著作権検出 API)。
-- 50+ 障害カテゴリでの失敗検出 / 敵対的テストケース自動生成 / Percival エージェント評価 copilot。
-- 顧客: AngelList / Etsy / Pearson / Cohere / Nomic AI。
-- Step 0: 7/9 (Meta AI founders / $40.1M Lightspeed / FinanceBench / CopyrightCatcher / 50+カテゴリ)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'patronus_ai',
  'overview',
  'Patronus AI — LLM 自動評価・安全プラットフォーム (Meta AI 創業 / FinanceBench / CopyrightCatcher)',
  $md$
# Patronus AI — LLM Evaluation & Safety at Scale

Meta AI 出身のエンジニア **Anand Kannappan と Rebecca Qian** が創業した、
LLM の失敗を大規模に自動検出するプラットフォーム。

累計 **$40.1M** を調達 (Notable Capital Series A 主導 / Lightspeed Venture Partners /
Datadog Ventures / Gokul Rajaram / Factorial Capital)。

**業界初**の金融 LLM ベンチマーク「FinanceBench」と
著作権侵害検出 API「CopyrightCatcher」を公開し、技術的優位性を確立。

## 主要機能

| 機能 | 説明 |
| :--- | :--- |
| **自動評価スコアリング** | LLM の出力を 50+ 失敗カテゴリで自動採点 |
| **敵対的テスト生成** | ハルシネーション・越境・不整合を誘発するテストケースを自動生成 |
| **ベンチマーキング** | モデル間・バージョン間のパフォーマンス比較 |
| **Percival** | エージェント評価専用の AI コパイロット (agentic eval) |
| **RL 環境** | LLM のファインチューニング・強化学習用評価環境 |

## 独自技術

### FinanceBench
金融ドメイン特化の LLM 評価ベンチマーク。
財務諸表・会計・コンプライアンスに関する質問で LLM の精度を測定する
**業界初**の金融専用標準。

### CopyrightCatcher
LLM の出力が著作権で保護されたコンテンツを再現しているかを検出する
**業界初**の著作権検出 API。エンタープライズの法的リスクを自動評価。

## 顧客

AngelList / Etsy / Pearson / Cohere / Nomic AI
$md$,
  'https://www.patronus.ai/',
  '2026-04-24',
  1
),

(
  'patronus_ai',
  'models',
  'Patronus AI 失敗カテゴリ & 評価機能詳細 (2026)',
  $md$
## 50+ 失敗カテゴリ (一部)

### 事実精度
| カテゴリ | 説明 |
| :--- | :--- |
| **Hallucination** | 事実に基づかない情報の生成 |
| **Factual Inconsistency** | 入力文書と矛盾する回答 |
| **Outdated Information** | 古い・更新されていない情報の出力 |

### 安全性
| カテゴリ | 説明 |
| :--- | :--- |
| **Copyright Infringement** | 著作権コンテンツの無断複製 |
| **PII Leakage** | 個人情報の漏洩 |
| **Prompt Injection** | 悪意あるプロンプトによる制御権奪取 |
| **Jailbreak** | 安全ガードレールの迂回 |

### 品質
| カテゴリ | 説明 |
| :--- | :--- |
| **Relevance** | クエリと関連しない回答 |
| **Completeness** | 必要な情報が不完全 |
| **Toxicity** | 有害・差別的コンテンツ |

## Percival — エージェント評価 AI コパイロット

マルチエージェントシステム特有の評価課題に対応:
- エージェントの思考過程・ツール使用をステップごとに評価
- ゴール達成率・迂回経路・失敗ポイントを自動特定
- フィードバックループで評価基準を継続改善

## RL 環境 (強化学習)

LLM の後学習 (Post-Training) 向けに、
Patronus の評価スコアを報酬シグナルとして利用できる RL 環境を提供。
モデルの品質を評価駆動で改善するフィードバックループを実現。
$md$,
  'https://www.patronus.ai/product/features',
  '2026-04-24',
  2
),

(
  'patronus_ai',
  'api',
  'Patronus AI API 入門 — 自動 LLM 評価',
  $md$
## Patronus AI の始め方

### インストール & セットアップ

```bash
pip install patronus
export PATRONUS_API_KEY="pat-..."
```

### 基本的な LLM 評価

```python
from patronus import Client
from anthropic import Anthropic

patronus = Client()
anthropic_client = Anthropic()

def get_claude_response(question: str) -> str:
    msg = anthropic_client.messages.create(
        model="claude-opus-4-7",
        max_tokens=512,
        messages=[{"role": "user", "content": question}]
    )
    return msg.content[0].text

# LLM の回答を Patronus で自動評価
result = patronus.evaluate(
    evaluator="patronus:hallucination",   # ハルシネーション検出
    evaluated_model_input="CrewAI とは何ですか？",
    evaluated_model_output=get_claude_response("CrewAI とは何ですか？"),
    evaluated_model_retrieved_context=[
        "CrewAI は Fortune 500 の 60% が採用するマルチエージェントフレームワークです。"
    ],
)
print(f"スコア: {result.score} / 合格: {result.pass_}")
```

### 複数の評価器を同時実行

```python
from patronus import Client

patronus = Client()

# 複数の評価器を並列実行
results = patronus.evaluate_batch(
    evaluators=[
        "patronus:hallucination",
        "patronus:toxicity",
        "patronus:relevance",
        "patronus:completeness",
    ],
    evaluated_model_input="AI大学の最も注目すべきプロバイダーは？",
    evaluated_model_output=get_claude_response("AI大学の最も注目すべきプロバイダーは？"),
)

for evaluator, result in zip(results.evaluators, results.results):
    status = "✅" if result.pass_ else "❌"
    print(f"{status} {evaluator}: {result.score:.2f}")
```

### CopyrightCatcher — 著作権検出

```python
from patronus import Client

patronus = Client()

# LLM 出力の著作権侵害を自動検出
copyright_result = patronus.evaluate(
    evaluator="patronus:copyright-catcher",
    evaluated_model_output="""
    "昨日 死んだような 今日を生きるのではなく..." (著名な歌詞の模倣)
    """,
)

if not copyright_result.pass_:
    print(f"著作権侵害の可能性: {copyright_result.explanation}")
    # → 本番への出力をブロック
```

### CI/CD 統合 (pytest)

```python
# test_llm_quality.py
import pytest
from patronus import Client

patronus = Client()

@pytest.mark.parametrize("question", [
    "LangSmith とは？",
    "CrewAI の採用率は？",
    "Braintrust の特徴は？",
])
def test_no_hallucination(question):
    response = get_claude_response(question)
    result = patronus.evaluate(
        evaluator="patronus:hallucination",
        evaluated_model_input=question,
        evaluated_model_output=response,
    )
    assert result.pass_, f"ハルシネーション検出: {result.explanation}"
```

## クイックスタート

1. `pip install patronus` でインストール
2. `PATRONUS_API_KEY` を設定
3. `patronus.evaluate(evaluator="patronus:hallucination", ...)` で 1 行評価
4. 50+ 評価器から用途に合わせて選択
5. pytest に組み込んで CI/CD の品質ゲートとして自動化
$md$,
  'https://docs.patronus.ai/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
