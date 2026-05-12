-- PS#3 S91: AI大学 276→277社化 — ClearML (MLops統合プラットフォーム / 実験管理 + データ管理)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'clearml', 'overview',
  'ClearML — MLops統合プラットフォーム・実験管理・データ管理・パイプライン・自動化 (GitHub 5k+ / 8/9)',
  $$## ClearML とは

**ClearML** は実験管理・データ管理・パイプライン・モデルリポジトリを統合した**フルスタック MLops プラットフォーム**。イスラエル発スタートアップ (2019年設立、旧称 Allegro AI)。オープンソース版 + ClearML Cloud (SaaS) + エンタープライズ版を提供。

GitHub 5,000+ スター。Apache 2.0 ライセンス。「MLops をワンストップで解決する」ことを目指す。

## 主要コンポーネント

```
ClearML の 5 つの柱:

  1. Experiment Management
     → 実験の自動追跡 (コード/メトリクス/モデル/環境)
     → W&B / MLflow の代替

  2. Data Management (ClearML Data)
     → データセットのバージョン管理
     → S3/GCS/Azure/MinIO 対応
     → DVC の代替

  3. Model Repository
     → モデルのバージョン管理・デプロイ管理
     → MLflow Model Registry の代替

  4. Orchestration (ClearML Agent)
     → ジョブキューに基づく分散実験実行
     → Kubernetes / Docker 対応

  5. Pipelines (ClearML Pipelines)
     → コードベースの ML パイプライン
     → Airflow / Prefect の軽量代替
```

## 自動追跡: コード変更なしで記録開始

```python
# task.py
from clearml import Task

# Task 初期化 (これだけで自動追跡が始まる)
task = Task.init(
    project_name="jibun-kaisha/sentiment",
    task_name="BERT日本語感情分析 v3",
    tags=["bert", "japanese", "production"],
)

# 既存のコードはそのまま — 自動追跡される:
#   ✓ git diff / git hash
#   ✓ pip freeze (環境)
#   ✓ コンソール出力
#   ✓ matplotlib/seaborn 図
#   ✓ モデルファイル (torch.save 等を自動検出)

import torch
from transformers import AutoModelForSequenceClassification

model = AutoModelForSequenceClassification.from_pretrained(
    "cl-tohoku/bert-base-japanese"
)

# ハイパーパラメータ記録
task.connect({
    "lr": 2e-5,
    "batch_size": 32,
    "epochs": 3,
})

# 訓練ループ (Loggger が自動注入)
logger = task.get_logger()
for epoch in range(3):
    loss = train()
    acc = evaluate()
    logger.report_scalar("loss", "train", value=loss, iteration=epoch)
    logger.report_scalar("accuracy", "val", value=acc, iteration=epoch)

task.close()
```

## ClearML Agent: リモート実行

```bash
# Worker (GPU マシン) でエージェント起動
clearml-agent daemon --queue gpu-queue

# 実験をキューに送信 → Agent が自動実行
clearml-agent execute --id <task-id>
# または
task.execute_remotely(queue_name="gpu-queue")
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **ワンストップMLops** | 実験/データ/モデル/パイプラインを一元管理 | ツール乱立を解消 |
| **リモート実行** | Agent で GPU マシンにジョブ投入 | ローカルPC不要 |
| **チーム共有** | ClearML Cloud で全実験を可視化共有 | 再現性・知識共有 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'clearml', 'api',
  'ClearML 実践 — Task/Logger/Dataset/Pipeline/HPO/clearml-agent/セルフホスト',
  $$## インストール & セットアップ

```bash
pip install clearml

# 初期設定 (API 認証)
clearml-init
# → ClearML WebUI (app.clear.ml) でトークン取得して入力

# または環境変数で設定
export CLEARML_WEB_HOST=https://app.clear.ml
export CLEARML_API_HOST=https://api.clear.ml
export CLEARML_FILES_HOST=https://files.clear.ml
export CLEARML_API_ACCESS_KEY=xxx
export CLEARML_API_SECRET_KEY=yyy
```

## Dataset: データバージョン管理

```python
from clearml import Dataset

# データセット作成
dataset = Dataset.create(
    dataset_name="jibun-kaisha-training-v2",
    dataset_project="jibun-kaisha/datasets",
    description="日本語感情分析 学習データ v2.0",
)

# ファイル追加
dataset.add_files(path="./data/train.parquet")
dataset.add_files(path="./data/val.parquet")

# S3 にアップロード & バージョン確定
dataset.upload(output_url="s3://jibun-kaisha-ml/clearml-data/")
dataset.finalize()

print(f"Dataset ID: {dataset.id}")  # → 再利用可能な ID
```

```python
# 別の実験でデータセットを使用
from clearml import Dataset

# バージョン管理されたデータを取得
dataset = Dataset.get(
    dataset_name="jibun-kaisha-training-v2",
    dataset_project="jibun-kaisha/datasets",
)
local_path = dataset.get_local_copy()  # S3 からダウンロード

import pandas as pd
train_df = pd.read_parquet(f"{local_path}/train.parquet")
```

## Pipeline: 複数ステップのワークフロー

```python
from clearml.automation.controller import PipelineDecorator

@PipelineDecorator.component(return_values=["dataset_id"], cache=True)
def prepare_data(source_path: str) -> str:
    from clearml import Dataset
    import pandas as pd

    df = pd.read_parquet(source_path)
    # 前処理...
    processed = df[df["text"].str.len() > 10]

    dataset = Dataset.create(
        dataset_name="processed-data",
        dataset_project="jibun-kaisha/pipeline",
    )
    processed.to_parquet("/tmp/processed.parquet")
    dataset.add_files("/tmp/processed.parquet")
    dataset.upload()
    dataset.finalize()
    return dataset.id

@PipelineDecorator.component(return_values=["model_id"], cache=False)
def train_model(dataset_id: str, lr: float, epochs: int) -> str:
    from clearml import Dataset, Task
    import torch

    # データ取得
    dataset = Dataset.get(dataset_id=dataset_id)
    local = dataset.get_local_copy()

    # 訓練...
    model_path = "/tmp/model.pt"
    torch.save({"accuracy": 0.934}, model_path)

    # モデル登録
    task = Task.current_task()
    task.upload_artifact("model", artifact_object=model_path)
    return task.id

@PipelineDecorator.pipeline(name="jibun-kaisha-training", project="jibun-kaisha")
def ml_pipeline(source_path: str, lr: float = 2e-5, epochs: int = 3):
    dataset_id = prepare_data(source_path)
    model_id = train_model(dataset_id, lr, epochs)
    return model_id

# パイプライン実行
PipelineDecorator.run_locally()  # ローカル実行 (デバッグ)
ml_pipeline("s3://jibun-kaisha-ml/raw/data.parquet")
# または
# PipelineDecorator.debug_pipeline()  # リモート実行
```

## HPO: ハイパーパラメータ最適化

```python
from clearml.automation import HyperParameterOptimizer, UniformParameterRange, DiscreteParameterRange
from clearml.automation.optuna import OptunaObjective

# ベースタスクの ID を指定して HPO 実行
optimizer = HyperParameterOptimizer(
    base_task_id="<base-task-id>",
    hyper_parameters=[
        UniformParameterRange("lr", min_value=1e-5, max_value=1e-3),
        DiscreteParameterRange("batch_size", values=[16, 32, 64]),
        DiscreteParameterRange("epochs", values=[3, 5, 10]),
    ],
    objective_metric_title="accuracy",
    objective_metric_series="val",
    objective_metric_sign="max",  # 最大化
    optimizer_class=OptunaObjective,
    max_number_of_concurrent_tasks=4,
    total_max_jobs=20,
    execution_queue="gpu-queue",
)
optimizer.start()
optimizer.wait()

# 最良の実験を取得
best_task = optimizer.get_top_experiments(top_k=1)[0]
print(f"Best accuracy: {best_task.get_last_scalar_metrics()}")
```

## セルフホスト (Docker Compose)

```bash
# ClearML Server をセルフホストで起動
git clone https://github.com/allegroai/clearml-server.git
cd clearml-server
docker-compose -f docker-compose.yml up -d

# → http://localhost:8080 で WebUI にアクセス
# API: http://localhost:8008
# Files: http://localhost:8081
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 276→277社化: ClearML 追加',
  'PS#3 S91。ClearML (フルスタックMLops/実験自動追跡/Dataset バージョン管理/Pipeline/HPO Optuna/clearml-agent リモート実行/セルフホスト Docker/GitHub 5k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
