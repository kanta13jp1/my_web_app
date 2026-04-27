-- PS#3 S81: AI大学 256→257社化 — DeepEval (LLM評価フレームワーク)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'deepeval', 'overview',
  'DeepEval — LLM/RAGシステムのユニットテストフレームワーク (G-Eval/ハルシネーション検出/CI統合 / GitHub 5k+ / 8/9)',
  $## DeepEval とは

**DeepEval** は Confident AI が開発する LLM・RAG システム専用のオープンソース評価フレームワーク。pytest と同じ感覚で LLM の出力品質をユニットテストし、CI/CD パイプラインに組み込める。

## 主要評価メトリクス

| メトリクス | 概要 | 検出対象 |
|-----------|------|---------|
| **G-Eval** | GPT-4 評価 / カスタム基準 | 汎用品質評価 |
| **Answer Relevancy** | 回答と質問の関連度 | 的外れ回答 |
| **Faithfulness** | ソースへの忠実度 | ハルシネーション |
| **Contextual Precision** | コンテキスト精度 | RAG 精度 |
| **Contextual Recall** | コンテキスト再現率 | RAG 網羅性 |
| **Hallucination** | 事実確認 | 幻覚生成 |
| **Bias** | 偏見・差別的表現 | 安全性 |
| **Toxicity** | 有害コンテンツ | 安全性 |
| **RAGAS** | RAG 総合スコア | RAG 品質 |

## なぜ LLM 評価が重要か

```
従来のソフトウェアテスト:
  assert output == expected_output  ← 決定的 / 簡単

LLM のテスト課題:
  assert llm("質問") == ???  ← 確率的 / 毎回異なる / 正解が曖昧
  → 人間による評価は高コスト・スケール困難
  → DeepEval: LLM が LLM を評価 (LLM-as-Judge)
```

## LLM-as-Judge パターン

```
ユーザー質問 → あなたのLLM → 回答
                              ↓
                    DeepEval Judge (GPT-4/Claude)
                              ↓
                  スコア (0-1) + 理由
```

評価LLMはクローズドでもオープンソースでも使用可能。

## RAG 評価の重要性

```
RAG パイプライン:
  質問 → [検索] → コンテキスト → [LLM] → 回答

DeepEval が検出する問題:
  1. Retrieval の問題: 関係ないコンテキストを取得
  2. Faithfulness の問題: コンテキストにない情報を生成
  3. Answer Relevancy: 質問と無関係な回答
```

## GitHub とエコシステム

- **GitHub**: 5,000+ Stars / MIT ライセンス
- **Confident AI**: クラウドダッシュボード (SaaS 版)
- **LangChain / LlamaIndex 統合**: 既存 RAG パイプラインに即追加
- **pytest 統合**: 既存 CI/CD に組み込み可

## 自分株式会社での活用

| シーン | メトリクス | 期待効果 |
|--------|-----------|---------|
| **AI アシスタント品質保証** | G-Eval + Answer Relevancy | 回答品質の定量化 |
| **RAG システム改善** | Faithfulness + Contextual | ハルシネーション除去 |
| **プロンプト A/B テスト** | 全メトリクス比較 | プロンプト最適化 |
| **リリース品質ゲート** | CI に統合 / スコア閾値設定 | 本番品質担保 |$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'deepeval', 'api',
  'DeepEval 実践 — pytest統合・RAG評価・G-Evalカスタム基準・CI/CDパイプライン組み込み',
  $## インストール

```bash
pip install deepeval

# 設定 (OpenAI API を評価 LLM として使用)
deepeval set-azure-openai ...  # Azure OpenAI
# または
export OPENAI_API_KEY="sk-..."
```

## 基本的なユニットテスト

```python
# test_llm.py
import pytest
from deepeval import assert_test
from deepeval.test_case import LLMTestCase
from deepeval.metrics import AnswerRelevancyMetric, FaithfulnessMetric

def test_answer_relevancy():
    """回答が質問と関連しているか検証"""
    test_case = LLMTestCase(
        input="自分株式会社のミッションは何ですか？",
        actual_output=your_llm("自分株式会社のミッションは何ですか？"),
        expected_output="個人がCEOとして自分の人生を経営すること",
    )
    metric = AnswerRelevancyMetric(threshold=0.7)
    assert_test(test_case, [metric])

# 実行: pytest test_llm.py -v
```

## RAG パイプライン評価

```python
from deepeval.test_case import LLMTestCase
from deepeval.metrics import (
    FaithfulnessMetric,
    ContextualPrecisionMetric,
    ContextualRecallMetric,
)

def test_rag_pipeline():
    """RAG の取得・生成品質を総合評価"""

    # RAG パイプラインの実行
    query = "LLMファインチューニングの方法を教えて"
    retrieved_contexts = retriever.search(query)  # あなたの検索エンジン
    answer = llm.generate(query, retrieved_contexts)

    test_case = LLMTestCase(
        input=query,
        actual_output=answer,
        expected_output="QLoRAやLoRAを使った方法が一般的です",
        retrieval_context=retrieved_contexts,  # 取得したコンテキスト
    )

    metrics = [
        FaithfulnessMetric(threshold=0.8),       # ハルシネーション検出
        ContextualPrecisionMetric(threshold=0.7), # 取得精度
        ContextualRecallMetric(threshold=0.6),    # 取得網羅性
    ]
    assert_test(test_case, metrics)
```

## G-Eval: カスタム評価基準

```python
from deepeval.metrics import GEval
from deepeval.test_case import LLMTestCaseParams

# 独自の評価基準を日本語で定義
helpfulness_metric = GEval(
    name="Helpfulness",
    criteria="""
    以下の基準で回答の役立ち度を 0〜10 で評価してください:
    - 具体的なアクションステップが含まれている (3点)
    - 日本語が自然で読みやすい (2点)
    - 質問の意図を正確に理解している (3点)
    - 追加のリソースや参考情報がある (2点)
    """,
    evaluation_params=[
        LLMTestCaseParams.INPUT,
        LLMTestCaseParams.ACTUAL_OUTPUT,
    ],
    threshold=0.7,
)

test_case = LLMTestCase(
    input="Pythonでファイルを読み込む方法は？",
    actual_output=your_llm("Pythonでファイルを読み込む方法は？"),
)

result = helpfulness_metric.measure(test_case)
print(f"スコア: {result.score:.2f}")
print(f"理由: {result.reason}")
```

## ハルシネーション検出

```python
from deepeval.metrics import HallucinationMetric

def test_no_hallucination():
    """LLM が事実と異なる情報を生成していないか確認"""
    test_case = LLMTestCase(
        input="Claude-3.5 Sonnet のリリース日は？",
        actual_output=your_llm("Claude-3.5 Sonnet のリリース日は？"),
        context=[
            "Claude-3.5 Sonnet は 2024年6月にリリースされました。",
            "Claude-3 Opus は 2024年3月にリリースされました。",
        ],
    )

    metric = HallucinationMetric(threshold=0.5)
    assert_test(test_case, [metric])
    # context にない情報を生成したらテスト失敗
```

## CI/CD 統合 (GitHub Actions)

```yaml
# .github/workflows/llm-quality-check.yml
name: LLM Quality Gate

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: pip install deepeval

      - name: Run LLM tests
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: |
          pytest tests/test_llm_quality.py \
            --deepeval-model gpt-4o-mini \
            -v \
            --tb=short
```

## バッチ評価: 複数テストケースの一括実行

```python
from deepeval import evaluate
from deepeval.dataset import EvaluationDataset

# テストケース一覧
test_cases = [
    LLMTestCase(input=q, actual_output=your_llm(q))
    for q in questions
]

dataset = EvaluationDataset(test_cases=test_cases)

# 全件評価 (並列実行)
results = evaluate(
    dataset,
    metrics=[AnswerRelevancyMetric(), FaithfulnessMetric()],
    verbose_mode=True,
)

# 統計サマリー
for metric_name, scores in results.items():
    print(f"{metric_name}: avg={sum(scores)/len(scores):.2f}")
```$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'deepeval', 'models',
  'DeepEval 技術詳解 — G-Eval数学・RAGAS指標・LLM-as-Judge設計・Confident AIダッシュボード活用',
  $## G-Eval の数学的基盤

**Liu et al. (2023) "G-Eval: NLG Evaluation using GPT-4 with Better Human Alignment"**:

```
G-Eval アルゴリズム:

1. Evaluation Form 作成:
   prompt = f"""
   タスク: [タスク説明]
   評価基準: [基準詳細]
   スコアリング: 1〜5

   入力: {input}
   回答: {output}

   スコアを出力してください。
   """

2. LLM で確率分布を取得:
   logprobs = judge_llm.generate(prompt, logprobs=True)

3. 加重平均でスコア計算:
   score = Σ(token_prob_i × score_value_i)
   # 確率で重み付けすることで連続スコアになる
   # 単純な生成より correlation が高い
```

## RAGAS (RAG Assessment) メトリクス詳細

```
4つの主要指標:

1. Faithfulness (忠実度):
   回答に含まれる各主張が、コンテキストで裏付けられているか
   score = |supported_claims| / |total_claims_in_answer|

2. Answer Relevancy (回答関連度):
   生成された回答から逆算した質問と元の質問の類似度
   score = avg_cosine_similarity(generated_questions, original_question)

3. Context Precision (コンテキスト精度):
   取得したコンテキストのうち正解に関連するものの割合
   score = Σ(precision@k × relevance_k) / |relevant_contexts|

4. Context Recall (コンテキスト再現率):
   正解の各主張がコンテキストで裏付けられている割合
   score = |claims_in_answer_supported_by_context| / |total_claims_in_ground_truth|
```

## LLM-as-Judge の設計原則

```
信頼できる評価のための 5 原則:

1. 評価基準の明示化
   ✅ "具体的なコード例が含まれている場合 +2点"
   ❌ "役立ちそうかどうか"

2. 評価 LLM の選択
   高品質評価: GPT-4o / Claude-3.5-Sonnet
   コスト重視: GPT-4o-mini / Claude-3-Haiku
   オフライン: Llama-3-70B-Instruct (精度は落ちる)

3. 自己評価バイアスの回避
   テスト対象と評価者が同じモデルは避ける
   例: GPT-4 で生成 → Claude-3 で評価

4. 複数評価者の合意
   threshold: 3 judges 中 2 以上が合格なら OK

5. 人間評価との相関確認
   定期的に人間評価と DeepEval スコアの相関を確認 (Cohen's κ ≥ 0.7)
```

## Confident AI ダッシュボード活用

```python
import deepeval

# Confident AI にログイン (無料プラン: 月 1000 テストケース)
deepeval.login_with_confident_api_key("your-api-key")

# 自動ダッシュボード送信
# テスト実行後、ブラウザで品質トレンド・失敗分析を確認可能
```

機能:
- テスト結果の履歴管理
- メトリクスのトレンドグラフ
- 失敗ケースの詳細分析
- チームメンバーへの共有
- デプロイ前品質ゲート

## 自分株式会社 品質保証戦略

```
4段階品質ゲート:

Stage 1: 開発中 (ローカル)
  deepeval test run test_llm.py
  → 高速フィードバック (GPT-4o-mini で評価 / 安価)

Stage 2: PR 作成時 (CI)
  GitHub Actions → deepeval 自動実行
  → AnswerRelevancy > 0.7, Faithfulness > 0.8 を要件

Stage 3: staging デプロイ前
  全メトリクス評価 + 人間サンプルレビュー
  → G-Eval 平均 > 8.0/10

Stage 4: 本番監視 (非同期)
  ユーザーリクエストをサンプリング → 非同期評価
  → スコア低下でアラート発火

コスト試算:
  GPT-4o-mini での評価: $0.15/1000 テストケース
  月 10,000 テスト: $1.5/月 ← ほぼ無コスト
```$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 256→257社化: DeepEval 追加',
  'PS#3 S81。DeepEval (LLM/RAGユニットテストフレームワーク/G-Eval/ハルシネーション検出/Answer Relevancy/Faithfulness/RAGAS/CI統合/LLM-as-Judge/Confident AI/GitHub 5k+/MIT/8/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
