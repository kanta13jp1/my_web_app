-- PS#3 S98: AI大学 290→291社化 — NannyML (遅延フィードバック対応MLモニタリング/コンセプトドリフト検知)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'nannyml', 'overview',
  'NannyML — 遅延フィードバック対応MLモニタリング・コンセプトドリフト検知・ラベルなし本番監視 (GitHub 2k+ / 8/9)',
  $$## NannyML とは

**NannyML** は **ラベル (正解データ) なしで本番 ML モデルの性能劣化を推定する OSS フレームワーク**。ベルギーの ML スタートアップが2021年に開発・OSSとして公開。

GitHub 2,000+ スター。Apache 2.0 ライセンス。「本番では正解ラベルがなかなか得られない」という現実的な問題を解決する独自のアプローチ。NannyML Cloud (SaaS) も提供。

## 「ラベルなし監視」の革新

```
ML 本番モニタリングの現実:

  問題: 正解データがすぐに手に入らない

    例 1: チャーン予測
      予測: 「このユーザーは30日後に退会する」
      実際の退会: 30日後に判明 → 精度計算は30日後まで不可能!

    例 2: クレジットリスク評価
      予測: 「この申請者はデフォルトする」
      実際のデフォルト: 数ヶ月〜数年後に判明

  従来のツールの問題:
    Great Expectations / Evidently → データ分布の変化は検知できる
    → でも「モデルの精度が下がっているか」は正解ラベルがないと分からない

  NannyML の解決策:
    CBPE (Confidence-Based Performance Estimation):
    → モデルの予測確率だけでパフォーマンスを「推定」
    → 正解ラベルなしで「今 AUC が 0.85 → 0.72 に下がっている可能性が高い」と分かる!

    DLE (Direct Loss Estimation):
    → 回帰モデルの誤差を正解なしで推定
```

## コンセプトドリフト vs データドリフト

```
2 種類のドリフト:

  データドリフト (Covariate Shift):
    入力データ X の分布が変化
    例: ユーザー年齢層が若くなった
    検知: Evidently AI / Monte Carlo でも対応可能

  コンセプトドリフト (Concept Drift):
    X と Y (ラベル) の関係性自体が変化
    例: 「若い = 活発ユーザー」という関係が崩れた
    検知: NannyML の CBPE/DLE が必要 (正解なし推定)

  NannyML は両方を統一的に扱える点が強み
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬予想監視** | 予測確率のみで的中率劣化を早期推定 | 30日後の成績を事前に察知 |
| **チャーン予測** | 退会確認前に精度劣化を検知 | モデル再訓練を適切なタイミングで実施 |
| **即時アラート** | 性能推定値が閾値を下回ったら Slack 通知 | ユーザー体験の悪化を最小化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'nannyml', 'api',
  'NannyML 実践 — CBPE/DLE/データドリフト検知/チャンクベース分析/アラート/可視化/GHA統合',
  $$## インストール & セットアップ

```bash
pip install nannyml

# バージョン確認
python -c "import nannyml; print(nannyml.__version__)"
```

## 基本: CBPE (Confidence-Based Performance Estimation)

```python
import pandas as pd
import nannyml as nml

# 学習/テスト時のデータ (参照データ)
reference_df = pd.read_parquet("./data/reference_with_labels.parquet")
# カラム: user_id, feature1..N, predicted_proba, actual_label

# 本番データ (正解ラベルなし)
production_df = pd.read_parquet("./data/production_no_labels.parquet")
# カラム: user_id, feature1..N, predicted_proba (actual_label は未知)

# CBPE: 正解なしで AUC-ROC を推定
estimator = nml.CBPE(
    y_pred_proba="predicted_proba",
    y_pred="predicted_label",
    y_true="actual_label",
    timestamp_column_name="timestamp",
    metrics=["roc_auc", "f1"],    # 推定する指標
    chunk_size=500,               # 500件ごとに評価
    problem_type="binary_classification",
)

estimator.fit(reference_df)

results = estimator.estimate(production_df)

# 結果表示
print(results.filter(period="analysis").to_df().head())
# → timestamp, estimated_roc_auc, lower_confidence_bound, upper_confidence_bound

# 可視化
figure = results.plot()
figure.write_html("./reports/cbpe_performance.html")
```

## データドリフト検知

```python
# 特徴量のドリフトを検知 (Univariate Drift)
drift_calculator = nml.UnivariateDriftCalculator(
    column_names=[
        "days_since_last_active",
        "avg_daily_events",
        "total_active_days",
        "churn_risk_score",
    ],
    timestamp_column_name="timestamp",
    chunk_size=500,
    continuous_methods=["kolmogorov_smirnov", "wasserstein"],  # 連続変数の検定
    categorical_methods=["chi2", "jensen_shannon"],             # カテゴリ変数の検定
)

drift_calculator.fit(reference_df)
drift_results = drift_calculator.calculate(production_df)

# ドリフトしたカラムを確認
print(drift_results.filter(period="analysis").to_df()[["timestamp", "column_name", "drift_detected"]])

# 可視化
figure = drift_results.plot()
figure.write_html("./reports/drift_report.html")
```

## DLE (Direct Loss Estimation) — 回帰モデル向け

```python
# 回帰モデルの誤差を正解なしで推定
dle_estimator = nml.DLE(
    feature_column_names=["feature1", "feature2", "feature3"],
    y_pred="prediction",
    y_true="actual_value",          # 参照データのみに存在
    timestamp_column_name="timestamp",
    metrics=["rmse", "mae"],
    chunk_size=300,
)

dle_estimator.fit(reference_df_with_labels)
dle_results = dle_estimator.estimate(production_df_no_labels)

figure = dle_results.plot()
figure.write_html("./reports/dle_regression.html")
```

## アラート設定 (閾値超過を検知)

```python
import nannyml as nml
import requests  # Slack 通知用

reference_df = pd.read_parquet("reference.parquet")
production_df = pd.read_parquet("production.parquet")

estimator = nml.CBPE(
    y_pred_proba="predicted_proba",
    y_pred="predicted_label",
    y_true="actual_label",
    timestamp_column_name="timestamp",
    metrics=["roc_auc"],
    chunk_size=500,
)
estimator.fit(reference_df)
results = estimator.estimate(production_df)

# 最新チャンクのパフォーマンスを確認
latest = results.filter(period="analysis").to_df().tail(1)
estimated_auc = latest["estimated_roc_auc"].iloc[0]
alert_triggered = latest["alert"].iloc[0]

print(f"Estimated AUC: {estimated_auc:.4f}, Alert: {alert_triggered}")

# Slack アラート
THRESHOLD = 0.80
if estimated_auc < THRESHOLD or alert_triggered:
    response = requests.post(
        SLACK_WEBHOOK,
        json={
            "text": (
                f"⚠️ *ML モデル性能劣化推定*\n"
                f"推定 AUC-ROC: `{estimated_auc:.4f}` (閾値: {THRESHOLD})\n"
                f"NannyML Alert: `{alert_triggered}`\n"
                f"→ モデル再訓練を検討してください"
            )
        }
    )
    print("Slack 通知送信完了")
```

## GHA CI/CD での週次監視

```yaml
# .github/workflows/ml-performance-monitoring.yml
name: ML Performance Monitoring (NannyML)

on:
  schedule:
    - cron: "0 8 * * 1"   # 毎週月曜 8時
  workflow_dispatch:

jobs:
  nannyml-monitor:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install NannyML
        run: pip install nannyml pandas pyarrow requests

      - name: Download latest production data
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
        run: python scripts/fetch_production_predictions.py

      - name: Run NannyML CBPE monitoring
        env:
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
        run: python scripts/nannyml_monitor.py

      - name: Upload reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: nannyml-reports
          path: reports/
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 290→291社化: NannyML 追加',
  'PS#3 S98。NannyML (遅延フィードバック対応MLモニタリング/CBPE正解なしAUC推定/DLE回帰誤差推定/コンセプトドリフト/データドリフト/アラート/GHA CI/GitHub 2k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
