-- PS#3 S112: AI大学 319→320社化 — DSPy (Stanford/プログラマティックプロンプト最適化)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dspy', 'overview',
  'DSPy — Stanford プログラマティックプロンプト最適化・自動チューニング・LM Compiler (GitHub 20k+ / 9/9)',
  $$## DSPy とは

**DSPy (Declarative Self-improving Python)** は **Stanford NLP グループが開発するプログラマティックな LLM パイプライン最適化フレームワーク**。GitHub 20,000+ スター。「**プロンプトを手動で書くのをやめて、プログラムとして記述し自動最適化する**」思想が核心。

従来の RAG や Chain-of-Thought は「良いプロンプトを手で書く」ことに依存するが、DSPy は **Optimizer (MIPROv2 / BootstrapFewShot など) がプロンプトと Few-shot 例を自動生成・最適化**する。LLM を「コンパイルする」LM Compiler とも呼ばれる。

## DSPy のアーキテクチャ

```
DSPy コアコンセプト:

  Signature (入出力の型定義):
    ・"question -> answer" のような宣言的な仕様
    ・フィールドに description を付加してヒントを与える
    ・プロンプトの実装を Optimizer に委ねる

  Module (処理単位):
    ・dspy.Predict: 基本的な LLM 呼び出し
    ・dspy.ChainOfThought: 推論ステップを自動生成
    ・dspy.ReAct: Reasoning + Acting (ツール使用)
    ・dspy.Retrieve: RAG の Retrieval
    ・カスタム Module (dspy.Module を継承)

  Optimizer (自動チューニング):
    ・BootstrapFewShot: 少数例で Few-shot を自動生成
    ・MIPROv2: プロンプト + Few-shot の同時最適化 (推奨)
    ・BootstrapFinetune: モデル自体を Fine-tune
    ・COPRO: 命令文を最適化

  Metric (評価関数):
    ・最適化の目標 (例: 正解率 / F1 / カスタム関数)
    ・自動評価 LLM も使用可能
```

## 主要機能

```
LLM サポート:
  ・dspy.LM("anthropic/claude-haiku-4-5")
  ・dspy.LM("openai/gpt-4o")
  ・dspy.LM("ollama/llama3")
  ・任意の LiteLLM 対応モデル

Retrieval サポート:
  ・ColBERTv2 (高精度ニューラル検索)
  ・Qdrant / Chroma / Weaviate / Pinecone
  ・カスタム Retriever

プログラマティック最適化:
  ・プロンプトエンジニアリング不要
  ・Few-shot 例の自動選択・生成
  ・LLM 切替時も再最適化で品質維持
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬予想品質向上** | 予想パイプラインを DSPy で定義→MIPROv2 で自動最適化 | 手動プロンプト調整コスト削減 |
| **AI大学 Q&A 精度向上** | RAG パイプラインを Optimizer で自動チューニング | 的中率・回答品質の継続改善 |
| **LLM 切替コスト削減** | Claude→Gemini 切替時も再 compile で品質維持 | マルチモデル戦略の現実化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dspy', 'api',
  'DSPy 実践 — インストール/Signature/Module/Optimizer/RAGパイプライン/Claude統合/自動最適化',
  $$## インストール

```bash
pip install dspy
# ベクターストア (オプション)
pip install dspy[chromadb]
pip install dspy[qdrant]
```

## LLM 設定 (Claude)

```python
import dspy

# Claude をデフォルト LLM として設定
lm = dspy.LM("anthropic/claude-haiku-4-5", api_key="YOUR_ANTHROPIC_API_KEY")
dspy.configure(lm=lm)

# 高品質モデルを使う場合
lm_pro = dspy.LM("anthropic/claude-sonnet-4-6", api_key="YOUR_ANTHROPIC_API_KEY")
```

## Signature と Predict (基本)

```python
import dspy

dspy.configure(lm=dspy.LM("anthropic/claude-haiku-4-5", api_key="YOUR_KEY"))

# Signature: 入出力の型を宣言
class RacingQA(dspy.Signature):
    """競馬に関する質問に専門家として回答する"""
    question: str = dspy.InputField(desc="競馬に関する質問")
    answer: str = dspy.OutputField(desc="詳細かつ正確な回答")

# Predict モジュール
predictor = dspy.Predict(RacingQA)

# 実行
result = predictor(question="天皇賞春の距離と開催場を教えて")
print(result.answer)
```

## ChainOfThought (推論ステップ付き)

```python
import dspy

class HorseAnalysis(dspy.Signature):
    """馬の情報を分析して予想スコアを出す"""
    horse_info: str = dspy.InputField(desc="馬の情報 (血統/戦績/騎手/調教師)")
    analysis: str = dspy.OutputField(desc="詳細な分析")
    score: str = dspy.OutputField(desc="1-10 の予想スコアと根拠")

# CoT は自動で推論ステップを生成
cot = dspy.ChainOfThought(HorseAnalysis)

horse_info = """
馬名: シャフリヤール
血統: ディープインパクト × Doyen
戦績: 12戦7勝 (G1: 日本ダービー, ドバイシーマクラシック)
騎手: C.デムーロ
調教師: 藤原英昭
"""

result = cot(horse_info=horse_info)
print(f"分析: {result.analysis}")
print(f"スコア: {result.score}")
print(f"推論過程: {result.reasoning}")  # CoT が自動追加
```

## RAG パイプライン (DSPy + Retriever)

```python
import dspy
from dspy.retrieve.chromadb_rm import ChromadbRM

dspy.configure(lm=dspy.LM("anthropic/claude-haiku-4-5", api_key="YOUR_KEY"))

# Retriever 設定
retriever = ChromadbRM(collection_name="ai_university", persist_directory="./chroma_db")
dspy.configure(rm=retriever)

class RAGSignature(dspy.Signature):
    """検索した文書を元に質問に回答する"""
    question: str = dspy.InputField()
    context: list[str] = dspy.InputField(desc="関連文書")
    answer: str = dspy.OutputField(desc="コンテキストに基づいた回答")

class RAGPipeline(dspy.Module):
    def __init__(self, num_passages=3):
        self.retrieve = dspy.Retrieve(k=num_passages)
        self.generate = dspy.ChainOfThought(RAGSignature)

    def forward(self, question):
        passages = self.retrieve(question).passages
        answer = self.generate(question=question, context=passages)
        return answer

rag = RAGPipeline()
result = rag(question="LlamaIndex と LangChain の違いは何ですか？")
print(result.answer)
```

## Optimizer による自動最適化 (MIPROv2)

```python
import dspy
from dspy.teleprompt import MIPROv2

dspy.configure(lm=dspy.LM("anthropic/claude-haiku-4-5", api_key="YOUR_KEY"))

# 訓練データセット
trainset = [
    dspy.Example(question="天皇賞春の距離は？", answer="3200m").with_inputs("question"),
    dspy.Example(question="有馬記念の開催場は？", answer="中山競馬場").with_inputs("question"),
    # ...さらに例を追加
]

# 評価指標
def exact_match(example, prediction, trace=None):
    return example.answer.lower() in prediction.answer.lower()

# RAG パイプラインを定義
rag = RAGPipeline()

# MIPROv2 でプロンプトと Few-shot を自動最適化
optimizer = MIPROv2(
    metric=exact_match,
    auto="light",  # "light" / "medium" / "heavy" (最適化レベル)
)

optimized_rag = optimizer.compile(
    rag,
    trainset=trainset,
    num_trials=10,
)

# 最適化後のパイプラインを保存
optimized_rag.save("optimized_rag.json")

# 推論で使用
result = optimized_rag(question="今年の天皇賞春の注目馬は？")
print(result.answer)
```

## BootstrapFewShot (軽量最適化)

```python
from dspy.teleprompt import BootstrapFewShot

# より軽量な最適化 (訓練コスト低)
optimizer = BootstrapFewShot(
    metric=exact_match,
    max_bootstrapped_demos=4,  # Few-shot 例の最大数
    max_labeled_demos=16,
)

optimized_predictor = optimizer.compile(
    dspy.Predict(RacingQA),
    trainset=trainset,
)

# 最適化後の Few-shot プロンプトを確認
optimized_predictor.dump_state()
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 319→320社化: DSPy 追加',
  'PS#3 S112。DSPy (Stanford NLP/プログラマティックプロンプト最適化/Signature+Module+Optimizer/MIPROv2自動チューニング/ChainOfThought/RAGパイプライン/Claude統合/LM Compiler/GitHub 20k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
