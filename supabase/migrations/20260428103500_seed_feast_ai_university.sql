-- PS#3 S88: AI大学 271→272社化 — Feast (OSS特徴量ストア / Google+Gojek共同開発)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'feast', 'overview',
  'Feast — OSS特徴量ストア・オフライン/オンライン統合・低レイテンシサービング (GitHub 5k+ / 8/9)',
  $$## Feast とは

**Feast** (Feature Store) は Google と Gojek が共同開発した**オープンソースの特徴量ストア**。MLパイプラインにおける「特徴量の一元管理・再利用・オンラインサービング」を解決する。

GitHub 5,000+ スター。Apache 2.0 ライセンス。現在は独立コミュニティが維持。Tecton 社 (商用版) の中核技術。

## 特徴量ストアが必要な理由

```
MLの"学習/推論ギャップ"問題:

  学習時: 過去の集計特徴量 (バッチ処理) を使う
  推論時: リアルタイムの特徴量 (オンライン処理) が必要

問題:
  → 学習で使った特徴量と推論で使う特徴量が一致しない
    (Training-Serving Skew)

Feast の解決策:
  → オフライン (学習用) とオンライン (推論用) ストアを統一管理
  → 同じ特徴量定義から両方を生成 → スキュー排除
```

## コアコンセプト

```
Feature View (特徴量グループ定義)
  ↓
  ┌─────────────────────────────────┐
  │  Offline Store (学習用)         │  ← BigQuery / Redshift / Parquet
  │  過去データ全件・ポイントインタイム |
  └─────────────────────────────────┘
  ┌─────────────────────────────────┐
  │  Online Store (推論用)          │  ← Redis / DynamoDB / Bigtable
  │  最新特徴量・低レイテンシ (<5ms) |
  └─────────────────────────────────┘

materialize: オフライン → オンライン 同期
```

## 定義ファイル

```python
# feature_repo/features.py
from datetime import timedelta
from feast import Entity, FeatureView, Field, FileSource
from feast.types import Float32, Int64, String

# Entity 定義 (特徴量のキー)
user = Entity(
    name="user_id",
    description="ユーザーID",
)

# Data Source (オフライン: Parquetファイル)
user_stats_source = FileSource(
    path="s3://jibun-kaisha-ml/features/user_stats.parquet",
    timestamp_field="event_timestamp",
)

# Feature View (特徴量グループ)
user_stats_fv = FeatureView(
    name="user_stats",
    entities=[user],
    ttl=timedelta(days=7),         # 7日間有効
    schema=[
        Field(name="total_logins", dtype=Int64),
        Field(name="avg_session_duration", dtype=Float32),
        Field(name="premium_score", dtype=Float32),
        Field(name="last_active_days_ago", dtype=Int64),
    ],
    source=user_stats_source,
    tags={"team": "jibun-kaisha-ml"},
)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **ユーザー行動予測** | ログイン頻度・滞在時間等の特徴量を一元化 | Training-Serving Skew 解消 |
| **リアルタイム推薦** | オンラインストアで <5ms サービング | UX 向上 |
| **特徴量再利用** | 複数モデルが同じ特徴量を共有 | 開発工数削減 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'feast', 'api',
  'Feast 実践 — apply/materialize/get_online_features/get_historical_features/Point-in-Time Join/Redis統合',
  $$## インストール & セットアップ

```bash
pip install feast
pip install feast[redis]     # Redis オンラインストア
pip install feast[gcp]       # BigQuery オフラインストア
pip install feast[aws]       # Redshift + DynamoDB

# Feature Repository 初期化
feast init jibun_kaisha_features
cd jibun_kaisha_features
```

## feature_store.yaml (設定ファイル)

```yaml
# jibun_kaisha_features/feature_store.yaml
project: jibun_kaisha
registry: s3://jibun-kaisha-ml/feast/registry.pb
provider: aws
offline_store:
  type: file          # ローカル開発: Parquet
  # type: bigquery   # 本番: BigQuery
  # type: redshift   # 本番: Redshift

online_store:
  type: redis
  connection_string: "redis:6379"

entity_key_serialization_version: 2
```

## apply: 定義をレジストリに登録

```bash
# 定義ファイルを Feast レジストリに登録
feast apply

# 登録済み Feature View 確認
feast feature-views list
feast entities list
```

## materialize: オフライン → オンライン同期

```bash
# 過去7日分の特徴量を Redis に同期 (バッチ)
feast materialize 2026-04-21T00:00:00 2026-04-28T00:00:00

# 増分同期 (最終同期以降のみ)
feast materialize-incremental 2026-04-28T23:59:59

# GHA Cron で定期実行
# 0 1 * * * feast materialize-incremental $(date -u +%Y-%m-%dT%H:%M:%S)
```

## get_online_features: リアルタイム推論

```python
from feast import FeatureStore
import pandas as pd

store = FeatureStore(repo_path="./jibun_kaisha_features")

# オンライン特徴量取得 (<5ms)
feature_vector = store.get_online_features(
    features=[
        "user_stats:total_logins",
        "user_stats:avg_session_duration",
        "user_stats:premium_score",
        "user_stats:last_active_days_ago",
    ],
    entity_rows=[
        {"user_id": "user_001"},
        {"user_id": "user_002"},
    ],
).to_dict()

print(feature_vector)
# {
#   "user_id": ["user_001", "user_002"],
#   "total_logins": [42, 8],
#   "premium_score": [0.92, 0.31],
#   ...
# }

# 推論エンドポイントで使用
import numpy as np
features_array = np.array([
    [feature_vector["total_logins"][0],
     feature_vector["avg_session_duration"][0],
     feature_vector["premium_score"][0]]
])
prediction = model.predict(features_array)
```

## get_historical_features: 学習データ生成 (Point-in-Time Join)

```python
from feast import FeatureStore
import pandas as pd
from datetime import datetime

store = FeatureStore(repo_path="./jibun_kaisha_features")

# 学習用のイベントデータ (正解ラベル付き)
training_df = pd.DataFrame({
    "user_id": ["user_001", "user_002", "user_003"],
    "event_timestamp": [
        datetime(2026, 4, 1),
        datetime(2026, 4, 10),
        datetime(2026, 4, 20),
    ],
    "label": [1, 0, 1],  # チャーンラベル
})

# Point-in-Time Join: イベント時点での特徴量を取得
# → Training-Serving Skew が発生しない!
training_dataset = store.get_historical_features(
    entity_df=training_df,
    features=[
        "user_stats:total_logins",
        "user_stats:avg_session_duration",
        "user_stats:premium_score",
        "user_stats:last_active_days_ago",
    ],
).to_df()

print(training_dataset.head())
# user_id  event_timestamp  label  total_logins  premium_score  ...
# user_001  2026-04-01       1      15            0.45           ...
# (イベント時点 2026-04-01 時点での特徴量が正確に取得される)

# 通常の学習処理
X = training_dataset.drop(["label", "event_timestamp", "user_id"], axis=1)
y = training_dataset["label"]
model.fit(X, y)
```

## FastAPI + Feast: リアルタイム推論 API

```python
# serve.py
from fastapi import FastAPI
from feast import FeatureStore
import joblib
import numpy as np

app = FastAPI()
store = FeatureStore(repo_path="./jibun_kaisha_features")
model = joblib.load("churn_model.pkl")

@app.post("/predict/churn")
async def predict_churn(user_id: str):
    # Feast からリアルタイム特徴量取得
    fv = store.get_online_features(
        features=[
            "user_stats:total_logins",
            "user_stats:avg_session_duration",
            "user_stats:premium_score",
            "user_stats:last_active_days_ago",
        ],
        entity_rows=[{"user_id": user_id}],
    ).to_dict()

    features = np.array([[
        fv["total_logins"][0],
        fv["avg_session_duration"][0],
        fv["premium_score"][0],
        fv["last_active_days_ago"][0],
    ]])

    prob = model.predict_proba(features)[0][1]
    return {"user_id": user_id, "churn_probability": float(prob)}
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 271→272社化: Feast 追加',
  'PS#3 S88。Feast (OSS特徴量ストア/Google+Gojek共同開発/Training-Serving Skew解消/Point-in-Time Join/Redis オンラインストア/BigQuery/DynamoDB/Materialization/GitHub 5k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
