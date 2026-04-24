-- Session PS#3-S39: AI大学 174社化 — Confident AI (DeepEval) 追加
-- LLM 評価 OSS フレームワーク DeepEval を提供する AI 品質プラットフォーム。
-- DeepEval: Apache 2.0 / GitHub stars 急増 / Pytest 互換 / 50+ 研究ベースメトリクス。
-- G-Eval (GPT-4o で任意基準を評価) / RAG メトリクス (文脈精度・文脈再現率) / マルチターン評価。
-- Confident AI: Cloud プラットフォーム — データセット管理 / トレーシング / 本番監視 / チームコラボ。
-- CI/CD 統合: pytest runner でパイプライン自動テスト (退行を PR 段階で検出)。
-- Step 0: 7/9 (DeepEval Apache 2.0 / 50+メトリクス / Pytest互換 / CI統合 / RAG+Agent特化評価)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'confident_ai',
  'overview',
  'Confident AI / DeepEval — LLM 評価 OSS フレームワーク & AI 品質プラットフォーム',
  $md$
# Confident AI — The AI Quality Platform

Confident AI は、OSS LLM 評価フレームワーク **DeepEval** を提供する AI 品質プラットフォーム。

DeepEval は「**LLM アプリのための Pytest**」として設計された Apache 2.0 の完全 OSS。
GitHub で急速に stars を獲得し、LLM 評価の事実上の標準フレームワークになりつつある。

## 2 つのプロダクト

### DeepEval (OSS)
完全 OSS (Apache 2.0) の LLM 評価フレームワーク。
**50+ の研究ベースメトリクス**を Pytest と同じ感覚で使える。

```python
# Pytest と同じ書き方で LLM を評価
assert_test(LLMTestCase(...), [AnswerRelevancyMetric()])
```

### Confident AI (クラウド)
DeepEval の上に構築されたチーム向けクラウドプラットフォーム。
データセット管理・トレーシング・本番監視・ダッシュボードを統合提供。

## 対応評価カテゴリ

| カテゴリ | メトリクス |
| :--- | :--- |
| **RAG 評価** | 文脈精度 / 文脈再現率 / 回答関連性 / 忠実性 |
| **エージェント評価** | タスク完了率 / ツール使用精度 |
| **安全性** | ハルシネーション / 有害コンテンツ / バイアス |
| **チャット** | 会話関連性 / マルチターン評価 |
| **カスタム** | G-Eval (GPT-4o で任意基準を定義) |

## 強み

- **Pytest 互換** — 既存 CI/CD に 1 行で組み込める
- **50+ メトリクス** — RAG・エージェント・チャット・安全性を網羅
- **G-Eval** — LLM-as-judge で任意の評価基準を自然言語で定義
- **完全 OSS** — Apache 2.0 / ローカル実行 / コスト最小
$md$,
  'https://www.confident-ai.com/',
  '2026-04-24',
  1
),

(
  'confident_ai',
  'models',
  'DeepEval メトリクス詳細 & Confident AI 料金 (2026)',
  $md$
## DeepEval 主要メトリクス

### RAG パイプライン評価

| メトリクス | 説明 | 目安スコア |
| :--- | :--- | :--- |
| **Answer Relevancy** | 回答がクエリと関連しているか | >0.8 |
| **Faithfulness** | 回答が検索文脈に忠実か (ハルシネーション検出) | >0.9 |
| **Contextual Precision** | 取得文書の精度 (ノイズが少ないか) | >0.7 |
| **Contextual Recall** | 必要な情報を文脈が網羅しているか | >0.8 |

### エージェント評価

| メトリクス | 説明 |
| :--- | :--- |
| **Task Completion** | エージェントがタスクを完了したか |
| **Tool Call Accuracy** | 適切なツールを適切な引数で呼び出したか |
| **Agent Goal Decomposition** | 目標を適切にサブタスクに分解したか |

### 安全性・品質評価

| メトリクス | 説明 |
| :--- | :--- |
| **Hallucination** | 事実に基づかない情報の割合 |
| **Toxicity** | 有害・差別・暴力的コンテンツの検出 |
| **Bias** | 不公平なバイアスの検出 |
| **G-Eval** | 任意の評価基準を自然言語で定義 |

## Confident AI 料金 (2026)

| プラン | 価格 | 概要 |
| :--- | :--- | :--- |
| **DeepEval OSS** | 完全無料 | ローカル実行 / 全メトリクス |
| **Confident AI Free** | $0 | 個人・小規模チーム |
| **Confident AI Team** | カスタム | 本番監視 / チームコラボ / 高度なダッシュボード |
| **Enterprise** | カスタム | SSO / SAML / 専任サポート |
$md$,
  'https://deepeval.com/docs/metrics-introduction',
  '2026-04-24',
  2
),

(
  'confident_ai',
  'api',
  'DeepEval API 入門 — LLM 評価 & CI/CD 統合',
  $md$
## DeepEval の始め方

### インストール & セットアップ

```bash
pip install deepeval
deepeval login  # Confident AI に接続 (オプション / ローカルのみも可)
```

### 基本的な LLM 評価 (Pytest スタイル)

```python
# test_ai_university.py
import pytest
from deepeval import assert_test
from deepeval.test_case import LLMTestCase
from deepeval.metrics import (
    AnswerRelevancyMetric,
    FaithfulnessMetric,
    HallucinationMetric,
)

# 評価するモデルの出力
def get_claude_response(question: str) -> str:
    from anthropic import Anthropic
    client = Anthropic()
    msg = client.messages.create(
        model="claude-opus-4-7",
        max_tokens=512,
        messages=[{"role": "user", "content": question}]
    )
    return msg.content[0].text

# Pytest テストケース (CI/CD でそのまま使える)
@pytest.mark.parametrize("question,context,expected", [
    (
        "LangSmith とは？",
        ["LangSmith は LangChain が提供する LLM 観測プラットフォームです。"],
        "LangChain の観測プラットフォーム",
    ),
    (
        "Braintrust の特徴は？",
        ["Braintrust は AI 観測・評価インフラで、Loop AI エージェントが特徴です。"],
        "AI 観測・評価・Loop AI エージェント",
    ),
])
def test_ai_university_qa(question, context, expected):
    actual_output = get_claude_response(question)

    test_case = LLMTestCase(
        input=question,
        actual_output=actual_output,
        expected_output=expected,
        retrieval_context=context,
    )

    # 複数メトリクスを同時評価
    assert_test(test_case, [
        AnswerRelevancyMetric(threshold=0.8),
        FaithfulnessMetric(threshold=0.9),
        HallucinationMetric(threshold=0.5),
    ])
```

```bash
# pytest で実行 — CI/CD に組み込める
pytest test_ai_university.py -v
# → Confident AI UI でスコア・詳細を確認
```

### G-Eval — 任意の評価基準をカスタム定義

```python
from deepeval.metrics import GEval
from deepeval.test_case import LLMTestCaseParams

# 任意の評価基準を自然言語で定義
ai_expert_metric = GEval(
    name="AI専門家品質",
    criteria="""
    回答が以下の基準を満たしているか評価してください:
    1. 最新の AI トレンドを反映している (2026年時点)
    2. 具体的な数字・会社名・技術名が正確
    3. 初心者にも理解できる平易な説明
    """,
    evaluation_params=[
        LLMTestCaseParams.ACTUAL_OUTPUT,
        LLMTestCaseParams.INPUT,
    ],
    threshold=0.7,
)

test_case = LLMTestCase(
    input="AI大学で最も注目すべきプロバイダーは？",
    actual_output=get_claude_response("AI大学で最も注目すべきプロバイダーは？"),
)
assert_test(test_case, [ai_expert_metric])
```

## クイックスタート

1. `pip install deepeval` でインストール
2. `test_my_llm.py` に `@pytest.mark` スタイルでテストケースを記述
3. `pytest test_my_llm.py` でローカル実行
4. GitHub Actions に組み込んで PR ごとに自動評価
5. `deepeval login` で Confident AI に接続 → チームでスコア共有
$md$,
  'https://deepeval.com/docs/getting-started',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
