-- PS#3 S93: AI大学 281→282社化 — Great Expectations (OSS データ品質バリデーション / テスト)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'great-expectations', 'overview',
  'Great Expectations — OSS データ品質バリデーション・データテスト・パイプライン品質保証 (GitHub 9k+ / 9/9)',
  $$## Great Expectations とは

**Great Expectations** (GX) は**データの品質を自動的にテスト・検証するオープンソースフレームワーク**。「コードのユニットテストをデータに適用する」というアプローチ。2018年設立の Great Expectations 社が開発。

GitHub 9,000+ スター。Apache 2.0 ライセンス。GX Cloud (SaaS 版) も提供。Airbnb / Yelp / Supercell 等で採用。ML パイプラインのデータ品質ゲートとして広く使われる。

## データ品質問題の重要性

```
"ゴミを入れればゴミが出る" (Garbage In, Garbage Out)

ML モデルの失敗の 80% はデータ品質問題:

  ✗ NULL値の混入 → モデルが誤学習
  ✗ 想定外の値域 → 特徴量が狂う
  ✗ スキーマ変更 → 本番パイプラインが破損
  ✗ 分布の急変 → 予測精度が急落 (Data Drift)
  ✗ 重複レコード → バイアスが発生

Great Expectations の解決策:
  → 期待値 (Expectation) をコードで定義
  → パイプラインの入口/出口で自動チェック
  → 違反があれば即アラート → パイプラインを止める
```

## Expectation (期待値) の概念

```python
# 「このデータはこうあるべき」を宣言的に定義

expect_column_to_exist("user_id")
expect_column_values_to_not_be_null("user_id")
expect_column_values_to_be_unique("user_id")
expect_column_values_to_be_between("age", min_value=0, max_value=120)
expect_column_values_to_match_regex("email", r"^[^@]+@[^@]+\.[^@]+$")
expect_column_values_to_be_in_set("label", {"positive", "negative", "neutral"})
expect_column_mean_to_be_between("score", min_value=0.0, max_value=1.0)
expect_table_row_count_to_be_between(min_value=1000, max_value=1000000)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **ML パイプライン** | 学習データ投入前に品質チェック | データ起因のモデル劣化を防止 |
| **Supabase データ** | EF からのデータ出力を検証 | API レスポンスの品質保証 |
| **Data Drift 検知** | 本番データ分布の変化を監視 | モデル再訓練のトリガー検知 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'great-expectations', 'api',
  'Great Expectations 実践 — DataContext/Expectation Suite/Checkpoint/Data Docs/Pandas+Spark/GHA統合',
  $$## インストール & セットアップ

```bash
pip install great-expectations

# プロジェクト初期化
great_expectations init
# → gx/ ディレクトリが生成される

# バージョン確認
great_expectations --version
```

## 基本: Expectation Suite の作成

```python
import great_expectations as gx
import pandas as pd

# DataContext (プロジェクト管理)
context = gx.get_context()

# Pandas DataFrame に対してバリデーション
df = pd.read_parquet("./data/jibun-kaisha-training.parquet")

# バリデーター作成
validator = context.sources.pandas_default.read_dataframe(df)

# Expectation を追加 (「こうあるべき」を定義)
validator.expect_column_to_exist("text")
validator.expect_column_to_exist("label")
validator.expect_column_values_to_not_be_null("text")
validator.expect_column_values_to_not_be_null("label")
validator.expect_column_values_to_be_in_set("label", {"positive", "negative", "neutral"})
validator.expect_column_value_lengths_to_be_between("text", min_value=5, max_value=5000)
validator.expect_table_row_count_to_be_between(min_value=1000, max_value=10000000)
validator.expect_column_values_to_be_unique("text")  # 重複テキストなし

# Expectation Suite として保存
validator.save_expectation_suite(
    expectation_suite_name="jibun-kaisha-training-suite"
)
print("Expectation Suite saved!")
```

## Checkpoint: バリデーションの実行

```python
import great_expectations as gx

context = gx.get_context()

# Checkpoint 作成 (Suite + Data Source を組み合わせたバリデーション設定)
checkpoint = context.add_or_update_checkpoint(
    name="jibun-kaisha-daily-checkpoint",
    validations=[{
        "batch_request": {
            "datasource_name": "pandas_datasource",
            "data_connector_name": "default_inferred_data_connector_name",
            "data_asset_name": "jibun-kaisha-training.parquet",
        },
        "expectation_suite_name": "jibun-kaisha-training-suite",
    }],
)

# バリデーション実行
result = checkpoint.run()

# 結果判定
if result.success:
    print("✅ All data quality checks passed!")
else:
    # 失敗した Expectation の詳細を表示
    for validation_result in result.list_validation_results():
        if not validation_result.success:
            print(f"❌ Failed: {validation_result.expectation_suite_name}")
            for result in validation_result.results:
                if not result.success:
                    print(f"  - {result.expectation_config.expectation_type}: "
                          f"{result.result}")
    raise ValueError("Data quality check failed! Pipeline stopped.")
```

## 統計的な Expectation (Data Drift 検知)

```python
import great_expectations as gx

context = gx.get_context()
validator = context.sources.pandas_default.read_dataframe(new_data_df)

# 分布チェック (Data Drift 検知に有効)
validator.expect_column_mean_to_be_between(
    "score",
    min_value=0.3,
    max_value=0.7,
    notes="スコアの平均が通常範囲を逸脱していないか確認",
)
validator.expect_column_stdev_to_be_between("score", min_value=0.1, max_value=0.4)

# パーセンタイルチェック
validator.expect_column_quantile_values_to_be_between(
    "score",
    quantile_ranges={
        "quantiles": [0.25, 0.5, 0.75],
        "value_ranges": [[0.2, 0.4], [0.4, 0.6], [0.6, 0.8]],
    },
)

# ラベル分布チェック
validator.expect_column_proportion_of_unique_values_to_be_between(
    "label", min_value=0.01, max_value=0.99
)
```

## Data Docs: 自動ドキュメント生成

```python
# バリデーション結果を HTML レポートとして自動生成
context.build_data_docs()
context.open_data_docs()  # ブラウザで開く

# → gx/uncommitted/data_docs/local_site/index.html
# → 全 Expectation の Pass/Fail 状況をビジュアルで確認可能
```

## GHA CI/CD 統合

```yaml
# .github/workflows/data-quality-check.yml
name: Data Quality Check

on:
  workflow_dispatch:
  schedule:
    - cron: "0 */6 * * *"   # 6時間ごとに実行

jobs:
  validate-data:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: pip install great-expectations pandas pyarrow

      - name: Download latest data
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          aws s3 cp s3://jibun-kaisha-ml/data/latest.parquet ./data/latest.parquet

      - name: Run data validation
        run: python scripts/validate_data.py

      - name: Upload Data Docs
        if: always()   # 失敗時もドキュメントをアップロード
        uses: actions/upload-artifact@v4
        with:
          name: data-docs
          path: gx/uncommitted/data_docs/

      - name: Notify on failure
        if: failure()
        run: |
          # Slack 通知 (データ品質問題をアラート)
          curl -X POST $SLACK_WEBHOOK \
            -d '{"text": "🚨 Data quality check failed! Check GH Actions for details."}'
```

```python
# scripts/validate_data.py
import great_expectations as gx
import sys

context = gx.get_context()
result = context.run_checkpoint(checkpoint_name="jibun-kaisha-daily-checkpoint")

if not result.success:
    print("❌ Data quality validation FAILED")
    sys.exit(1)  # GHA ワークフローを失敗させる

print("✅ Data quality validation PASSED")
sys.exit(0)
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 281→282社化: Great Expectations 追加',
  'PS#3 S93。Great Expectations (OSS データ品質バリデーション/Expectation Suite/Checkpoint/Data Drift検知/Data Docs HTML/GHA CI統合/Pandas+Spark対応/GitHub 9k+/Apache 2.0/9/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
