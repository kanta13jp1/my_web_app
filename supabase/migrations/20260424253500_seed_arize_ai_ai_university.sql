-- Session PS#3-S36: AI大学 168社化 — Arize AI 追加
-- 2020 年 Berkeley CA 創業の AI/ML 観測・評価プラットフォーム。累計 $131M 調達 (Series C $70M / Adams Street)。
-- Phoenix: OSS LLM 観測フレームワーク (GitHub stars 多数・完全無料 self-host)。
-- Arize AX: Enterprise LLM 監視 (~$50K/年〜) — span レベルトレース / LLM-as-judge / PagerDuty 連携。
-- 2026-01 CLI リリース: Claude Code / Cursor から直接 Phoenix にアクセス可能。
-- OpenAI / Anthropic / Google / LangChain / LlamaIndex / CrewAI / LangGraph / Vercel AI SDK 対応。
-- 既存 166 社の「LLM 観測・評価・デバッグ」軸空白を埋める (W&B は学習追跡 / Arize は推論品質監視)。
-- Step 0: 8/9 (Phoenix OSS / 多フレームワーク / Claude Code CLI統合 / $131M / LLM-as-judge)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'arize_ai',
  'overview',
  'Arize AI — LLM 観測・評価プラットフォーム / Phoenix OSS',
  $md$
# Arize AI — AI Observability & Evaluation

2020 年創業 (Berkeley, CA)。機械学習モデルと LLM アプリケーションの
**本番監視・評価・デバッグ** に特化したプラットフォーム。

累計 **$131M** を調達 (Series C $70M / Adams Street Partners 主導)。

## 2 つのプロダクト

### Phoenix (オープンソース)
完全 OSS・self-host 可能な LLM 観測フレームワーク。
機能制限なし / ベンダー・言語非依存 / Apache 2.0。

**2026 年 1 月**: CLI リリースにより **Claude Code・Cursor** などの
AI コーディングアシスタントから直接 Phoenix にアクセス可能に。

### Arize AX (エンタープライズ)
本番 LLM アプリ向けのフルマネージドプラットフォーム。
リアルタイムアラート / LLM-as-judge 評価 / AI デバッグアシスタント「Alyx」。

## 対応フレームワーク

| カテゴリ | サポート |
| :--- | :--- |
| **LLM プロバイダー** | OpenAI / Anthropic / Google GenAI / AWS Bedrock / OpenRouter / LiteLLM |
| **エージェントフレームワーク** | LangGraph / CrewAI / OpenAI Agents SDK / Claude Agent SDK |
| **RAG フレームワーク** | LangChain / LlamaIndex / DSPy |
| **フロントエンド** | Vercel AI SDK / Mastra |

## 強み

- **Phoenix 完全無料 OSS** — 機能制限なし・self-host・GDPR 対応
- **LLM-as-judge 評価** — GPT-4o 等で LLM 出力の品質を自動評価
- **マルチフレームワーク** — 1 行追加で LangChain/LlamaIndex/CrewAI に対応
- **Claude Code CLI 統合** — AI コーディング中にリアルタイムでトレース確認
$md$,
  'https://arize.com/',
  '2026-04-24',
  1
),

(
  'arize_ai',
  'models',
  'Arize Phoenix / AX 機能・料金比較 (2026)',
  $md$
## Phoenix vs Arize AX 比較

| 機能 | Phoenix (OSS) | Arize AX (Enterprise) |
| :--- | :--- | :--- |
| **価格** | 完全無料 | ~$50,000/年〜 |
| **ホスティング** | Self-host | マネージドクラウド |
| **トレース** | ✅ span/session 両方 | ✅ span/session 両方 |
| **LLM-as-judge** | ✅ | ✅ (拡張版) |
| **リアルタイムアラート** | — | ✅ PagerDuty / Slack |
| **ドリフト検出** | — | ✅ |
| **AI デバッグアシスタント** | — | ✅ Alyx |
| **SSO / RBAC** | — | ✅ |
| **SLA** | — | ✅ |

## Phoenix の主要機能

| 機能 | 説明 |
| :--- | :--- |
| **OpenTelemetry 互換** | 業界標準プロトコルでトレースを収集 |
| **LLM Traces** | プロンプト・レスポンス・レイテンシーを span ごとに記録 |
| **Evaluations** | LLM-as-judge / ハルシネーション検出 / 関連性スコア |
| **Datasets** | テストケース管理・回帰テスト |
| **Experiments** | プロンプト A/B テスト |
| **Embeddings** | 埋め込みドリフトの可視化 |

## 対応 LLM プロバイダー評価指標

| 指標 | 説明 |
| :--- | :--- |
| **Hallucination** | 回答の事実根拠スコア |
| **Relevance** | クエリとの関連性 |
| **Toxicity** | 有害コンテンツ検出 |
| **QA Correctness** | 正解率 (参照回答との比較) |
$md$,
  'https://phoenix.arize.com/pricing/',
  '2026-04-24',
  2
),

(
  'arize_ai',
  'api',
  'Arize Phoenix API 入門',
  $md$
## Arize Phoenix の始め方

### インストール & 起動

```bash
pip install arize-phoenix
python -m phoenix.server.main &   # ローカルで Phoenix サーバーを起動
# → http://localhost:6006 で UI にアクセス
```

### OpenAI / Anthropic のトレース (1行追加)

```python
import phoenix as px
from phoenix.otel import register

# Phoenix にトレースを送信するよう設定 (1 行)
tracer_provider = register(project_name="ai-university-app")

# 以降、OpenAI / Anthropic の呼び出しが自動的にトレースされる
from openai import OpenAI
client = OpenAI()

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "AI大学で学べることは？"}]
)

# Phoenix UI (localhost:6006) でトレースを確認できる
```

### LangChain との統合

```python
from phoenix.otel import register
from opentelemetry.instrumentation.langchain import LangchainInstrumentor

# Phoenix + LangChain 自動計装
register(project_name="rag-pipeline")
LangchainInstrumentor().instrument()

# 以降の LangChain コードは自動トレース
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage

llm = ChatOpenAI(model="gpt-4o")
result = llm.invoke([HumanMessage(content="AI観測の重要性は？")])
```

### LLM-as-Judge 評価

```python
import phoenix as px
from phoenix.evals import (
    HallucinationEvaluator,
    RelevanceEvaluator,
    run_evals,
)
from openai import OpenAI

# 評価器の設定
model = px.evals.OpenAIModel(model="gpt-4o")
hallucination_evaluator = HallucinationEvaluator(model)
relevance_evaluator = RelevanceEvaluator(model)

# データセットに対して評価を実行
client = px.Client()
ds = client.get_dataset(name="my-rag-traces")

results = run_evals(
    dataframe=ds.as_dataframe(),
    evaluators=[hallucination_evaluator, relevance_evaluator],
    provide_explanation=True,
)
print(results)
```

## クイックスタート

1. `pip install arize-phoenix` でインストール
2. `python -m phoenix.server.main` でローカルサーバー起動
3. `register(project_name="my-project")` をコードに 1 行追加
4. LLM コールが自動的に `localhost:6006` でトレース確認可能
5. 本番環境: [phoenix.arize.com](https://phoenix.arize.com) でクラウド版を利用
$md$,
  'https://arize.com/docs/phoenix',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
