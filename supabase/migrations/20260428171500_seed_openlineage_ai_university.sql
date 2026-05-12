-- PS#3 S97: AI大学 289→290社化 — OpenLineage (データリネージ標準規格 / Apache プロジェクト)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'openlineage', 'overview',
  'OpenLineage — データリネージ標準規格・Apache プロジェクト・データ系譜の相互運用 (GitHub 2k+ / 8/9)',
  $$## OpenLineage とは

**OpenLineage** は **データリネージ (データの系譜・血統) を記録・共有するためのオープン標準規格**。2021年に Astronomer (Airflow の商用サポート企業) が提案し、現在は Apache Software Foundation 傘下のプロジェクト。

GitHub 2,000+ スター。Apache 2.0 ライセンス。Airflow / dbt / Spark / Flink / Dagster / Great Expectations などが統合。Marquez (OSS メタデータサーバー) とセットで使われることが多い。

## データリネージとは何か

```
「データの系譜」— このデータはどこから来て、どこへ行くか

  例: 競馬予想モデルの予測結果の場合

  1. horse_race_raw (Supabase)
       ↓ [dbt: stg_horse_race]
  2. stg_horse_race (DWH)
       ↓ [Airflow DAG: feature_engineering]
  3. horse_race_features (Feature Store)
       ↓ [ML学習パイプライン]
  4. churn_model_v3 (Model Registry)
       ↓ [推論 API]
  5. prediction_results (Supabase)

  データリネージがあると:
  ✓ 「なぜこの予測結果がおかしいのか」を追跡できる
  ✓ 上流の変更が下流に与える影響を事前に把握できる
  ✓ コンプライアンス・監査で「このデータはどこから」に答えられる
  ✓ 削除リクエスト (GDPR) でどこに影響するか分かる
```

## OpenLineage の役割

```
問題: 各ツールが独自のリネージ形式を使う

  Airflow → Airflow 独自フォーマット
  dbt     → dbt 独自フォーマット
  Spark   → Spark 独自フォーマット
         → 繋げて見ることができない!

OpenLineage の解決策:
  共通のイベント仕様 (RunEvent / DatasetEvent / JobEvent) を定義
  → 全ツールが同じフォーマットで出力
  → Marquez や Atlas などのメタデータサーバーで統合表示
  → End-to-End リネージを1つの画面で確認
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **パイプライン全体把握** | Airflow + dbt + ML を OpenLineage で繋ぐ | Supabase raw → 予測結果まで系譜を可視化 |
| **影響分析** | Supabase テーブル変更の影響を事前確認 | 上流変更で下流 ML が壊れるリスクを低減 |
| **コンプライアンス** | ユーザーデータの流れをトレース | GDPR 対応・プライバシー監査の証跡 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'openlineage', 'api',
  'OpenLineage 実践 — RunEvent/DatasetEvent/Python Client/Airflow統合/dbt統合/Marquez/Atlan',
  $$## インストール & セットアップ

```bash
pip install openlineage-python

# Marquez (OSS メタデータサーバー) を Docker で起動
docker run --rm -it -p 5000:5000 -p 5001:5001 \
  marquezproject/marquez:latest

# Marquez UI: http://localhost:3000
```

## 基本: RunEvent の手動送信

```python
from openlineage.client import OpenLineageClient
from openlineage.client.run import (
    RunEvent, RunState, Run, Job,
    InputDataset, OutputDataset,
)
from openlineage.client.facet import (
    SchemaDatasetFacet, SchemaField,
    SqlJobFacet, DocumentationJobFacet,
)
from datetime import datetime, timezone
import uuid

# OpenLineage クライアント (Marquez に送信)
client = OpenLineageClient.from_environment()
# 環境変数: OPENLINEAGE_URL=http://localhost:5000

# ジョブの実行を記録
run_id = str(uuid.uuid4())
job_namespace = "jibun-kaisha"
job_name = "horse_race_feature_engineering"

# START イベント
client.emit(RunEvent(
    eventType=RunState.START,
    eventTime=datetime.now(timezone.utc).isoformat(),
    run=Run(runId=run_id),
    job=Job(
        namespace=job_namespace,
        name=job_name,
        facets={
            "documentation": DocumentationJobFacet(
                description="競馬レースデータから ML 特徴量を生成"
            ),
        },
    ),
    inputs=[InputDataset(
        namespace="supabase",
        name="horse_race_raw",
        facets={
            "schema": SchemaDatasetFacet(fields=[
                SchemaField(name="race_id", type="VARCHAR"),
                SchemaField(name="horse_id", type="VARCHAR"),
                SchemaField(name="result", type="INTEGER"),
                SchemaField(name="race_date", type="DATE"),
            ])
        }
    )],
    outputs=[],
))

# 実際の処理実行
import pandas as pd
df = pd.read_sql("SELECT * FROM horse_race_raw", engine)
feature_df = compute_features(df)
feature_df.to_sql("horse_race_features", engine, if_exists="replace")

# COMPLETE イベント (出力データセットを記録)
client.emit(RunEvent(
    eventType=RunState.COMPLETE,
    eventTime=datetime.now(timezone.utc).isoformat(),
    run=Run(runId=run_id),
    job=Job(namespace=job_namespace, name=job_name),
    inputs=[InputDataset(namespace="supabase", name="horse_race_raw")],
    outputs=[OutputDataset(
        namespace="feature_store",
        name="horse_race_features",
        facets={
            "schema": SchemaDatasetFacet(fields=[
                SchemaField(name="horse_id", type="VARCHAR"),
                SchemaField(name="avg_finish_position", type="FLOAT"),
                SchemaField(name="win_rate_3m", type="FLOAT"),
                SchemaField(name="days_since_last_race", type="INTEGER"),
            ])
        }
    )],
))
print(f"Lineage recorded: run_id={run_id}")
```

## Airflow 統合 (自動リネージ記録)

```bash
# Airflow 用 OpenLineage プラグイン
pip install openlineage-airflow
```

```python
# airflow.cfg または環境変数で設定
# AIRFLOW__LINEAGE__BACKEND=openlineage
# OPENLINEAGE_URL=http://marquez:5000
# OPENLINEAGE_NAMESPACE=jibun-kaisha

# DAG は変更不要 — Airflow タスクの入出力が自動記録される
from airflow.decorators import dag, task

@dag(schedule_interval="@daily")
def feature_pipeline():

    @task(
        inlets=[{"dataSets": [{"namespace": "supabase", "name": "horse_race_raw"}]}],
        outlets=[{"dataSets": [{"namespace": "feature_store", "name": "horse_race_features"}]}],
    )
    def compute_features():
        # タスク実行 → OpenLineage が自動的に RunEvent を送信
        pass

    compute_features()
```

## dbt 統合 (自動リネージ記録)

```bash
# dbt 用 OpenLineage アダプター
pip install openlineage-dbt
```

```yaml
# profiles.yml で OpenLineage を有効化
jibun_kaisha_analytics:
  target: prod
  outputs:
    prod:
      type: postgres
      # ... 接続設定 ...
      openlineage:
        url: http://marquez:5000
        namespace: jibun-kaisha
```

```bash
# dbt run すると自動的にリネージが記録される
dbt run --target prod
# → Marquez UI で dbt モデル間の依存関係 + 上流ソースが可視化される
```

## Marquez UI でリネージを可視化

```python
# Marquez REST API でリネージ情報を取得
import requests

BASE_URL = "http://localhost:5000/api/v1"

# データセットのリネージを取得
response = requests.get(
    f"{BASE_URL}/lineage",
    params={
        "nodeId": "dataset:feature_store:horse_race_features",
        "depth": 3,  # 上流3段階まで追跡
    }
)
lineage = response.json()

# グラフの表示
for node in lineage["graph"]:
    node_type = node["type"]   # DATASET or JOB
    node_id = node["id"]
    print(f"{node_type}: {node_id}")
    for edge in node.get("inEdges", []):
        print(f"  ← {edge['origin']}")

# ジョブの実行履歴
runs = requests.get(f"{BASE_URL}/namespaces/jibun-kaisha/jobs/horse_race_feature_engineering/runs")
for run in runs.json()["runs"][:5]:
    print(f"Run: {run['id']} | State: {run['state']} | {run['startedAt']}")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 289→290社化: OpenLineage 追加',
  'PS#3 S97。OpenLineage (データリネージ標準規格/Apache プロジェクト/RunEvent+DatasetEvent+JobEvent/Airflow自動統合/dbt自動統合/Marquez可視化/GDPR対応/影響分析/Astronomer発/GitHub 2k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
