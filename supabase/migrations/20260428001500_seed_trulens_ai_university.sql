-- PS#3 S82: AI大学 259→260社化 — TruLens (RAG評価フレームワーク / Snowflake)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'trulens', 'overview',
  'TruLens — Snowflake製RAG・LLMアプリ評価フレームワーク (Feedback Functions / トレース可視化 / GitHub 2k+ / 8/9)',
  $$## TruLens とは

**TruLens** は Snowflake が買収した TruEra が開発する、LLM アプリケーション・RAG システムの評価と可視化フレームワーク。LLM アプリの**内部動作を "レンズ"** で観察し、品質問題の根本原因を特定できる。

## 主要コンセプト

### TruLens の 3 つのコア概念

| 概念 | 説明 |
|------|------|
| **Recorder** | LLM アプリの入出力を自動記録するラッパー |
| **Feedback Functions** | 品質を自動スコアリングする評価関数 |
| **TruLens Dashboard** | 記録・スコアを可視化する Web UI |

## RAG の評価三角形

```
TruLens が評価する RAG の 3 要素:

         [Query]
            ↓
     [Retrieved Context]
            ↓
       [LLM Response]

1. Context Relevance:  Query → Context が関連しているか
2. Groundedness:       Response → Context に基づいているか (ハルシネーション検出)
3. Answer Relevance:   Response → Query に回答しているか
```

この 3 指標が全て高いとき、RAG は正常に機能している。

## Feedback Functions の仕組み

```python
# Feedback Function = "採点基準を持つ評価関数"

def context_relevance(question: str, context: str) -> float:
    # 評価 LLM に "この context は質問に関連しているか" と聞く
    # → スコア 0.0〜1.0 を返す
    ...
```

LLM / 埋め込みモデル / ルールベース の 3 種から選択できる。

## Snowflake との統合

2023年に Snowflake が TruEra を買収:
- Snowflake Arctic (Snowflake 製 LLM) との深い統合
- Snowflake Cortex との連携
- エンタープライズ向けのデータガバナンス対応

## 競合との差別化

| ツール | 強み | 弱み |
|--------|------|------|
| **TruLens** | RAG トレース可視化 / Snowflake 統合 | コミュニティ小さい |
| **DeepEval** | pytest 統合 / 多様な指標 | トレース機能弱い |
| **RAGAS** | シンプル / 軽量 | 可視化なし |
| **Arize Phoenix** | MLOps 視点 / Spans | 設定複雑 |

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **RAG デバッグ** | トレース可視化で問題箇所特定 | 改善サイクル短縮 |
| **Snowflake 連携** | Cortex + TruLens 統合 | エンタープライズ品質 |
| **A/B テスト** | 検索戦略の比較評価 | RAG 精度最大化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'trulens', 'api',
  'TruLens 実践 — RAGアプリのラッピング・Feedback Functions設定・ダッシュボード起動・LlamaIndex/LangChain統合',
  $$## インストール

```bash
# 基本
pip install trulens

# LLM プロバイダー連携
pip install trulens[openai]       # OpenAI
pip install trulens[bedrock]      # AWS Bedrock

# RAG フレームワーク連携
pip install trulens[llama-index]  # LlamaIndex
pip install trulens[langchain]    # LangChain
```

## 基本的なセットアップと評価

```python
from trulens.core import TruSession, Feedback
from trulens.providers.openai import OpenAI as fOpenAI
from trulens.apps.custom import TruCustomApp
import numpy as np

# TruLens セッション初期化 (SQLite に記録)
session = TruSession()
session.reset_database()

# 評価プロバイダー設定 (LLM-as-Judge)
provider = fOpenAI(model_engine="gpt-4o-mini")

# Feedback Functions 定義
f_context_relevance = (
    Feedback(provider.context_relevance, name="Context Relevance")
    .on_input()
    .on(TruCustomApp.select_context())
    .aggregate(np.mean)
)

f_groundedness = (
    Feedback(provider.groundedness_measure_with_cot_reasons, name="Groundedness")
    .on(TruCustomApp.select_context().collect())
    .on_output()
)

f_answer_relevance = (
    Feedback(provider.relevance_with_cot_reasons, name="Answer Relevance")
    .on_input_output()
)

feedbacks = [f_context_relevance, f_groundedness, f_answer_relevance]
```

## RAG アプリのラッピング

```python
# あなたの RAG 関数
def my_rag_app(question: str) -> str:
    # 1. 検索
    contexts = vector_db.search(question, top_k=5)
    context_text = "\n".join(contexts)

    # 2. 生成
    response = openai_client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": f"Context:\n{context_text}"},
            {"role": "user", "content": question},
        ]
    )
    return response.choices[0].message.content

# TruLens でラップ → 自動的に入出力を記録
tru_rag = TruCustomApp(
    my_rag_app,
    app_name="JibunKaisha RAG",
    app_version="v1.0",
    feedbacks=feedbacks,
)

# 評価実行
with tru_rag as recording:
    for question in test_questions:
        response = my_rag_app(question)

# セッションのスコアを確認
records_df = session.get_records_and_feedback()[0]
print(records_df[["input", "output", "Context Relevance", "Groundedness", "Answer Relevance"]])
```

## LlamaIndex との統合

```python
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader
from trulens.apps.llamaindex import TruLlama

# LlamaIndex RAG アプリ構築
documents = SimpleDirectoryReader("./data/").load_data()
index = VectorStoreIndex.from_documents(documents)
query_engine = index.as_query_engine()

# TruLens でラップ
tru_query_engine = TruLlama(
    query_engine,
    app_name="LlamaIndex RAG",
    feedbacks=feedbacks,
)

# 評価実行
with tru_query_engine as recording:
    for q in questions:
        query_engine.query(q)
```

## LangChain との統合

```python
from langchain.chains import RetrievalQA
from trulens.apps.langchain import TruChain

# LangChain RAG チェーン
qa_chain = RetrievalQA.from_chain_type(
    llm=ChatOpenAI(model="gpt-4o"),
    retriever=vectorstore.as_retriever(),
)

# TruLens でラップ
tru_chain = TruChain(
    qa_chain,
    app_name="LangChain RAG",
    feedbacks=feedbacks,
)

# 評価実行
with tru_chain as recording:
    for q in questions:
        qa_chain.invoke({"query": q})
```

## ダッシュボード起動

```python
from trulens.dashboard import run_dashboard

# ブラウザで可視化 (http://localhost:8501)
run_dashboard(session)
```

## ダッシュボードで確認できること

```
Overview:
  - アプリ別・バージョン別の平均スコア
  - 指標のトレンドグラフ

Evaluations タブ:
  - 各リクエストのスコア一覧
  - スコアが低いリクエストのフィルタリング

Record タブ:
  - 個別リクエストの詳細トレース
  - どのコンテキストを取得したか
  - なぜスコアが低かったか (CoT Reasons)
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'trulens', 'models',
  'TruLens 技術詳解 — Feedback Functions設計・Groundedness計算・RAGトライアド評価理論・Snowflake統合',
  $$## RAG トライアド (RAG Triad) 理論

TruLens の評価哲学は "RAG Triad" に基づく:

```
        [User Query]
           /    \
          /      \
[Context        [Answer]
Relevance]      Relevance]
    \               /
     \             /
      [Context]
          |
      [Groundedness]
```

**3 指標すべてが必要な理由**:

```
Context Relevance のみ高い場合:
  → 関連するコンテキストを取得できているが、
    LLM がハルシネーションを起こしている可能性

Groundedness のみ高い場合:
  → コンテキストに忠実だが、
    コンテキスト自体が質問と無関係かもしれない

Answer Relevance のみ高い場合:
  → 質問に答えているように見えるが、
    コンテキストを使わず事前知識で回答している可能性

3つすべてが高い → RAG が正しく機能している
```

## Groundedness の計算方法 (CoT)

```python
# Groundedness with Chain-of-Thought の内部動作

def groundedness_measure_with_cot_reasons(context: str, statement: str) -> float:
    prompt = f"""
    コンテキスト: {context}
    主張: {statement}

    この主張はコンテキストで支持されていますか？
    ステップバイステップで考えてください:
    1. 主張の各要素を列挙
    2. 各要素がコンテキストに存在するか確認
    3. 0〜1 でスコアを出力

    Score: [0.0〜1.0]
    Reason: [理由]
    """
    # LLM の出力からスコアと理由を抽出
    response = judge_llm(prompt)
    return parse_score(response)
```

## カスタム Feedback Function

```python
from trulens.core import Feedback
from trulens.providers.openai import OpenAI

provider = OpenAI(model_engine="gpt-4o-mini")

# 日本語品質チェックのカスタム関数
def japanese_quality(output: str) -> float:
    """日本語の品質を 0〜1 で評価"""
    has_japanese = bool(re.search(r'[ぁ-んァ-ン一-龯]', output))
    has_polite = bool(re.search(r'ます|です|ください', output))
    appropriate_length = 50 <= len(output) <= 800

    return sum([
        0.5 if has_japanese else 0,
        0.3 if has_polite else 0,
        0.2 if appropriate_length else 0,
    ])

f_japanese = Feedback(japanese_quality, name="Japanese Quality").on_output()
```

## Snowflake Cortex 統合 (Enterprise)

```python
from trulens.providers.cortex import Cortex

# Snowflake Cortex を評価 LLM として使用
snowflake_provider = Cortex(
    snowflake_connector=my_snowflake_connection,
    model_engine="snowflake-arctic-instruct",
)

f_context_relevance = Feedback(
    snowflake_provider.context_relevance,
    name="Context Relevance (Arctic)"
).on_input().on(TruCustomApp.select_context()).aggregate(np.mean)

# データはすべて Snowflake 内で処理 → 外部API不要
# → 医療・金融など規制業界に最適
```

## 自分株式会社 RAG 品質改善サイクル

```
Week 1: ベースライン計測
  - 現在の RAG を TruLens でラップ
  - 100 件のテスト質問で評価
  - Context Relevance / Groundedness / Answer Relevance 計測

Week 2: ボトルネック特定
  - Dashboard でスコア低い件の確認
  - よくある失敗パターンを分類:
    a. 取得失敗 (Context Relevance が低い)
    b. ハルシネーション (Groundedness が低い)
    c. 的外れ回答 (Answer Relevance が低い)

Week 3-4: 対策実施
  a. 取得失敗 → チャンクサイズ変更 / HyDE / Rerank 追加
  b. ハルシネーション → Temperature 下げる / プロンプト強化
  c. 的外れ → システムプロンプト修正

Week 5: 再計測 → 改善確認
```$$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 259→260社化: TruLens 追加',
  'PS#3 S82。TruLens (Snowflake製RAG評価フレームワーク/RAGトライアド/Context Relevance/Groundedness/Answer Relevance/Feedback Functions/LlamaIndex+LangChain統合/ダッシュボード可視化/GitHub 2k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
