-- Session PS#3-S37: AI大学 169社化 — LangSmith 追加
-- LangChain が提供するエージェント・LLM 観測プラットフォーム。
-- 2025-10 Series B $125M @ $1.25B (IVP) / 累計 $260M / ユニコーン。
-- LangChain + LangGraph: 月 9,000 万ダウンロード / Fortune 500 の 35%。
-- LangSmith: 月次トレース量 YoY 12× / $16M ARR (2025)。
-- Python / TypeScript / Go / Java SDK + Framework非依存 / BYOC + self-host 対応。
-- Polly AI アシスタント: 大規模トレースを即座に解析・原因特定。
-- Step 0: 9/9 (ユニコーン $1.25B / 12× 成長 / Fortune 500 35% / 多言語 SDK / self-host)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'langsmith',
  'overview',
  'LangSmith — AI エージェント・LLM 観測プラットフォーム (ユニコーン / LangChain 公式)',
  $md$
# LangSmith — AI Agent & LLM Observability Platform

LangChain が提供するエージェント・LLM 観測プラットフォーム。
**フレームワーク非依存** の設計で、あらゆる AI スタックのトレース・評価・デプロイを統合管理する。

2025 年 10 月、**Series B $125M** (IVP 主導) を完了し評価額 **$1.25B** のユニコーンに到達。
累計調達額 **$260M**。LangSmith の月次トレース量は **YoY 12×** 成長。

## エコシステム規模

| 指標 | 数値 |
| :--- | :--- |
| **月次ダウンロード** | 9,000 万 (LangChain + LangGraph 合計) |
| **Fortune 500 採用率** | 35% |
| **LangSmith ARR** | ~$16M (2025) |
| **YoY トレース成長** | 12× |

## 主要機能

| 機能 | 説明 |
| :--- | :--- |
| **トレーシング** | LLM コール・エージェントステップ・RAG クエリを span ごとに記録 |
| **評価 (Evals)** | カスタム評価器・LLM-as-judge・自動回帰テスト |
| **Polly AI アシスタント** | 大規模トレースを自然言語で即座に解析・原因特定 |
| **Insights Agent** | エージェントの利用パターン・失敗モードを自動検出 |
| **カスタムダッシュボード** | メトリクス監視・アラート設定 |
| **データセット管理** | テストケース・ゴールデンデータセットを管理 |

## デプロイオプション

- **マネージドクラウド** — すぐに使える SaaS
- **BYOC (Bring Your Own Cloud)** — 自社 AWS/GCP/Azure 上で運用
- **Self-hosted** — データレジデンシー要件に完全対応

## 対応 SDK

Python / TypeScript / Go / Java の 4 言語で完全サポート。
LangChain 以外 (OpenAI SDK / Anthropic SDK / LlamaIndex 等) にも 1 行追加で対応。
$md$,
  'https://www.langchain.com/langsmith',
  '2026-04-24',
  1
),

(
  'langsmith',
  'models',
  'LangSmith 料金・プラン比較 (2026)',
  $md$
## LangSmith 料金プラン (2026)

| プラン | 価格 | トレース | 保存期間 | サポート |
| :--- | :--- | :--- | :--- | :--- |
| **Developer (無料)** | $0 | 5,000 件/月 | 14 日 | コミュニティ |
| **Plus** | $39/席/月 | 10,000 件基本込み | 14 日 | メール |
| **Plus (拡張保存)** | $5.00/1,000 件 | 追加分 | 400 日 | メール |
| **Enterprise** | カスタム | カスタム | カスタム | 専任 + SLA |

### Plus プランの追加課金

| 項目 | 料金 |
| :--- | :--- |
| 標準トレース超過 | $2.50 / 1,000 件 |
| 拡張保存 (400日) | $5.00 / 1,000 件 |

### Enterprise 追加機能

- SSO / RBAC / 監査ログ
- 専任 Slack サポート + SLA 保証
- カスタム保存ポリシー / コンプライアンス対応 (SOC 2 Type II)
- 優先機能リクエスト

## なぜ LangSmith が選ばれるか

| 理由 | 詳細 |
| :--- | :--- |
| **フレームワーク非依存** | LangChain 以外でも 1 行で統合 |
| **エージェント特化** | 複雑なマルチエージェントの全ステップを可視化 |
| **Polly AI** | トレース解析の工数を 90% 削減 |
| **BYOC / Self-host** | GDPR / HIPAA 対応の完全データ制御 |
$md$,
  'https://www.langchain.com/pricing',
  '2026-04-24',
  2
),

(
  'langsmith',
  'api',
  'LangSmith API 入門 — トレーシング & 評価',
  $md$
## LangSmith の始め方

### インストール & セットアップ

```bash
pip install langsmith
export LANGCHAIN_API_KEY="ls__..."    # LangSmith API キー
export LANGCHAIN_TRACING_V2="true"   # 自動トレース有効化
export LANGCHAIN_PROJECT="ai-university-app"
```

### 任意の LLM を 1 行でトレース

```python
from langsmith import traceable
from anthropic import Anthropic

client = Anthropic()

# @traceable で LangSmith に自動送信
@traceable
def call_claude(prompt: str) -> str:
    message = client.messages.create(
        model="claude-opus-4-7",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}]
    )
    return message.content[0].text

# 呼び出すだけで LangSmith UI にトレースが記録される
response = call_claude("AI大学で学べることを教えてください")
print(response)
```

### LangChain / LangGraph との統合

```python
from langchain_anthropic import ChatAnthropic
from langchain_core.messages import HumanMessage
import os

# 環境変数設定済みなら自動でトレース開始
os.environ["LANGCHAIN_TRACING_V2"] = "true"
os.environ["LANGCHAIN_API_KEY"] = "ls__..."

llm = ChatAnthropic(model="claude-opus-4-7")
response = llm.invoke([HumanMessage(content="LangSmith の使い方を教えて")])
# → LangSmith UI でトレース確認可能
```

### カスタム評価 (Evals)

```python
from langsmith import Client
from langsmith.evaluation import evaluate

client = Client()

# 評価関数を定義
def correctness_evaluator(run, example):
    """生成結果と期待値を比較"""
    prediction = run.outputs["output"]
    expected = example.outputs["expected"]
    score = 1.0 if expected in prediction else 0.0
    return {"key": "correctness", "score": score}

# データセットに対して評価を実行
results = evaluate(
    lambda inputs: {"output": call_claude(inputs["question"])},
    data="ai-university-qa-dataset",
    evaluators=[correctness_evaluator],
    experiment_prefix="claude-opus-4-7",
)
print(results.to_pandas())
```

## クイックスタート

1. `pip install langsmith` でインストール
2. `LANGCHAIN_API_KEY` と `LANGCHAIN_TRACING_V2=true` を環境変数に設定
3. `@traceable` デコレータを関数に追加 (任意のフレームワークで動作)
4. [smith.langchain.com](https://smith.langchain.com) でトレース確認
5. 本番環境: BYOC / Self-host でデータ完全制御
$md$,
  'https://docs.smith.langchain.com/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
