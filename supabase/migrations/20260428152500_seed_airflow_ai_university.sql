-- PS#3 S94: AI大学 283→284社化 — Apache Airflow (DAGベースワークフロー/MLパイプライン標準)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'apache-airflow', 'overview',
  'Apache Airflow — DAGベースMLパイプライン・ワークフロー自動化・スケジューリング基盤 (GitHub 35k+ / 9/9)',
  $$## Apache Airflow とは

**Apache Airflow** は **DAG (有向非巡回グラフ) でワークフローをコードとして定義・実行するオープンソースプラットフォーム**。Airbnb が2014年に開発し2016年に Apache Foundation に寄贈。「コードとして書いたパイプラインを、スケジューリング・依存解決・監視まで一気通貫で管理する」思想。

GitHub 35,000+ スター。Apache 2.0 ライセンス。Airbnb / Lyft / Twitter / NASA / LINE など数千社で採用。ML パイプライン標準基盤として Kubeflow / Vertex AI / SageMaker Pipelines の比較対象になる。

## DAG (有向非巡回グラフ) の概念

```
Airflow の核心: パイプライン = Python コード = バージョン管理可能なDAG

例: ML 学習パイプライン DAG

  [データ取得] ──→ [前処理] ──→ [特徴量生成] ──→ [モデル学習]
                                                        │
                                              ┌──────────┴──────────┐
                                         [検証・評価]         [モデル登録]
                                              │                    │
                                         [Slack通知]         [デプロイ判定]

特徴:
  ✓ 各ステップ (Task) を関数として定義
  ✓ 依存関係を >> 演算子で直感的に記述
  ✓ 失敗タスクのみ再実行 (上流は再実行しない)
  ✓ 実行履歴・ログを Web UI で可視化
  ✓ Cron 形式または外部トリガーでスケジュール実行
```

## ML パイプラインでの位置づけ

```
Airflow vs 他MLOpsツール:

  Airflow   → 汎用ワークフロー基盤。ML以外でも使える。ETL+ML+通知を1DAGで管理
  Kubeflow  → Kubernetes専用。ML学習に特化。スケール重視
  Prefect   → Python-native。動的フロー。より現代的な設計
  dbt       → SQL変換専用。Airflow と相補的 (Airflow が dbt を呼ぶパターンが多い)

  典型的な組み合わせ:
  Airflow (スケジュール) → dbt (データ変換) → ML学習 → MLflow/wandb (記録) → デプロイ
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **データパイプライン** | Supabase → 変換 → 特徴量 → 学習を1DAGで管理 | 再現性ある完全なML基盤 |
| **定期バッチ** | 毎日夜間に競馬予想データ収集・推論 | GHA Cron より高機能な依存管理 |
| **障害回復** | 失敗タスクのみリトライ・Slack通知 | 夜間バッチの無人監視 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'apache-airflow', 'api',
  'Apache Airflow 実践 — DAG/Operator/TaskFlow/@task/KubernetesPod/dbt統合/MLflow連携/Astronomer',
  $$## インストール & セットアップ

```bash
pip install apache-airflow

# DB初期化
airflow db init

# ユーザー作成
airflow users create \
  --username admin --password admin \
  --firstname Kanta --lastname Yamada \
  --role Admin --email kanta13jp@gmail.com

# Scheduler + WebServer 起動
airflow scheduler &
airflow webserver --port 8080
# → http://localhost:8080 で Web UI
```

## 基本: DAG 定義

```python
# dags/ml_training_pipeline.py
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

# DAG のデフォルト設定
default_args = {
    "owner": "kanta",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "email_on_failure": True,
    "email": ["kanta13jp@gmail.com"],
}

# DAG 定義
with DAG(
    dag_id="jibun_kaisha_ml_pipeline",
    default_args=default_args,
    description="自分株式会社 ML学習パイプライン",
    schedule_interval="0 2 * * *",   # 毎日深夜2時に実行
    start_date=datetime(2026, 1, 1),
    catchup=False,                   # 過去分を遡らない
    tags=["ml", "training"],
) as dag:

    # Task 1: データ取得
    def fetch_data(**context):
        import requests
        import json

        # Supabase からデータ取得
        response = requests.get(
            "https://xxxx.supabase.co/functions/v1/get-training-data",
            headers={"Authorization": f"Bearer {SUPABASE_KEY}"}
        )
        data = response.json()

        # XCom で次タスクにデータパスを渡す
        context["task_instance"].xcom_push(key="data_path", value="/tmp/data.parquet")
        print(f"Fetched {len(data)} records")

    fetch_task = PythonOperator(
        task_id="fetch_data",
        python_callable=fetch_data,
    )

    # Task 2: 前処理
    def preprocess(**context):
        data_path = context["task_instance"].xcom_pull(
            task_ids="fetch_data", key="data_path"
        )
        import pandas as pd
        df = pd.read_parquet(data_path)
        # 前処理ロジック
        df = df.dropna().drop_duplicates()
        df.to_parquet("/tmp/processed_data.parquet")

    preprocess_task = PythonOperator(
        task_id="preprocess",
        python_callable=preprocess,
    )

    # Task 3: モデル学習
    train_task = BashOperator(
        task_id="train_model",
        bash_command="python /opt/airflow/scripts/train_model.py --data /tmp/processed_data.parquet",
    )

    # Task 4: Slack 通知
    def notify_slack(**context):
        import requests
        dag_run = context["dag_run"]
        requests.post(SLACK_WEBHOOK, json={
            "text": f"✅ ML Pipeline 完了: {dag_run.dag_id} ({dag_run.run_id})"
        })

    notify_task = PythonOperator(
        task_id="notify_slack",
        python_callable=notify_slack,
        trigger_rule="all_done",   # 成功・失敗どちらでも実行
    )

    # 依存関係 (>> = 左から右へ順番に実行)
    fetch_task >> preprocess_task >> train_task >> notify_task
```

## TaskFlow API (@task デコレータ — Airflow 2.x 推奨)

```python
# dags/ml_pipeline_taskflow.py
from airflow.decorators import dag, task
from datetime import datetime

@dag(
    dag_id="jibun_kaisha_ml_taskflow",
    schedule_interval="@daily",
    start_date=datetime(2026, 1, 1),
    catchup=False,
)
def ml_pipeline():

    @task
    def fetch_data() -> str:
        """Supabase からデータ取得"""
        import pandas as pd
        # ...データ取得処理...
        df.to_parquet("/tmp/data.parquet")
        return "/tmp/data.parquet"   # 戻り値が自動的に XCom に保存

    @task
    def preprocess(data_path: str) -> str:
        """データクリーニング・特徴量生成"""
        import pandas as pd
        df = pd.read_parquet(data_path)
        df_clean = df.dropna().drop_duplicates()
        df_clean.to_parquet("/tmp/processed.parquet")
        return "/tmp/processed.parquet"

    @task
    def train_model(data_path: str) -> dict:
        """モデル学習"""
        import mlflow
        with mlflow.start_run():
            # 学習ロジック
            accuracy = 0.92
            mlflow.log_metric("accuracy", accuracy)
            return {"accuracy": accuracy, "model_path": "/tmp/model.pkl"}

    @task
    def register_model(train_result: dict):
        """精度が閾値以上ならモデル登録"""
        if train_result["accuracy"] >= 0.90:
            print(f"✅ モデル登録: accuracy={train_result['accuracy']}")
        else:
            raise ValueError(f"精度不足: {train_result['accuracy']} < 0.90")

    # DAG の実行順序を定義 (TaskFlow は戻り値で自動的に依存関係を解決)
    raw = fetch_data()
    processed = preprocess(raw)
    result = train_model(processed)
    register_model(result)

# DAG インスタンス化
ml_pipeline_dag = ml_pipeline()
```

## KubernetesPodOperator (本番スケール)

```python
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator

# Kubernetes Pod でモデル学習を実行 (GPUジョブに最適)
train_on_gpu = KubernetesPodOperator(
    task_id="train_on_gpu",
    name="ml-training-job",
    namespace="airflow",
    image="my-registry/ml-trainer:latest",
    cmds=["python", "train.py"],
    arguments=["--epochs", "100", "--batch-size", "32"],
    resources={
        "limit": {"nvidia.com/gpu": "1"},   # GPU 1枚
        "request": {"memory": "8Gi", "cpu": "4"},
    },
    env_vars={"MLFLOW_TRACKING_URI": "http://mlflow:5000"},
    get_logs=True,
    is_delete_operator_pod=True,  # 完了後にPodを削除
)
```

## dbt + Airflow 統合

```python
from airflow.operators.bash import BashOperator

# Airflow が dbt を呼び出す (最も一般的なパターン)
dbt_run = BashOperator(
    task_id="dbt_transform",
    bash_command="""
        cd /opt/airflow/dbt_project &&
        dbt run --target prod --models +fct_churn_features &&
        dbt test --target prod
    """,
    env={"DBT_PROFILES_DIR": "/opt/airflow/dbt_project"},
)

# または astronomer-cosmos を使ってdbtモデルをネイティブTaskに変換
# pip install astronomer-cosmos
from cosmos import DbtDag, ProjectConfig, ProfileConfig

dbt_dag = DbtDag(
    dag_id="dbt_dag",
    project_config=ProjectConfig("/opt/airflow/dbt_project"),
    profile_config=ProfileConfig(
        profile_name="jibun_kaisha_analytics",
        target_name="prod",
    ),
    schedule_interval="@daily",
)
```

## Astronomer (マネージド Airflow)

```bash
# Astronomer CLI インストール
brew install astro

# プロジェクト初期化 (Docker ベース)
astro dev init
astro dev start   # ローカルで Airflow を起動
astro deploy      # Astronomer Cloud にデプロイ

# コスト比較:
# セルフホスト (GKE/EKS): $50-200/月 (管理コスト別)
# Astronomer Cloud: $300/月〜 (マネージド)
# MWAA (AWS): $0.49/環境/時間 ≈ $360/月〜
# Cloud Composer (GCP): $0.35/vCPU/時間
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 283→284社化: Apache Airflow 追加',
  'PS#3 S94。Apache Airflow (DAGベースワークフロー/TaskFlow @task/KubernetesPodOperator/dbt+Airflow統合/MLflow連携/Astronomer/XCom/スケジューリング/GitHub 35k+/Apache 2.0/9/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
