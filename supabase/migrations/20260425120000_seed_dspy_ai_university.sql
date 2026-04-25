-- Session PS#3-S45: AI大学 188社化 — DSPy 追加
-- Stanford NLP Lab (Omar Khattab) が開発する LLM "プログラミング" フレームワーク。
-- プロンプトを手書きせず、Python コードで LLM パイプラインを宣言的に定義。
-- GitHub 18k+ Stars / Apache 2.0 / Databricks / MLE-bench / RAG・エージェント実績多数。
-- Step 0: 7.5/9 (独自パラダイム / Stanford 信頼性 / 急成長 / Apache 2.0 / 企業採用)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'dspy',
  'overview',
  'DSPy — LLM を「プロンプト」ではなく「プログラム」で操る Stanford 発フレームワーク',
  $md$
# DSPy — Programming, not Prompting

**Omar Khattab** (Stanford NLP / Databricks) が開発する LLM アプリ構築フレームワーク。

手書きのプロンプトに頼らず、Python のコードロジックとして LLM パイプラインを記述し、
**Optimizer** (オプティマイザー) がデータに基づいてプロンプトを自動的に最適化する。

GitHub Stars **18,000+** / Apache 2.0 ライセンス。

## 核心思想: Prompting → Programming

| 旧来のアプローチ | DSPy のアプローチ |
| :--- | :--- |
| プロンプトを手書きで長文管理 | **Signature** で入出力を型定義 |
| モデル変更 = プロンプト全書き直し | コード変更なし・Optimizer が再最適化 |
| ヒューリスティックな few-shot 選択 | **BootstrapFewShot** が自動生成 |
| 評価 = 感覚 | **Metric 関数** で数値ベース評価 |

## コアコンポーネント

| コンポーネント | 役割 |
| :--- | :--- |
| **Signature** | LLM タスクの入出力を Python 型で宣言 |
| **Module** | ChainOfThought / ReAct / Predict など |
| **Optimizer** | BootstrapFewShot / MIPRO / BayesianSignatureOptimizer |
| **Metric** | 評価関数 (正解率・F1・LLM-as-Judge など) |

## 採用実績

- **Databricks** — 社内 RAG・エージェントパイプライン
- **Replit** — コードアシスタント品質向上
- **VMware** — エンタープライズ RAG
- **JetBlue** — カスタマーサポート自動化
$md$,
  'https://dspy.ai/',
  '2026-04-25',
  1
),

(
  'dspy',
  'api',
  'DSPy 入門 — インストール・Signature・ChainOfThought・Optimizer の基本',
  $md$
## インストール

```bash
pip install dspy
```

---

## 基本的な使い方

### Step 1: LLM を設定

```python
import dspy

# OpenAI (GPT-4o)
lm = dspy.LM('openai/gpt-4o', api_key='sk-...')
dspy.configure(lm=lm)

# Anthropic (Claude)
lm = dspy.LM('anthropic/claude-sonnet-4-6', api_key='sk-ant-...')
dspy.configure(lm=lm)
```

---

### Step 2: Signature — タスクを型で定義

```python
# 質問 → 回答
class QA(dspy.Signature):
    """質問に答えてください。"""
    question: str = dspy.InputField()
    answer: str = dspy.OutputField()

# RAG: コンテキスト + 質問 → 回答
class RAGAnswer(dspy.Signature):
    """コンテキストを元に質問に日本語で答えてください。"""
    context: list[str] = dspy.InputField(desc="関連文書のリスト")
    question: str = dspy.InputField()
    answer: str = dspy.OutputField(desc="簡潔な回答")
```

---

### Step 3: Module — 処理ロジックを組み立て

```python
# ChainOfThought: 思考ステップを自動追加
cot = dspy.ChainOfThought(QA)
result = cot(question="日本の首都は？")
print(result.answer)   # → "東京"
print(result.rationale)  # → 推論ステップ

# ReAct: ツール呼び出し可能なエージェント
def search(query: str) -> str:
    # 検索 API 呼び出し
    return "検索結果..."

react = dspy.ReAct(QA, tools=[search])
result = react(question="2026年の最新AIニュースは？")
```

---

### Step 4: Optimizer — プロンプトを自動最適化

```python
from dspy.teleprompt import BootstrapFewShot

# 評価メトリック関数
def metric(example, prediction, trace=None):
    return example.answer.lower() in prediction.answer.lower()

# 訓練データ (少量でOK)
trainset = [
    dspy.Example(question="Python の GIL とは？", answer="Global Interpreter Lock").with_inputs("question"),
    dspy.Example(question="REST と GraphQL の違いは？", answer="クエリ柔軟性").with_inputs("question"),
    # ... 20〜50 件程度
]

# 最適化実行
optimizer = BootstrapFewShot(metric=metric)
compiled_program = optimizer.compile(cot, trainset=trainset)

# 最適化済みプログラムを保存
compiled_program.save("optimized_qa.json")
```

---

## LangChain / LlamaIndex との比較

| 比較項目 | DSPy | LangChain | LlamaIndex |
| :--- | :--- | :--- | :--- |
| 設計思想 | **プログラム** (コンパイル) | チェーン (ラッパー) | RAG 特化 |
| プロンプト管理 | **自動最適化** | 手書き | 手書き |
| モデル切替 | **コード変更なし** | 要調整 | 要調整 |
| 学習コスト | 中 (新概念) | 低 | 低 |
| 本番品質 | **高** (Metric ベース) | 主観的 | 主観的 |
$md$,
  'https://dspy.ai/learn/',
  '2026-04-25',
  2
),

(
  'dspy',
  'models',
  'DSPy RAG パイプライン実装 — 検索・生成・評価の完全ガイド',
  $md$
## RAG パイプライン with DSPy

### 完全な RAG 実装例

```python
import dspy
from dspy.retrieve import ColBERTv2

# 設定
lm = dspy.LM('anthropic/claude-sonnet-4-6')
retriever = ColBERTv2(url='http://20.102.90.50:2017/wiki17_abstracts')
dspy.configure(lm=lm, rm=retriever)

# Signature 定義
class GenerateAnswer(dspy.Signature):
    """コンテキストを元に、詳細かつ正確な回答を提供してください。"""
    context: list[str] = dspy.InputField(desc="検索で取得した関連文書")
    question: str = dspy.InputField()
    answer: str = dspy.OutputField(desc="完全な文章で答えること")

# RAG Module
class RAG(dspy.Module):
    def __init__(self, num_passages=3):
        self.retrieve = dspy.Retrieve(k=num_passages)
        self.generate_answer = dspy.ChainOfThought(GenerateAnswer)

    def forward(self, question):
        context = self.retrieve(question).passages
        prediction = self.generate_answer(context=context, question=question)
        return dspy.Prediction(context=context, answer=prediction.answer)

# 使用
rag = RAG()
result = rag(question="Colossal Cave Adventure はいつ作られましたか？")
print(result.answer)
```

---

## MIPRO Optimizer — 高品質な自動最適化

```python
from dspy.teleprompt import MIPROv2

optimizer = MIPROv2(
    metric=metric,
    auto="medium",   # "light" / "medium" / "heavy"
)
optimized_rag = optimizer.compile(
    RAG(),
    trainset=trainset,
    num_trials=15,
)
```

---

## アサーション — 出力に制約を追加

```python
class ConstrainedQA(dspy.Module):
    def __init__(self):
        self.generate = dspy.ChainOfThought("question -> answer")

    def forward(self, question):
        pred = self.generate(question=question)
        # 回答が 100 文字以内であることを要求
        dspy.Suggest(
            len(pred.answer) <= 100,
            "回答を 100 文字以内に短縮してください"
        )
        return pred
```

---

## 実装チェックリスト

- [ ] `pip install dspy` でインストール完了
- [ ] `dspy.configure(lm=...)` で LLM 設定
- [ ] Signature で入出力を型定義
- [ ] Module に `forward()` メソッドを実装
- [ ] trainset を 20 件以上用意
- [ ] metric 関数を数値ベースで定義
- [ ] BootstrapFewShot で最適化実行
- [ ] `compiled.save("program.json")` で保存
$md$,
  'https://dspy.ai/tutorials/rag/',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
