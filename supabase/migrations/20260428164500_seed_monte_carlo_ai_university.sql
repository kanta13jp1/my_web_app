-- PS#3 S96: AI大学 287→288社化 — Monte Carlo (Data Observability / データパイプライン品質監視)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'monte-carlo', 'overview',
  'Monte Carlo — Data Observability・データパイプライン品質監視・データインシデント自動検知 (SaaS / 8/9)',
  $$## Monte Carlo とは

**Monte Carlo** は **データパイプライン全体の品質を自動的に監視する Data Observability プラットフォーム**。2019年設立の米国スタートアップ。「ダウンタイムのないデータ (Data Downtime をゼロに)」をミッションとする。Andreessen Horowitz が投資。

SaaS 型 (クラウド接続)。BigQuery / Snowflake / Redshift / dbt / Airflow / Looker / Tableau と統合。ML 向けだけでなく BI・アナリティクス全般のデータ品質問題を検知する。

## Data Observability の概念

```
「データの観測性」= データの健全性を継続的に把握する能力

  従来のアプローチ:
    - 問題発生 → ユーザーから報告 → 調査 → 修正
    - 数時間〜数日のデータ品質問題に気づかない
    - 原因調査に膨大な時間がかかる

  Monte Carlo のアプローチ:
    - データの 5 つの柱を常時監視
    ┌─────────────────────────────────────────┐
    │  1. Freshness  — データは最新か?         │
    │  2. Volume     — データ量に異常はないか?  │
    │  3. Distribution — 値の分布は正常か?     │
    │  4. Schema     — スキーマが変更されたか? │
    │  5. Lineage    — 上流の問題が影響するか? │
    └─────────────────────────────────────────┘
    - 異常を自動検知 → Slack/PagerDuty にアラート
    - データリネージ (血統) で根本原因を素早く特定
```

## ML パイプラインでの位置づけ

```
Monte Carlo vs 類似ツール:

  Great Expectations → ルールベース (expect_* を自分で書く)
  Evidently AI      → ML モデル入出力の統計的ドリフト検知
  Monte Carlo       → インフラレベルのデータ品質 (鮮度/量/分布)
                      ルール定義不要 — ML で異常を自動検知

  典型的な使い方:
  Airflow / dbt でデータ変換 → Monte Carlo が自動監視
  → 異常検知 → Slack通知 → データリネージで原因特定
  → ML Feature Store への異常データ混入を防止
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **Supabase データ監視** | テーブルの鮮度・行数・分布を自動監視 | EF バグによるデータ欠損を即時検知 |
| **dbt パイプライン** | dbt モデルの出力品質を自動チェック | 変換バグが下流 ML に伝播する前に止める |
| **ML 特徴量監視** | 特徴量テーブルの異常を事前検知 | モデル精度劣化の根本原因を素早く特定 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'monte-carlo', 'api',
  'Monte Carlo 実践 — Python SDK/カスタムモニター/dbt統合/Airflow統合/Slack通知/データリネージ/API',
  $$## セットアップ & 接続

```bash
# Monte Carlo CLI インストール
pip install pycarlo

# 認証設定
mc configure
# → API Key ID / Token を入力 (app.montecarlodata.com で取得)

# 接続テスト
mc info
```

## Python SDK: カスタムモニター & アラート

```python
from pycarlo.core import Client, Query, Mutation

# Monte Carlo クライアント初期化
mc = Client()

# テーブルの監視状態を確認
query = Query()
query.get_table(
    mcon="MCON++...",   # Monte Carlo Object Name (テーブルの一意ID)
).__fields__(
    "full_table_id",
    "is_monitored",
    "last_update_ts",
    "row_count",
)
result = mc(query)
print(result)
```

## カスタム SQL モニター (ルールベース監視)

```python
from pycarlo.features.monitors import MonitorService

monitor_service = MonitorService()

# カスタム SQL モニター: 毎時チェック
monitor = monitor_service.create_sql_rule_monitor(
    warehouse_id="your-warehouse-id",
    namespace="jibun_kaisha",
    rule_name="horse_race_data_freshness",
    description="競馬データが24時間以内に更新されているかチェック",
    sql="""
        SELECT COUNT(*) as recent_records
        FROM horse_race_features
        WHERE updated_at >= NOW() - INTERVAL '24 hours'
    """,
    comparisons=[
        {
            "type": "THRESHOLD",
            "operator": "GTE",
            "threshold_value": 1,   # 1件以上なら正常
        }
    ],
    schedule_config={
        "type": "FIXED",
        "intervalMinutes": 60,  # 毎時チェック
    },
    alert_conditions=[
        {
            "type": "BREACH",
            "notification_channels": ["slack-ml-alerts"],
        }
    ],
)
print(f"Monitor created: {monitor.id}")
```

## dbt 統合 (dbt Cloud / Core)

```yaml
# dbt プロジェクト設定で Monte Carlo に自動報告
# packages.yml
packages:
  - package: monte-carlo-data/montecarlo_dbt
    version: [">=0.1.0", "<1.0.0"]
```

```bash
# dbt run 後に Monte Carlo にメタデータを送信
dbt run --target prod
dbt run-operation upload_monte_carlo_artifacts \
  --args '{"mc_api_key_id": "xxxx", "mc_api_key_token": "xxxx"}'
```

```python
# dbt モデルの品質問題を Monte Carlo で検知した場合の処理
import requests

def check_dbt_model_health(model_name: str) -> dict:
    """Monte Carlo API でモデルの品質を確認"""
    headers = {
        "x-mcd-id": MC_API_KEY_ID,
        "x-mcd-token": MC_API_KEY_TOKEN,
        "Content-Type": "application/json",
    }
    query = """
    query GetTableHealth($fullTableId: String!) {
        getTable(fullTableId: $fullTableId) {
            fullTableId
            isMonitored
            breaches {
                anomalyType
                severity
                startTime
                endTime
            }
        }
    }
    """
    response = requests.post(
        "https://api.montecarlodata.com/graphql",
        headers=headers,
        json={"query": query, "variables": {"fullTableId": f"jibun_kaisha:dbt_prod.{model_name}"}},
    )
    return response.json()

# CI/CD でデプロイ前チェック
health = check_dbt_model_health("fct_churn_features")
if health["data"]["getTable"]["breaches"]:
    print("⚠️ データ品質問題が検知されています — デプロイを中断します")
    exit(1)
```

## Airflow 統合 (パイプライン監視)

```python
from airflow.decorators import dag, task
from airflow.operators.python import PythonOperator
from pycarlo.core import Client

@dag(schedule_interval="@daily")
def ml_pipeline_with_mc_monitoring():

    @task
    def check_data_freshness():
        """Airflow タスク開始前に Monte Carlo でデータ品質確認"""
        mc = Client()
        # テーブルの鮮度チェック
        # 問題があれば例外を発生させてパイプラインを止める
        print("✅ Data freshness check passed")

    @task
    def run_feature_engineering():
        """特徴量計算 (Monte Carlo が出力を自動監視)"""
        import pandas as pd
        # 計算ロジック...
        print("Feature engineering completed")

    @task
    def report_to_monte_carlo(model_name: str):
        """パイプライン完了を Monte Carlo に通知"""
        mc = Client()
        # カスタムメタデータを送信してリネージを更新
        print(f"Pipeline completion reported to Monte Carlo: {model_name}")

    check = check_data_freshness()
    features = run_feature_engineering()
    report = report_to_monte_carlo("churn_model")

    check >> features >> report
```

## Slack 通知の設定

```python
# Monte Carlo の Slack 通知設定 (API 経由)
mutation_query = """
mutation CreateNotificationSetting($input: CreateNotificationSettingInput!) {
    createNotificationSetting(input: $input) {
        setting {
            id
            type
            recipients
        }
    }
}
"""

variables = {
    "input": {
        "type": "SLACK",
        "recipients": ["#ml-alerts", "#data-quality"],
        "notifyOnAnomalyDetected": True,
        "notifyOnIncidentResolved": True,
        "tables": ["jibun_kaisha:horse_race_features", "jibun_kaisha:user_churn_features"],
    }
}
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 287→288社化: Monte Carlo 追加',
  'PS#3 S96。Monte Carlo (Data Observability/5柱監視/Freshness+Volume+Distribution+Schema+Lineage/ルール定義不要ML自動検知/Python SDK/dbt統合/Airflow統合/Slack通知/GraphQL API/Andreessen Horowitz投資/SaaS/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
