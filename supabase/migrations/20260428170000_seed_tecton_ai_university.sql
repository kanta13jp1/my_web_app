-- PS#3 S97: AI大学 288→289社化 — Tecton (エンタープライズ Feature Store / リアルタイム特徴量基盤)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'tecton', 'overview',
  'Tecton — エンタープライズ Feature Store・リアルタイム特徴量パイプライン・Uber/Airbnb MLops発 (SaaS / 8/9)',
  $$## Tecton とは

**Tecton** は **エンタープライズグレードの Feature Store プラットフォーム**。Uber の元 ML エンジニア (Michelangelo チームの共同創業者) が2019年に創業。Uber・Airbnb・LinkedIn の MLops 経験を商用製品として提供。

SaaS 型 (AWS/GCP)。Snowflake / BigQuery / Databricks / Spark / Kafka と統合。リアルタイム特徴量 (低遅延 <10ms) + バッチ特徴量の両方を管理。Feast (OSS) より本番運用向けの機能が充実。

## Feast vs Tecton の位置づけ

```
Feature Store エコシステム:

  Feast (OSS):
    ✓ 無料・セルフホスト
    ✓ シンプルな設計
    ✗ 運用コスト大 (インフラ管理が必要)
    ✗ リアルタイム特徴量の遅延管理が難しい

  Hopsworks (OSS/SaaS):
    ✓ 統合MLプラットフォーム (Feature Store + Model Registry)
    ✓ KTH 発の研究に裏打ちされた設計
    ✗ エンタープライズ向け機能は限定的

  Tecton (エンタープライズ SaaS):
    ✓ Uber Michelangelo の実績ある設計を商用化
    ✓ リアルタイム特徴量 <10ms 保証 (SLA あり)
    ✓ Feature Pipeline のバージョン管理・デプロイ自動化
    ✓ 特徴量の再利用・共有・ガバナンスが充実
    ✗ 有料 (エンタープライズ価格)
```

## Feature Pipeline の概念

```
Tecton の核心: Feature Pipeline = コードとして定義した特徴量計算

  従来のアプローチ:
    データエンジニア → ETL で特徴量作成
    ML エンジニア → 別で再実装 (Training-Serving Skew の温床)

  Tecton のアプローチ:
    Feature View = Python コードで定義した特徴量計算
    ↓
    学習時: Tecton がオフライン ストアから取得
    推論時: Tecton がオンライン ストア (DynamoDB等) から取得
    ↓
    同じ Feature View を使うので絶対にずれない
    + 変更履歴・バージョン管理が自動化
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬予想 v2** | 競馬特徴量を Tecton Feature View で定義 | リアルタイム推論 <10ms + 学習の完全一致 |
| **ユーザー行動特徴量** | チャーン・レコメンド向け特徴量を集中管理 | 複数モデルが同じ特徴量を再利用 |
| **特徴量ガバナンス** | 特徴量カタログ + 承認フローで品質管理 | 本番へのゴミ特徴量混入を防止 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'tecton', 'api',
  'Tecton 実践 — Feature View/Batch Source/Stream Source/On-Demand/SDK/Snowflake統合/リアルタイム推論',
  $$## インストール & セットアップ

```bash
pip install tecton

# Tecton クラスターに接続
tecton login --url https://your-org.tecton.ai

# 接続確認
tecton version
```

## Feature Repository 構造

```
tecton_repo/
  ├── feature_repo.yaml          # リポジトリ設定
  ├── data_sources/
  │   ├── user_events.py         # データソース定義
  │   └── horse_race_data.py
  ├── feature_views/
  │   ├── user_churn_features.py # Feature View 定義
  │   └── horse_race_features.py
  └── feature_services/
      └── churn_prediction_service.py  # Feature Service 定義
```

## Batch Feature View: バッチ特徴量

```python
# feature_views/user_churn_features.py
from tecton import batch_feature_view, FilteredSource, Aggregation
from tecton.types import Field, Int64, Float64, String, Timestamp
from datetime import datetime, timedelta
from data_sources.user_events import user_events_source

@batch_feature_view(
    sources=[FilteredSource(user_events_source)],
    entities=["user_id"],
    mode="spark_sql",
    online=True,   # オンラインストアにも同期
    offline=True,  # オフラインストア (学習用)
    feature_start_time=datetime(2026, 1, 1),
    batch_schedule=timedelta(hours=1),   # 1時間ごとにバッチ更新
    description="ユーザーチャーン予測用特徴量",
    tags={"owner": "ml-team", "use_case": "churn"},
)
def user_churn_features(user_events):
    return f"""
        SELECT
            user_id,
            COUNT(*) AS event_count_7d,
            COUNT(DISTINCT DATE(event_at)) AS active_days_7d,
            SUM(duration_ms) / 1000.0 AS total_duration_sec_7d,
            MAX(event_at) AS last_event_at,
            DATEDIFF(CURRENT_DATE, MAX(DATE(event_at))) AS days_since_last_active
        FROM {user_events}
        WHERE event_at >= NOW() - INTERVAL 7 DAYS
        GROUP BY user_id
    """
```

## Stream Feature View: リアルタイム特徴量 (<10ms)

```python
# feature_views/user_realtime_features.py
from tecton import stream_feature_view, FilteredSource, Aggregation
from tecton.types import Field, Int64, Float64
from datetime import timedelta
from data_sources.user_event_stream import kafka_user_events  # Kafka ソース

@stream_feature_view(
    sources=[FilteredSource(kafka_user_events)],
    entities=["user_id"],
    online=True,
    offline=True,
    aggregations=[
        Aggregation(column="event_count", function="count", time_window=timedelta(hours=1)),
        Aggregation(column="duration_ms", function="sum", time_window=timedelta(hours=1)),
    ],
    description="ユーザーの直近1時間のリアルタイム活動量",
)
def user_realtime_features(user_events):
    return user_events.select("user_id", "event_count", "duration_ms", "event_at")
```

## On-Demand Feature View: 推論時に動的計算

```python
# feature_views/on_demand_features.py
from tecton import on_demand_feature_view
from tecton.types import Field, Float64
import pandas as pd

@on_demand_feature_view(
    sources=["user_churn_features"],  # 他の Feature View に依存
    mode="pandas",
    schema=[Field("churn_risk_level", String)],
    description="チャーンリスクレベル (low/medium/high) を動的計算",
)
def churn_risk_level(user_churn_features: pd.DataFrame) -> pd.DataFrame:
    def classify(days):
        if days > 60: return "high"
        elif days > 30: return "medium"
        elif days > 14: return "low"
        return "active"

    return pd.DataFrame({
        "churn_risk_level": user_churn_features["days_since_last_active"].apply(classify)
    })
```

## Feature Service: 推論 API

```python
# feature_services/churn_prediction_service.py
from tecton import FeatureService
from feature_views.user_churn_features import user_churn_features
from feature_views.user_realtime_features import user_realtime_features
from feature_views.on_demand_features import churn_risk_level

churn_prediction_service = FeatureService(
    name="churn_prediction_service",
    features=[
        user_churn_features,          # バッチ特徴量
        user_realtime_features,        # リアルタイム特徴量
        churn_risk_level,              # On-Demand 特徴量
    ],
    description="チャーン予測モデル用の統合特徴量サービス",
)
```

## Python SDK で特徴量取得

```python
import tecton

# Tecton に接続
ws = tecton.get_workspace("production")
service = ws.get_feature_service("churn_prediction_service")

# ① 学習データ生成 (オフライン)
from datetime import datetime
training_data = service.get_historical_features(
    spine=user_ids_df,   # user_id + timestamp の DataFrame
    from_source=False,   # オフラインストアから取得 (高速)
)
print(f"学習データ: {training_data.shape}")

# ② リアルタイム推論 (オンライン) — <10ms
feature_vector = service.get_online_features(
    join_keys={"user_id": "12345"}
)
print(feature_vector.to_dict())
# → {"event_count_7d": 15, "days_since_last_active": 3, "churn_risk_level": "active", ...}

# ③ Feature View 単体でのデバッグ
fv = ws.get_feature_view("user_churn_features")
sample = fv.get_historical_features(
    spine=pd.DataFrame({"user_id": ["123"], "timestamp": [datetime.now()]}),
)
```

## apply でデプロイ

```bash
# Feature View をクラスターにデプロイ
tecton apply

# 差分確認
tecton plan

# 特定の Feature View だけ更新
tecton apply --selective-apply user_churn_features
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 288→289社化: Tecton 追加',
  'PS#3 S97。Tecton (エンタープライズFeature Store/Uber Michelangelo発/Batch+Stream+On-Demand Feature View/FeatureService/リアルタイム<10ms/Snowflake+Databricks統合/SaaS/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
