-- PS#3 S98: AI大学 291→292社化 — whylogs (データロギング/統計プロファイリング/WhyLabs統合)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'whylogs', 'overview',
  'whylogs — データロギング・統計プロファイリング・WhyLabs MLモニタリング統合 (GitHub 3k+ / 8/9)',
  $$## whylogs とは

**whylogs** は **データセット・ML 特徴量の統計プロファイルを軽量に記録するオープンソースライブラリ**。WhyLabs 社 (2019年創業、AI 観測性 SaaS) が開発。「データの統計的概要 (プロファイル) を低コストで継続的に収集する」ことに特化。

GitHub 3,000+ スター。Apache 2.0 ライセンス。pandas / Spark / Ray に対応。WhyLabs Observatory (SaaS) と統合すると自動的にドリフトダッシュボードが生成される。

## whylogs の思想: ログではなくプロファイル

```
従来のアプローチ:
  全データを保存 → ストレージ大 + プライバシー問題
  サンプリング → 代表性がない

whylogs のアプローチ:
  統計プロファイルだけを保存 (データ自体は保存しない)

  記録する統計量:
  ┌──────────────────────────────────────────────┐
  │  数値特徴量:                                   │
  │    平均 / 分散 / 最小 / 最大 / パーセンタイル  │
  │    HyperLogLog (近似カーディナリティ)          │
  │    KLL スケッチ (分位数を少ないメモリで近似)   │
  │                                              │
  │  カテゴリ特徴量:                               │
  │    値の頻度分布 / ユニーク数 / NULL 率         │
  │                                              │
  │  テキスト:                                    │
  │    文字数統計 / 言語検出                       │
  └──────────────────────────────────────────────┘

  メリット: 元データの 1/1000 以下のサイズで統計特性を保持
  → 継続的なロギングが現実的なコストで可能
```

## ML パイプラインでの位置づけ

```
whylogs の典型的な使い方:

  学習時: reference プロファイルを保存
    ↓
  本番推論時: 毎時/毎日プロファイルを記録
    ↓
  WhyLabs / カスタムコード: プロファイルを比較してドリフト検知
    ↓
  アラート → モデル再訓練

  他ツールとの使い分け:
    whylogs   → 低コストな継続的データロギング (インフラとして)
    NannyML   → 遅延ラベルがある場合のパフォーマンス推定
    Evidently → 詳細な1回限りのレポート生成
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **推論ログ** | 毎回の予測入力をプロファイル化して保存 | 低コストで全推論の統計履歴を維持 |
| **特徴量監視** | Feature Store への書き込み時にプロファイル | データ品質問題をリアルタイム検知 |
| **データ品質** | Supabase テーブルの統計変化を追跡 | EF バグによる異常データを即座に発見 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'whylogs', 'api',
  'whylogs 実践 — DatasetProfileView/log/merge/条件付きプロファイル/WhyLabs統合/Airflow/Spark対応',
  $$## インストール & セットアップ

```bash
pip install whylogs

# WhyLabs 統合 (SaaS ダッシュボード)
pip install whylogs[whylabs]

# Spark 対応
pip install whylogs[spark]
```

## 基本: DataFrame のプロファイリング

```python
import whylogs as why
import pandas as pd

# データを読み込み
df = pd.DataFrame({
    "user_id": ["u1", "u2", "u3", "u4", "u5"],
    "days_since_last_active": [5, 30, 60, 2, 90],
    "avg_daily_events": [8.5, 3.2, 1.0, 12.0, 0.5],
    "churn_risk_score": [20.0, 50.0, 75.0, 10.0, 90.0],
    "churn_label": [0, 0, 1, 0, 1],
})

# プロファイルを生成
result = why.log(df)
profile = result.profile()

# プロファイルを確認
view = profile.view()
df_profile = view.to_pandas()
print(df_profile[["counts/n", "types/integral", "distribution/mean", "distribution/stddev"]])

# プロファイルをファイルに保存
profile.write("./profiles/reference_profile.bin")
print("プロファイル保存完了")
```

## 継続的なロギング (推論パイプライン)

```python
import whylogs as why
import pandas as pd
from datetime import datetime, timezone

def log_inference_data(input_df: pd.DataFrame, predictions: pd.Series, timestamp: datetime):
    """推論のたびに入力データをプロファイリングして保存"""

    # 予測結果も含めてプロファイル
    log_df = input_df.copy()
    log_df["prediction"] = predictions
    log_df["prediction_proba"] = predictions  # 確率値がある場合

    # タイムスタンプ付きでロギング
    result = why.log(log_df, dataset_timestamp=timestamp)

    # 日付ごとのファイルに保存
    date_str = timestamp.strftime("%Y-%m-%d")
    result.writer("local").option(base_dir="./profiles").write(dest=f"profile_{date_str}.bin")

    return result

# 本番推論ループ
import time
while True:
    batch = fetch_prediction_batch()  # Supabase から取得
    predictions = model.predict_proba(batch)[:, 1]

    log_inference_data(batch, predictions, datetime.now(timezone.utc))
    time.sleep(3600)  # 1時間ごと
```

## プロファイルの比較 (ドリフト検知)

```python
import whylogs as why
from whylogs.core.constraints.factories import (
    greater_than_number,
    mean_between_range,
    null_percentage_below_number,
)

# 参照プロファイルを読み込み
with open("./profiles/reference_profile.bin", "rb") as f:
    reference_profile = why.read(f)

# 本番プロファイルを読み込み
with open("./profiles/profile_2026-04-28.bin", "rb") as f:
    current_profile = why.read(f)

# 制約チェック (プロファイルベースのテスト)
from whylogs.core.constraints import ConstraintsBuilder

builder = ConstraintsBuilder(dataset_profile_view=current_profile.view())
builder.add_constraint(
    null_percentage_below_number(column_name="user_id", number=0.01)
)
builder.add_constraint(
    mean_between_range(
        column_name="days_since_last_active",
        lower=0.0,
        upper=120.0,
    )
)
builder.add_constraint(
    mean_between_range(
        column_name="churn_risk_score",
        lower=0.0,
        upper=100.0,
    )
)

constraints = builder.build()
valid = constraints.validate()

if not valid:
    violations = constraints.generate_constraints_report()
    for v in violations:
        print(f"❌ Constraint violation: {v}")
    raise ValueError("Data quality constraints violated!")

print("✅ All data quality constraints passed")
```

## WhyLabs Observatory 統合 (SaaS ダッシュボード)

```python
import whylogs as why
import os

# WhyLabs API キーを環境変数で設定
# WHYLABS_API_KEY, WHYLABS_ORG_ID, WHYLABS_MODEL_ID

# WhyLabs に自動アップロード
result = why.log(production_df)
result.writer("whylabs").write()
# → WhyLabs ダッシュボードで自動的にドリフトを可視化

# または設定を明示
from whylogs.api.writer.whylabs import WhyLabsWriter

writer = WhyLabsWriter(
    api_key=os.environ["WHYLABS_API_KEY"],
    org_id=os.environ["WHYLABS_ORG_ID"],
    model_id=os.environ["WHYLABS_MODEL_ID"],
)
result.writer(writer).write()
print("WhyLabs にプロファイルをアップロードしました")
```

## Airflow タスクでの組み込み

```python
from airflow.decorators import dag, task
import whylogs as why
import pandas as pd

@dag(schedule_interval="@hourly")
def feature_monitoring_pipeline():

    @task
    def profile_feature_data():
        """特徴量データのプロファイルを記録"""
        df = fetch_latest_features_from_supabase()

        result = why.log(df)

        # ローカル保存 + WhyLabs アップロード
        result.writer("local").option(base_dir="/opt/airflow/profiles").write()
        result.writer("whylabs").write()

        # プロファイルの基本統計を XCom で共有
        view = result.profile().view().to_pandas()
        null_rates = view["counts/null"].to_dict()
        return null_rates

    @task
    def alert_on_quality_issues(null_rates: dict):
        """NULL 率が高い場合はアラート"""
        import requests
        problematic = {k: v for k, v in null_rates.items() if v > 0.05}
        if problematic:
            requests.post(SLACK_WEBHOOK, json={
                "text": f"⚠️ 高 NULL 率検知: {problematic}"
            })

    null_rates = profile_feature_data()
    alert_on_quality_issues(null_rates)
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 291→292社化: whylogs 追加',
  'PS#3 S98。whylogs (データロギング/統計プロファイリング/KLLスケッチ/HyperLogLog/WhyLabs統合/制約チェック/Airflow統合/Spark対応/GitHub 3k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
