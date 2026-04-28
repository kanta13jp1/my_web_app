-- PS#3 S96: AI大学 286→287社化 — Evidently AI (OSS MLモニタリング/データドリフト/モデル性能劣化検知)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'evidently-ai', 'overview',
  'Evidently AI — OSS MLモニタリング・データドリフト検知・モデル性能劣化・レポート自動生成 (GitHub 5k+ / 9/9)',
  $$## Evidently AI とは

**Evidently AI** は **本番 ML モデルのデータドリフト・モデル性能劣化をリアルタイムに検知・可視化する OSS フレームワーク**。2021年設立のロシア発スタートアップが開発。Evidently Cloud (SaaS) も提供。

GitHub 5,000+ スター。Apache 2.0 ライセンス。Jupyter / HTML レポート / Grafana / MLflow / Airflow と統合。バッチ監視 + リアルタイム監視の両方に対応。

## ML 本番モニタリングの必要性

```
「モデルは劣化する」— 本番 ML の現実

  データドリフト:   入力データの分布が学習時から変化
                    例: 競馬予想で騎手の起用傾向が変わる
                        ユーザー行動が季節性・トレンドで変化

  コンセプトドリフト: ラベルとの関係性自体が変化
                    例: 「強いと思われていた要因」が通用しなくなる

  モデル性能劣化:   精度・AUC・RMSE が時間とともに悪化

  Evidently AI の検知方法:
  ┌──────────────────────────────────────────────┐
  │  Reference データ (学習時) vs Current データ │
  │         ↓          比較・統計検定             │
  │  PSI / KL Divergence / Wasserstein 距離       │
  │  KS 検定 / Chi-Square 検定 でドリフトを定量化 │
  └──────────────────────────────────────────────┘
```

## テスト・レポートの種類

```
Evidently の主要コンポーネント:

  Report:  可視化レポート (HTML/Jupyter) — 人間が読む
    ├── DataDriftPreset   — 全特徴量のドリフト一覧
    ├── DataQualityPreset — NULL率/重複/外れ値チェック
    ├── ClassificationPreset — 精度/AUC/混同行列
    └── RegressionPreset  — RMSE/MAE/残差分析

  TestSuite: CI/CD 用の自動テスト — 機械が判定
    ├── TestColumnDrift   — 特定カラムのドリフト
    ├── TestShareOfOutRangeValues — 値域外サンプル率
    ├── TestAccuracyScore  — 精度の閾値チェック
    └── カスタムテスト     — 任意の条件をコードで定義
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬予想監視** | 毎週の予測結果と学習時データを比較 | モデル再訓練のタイミングを自動判定 |
| **ユーザー特徴量監視** | チャーン予測の入力分布を追跡 | 急激な行動変化をいち早く検知 |
| **CI/CD ゲート** | TestSuite を GHA に組み込み | 本番デプロイ前のデータ品質チェック |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'evidently-ai', 'api',
  'Evidently AI 実践 — Report/TestSuite/DataDrift/ClassificationPreset/Grafana統合/MLflow/GHA CI',
  $$## インストール & セットアップ

```bash
pip install evidently

# Grafana ダッシュボード統合 (リアルタイム監視)
pip install evidently[spark]   # Spark 対応

# バージョン確認
python -c "import evidently; print(evidently.__version__)"
```

## 基本: データドリフト レポート生成

```python
import pandas as pd
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset, DataQualityPreset

# 参照データ (学習時) と現在データを準備
reference_df = pd.read_parquet("./data/reference_features.parquet")
current_df   = pd.read_parquet("./data/current_features.parquet")

# データドリフト レポート生成
report = Report(metrics=[
    DataDriftPreset(),    # 全特徴量のドリフトをまとめてチェック
    DataQualityPreset(),  # データ品質 (NULL/外れ値/重複) チェック
])

report.run(reference_data=reference_df, current_data=current_df)

# HTML レポートとして保存
report.save_html("./reports/drift_report.html")
print("レポート生成完了: drift_report.html")

# Jupyter でインタラクティブに表示
report.show()
```

## モデル性能レポート (Classification)

```python
from evidently.report import Report
from evidently.metric_preset import ClassificationPreset
from evidently.metrics import (
    ClassificationQualityMetric,
    ClassificationConfusionMatrix,
    ClassificationRocCurve,
)

# 予測結果データフレーム (target=正解, prediction=予測)
eval_df = pd.DataFrame({
    "target": [0, 1, 0, 1, 0, 1, 1, 0],
    "prediction": [0, 1, 0, 0, 0, 1, 1, 1],
    "churn_probability": [0.1, 0.9, 0.2, 0.6, 0.3, 0.85, 0.95, 0.7],
    "days_since_last_active": [5, 60, 10, 30, 7, 90, 120, 45],
    "avg_daily_events": [8.0, 1.0, 6.5, 3.0, 7.5, 0.5, 0.2, 2.0],
})

report = Report(metrics=[
    ClassificationPreset(),   # 精度/AUC/混同行列/ROC曲線を全部生成
])

report.run(reference_data=None, current_data=eval_df)
report.save_html("./reports/model_performance.html")
```

## TestSuite: CI/CD 自動テスト (合否判定)

```python
from evidently.test_suite import TestSuite
from evidently.tests import (
    TestColumnDrift,
    TestShareOfOutRangeValues,
    TestNumberOfNulls,
    TestAllColumnsShareOfMissingValues,
)

# CI/CD で使うテストスイート
test_suite = TestSuite(tests=[
    TestColumnDrift(column_name="days_since_last_active"),
    TestColumnDrift(column_name="avg_daily_events"),
    TestShareOfOutRangeValues(
        column_name="churn_risk_score",
        left=0,
        right=100,
        lte=0.05,   # 5%以上が範囲外なら失敗
    ),
    TestAllColumnsShareOfMissingValues(lt=0.01),  # NULL率 1%未満
    TestNumberOfNulls(lte=100),
])

test_suite.run(reference_data=reference_df, current_data=current_df)

# JSON 結果取得 (CI/CD での機械判定)
result = test_suite.as_dict()
if result["summary"]["all_passed"]:
    print("✅ All data quality tests passed!")
else:
    failed = [t for t in result["tests"] if t["status"] != "SUCCESS"]
    for f in failed:
        print(f"❌ FAILED: {f['name']} — {f['description']}")
    raise ValueError("Data quality check failed!")
```

## GHA CI/CD 統合

```yaml
# .github/workflows/ml-monitoring.yml
name: ML Model Monitoring

on:
  schedule:
    - cron: "0 9 * * 1"   # 毎週月曜 9時に実行
  workflow_dispatch:

jobs:
  drift-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install Evidently
        run: pip install evidently pandas pyarrow

      - name: Download data from Supabase
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
        run: python scripts/fetch_monitoring_data.py

      - name: Run drift detection
        run: |
          python - <<'EOF'
          import pandas as pd
          from evidently.test_suite import TestSuite
          from evidently.tests import TestColumnDrift, TestAllColumnsShareOfMissingValues
          import sys

          reference = pd.read_parquet("data/reference.parquet")
          current   = pd.read_parquet("data/current.parquet")

          suite = TestSuite(tests=[
              TestColumnDrift(column_name="days_since_last_active"),
              TestColumnDrift(column_name="avg_daily_events"),
              TestAllColumnsShareOfMissingValues(lt=0.02),
          ])
          suite.run(reference_data=reference, current_data=current)

          result = suite.as_dict()
          if not result["summary"]["all_passed"]:
              print("⚠️ Data drift detected — consider retraining!")
              sys.exit(1)
          print("✅ No significant drift detected")
          EOF

      - name: Generate HTML report
        if: always()
        run: python scripts/generate_drift_report.py

      - name: Upload report artifact
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: drift-report
          path: reports/drift_report.html

      - name: Notify Slack on drift
        if: failure()
        env:
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
        run: |
          curl -X POST $SLACK_WEBHOOK \
            -H "Content-Type: application/json" \
            -d '{"text":"⚠️ *データドリフト検知* — ML モデルの再訓練を検討してください。詳細は GitHub Actions のアーティファクトを確認。"}'
```

## MLflow との統合

```python
import mlflow
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset

# MLflow の run 内でドリフトレポートを記録
with mlflow.start_run(run_name="drift_monitoring"):
    report = Report(metrics=[DataDriftPreset()])
    report.run(reference_data=reference_df, current_data=current_df)

    # ドリフトした特徴量数を MLflow メトリクスとして記録
    result = report.as_dict()
    drifted_features = sum(
        1 for m in result["metrics"]
        if m.get("result", {}).get("drift_detected", False)
    )
    mlflow.log_metric("drifted_features_count", drifted_features)

    # HTML レポートをアーティファクトとして保存
    report.save_html("/tmp/drift_report.html")
    mlflow.log_artifact("/tmp/drift_report.html")

    print(f"Drifted features: {drifted_features}")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 286→287社化: Evidently AI 追加',
  'PS#3 S96。Evidently AI (OSS MLモニタリング/データドリフト検知/PSI・KS検定/Report+TestSuite/ClassificationPreset/DataDriftPreset/GHA CI統合/MLflow連携/Grafana対応/GitHub 5k+/Apache 2.0/9/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
