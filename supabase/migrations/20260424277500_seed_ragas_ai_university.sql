-- Session PS#3-S43: AI大学 182社化 — Ragas 追加
-- Explodin Gradients 開発の RAG パイプライン評価フレームワーク (OSS)。
-- Faithfulness / Answer Relevance / Context Precision / Context Recall の4主要メトリクス。
-- LangChain / LlamaIndex / Haystack と統合 / pytest 形式で CI/CD に組み込み可能。
-- TestsetGenerator: ドキュメントから合成テストデータを自動生成。
-- pip install ragas / GitHub 7k+ Stars / LLM-as-judge アーキテクチャ採用。
-- Step 0: 7/9 (RAG評価特化 / 4主要メトリクス / pytest統合 / TestsetGenerator / LangChain公式推薦)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'ragas',
  'overview',
  'Ragas — RAG パイプライン評価フレームワーク (Faithfulness / Context / Answer 4 メトリクス)',
  $md$
# Ragas — Evaluation Framework for Retrieval Augmented Generation

**Explodin Gradients** が開発する OSS の RAG パイプライン評価フレームワーク。
「RAG を組んだが、本当に精度が出ているか?」を定量的に測定する標準ツールとして
LangChain / LlamaIndex コミュニティで広く採用されている。

GitHub Stars **7,000+** / `pip install ragas` / LLM-as-judge アーキテクチャを採用。

## 4 主要評価メトリクス

| メトリクス | 測定内容 | LLM 必要? |
| :--- | :--- | :--- |
| **Faithfulness** | 回答が検索コンテキストの事実に基づいているか (ハルシネーション検出) | ✅ |
| **Answer Relevance** | 回答が質問に対して関連しているか | ✅ |
| **Context Precision** | 検索された文書のどれだけが実際に役立ったか | ✅ |
| **Context Recall** | 正解に必要な情報が検索できているか | ✅ |

### 補助メトリクス

- **Answer Correctness** — 参照正解との一致度 (NLI + BLEU 融合)
- **Answer Similarity** — セマンティック類似度
- **Context Entity Recall** — エンティティ単位の再現率

## TestsetGenerator — 合成テストデータ自動生成

ドキュメントコーパスから **質問・コンテキスト・正解** を自動生成。
手動アノテーション不要で本格的な評価データセットを構築できる。

## 統合エコシステム

| ツール | 統合方法 |
| :--- | :--- |
| **LangChain** | `RagasEvaluatorChain` で直接評価 |
| **LlamaIndex** | `RagasEvaluator` ノードで統合 |
| **Haystack** | `RagasEvaluator` パイプラインコンポーネント |
| **pytest** | `assert` ベースで CI/CD 品質ゲート化 |
| **MLflow / W&B** | メトリクス自動ログ |
$md$,
  'https://docs.ragas.io/',
  '2026-04-24',
  1
),

(
  'ragas',
  'models',
  'Ragas メトリクス詳細 & TestsetGenerator (2026)',
  $md$
## Faithfulness — ハルシネーション検出の仕組み

```
1. LLM が回答から「主張 (Statement)」を抽出
2. 各主張を検索コンテキストと照合 (NLI)
3. score = コンテキストが支持する主張数 / 全主張数
```

スコア 1.0 = 完全に文書に基づく回答 / 0.0 = 完全なハルシネーション

## Answer Relevance — 質問適合度

```
1. LLM が回答から「この回答が答える質問」を N 個生成
2. 各生成質問と元の質問のコサイン類似度を計算
3. score = 類似度の平均
```

## Context Precision — 検索精度

```
score = 関連文書が上位に来ている割合
高スコア = 検索エンジンが適切に関連文書を優先してランク付け
```

## TestsetGenerator の生成戦略

| 質問タイプ | 説明 | 難易度 |
| :--- | :--- | :--- |
| **Simple** | 単一文書から直接回答できる質問 | 低 |
| **Reasoning** | 推論・比較が必要な質問 | 中 |
| **Multi-Context** | 複数文書を組み合わせる質問 | 高 |
| **Conditional** | 条件付き・仮定の質問 | 高 |

## 評価の LLM 選択

Ragas はデフォルトで GPT-4 を評価 LLM として使用するが、
Claude / Gemini / Llama など任意の LLM に変更可能。

```python
from ragas.llms import LangchainLLMWrapper
from langchain_anthropic import ChatAnthropic

# Claude で評価
evaluator_llm = LangchainLLMWrapper(
    ChatAnthropic(model="claude-opus-4-7")
)
```
$md$,
  'https://docs.ragas.io/en/latest/concepts/metrics/',
  '2026-04-24',
  2
),

(
  'ragas',
  'api',
  'Ragas API 入門 — RAG パイプライン評価 & CI/CD 品質ゲート',
  $md$
## Ragas の始め方

### インストール

```bash
pip install ragas langchain-anthropic
```

### 基本評価 (Claude 使用)

```python
from ragas import evaluate
from ragas.metrics import (
    faithfulness,
    answer_relevancy,
    context_precision,
    context_recall,
)
from langchain_anthropic import ChatAnthropic
from ragas.llms import LangchainLLMWrapper
from datasets import Dataset

# 評価データ準備
eval_data = {
    "question": [
        "CrewAI は Fortune 500 の何% が採用していますか？",
        "AutoGen の開発元はどこですか？",
        "Patronus AI の FinanceBench とは何ですか？",
    ],
    "answer": [
        "CrewAI は Fortune 500 の 60% が採用しています。",
        "AutoGen は Microsoft Research が開発しています。",
        "FinanceBench は Patronus AI が開発した金融 LLM ベンチマークです。",
    ],
    "contexts": [
        ["CrewAI は Fortune 500 の 60% が採用するマルチエージェントフレームワークです。"],
        ["AutoGen は Microsoft Research が開発するマルチエージェント OSS です。"],
        ["Patronus AI の FinanceBench は業界初の金融 LLM 評価ベンチマークです。"],
    ],
    "ground_truth": [
        "Fortune 500 の 60%",
        "Microsoft Research",
        "金融ドメイン特化の LLM 評価ベンチマーク",
    ],
}

dataset = Dataset.from_dict(eval_data)

# Claude で評価
claude_llm = LangchainLLMWrapper(
    ChatAnthropic(model="claude-opus-4-7")
)

results = evaluate(
    dataset=dataset,
    metrics=[faithfulness, answer_relevancy, context_precision, context_recall],
    llm=claude_llm,
)

print(results)
# {'faithfulness': 0.97, 'answer_relevancy': 0.94,
#  'context_precision': 1.00, 'context_recall': 0.92}
```

### TestsetGenerator — 合成テストデータ生成

```python
from ragas.testset import TestsetGenerator
from langchain_anthropic import ChatAnthropic
from langchain_community.document_loaders import DirectoryLoader

# ドキュメントをロード
loader = DirectoryLoader("./docs/", glob="**/*.md")
docs = loader.load()

# Claude でテストデータ生成
generator = TestsetGenerator.from_langchain(
    generator_llm=ChatAnthropic(model="claude-opus-4-7"),
    critic_llm=ChatAnthropic(model="claude-haiku-4-5"),
    embeddings=None,  # デフォルト埋め込みを使用
)

testset = generator.generate_with_langchain_docs(
    docs,
    test_size=30,
    distributions={"simple": 0.5, "reasoning": 0.3, "multi_context": 0.2},
)

# pandas DataFrame に変換
df = testset.to_pandas()
print(df.head())
```

### pytest 統合 — CI/CD 品質ゲート

```python
# test_rag_quality.py
import pytest
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy

QUALITY_THRESHOLD = {
    "faithfulness": 0.85,
    "answer_relevancy": 0.80,
}

def run_rag_pipeline(question: str) -> dict:
    """RAG パイプライン実行 (Haystack / LangChain など)"""
    # ... 実装 ...
    return {"answer": "...", "contexts": [...]}

@pytest.mark.parametrize("question,expected_topic", [
    ("AI 大学の主要プロバイダーは？", "プロバイダー"),
    ("CrewAI の採用率は？", "60%"),
])
def test_rag_quality(question, expected_topic):
    result = run_rag_pipeline(question)

    dataset = Dataset.from_dict({
        "question": [question],
        "answer": [result["answer"]],
        "contexts": [result["contexts"]],
    })

    scores = evaluate(dataset=dataset, metrics=[faithfulness, answer_relevancy])

    assert scores["faithfulness"] >= QUALITY_THRESHOLD["faithfulness"], \
        f"Faithfulness 不足: {scores['faithfulness']:.2f}"
    assert scores["answer_relevancy"] >= QUALITY_THRESHOLD["answer_relevancy"], \
        f"Answer Relevancy 不足: {scores['answer_relevancy']:.2f}"
```

### LangChain RAG パイプライン直接評価

```python
from ragas.integrations.langchain import EvaluatorChain
from ragas.metrics import faithfulness

# LangChain チェーンとそのまま統合
evaluator = EvaluatorChain(metric=faithfulness)
result = evaluator({"question": q, "answer": a, "contexts": ctxs})
print(result["faithfulness_score"])
```

## クイックスタート

1. `pip install ragas` でインストール
2. 質問・回答・コンテキスト・正解 の 4 フィールドを `Dataset` に格納
3. `evaluate(dataset, metrics=[faithfulness, answer_relevancy, ...])` で採点
4. スコアが閾値を下回れば RAG パイプラインを改善
5. `TestsetGenerator` でドキュメントから合成テストデータを自動生成
$md$,
  'https://docs.ragas.io/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
