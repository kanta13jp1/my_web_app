-- PS#3 S84: AI大学 262→263社化 — Arize Phoenix (OSS LLMオブザーバビリティ / OpenTelemetry)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'arize-phoenix', 'overview',
  'Arize Phoenix — OSS LLMオブザーバビリティ・RAGトレース・OpenTelemetry統合 (GitHub 4k+ / 9/9)',
  $$## Arize Phoenix とは

**Arize Phoenix** は Arize AI が OSS で提供する **LLM アプリケーションのオブザーバビリティプラットフォーム**。OpenTelemetry 標準に基づき、LLM アプリの**トレース・評価・デバッグ**を一元管理できる。

GitHub 4,000+ スター。Apache 2.0 ライセンス。完全ローカル実行可能 (データ外部送信なし)。

## Phoenix の 4 大特徴

| 特徴 | 内容 |
|------|------|
| **OpenTelemetry 標準** | OTel ベースのトレーシング → 業界標準で将来性高い |
| **ローカル完結** | Docker 1行 / pip install で自己ホスト可 |
| **RAG 特化評価** | Relevance / Hallucination / QA 評価を内蔵 |
| **多フレームワーク対応** | OpenAI / LangChain / LlamaIndex / DSPy / Haystack |

## TruLens・Langsmith との違い

```
TruLens:
  → Snowflake 製 / RAG トライアド特化 / SQLite 記録
  → 評価に強い / 可視化やや弱い

Langsmith:
  → LangChain 公式 / クラウドのみ / 有料
  → LangChain ユーザーに最適

Arize Phoenix:
  → OSS / ローカル自己ホスト / OpenTelemetry 標準
  → フレームワーク非依存・プライバシー重視環境に最適
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **GDPR対応** | ローカル実行で個人データ外部送信なし | コンプライアンス確保 |
| **RAG品質管理** | トレース可視化で問題箇所特定 | 改善サイクル短縮 |
| **マルチLLM比較** | OpenAI vs Claude vs Gemini 品質比較 | コスト最適化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'arize-phoenix', 'api',
  'Arize Phoenix 実践 — インストール/OpenAI+LangChain+LlamaIndex トレース/RAG評価/Evals/ダッシュボード起動',
  $$## インストールと起動

```bash
# pip でインストール
pip install arize-phoenix

# ローカルサーバー起動 (http://localhost:6006)
python -m phoenix.server.main &

# または Docker
docker run -p 6006:6006 arizephoenix/phoenix:latest

# OpenTelemetry インストルメント
pip install openinference-instrumentation-openai
pip install openinference-instrumentation-langchain
pip install openinference-instrumentation-llama-index
```

## OpenAI 自動トレース

```python
import phoenix as px
from openinference.instrumentation.openai import OpenAIInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

# Phoenix に接続
session = px.launch_app()  # ブラウザで http://localhost:6006 が開く

# OpenTelemetry 設定 (Phoenix に送信)
endpoint = "http://localhost:6006/v1/traces"
tracer_provider = TracerProvider()
tracer_provider.add_span_processor(
    SimpleSpanProcessor(OTLPSpanExporter(endpoint=endpoint))
)

# OpenAI を自動インストルメント
OpenAIInstrumentor().instrument(tracer_provider=tracer_provider)

# 以降の OpenAI 呼び出しが自動でトレース記録される
from openai import OpenAI
client = OpenAI()

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "自分株式会社の競合を教えて"}],
)
# → Phoenix ダッシュボードにトレースが自動表示される
```

## LangChain トレース

```python
from openinference.instrumentation.langchain import LangChainInstrumentor
from langchain_openai import ChatOpenAI
from langchain.chains import RetrievalQA

# LangChain を自動インストルメント
LangChainInstrumentor().instrument(tracer_provider=tracer_provider)

# 通常通り LangChain を使うだけでトレースが記録される
llm = ChatOpenAI(model="gpt-4o")
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    retriever=vectorstore.as_retriever(),
)

result = qa_chain.invoke({"query": "AIライフマネジメントとは？"})
# → RAG の各ステップ (Retrieval → Augmentation → Generation) がトレースに記録
```

## LlamaIndex トレース

```python
from openinference.instrumentation.llama_index import LlamaIndexInstrumentor
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader

# LlamaIndex を自動インストルメント
LlamaIndexInstrumentor().instrument(tracer_provider=tracer_provider)

# 通常通り LlamaIndex を使うだけ
documents = SimpleDirectoryReader("./data/").load_data()
index = VectorStoreIndex.from_documents(documents)
query_engine = index.as_query_engine()

response = query_engine.query("競合21社の特徴は？")
# → 埋め込み生成 → 検索 → LLM 生成の全ステップがトレースに表示
```

## RAG 評価 (Phoenix Evals)

```python
import phoenix as px
from phoenix.evals import (
    HallucinationEvaluator,
    QAEvaluator,
    RelevanceEvaluator,
    run_evals,
)
from phoenix.evals.models import OpenAIModel

# 評価用 LLM (judge として使う)
eval_model = OpenAIModel(model="gpt-4o-mini")

# 評価器定義
hallucination_evaluator = HallucinationEvaluator(eval_model)
qa_evaluator = QAEvaluator(eval_model)
relevance_evaluator = RelevanceEvaluator(eval_model)

# Phoenix からトレースデータを取得
phoenix_client = px.Client()
spans_df = phoenix_client.get_spans_dataframe(project_name="jibun-kaisha-rag")

# バッチ評価実行
eval_results = run_evals(
    dataframe=spans_df,
    evaluators=[hallucination_evaluator, qa_evaluator, relevance_evaluator],
    provide_explanation=True,  # なぜそのスコアか説明付き
)

# 結果を Phoenix にアップロード (ダッシュボードで確認)
px.Client().log_evaluations(*eval_results)
```

## ダッシュボードで確認できること

```
Phoenix UI (http://localhost:6006):

Traces タブ:
  ├── 各リクエストのスパンツリー
  ├── LLM 呼び出しの詳細 (プロンプト / レスポンス / トークン数 / レイテンシ)
  └── RAG の各ステップの入出力

Evaluations タブ:
  ├── ハルシネーション率
  ├── QA 正解率
  └── 取得コンテキスト関連度

Dataset タブ:
  ├── 評価に使ったデータセット管理
  └── 失敗ケースの自動収集 → ファインチューニングデータに活用
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'arize-phoenix', 'models',
  'Arize Phoenix 技術詳解 — OpenTelemetryアーキテクチャ/Span設計/DSPy統合/本番監視/Arize Cloud連携',
  $$## OpenTelemetry アーキテクチャ

```
Phoenix の OTel アーキテクチャ:

Your App
  ↓ (OTel SDK + Instrumentor)
Spans (トレースデータ)
  ↓ (OTLP over HTTP)
Phoenix Collector (localhost:6006)
  ↓ (SQLite / PostgreSQL)
Phoenix UI

OTel のメリット:
  ・ベンダーロックインなし (Phoenix → Jaeger → DataDog に切替可能)
  ・標準化されたデータ形式 (全フレームワーク共通)
  ・既存のオブザーバビリティ基盤 (Grafana / Datadog) と統合可
```

## カスタム Span (手動トレーシング)

```python
from opentelemetry import trace
from opentelemetry.trace import SpanKind

tracer = trace.get_tracer(__name__)

def process_user_query(user_id: str, query: str) -> str:
    # カスタムスパンで任意の処理をトレース
    with tracer.start_as_current_span(
        "jibun-kaisha.query-pipeline",
        kind=SpanKind.SERVER,
        attributes={
            "user.id": user_id,
            "query.text": query,
            "query.length": len(query),
        }
    ) as span:
        # 検索ステップ
        with tracer.start_as_current_span("retrieval") as retrieval_span:
            contexts = vector_db.search(query, top_k=5)
            retrieval_span.set_attribute("retrieved.count", len(contexts))

        # LLM ステップ (OpenAI Instrumentor が自動でトレース)
        response = openai_client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": f"Context: {contexts}"},
                {"role": "user", "content": query},
            ]
        )
        result = response.choices[0].message.content

        # カスタム評価スコアをスパンに付加
        span.set_attribute("response.length", len(result))
        span.set_attribute("contexts.count", len(contexts))

        return result
```

## DSPy 統合 (プログラマティック LLM 開発)

```python
from openinference.instrumentation.dspy import DSPyInstrumentor
import dspy

# DSPy を自動インストルメント
DSPyInstrumentor().instrument(tracer_provider=tracer_provider)

# DSPy でプログラマティックに LLM パイプライン構築
lm = dspy.LM("openai/gpt-4o")
dspy.configure(lm=lm)

class JibunKaishaQA(dspy.Signature):
    """自分株式会社アプリに関する質問に答える"""
    question: str = dspy.InputField()
    answer: str = dspy.OutputField(desc="簡潔で正確な回答")

qa = dspy.ChainOfThought(JibunKaishaQA)
result = qa(question="競合は何社？")
# → DSPy の内部ステップ (CoT 推論) が全てトレースに表示
```

## 本番環境への展開

```yaml
# docker-compose.yml
version: "3.8"
services:
  phoenix:
    image: arizephoenix/phoenix:latest
    ports:
      - "6006:6006"
    environment:
      - PHOENIX_WORKING_DIR=/phoenix-data
      - PHOENIX_SQL_DATABASE_URL=postgresql://user:pass@postgres:5432/phoenix
    volumes:
      - phoenix-data:/phoenix-data
    depends_on:
      - postgres

  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: phoenix
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  phoenix-data:
  pgdata:
```

## Arize Cloud (エンタープライズ版)

```
OSS Phoenix vs Arize Cloud:

Phoenix (OSS):
  ✓ 完全無料
  ✓ 自己ホスト
  ✓ データ外部送信なし
  ✗ チームコラボ機能なし
  ✗ アラート / 本番監視なし

Arize Cloud:
  ✓ マネージド
  ✓ チームダッシュボード共有
  ✓ ドリフト検出 / アラート
  ✓ A/B テスト
  $ 有料 (エンタープライズ向け)

推奨:
  開発・検証段階 → Phoenix OSS
  本番・チーム運用 → Arize Cloud 検討
```$$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 262→263社化: Arize Phoenix 追加',
  'PS#3 S84。Arize Phoenix (OSS LLMオブザーバビリティ/OpenTelemetry標準/RAG評価Evals/LangChain+LlamaIndex+DSPy統合/ローカル自己ホスト/GitHub 4k+/Apache 2.0/9/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
