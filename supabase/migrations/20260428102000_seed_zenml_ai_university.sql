-- PS#3 S88: AI大学 270→271社化 — ZenML (Python ファーストのスタック非依存 MLOps フレームワーク)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'zenml', 'overview',
  'ZenML — Pythonファースト・スタック非依存MLOpsフレームワーク・クラウド/オンプレ対応 (GitHub 4k+ / 8/9)',
  $$## ZenML とは

**ZenML** は Python ファーストの**スタック非依存 MLOps フレームワーク**。2021年創業のスタートアップ ZenML GmbH が開発。MLパイプラインをポータブルに保ちつつ、インフラ (Kubeflow / SageMaker / Vertex AI / Airflow) を抽象化する。

GitHub 4,000+ スター。Apache 2.0 ライセンス。VC 調達済み (系列: Crane Venture Partners 他)。

## 設計哲学

```
"インフラに縛られないMLパイプライン"

他ツールとの違い:
  Kubeflow    → Kubernetes 前提 / インフラ知識必須
  MLflow      → 実験管理中心 / オーケストレーション弱
  ZenML       → どのインフラでも同じコードで動く
                "Stack" 概念で環境を切り替え可能
```

## コアコンセプト: Pipeline + Stack

```python
from zenml import pipeline, step
from zenml.client import Client

# Step 定義 (純粋 Python 関数)
@step
def load_data() -> dict:
    import pandas as pd
    df = pd.read_parquet("s3://jibun-kaisha-ml/train.parquet")
    return {"X": df["text"].tolist(), "y": df["label"].tolist()}

@step
def train_model(data: dict) -> str:
    from transformers import AutoModelForSequenceClassification, Trainer
    model = AutoModelForSequenceClassification.from_pretrained(
        "cl-tohoku/bert-base-japanese", num_labels=2
    )
    # ... 訓練処理 ...
    model_path = "/tmp/jibun-kaisha-model"
    model.save_pretrained(model_path)
    return model_path

@step
def evaluate_model(model_path: str) -> float:
    # ... 評価処理 ...
    return 0.92

# Pipeline 定義 (Step を繋ぐだけ)
@pipeline
def jibun_kaisha_training_pipeline():
    data = load_data()
    model_path = train_model(data)
    accuracy = evaluate_model(model_path)
```

## Stack: インフラ抽象化の核心

```yaml
# stack.yaml (ローカル開発 Stack)
name: local-stack
orchestrator:
  flavor: local          # ローカルで実行
artifact_store:
  flavor: local
  path: /tmp/zenml-artifacts

# stack.yaml (本番 Stack: GCP)
name: gcp-production
orchestrator:
  flavor: kubeflow       # Kubeflow で実行
  kubernetes_context: gke_jibun-kaisha_asia-northeast1_prod
artifact_store:
  flavor: gcs
  path: gs://jibun-kaisha-ml/artifacts
container_registry:
  flavor: gcp
  uri: asia-northeast1-docker.pkg.dev/jibun-kaisha/ml
experiment_tracker:
  flavor: mlflow
  tracking_uri: https://mlflow.jibun-kaisha.com
```

```bash
# Stack 切替 (コード変更なし!)
zenml stack set local-stack     # 開発
zenml stack set gcp-production  # 本番
python run_pipeline.py          # 同じコードで実行
```

## 対応インフラ一覧

| カテゴリ | 対応サービス |
|----------|-------------|
| **オーケストレーター** | Kubeflow / Airflow / SageMaker / Vertex AI / Skypilot / AzureML |
| **アーティファクトストア** | S3 / GCS / Azure Blob / MinIO / ローカル |
| **実験トラッカー** | MLflow / W&B / Comet ML / Neptune |
| **コンテナレジストリ** | ECR / GCR / ACR / Docker Hub |
| **モデルデプロイ** | Seldon / BentoML / KServe / Hugging Face |

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **ローカル→本番** | Stack 切替でコード変更ゼロ | 移行コスト最小化 |
| **マルチクラウド** | AWS/GCP/Azure を同一コードで | ベンダーロックイン回避 |
| **チーム共有** | Pipeline を git 管理 | 再現性・協調性確保 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'zenml', 'api',
  'ZenML 実践 — Step/Pipeline/Stack/Artifact/Model Registry/スケジュール実行/ZenML Cloud',
  $$## インストール & セットアップ

```bash
pip install zenml
zenml init          # プロジェクト初期化 (.zenml/ 作成)
zenml up            # ZenML Server をローカルで起動 (Dashboard付き)

# 統合インストール (必要なもののみ)
pip install zenml[aws]       # AWS 統合
pip install zenml[gcp]       # GCP 統合
pip install zenml[mlflow]    # MLflow 統合
pip install zenml[kubeflow]  # Kubeflow 統合
```

## Step の入出力型: Artifact 自動バージョン管理

```python
from zenml import step, pipeline
from zenml.types import HTMLString
from typing import Annotated, Tuple
import pandas as pd
from sklearn.base import ClassifierMixin

# 型アノテーションで Artifact が自動管理される
@step
def preprocess(
    raw_data: pd.DataFrame,
) -> Tuple[
    Annotated[pd.DataFrame, "X_train"],
    Annotated[pd.DataFrame, "X_val"],
    Annotated[pd.Series, "y_train"],
    Annotated[pd.Series, "y_val"],
]:
    from sklearn.model_selection import train_test_split
    X = raw_data[["text"]]
    y = raw_data["label"]
    X_tr, X_v, y_tr, y_v = train_test_split(X, y, test_size=0.2)
    return X_tr, X_v, y_tr, y_v

@step
def train(
    X_train: pd.DataFrame,
    y_train: pd.Series,
) -> Annotated[ClassifierMixin, "model"]:
    from sklearn.linear_model import LogisticRegression
    clf = LogisticRegression()
    clf.fit(X_train, y_train)
    return clf
```

## Model Registry: モデルのバージョン管理

```python
from zenml import step
from zenml.client import Client
from zenml.models import ModelVersion

@step
def register_model(model_path: str, accuracy: float) -> None:
    """モデルを ZenML Model Registry に登録"""
    client = Client()

    # モデル登録 (なければ新規作成)
    zenml_model = client.get_or_create_model(
        model_name="jibun-kaisha-sentiment",
        description="日本語感情分析モデル",
        tags=["bert", "japanese", "sentiment"],
    )

    # バージョン登録
    model_version = client.create_model_version(
        model_name="jibun-kaisha-sentiment",
        version=None,  # 自動採番
        metadata={"accuracy": accuracy, "dataset": "jibun-kaisha-v2"},
    )

    # ステージ管理 (staging → production)
    if accuracy > 0.90:
        model_version.set_stage("production", force=True)
        print(f"Model promoted to production! Accuracy: {accuracy}")
```

```python
# 過去のモデルを取得
client = Client()

# 本番モデルを取得
prod_model = client.get_model_version(
    model_name="jibun-kaisha-sentiment",
    model_version_name="production",
)

# 全バージョンを比較
versions = client.list_model_versions(
    model_name="jibun-kaisha-sentiment"
)
for v in versions:
    print(f"v{v.number}: accuracy={v.metadata.get('accuracy')}, stage={v.stage}")
```

## スケジュール実行 (定期パイプライン)

```python
from zenml import pipeline
from zenml.config import ScheduleConfig
from datetime import datetime, timedelta

@pipeline(
    schedule=ScheduleConfig(
        cron_expression="0 2 * * *",  # 毎日 AM2時
        start_time=datetime(2026, 5, 1),
    )
)
def daily_retrain_pipeline():
    data = load_data()
    model_path = train_model(data)
    accuracy = evaluate_model(model_path)
    register_model(model_path, accuracy)

# デプロイ (Kubeflow/Airflow が受け取る)
daily_retrain_pipeline()
```

## ZenML Cloud (SaaS 版)

```bash
# ZenML Cloud に接続 (無料枠あり)
zenml connect --url https://cloud.zenml.io

# チームで Stack を共有
zenml stack share gcp-production --users alice,bob

# Dashboard でパイプライン可視化
# → https://cloud.zenml.io/dashboard でリアルタイム確認
```

## CLI クイックリファレンス

```bash
zenml pipeline list              # パイプライン一覧
zenml pipeline runs list         # 実行履歴
zenml artifact list              # アーティファクト一覧
zenml model list                 # モデル一覧
zenml stack list                 # Stack 一覧
zenml stack describe             # 現在の Stack 詳細
zenml integration list           # 使用可能な統合一覧
zenml integration install mlflow # 統合インストール
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 270→271社化: ZenML 追加',
  'PS#3 S88。ZenML (Pythonファースト/スタック非依存MLOps/Stack抽象化/Kubeflow+SageMaker+Vertex AI対応/Model Registry/スケジュール実行/ZenML Cloud/GitHub 4k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
