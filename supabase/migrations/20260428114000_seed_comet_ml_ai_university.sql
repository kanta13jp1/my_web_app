-- PS#3 S89: AI大学 272→273社化 — Comet ML (ML実験管理・モデルレジストリ・LLM評価)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'comet-ml', 'overview',
  'Comet ML — ML実験管理・モデルレジストリ・LLMops監視・クラウド/オンプレ対応 (GitHub 3k+ / 8/9)',
  $$## Comet ML とは

**Comet ML** は ML実験管理・モデルレジストリ・LLM 評価を統合した**MLops プラットフォーム**。2016年創業、ニューヨーク拠点。クラウド SaaS とオンプレ両対応。

GitHub 3,000+ スター (SDK)。エンタープライズ採用多数 (Uber / Twitter / Airbnb 等)。W&B / MLflow と直接競合する主要プレーヤー。

## 特徴と設計哲学

```
"すべての実験を自動追跡し、モデルをプロダクションまで管理"

主要機能:
  ✓ 実験追跡 (メトリクス/パラメータ/コード/環境を自動記録)
  ✓ モデルレジストリ (バージョン管理・ステージング・本番)
  ✓ Comet Artifacts (データセット/モデルアーティファクト管理)
  ✓ LLM 評価 (Opik: OSS LLMops プラットフォーム)
  ✓ データパネル (インタラクティブ可視化)
```

## Opik: OSS LLMops (2024年新機能)

```
Comet が 2024年に OSS 化した LLM 評価・監視プラットフォーム:

  ✓ LLM アプリのトレース (prompt → response 全記録)
  ✓ RAG パイプライン評価 (hallucination / context recall)
  ✓ A/B テスト (プロンプトテンプレート比較)
  ✓ プロダクション監視 (本番LLMアプリのリアルタイム観察)
  ✓ CI/CD 統合 (PR ごとにプロンプト品質をゲート)

pip install opik
# → MLflow と同じ感覚で LLM を評価できる
```

## W&B との違い

| 機能 | Comet ML | W&B |
|------|----------|-----|
| 価格 | 無料枠: 無制限実験 (チーム3名まで) | 無料枠: 個人のみ |
| オンプレ | ✓ Enterprise | ✓ Enterprise |
| LLMops | Opik (OSS) | W&B Weave |
| 特徴量ストア | — | — |

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **実験管理** | 全 ML 実験を自動記録 | 最良モデルを即座に追跡 |
| **LLM 評価** | Opik で RAG 品質を定量化 | 幻覚・コンテキスト品質改善 |
| **モデル本番化** | レジストリで staging → prod | デプロイ標準化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'comet-ml', 'api',
  'Comet ML 実践 — Experiment/log_metric/Artifact/Model Registry/Opik LLMトレース/CI統合',
  $$## インストール & セットアップ

```bash
pip install comet_ml
pip install opik          # LLMops (別パッケージ)

# API キー設定
export COMET_API_KEY="your-api-key"
# または comet-ml login で対話的に設定
```

## 基本: Experiment で実験追跡

```python
import comet_ml
from comet_ml import Experiment

# 実験開始 (自動でコード・環境・git差分を記録)
experiment = Experiment(
    api_key="your-api-key",
    project_name="jibun-kaisha-sentiment",
    workspace="kanta13jp1",
)

# パラメータ記録
experiment.log_parameters({
    "learning_rate": 2e-5,
    "batch_size": 32,
    "model": "bert-base-japanese",
    "epochs": 3,
})

# 訓練ループ
for epoch in range(3):
    train_loss = train_epoch(model, train_loader)
    val_acc = evaluate(model, val_loader)

    # メトリクス記録
    experiment.log_metric("train_loss", train_loss, step=epoch)
    experiment.log_metric("val_accuracy", val_acc, step=epoch)

# モデルファイル記録
experiment.log_model("bert-japanese-v1", "./model_output/")

experiment.end()
```

## sklearn / PyTorch 自動統合

```python
# sklearn: fit 前後を自動記録
from comet_ml.integration.sklearn import log_model
import comet_ml

experiment = comet_ml.start(project_name="jibun-kaisha-churn")

from sklearn.ensemble import GradientBoostingClassifier
clf = GradientBoostingClassifier(n_estimators=100, max_depth=4)
clf.fit(X_train, y_train)

# モデルをワンライナーで記録
log_model(experiment, clf, "churn-model-v2")
```

## Artifact: データセット & モデル管理

```python
from comet_ml import Artifact

# Artifact 作成 (データセット)
dataset_artifact = Artifact(
    name="jibun-kaisha-training-data",
    artifact_type="dataset",
    version="2.0.0",
    metadata={"rows": 50000, "created": "2026-04-28"},
)
dataset_artifact.add("./data/train.parquet")
dataset_artifact.add("./data/val.parquet")
experiment.log_artifact(dataset_artifact)

# Artifact 取得 (別実験から再利用)
downloaded = experiment.get_artifact(
    "jibun-kaisha-training-data",
    version_or_alias="2.0.0",
)
downloaded.download("./data/")
```

## Model Registry: ステージ管理

```python
from comet_ml.api import API

api = API(api_key="your-api-key")

# モデルをレジストリに登録
api.update_registry_model_version(
    workspace="kanta13jp1",
    registry_name="jibun-kaisha-sentiment",
    version="1.0.0",
    status="Staging",
    comment="val_accuracy=0.93, テスト環境で検証中",
)

# Staging → Production に昇格
api.update_registry_model_version(
    workspace="kanta13jp1",
    registry_name="jibun-kaisha-sentiment",
    version="1.0.0",
    status="Production",
)

# 本番モデルのダウンロード
api.download_registry_model(
    workspace="kanta13jp1",
    registry_name="jibun-kaisha-sentiment",
    version="1.0.0",
    output_path="./prod_model/",
)
```

## Opik: LLM 評価・トレース

```python
import opik
from opik import track
from opik.evaluation import evaluate
from opik.evaluation.metrics import Hallucination, AnswerRelevance

# LLM 呼び出しを自動トレース
@track
def generate_response(prompt: str) -> str:
    import anthropic
    client = anthropic.Anthropic()
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}]
    )
    return response.content[0].text

# RAG パイプライン評価
dataset = [
    {"input": "自分株式会社の特徴は?", "expected_output": "..."},
    {"input": "競合との違いは?", "expected_output": "..."},
]

results = evaluate(
    experiment_name="jibun-kaisha-rag-v2",
    dataset=dataset,
    task=generate_response,
    scoring_metrics=[
        Hallucination(),    # 幻覚チェック
        AnswerRelevance(),  # 関連性スコア
    ],
)

print(f"Hallucination rate: {results.hallucination:.2%}")
print(f"Answer relevance: {results.answer_relevance:.2f}")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 272→273社化: Comet ML 追加',
  'PS#3 S89。Comet ML (ML実験管理/モデルレジストリ/Artifact管理/Opik LLMops OSS/RAG評価/Hallucination検出/GitHub 3k+/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
