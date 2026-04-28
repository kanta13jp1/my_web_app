-- PS#3 S95: AI大学 284→285社化 — Hamilton (DAGベースPythonデータ変換/関数グラフ/再現性パイプライン)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'hamilton', 'overview',
  'Hamilton — DAGベースPythonデータ変換・関数グラフ・特徴量パイプライン再現性 (GitHub 2k+ / 8/9)',
  $$## Hamilton とは

**Hamilton** は **Python 関数をそのまま DAG (有向非巡回グラフ) に変換するデータ変換ライブラリ**。Stitch Fix の Stefan Krawczyk らが開発し OSS 化。「関数の引数名 = 依存関係」という発想で、ボイラープレートなしにデータフローを記述できる。

GitHub 2,000+ スター。Apache 2.0 ライセンス。DAGWorks 社が商用サポートを提供。pandas / Polars / Spark / Dask / Ray に対応。特徴量エンジニアリング・ML パイプライン・ETL に強い。

## 「引数名 = 依存関係」の革新

```
従来のデータパイプライン:
  step1_result = compute_step1(raw_data)
  step2_result = compute_step2(step1_result)    # 依存関係が暗黙的
  step3_result = compute_step3(step1_result, step2_result)

Hamilton のアプローチ:
  def step1_result(raw_data: pd.DataFrame) -> pd.Series:
      ...

  def step2_result(step1_result: pd.Series) -> pd.Series:
      # 引数名 step1_result が自動的に依存関係を定義する
      ...

  def step3_result(step1_result: pd.Series, step2_result: pd.Series) -> pd.Series:
      ...

  # Hamilton が自動的に DAG を構築・実行
  driver = h.Driver({"raw_data": df}, my_module)
  result = driver.execute(["step3_result"])
```

## ML パイプラインでの位置づけ

```
Hamilton が解決する問題:

  ✓ 特徴量計算の再現性: 同じ関数 = 同じ結果 (テスト可能)
  ✓ 依存関係の可視化: DAG をそのまま図示できる
  ✓ 部分実行: 必要なノードだけ実行 (コスト削減)
  ✓ バックエンド切り替え: pandas → Polars → Spark を設定1行で変更
  ✓ データカタログ: 各関数のドキュメントが自動的に特徴量仕様になる

  典型的な位置づけ:
  Hamilton (特徴量計算) → Feature Store (保存) → モデル学習/推論
  Hamilton (ETL) → DWH → dbt (変換) → BIツール
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **特徴量エンジニアリング** | 競馬予想の特徴量計算を関数グラフで定義 | 再現性・テスト可能な特徴量パイプライン |
| **ETL パイプライン** | Supabase → 変換 → ML 入力データ作成 | 依存関係の明示化・デバッグ容易化 |
| **ドキュメント自動化** | 各関数の docstring = データ仕様書 | 特徴量カタログを自動生成 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'hamilton', 'api',
  'Hamilton 実践 — Driver/モジュール定義/@tag/@check_output/Polars対応/DAG可視化/テスト/DAGWorks Hub',
  $$## インストール & セットアップ

```bash
pip install sf-hamilton

# pandas バックエンド (デフォルト)
pip install sf-hamilton[pandas]

# Polars バックエンド
pip install sf-hamilton[polars]

# 可視化
pip install sf-hamilton[visualization]
```

## 基本: モジュール定義と Driver 実行

```python
# features/user_features.py — Hamilton モジュール
import pandas as pd
from hamilton.function_modifiers import tag, check_output

def days_since_last_active(
    last_active_date: pd.Series,
    current_date: pd.Series,
) -> pd.Series:
    """ユーザーの最終アクティブ日からの経過日数"""
    return (current_date - last_active_date).dt.days


def churn_risk_score(
    days_since_last_active: pd.Series,
    avg_daily_events: pd.Series,
) -> pd.Series:
    """チャーンリスクスコア (0-100)"""
    recency_score = (days_since_last_active / 30).clip(0, 1) * 60
    frequency_score = (1 - (avg_daily_events / 10).clip(0, 1)) * 40
    return (recency_score + frequency_score).clip(0, 100)


@tag(owner="ml-team", category="churn")
def is_high_churn_risk(churn_risk_score: pd.Series) -> pd.Series:
    """高チャーンリスクフラグ"""
    return churn_risk_score >= 70


@check_output(
    data_type=pd.Series,
    range=(0, 100),
    allow_nans=False,
)
def normalized_activity_score(
    avg_daily_events: pd.Series,
    max_events: float = 50.0,
) -> pd.Series:
    """アクティビティスコア (正規化済み)"""
    return (avg_daily_events / max_events * 100).clip(0, 100)
```

```python
# main.py — Driver でパイプライン実行
import pandas as pd
import importlib
from hamilton import driver

# モジュール読み込み
import features.user_features as user_features_module

# 入力データ (raw データ)
input_data = {
    "last_active_date": pd.Series(pd.to_datetime(["2026-03-01", "2026-04-20", "2026-01-15"])),
    "current_date": pd.Series(pd.to_datetime(["2026-04-28"] * 3)),
    "avg_daily_events": pd.Series([5.0, 12.0, 1.0]),
}

# Driver 構築 (DAG を自動解析)
dr = driver.Driver(input_data, user_features_module)

# 出力したいノードを指定して実行
outputs = dr.execute(
    final_vars=["churn_risk_score", "is_high_churn_risk", "normalized_activity_score"],
    inputs=input_data,
)

print(outputs)
# → DataFrame: churn_risk_score, is_high_churn_risk, normalized_activity_score
```

## DAG 可視化

```python
# DAG を画像として出力
dr.visualize_execution(
    final_vars=["churn_risk_score"],
    inputs=input_data,
    output_file_path="dag.png",
)

# 全ノードを表示
dr.display_all_functions("all_dag.png")
```

## テスト: 個別関数を単体テストできる

```python
# tests/test_user_features.py
import pandas as pd
import pytest
from features.user_features import churn_risk_score, days_since_last_active

def test_days_since_last_active():
    last_active = pd.Series(pd.to_datetime(["2026-04-01"]))
    current = pd.Series(pd.to_datetime(["2026-04-28"]))
    result = days_since_last_active(last_active, current)
    assert result.iloc[0] == 27

def test_churn_risk_score_high():
    days = pd.Series([60.0])   # 60日間非アクティブ
    events = pd.Series([0.5])  # ほぼ使っていない
    result = churn_risk_score(days, events)
    assert result.iloc[0] >= 70  # 高リスク判定

def test_churn_risk_score_low():
    days = pd.Series([1.0])    # 昨日もアクティブ
    events = pd.Series([8.0])  # よく使っている
    result = churn_risk_score(days, events)
    assert result.iloc[0] < 30  # 低リスク判定
```

## Polars バックエンドへの切り替え

```python
import polars as pl
from hamilton import driver
from hamilton.plugins import h_polars

# Polars モードで Driver を構築 (モジュールは変更不要)
dr = driver.Driver(
    input_data,
    user_features_module,
    adapter=h_polars.PolarsDataFrameResult(),
)

# 同じコードで Polars DataFrame を出力
result = dr.execute(["churn_risk_score"], inputs=input_data)
# → Polars DataFrame (pandas より高速)
```

## Airflow / Prefect との統合

```python
# Airflow DAG から Hamilton を呼び出す
from airflow.decorators import dag, task
from hamilton import driver
import features.user_features as user_features_module

@dag(schedule_interval="@daily")
def churn_feature_pipeline():

    @task
    def compute_churn_features():
        dr = driver.Driver({}, user_features_module)
        df = fetch_user_data_from_supabase()
        inputs = {
            "last_active_date": df["last_active_date"],
            "current_date": pd.Series([pd.Timestamp.today()] * len(df)),
            "avg_daily_events": df["avg_daily_events"],
        }
        result = dr.execute(["churn_risk_score", "is_high_churn_risk"], inputs=inputs)
        save_features_to_store(result)

    compute_churn_features()
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 284→285社化: Hamilton 追加',
  'PS#3 S95。Hamilton (DAGベースPythonデータ変換/引数名=依存関係/Driver/モジュール/@tag/@check_output/Polars対応/DAG可視化/単体テスト可能/Airflow統合/Stitch Fix発/GitHub 2k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
