-- Session PS#3-S37: AI大学 170社化 — Comet ML 追加
-- 2013年創業。ML実験追跡・LLMトレーシング・本番監視の統合プラットフォーム。
-- 2021-11 Series B $50M (OpenView + Scale Venture Partners + Two Sigma Ventures) / 累計 ~$70M。
-- ARR $17M (2024年) / 88名規模。
-- Opik (OSS LLMトレーシング): GitHub stars 急増 / Apache 2.0 / self-host 可能。
-- W&B がモデル学習追跡寄りに対し、Comet は LLM アプリ評価・本番監視に強み。
-- Step 0: 7/9 (Opik OSS / $70M累計 / $17M ARR / 実験追跡老舗 / LLM特化evals)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'comet_ml',
  'overview',
  'Comet ML — ML 実験追跡 & LLM 評価プラットフォーム / Opik OSS',
  $md$
# Comet ML — End-to-End AI Developer Platform

2013 年創業の ML 実験追跡プラットフォーム。
機械学習モデルの実験管理から、LLM アプリケーションの観測・評価まで一貫して対応する。

2021 年 11 月に **Series B $50M** (OpenView 主導 / Scale Venture Partners / Two Sigma Ventures) 完了。
累計調達額 **~$70M** / ARR **$17M** (2024年)。

## 2 つのプロダクト

### Opik (オープンソース LLM 観測)
Apache 2.0 ライセンスの完全 OSS LLM トレーシング・評価フレームワーク。
Self-host または [comet.com/opik](https://www.comet.com/opik) のクラウド版を利用可能。

### Comet (ML 実験追跡・管理)
機械学習実験の自動追跡・比較・チーム共有を提供するコアプラットフォーム。
ハイパーパラメータ・メトリクス・アーティファクトを自動記録し、
実験の再現性とチームコラボレーションを支援する。

## Comet vs Weights & Biases

| 観点 | Comet ML | W&B |
| :--- | :--- | :--- |
| **強み** | LLM 評価・本番監視 | モデル学習追跡・スイープ最適化 |
| **OSS** | Opik (完全無料) | W&B は SaaS 寄り |
| **LLM トレーシング** | ✅ Opik でネイティブ対応 | 部分対応 (Weave) |
| **ML 実験追跡** | ✅ | ✅ (より成熟) |
| **創業** | 2013年 | 2018年 |

## 対応フレームワーク (Opik)

OpenAI / Anthropic / Google GenAI / LangChain / LlamaIndex / Ragas /
Haystack / CrewAI / LangGraph に対応。
$md$,
  'https://www.comet.com/',
  '2026-04-24',
  1
),

(
  'comet_ml',
  'models',
  'Comet ML / Opik 機能・料金比較 (2026)',
  $md$
## Opik (LLM 観測) 機能

| 機能 | 説明 |
| :--- | :--- |
| **LLM トレーシング** | プロンプト・レスポンス・レイテンシー・コストを自動記録 |
| **評価 (Evals)** | LLM-as-judge / カスタム評価器 / ハルシネーション検出 |
| **データセット管理** | テストケース・ゴールデンデータセット管理 |
| **プロンプト管理** | バージョン管理・A/B テスト |
| **本番監視** | リアルタイムアラート・ドリフト検出 |
| **Self-host** | Docker/Kubernetes でオンプレミス運用可 |

## Comet (ML 実験追跡) 機能

| 機能 | 説明 |
| :--- | :--- |
| **自動追跡** | コード・ハイパーパラメータ・メトリクス・出力を自動記録 |
| **実験比較** | カスタム可視化でモデルバージョン比較 |
| **モデルレジストリ** | 実験から本番まで一元管理 |
| **データ・アーティファクト** | データセット・モデル重みのバージョン管理 |
| **チームコラボ** | レポート・ダッシュボード共有 |

## 料金 (2026)

| プラン | 価格 | 概要 |
| :--- | :--- | :--- |
| **Opik OSS** | 完全無料 | self-host / 機能制限なし |
| **Opik Cloud (無料枠)** | $0 | 個人開発 |
| **Comet 無料** | $0/月 | 個人向け基本機能 |
| **Comet Team** | $39/ユーザー/月 | チーム向け共同作業 |
| **Enterprise** | カスタム | SSO / SAML / SLA / 監査ログ |
$md$,
  'https://www.comet.com/site/pricing/',
  '2026-04-24',
  2
),

(
  'comet_ml',
  'api',
  'Comet ML (Opik) API 入門',
  $md$
## Opik の始め方 (LLM トレーシング)

### インストール & セットアップ

```bash
pip install opik
opik configure  # API キーを設定 (または環境変数 OPIK_API_KEY)
```

### Anthropic トレーシング (1 行追加)

```python
import opik
from opik.integrations.anthropic import track_anthropic
from anthropic import Anthropic

# Anthropic クライアントを 1 行でラップ
client = track_anthropic(Anthropic())

@opik.track
def analyze_ai_provider(provider_name: str) -> str:
    message = client.messages.create(
        model="claude-opus-4-7",
        max_tokens=512,
        messages=[{
            "role": "user",
            "content": f"{provider_name} の強みを教えてください"
        }]
    )
    return message.content[0].text

# 呼び出しが自動的に Opik でトレースされる
result = analyze_ai_provider("LangSmith")
print(result)
# → Opik UI (comet.com/opik) でトレース確認可能
```

### LLM-as-Judge 評価

```python
import opik
from opik.evaluation import evaluate
from opik.evaluation.metrics import Hallucination, AnswerRelevance

# 評価セットを定義
dataset = opik.get_or_create_dataset("ai-university-qa")
dataset.insert([
    {"input": {"question": "LangSmith とは？"}, "expected_output": "LangChain の観測プラットフォーム"},
    {"input": {"question": "Comet ML の特徴は？"}, "expected_output": "ML実験追跡 + LLMトレーシング"},
])

# 評価を実行
def llm_task(item):
    return {"output": analyze_ai_provider(item["question"])}

results = evaluate(
    experiment_name="claude-opik-eval",
    dataset=dataset,
    task=llm_task,
    scoring_metrics=[Hallucination(), AnswerRelevance()],
)
```

### ML 実験追跡 (Comet)

```python
import comet_ml

# 実験を開始
experiment = comet_ml.start(project_name="ai-university-model")

# ハイパーパラメータを記録
experiment.log_parameters({
    "model": "claude-opus-4-7",
    "temperature": 0.7,
    "max_tokens": 1024,
})

# メトリクスを記録
experiment.log_metric("accuracy", 0.92)
experiment.log_metric("latency_ms", 450)

# モデル重みを保存
experiment.log_model("my-llm-wrapper", "path/to/model/")
experiment.end()
```

## クイックスタート

1. `pip install opik` でインストール
2. `opik configure` で API キー設定
3. `track_anthropic(Anthropic())` で 1 行ラップ
4. `@opik.track` デコレータで関数にトレースを付加
5. [comet.com/opik](https://www.comet.com/opik) で UI 確認 (または self-host)
$md$,
  'https://www.comet.com/docs/opik/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
