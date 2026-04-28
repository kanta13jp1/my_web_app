-- PS#3 S94: AI大学 282→283社化 — dbt (data build tool / SQLファーストデータ変換)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dbt', 'overview',
  'dbt — SQLファーストデータ変換・アナリティクスエンジニアリング・データウェアハウス変換 (GitHub 9k+ / 9/9)',
  $$## dbt とは

**dbt** (data build tool) は **SQL だけでデータウェアハウス内の変換を管理する**ツール。Fishtown Analytics (現 dbt Labs) が2016年に創業。「データエンジニアリングをソフトウェアエンジニアリングのベストプラクティスで行う」という思想。

GitHub 9,000+ スター。Apache 2.0 ライセンス。dbt Core (OSS) + dbt Cloud (SaaS) を提供。BigQuery / Snowflake / Redshift / DuckDB など主要DWHに対応。

## アナリティクスエンジニアリングの革新

```
従来のデータ変換:
  ETL ツール → 複雑な GUI → バージョン管理困難

dbt のアプローチ:
  SQL ファイル → git 管理 → テスト → ドキュメント自動生成

  特徴:
  ✓ SELECT 文だけ書けばよい (INSERT/UPDATE/CREATE 不要)
  ✓ モデル間の依存関係を自動解決
  ✓ テスト (not_null / unique / accepted_values) が内蔵
  ✓ データリネージ (血統) を自動可視化
  ✓ Jinja テンプレートで SQL を DRY 化
```

## ML パイプラインでの位置づけ

```
dbt の役割:
  Raw Data (S3/BigQuery) → [dbt] → Feature Store / ML データマート

  例:
  ├── staging/          # 生データをクリーニング
  │   └── stg_users.sql
  ├── intermediate/     # ビジネスロジック
  │   └── int_user_features.sql
  └── marts/            # ML 用特徴量テーブル
      └── fct_churn_features.sql
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **特徴量生成** | Supabase/BigQuery のデータを SQL で変換 | 再現性ある特徴量パイプライン |
| **データ品質** | dbt test で NULL/重複を自動検知 | GE との二重防衛 |
| **ドキュメント** | dbt docs で全テーブルを自動文書化 | データカタログ無料構築 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dbt', 'api',
  'dbt 実践 — models/tests/seeds/macros/sources/Jinja/dbt docs/dbt Cloud/Supabase統合',
  $$## インストール & セットアップ

```bash
pip install dbt-core
pip install dbt-bigquery   # BigQuery アダプター
pip install dbt-postgres   # PostgreSQL / Supabase
pip install dbt-duckdb     # ローカル開発用

# プロジェクト初期化
dbt init jibun_kaisha_analytics
cd jibun_kaisha_analytics
```

## profiles.yml (接続設定)

```yaml
# ~/.dbt/profiles.yml
jibun_kaisha_analytics:
  target: dev
  outputs:
    dev:
      type: postgres
      host: "db.xxxx.supabase.co"
      user: postgres
      password: "{{ env_var('SUPABASE_DB_PASSWORD') }}"
      port: 5432
      dbname: postgres
      schema: dbt_dev
      threads: 4

    prod:
      type: bigquery
      method: service-account
      project: jibun-kaisha-data
      dataset: dbt_prod
      threads: 8
      keyfile: "{{ env_var('GOOGLE_APPLICATION_CREDENTIALS') }}"
```

## モデル (SQL ファイル = テーブル/ビュー定義)

```sql
-- models/staging/stg_user_events.sql
-- Supabase の生データをクリーニング

{{ config(materialized='view') }}  -- ビューとして作成

SELECT
    id                                    AS event_id,
    user_id,
    event_type,
    created_at                           AS event_at,
    metadata->>'page' AS page_name,
    CAST(metadata->>'duration_ms' AS INTEGER) AS duration_ms
FROM {{ source('supabase', 'user_events') }}  -- 元テーブルを参照
WHERE created_at >= '2026-01-01'
  AND user_id IS NOT NULL
```

```sql
-- models/intermediate/int_user_daily_stats.sql
-- ユーザー別日次集計

{{ config(materialized='table') }}  -- テーブルとして実体化

WITH daily_events AS (
    SELECT
        user_id,
        DATE(event_at)  AS date,
        COUNT(*)        AS event_count,
        COUNT(DISTINCT event_type) AS unique_event_types,
        SUM(duration_ms) / 1000.0 AS total_duration_sec
    FROM {{ ref('stg_user_events') }}  -- 他モデルを参照
    GROUP BY user_id, DATE(event_at)
)

SELECT
    user_id,
    date,
    event_count,
    unique_event_types,
    total_duration_sec,
    -- 7日移動平均
    AVG(event_count) OVER (
        PARTITION BY user_id
        ORDER BY date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS event_count_7d_avg
FROM daily_events
```

```sql
-- models/marts/fct_churn_features.sql
-- チャーン予測用 ML 特徴量テーブル

{{ config(
    materialized='incremental',  -- 増分更新 (差分だけ処理)
    unique_key='user_id',
) }}

WITH user_stats AS (
    SELECT
        user_id,
        MAX(date)     AS last_active_date,
        COUNT(*)      AS active_days_total,
        AVG(event_count) AS avg_daily_events,
        AVG(total_duration_sec) AS avg_session_duration
    FROM {{ ref('int_user_daily_stats') }}
    {% if is_incremental() %}
        WHERE date > (SELECT MAX(last_active_date) FROM {{ this }})
    {% endif %}
    GROUP BY user_id
)

SELECT
    user_id,
    last_active_date,
    active_days_total,
    avg_daily_events,
    avg_session_duration,
    CURRENT_DATE - last_active_date AS days_since_last_active,
    CASE
        WHEN CURRENT_DATE - last_active_date > 30 THEN 1
        ELSE 0
    END AS is_churned
FROM user_stats
```

## テスト (データ品質チェック)

```yaml
# models/schema.yml
version: 2

models:
  - name: stg_user_events
    description: "クリーニング済みのユーザーイベントデータ"
    columns:
      - name: event_id
        description: "イベントID (一意)"
        tests:
          - not_null
          - unique
      - name: user_id
        tests:
          - not_null
          - relationships:
              to: source('supabase', 'users')
              field: id
      - name: event_type
        tests:
          - accepted_values:
              values: ['page_view', 'click', 'login', 'logout', 'purchase']

  - name: fct_churn_features
    tests:
      - dbt_expectations.expect_table_row_count_to_equal_other_table:
          compare_model: ref('stg_user_events')
```

## Jinja マクロ (SQL の DRY 化)

```sql
-- macros/generate_schema_name.sql
{% macro calculate_churn_risk(days_inactive) %}
    CASE
        WHEN {{ days_inactive }} > 60 THEN 'high'
        WHEN {{ days_inactive }} > 30 THEN 'medium'
        WHEN {{ days_inactive }} > 14 THEN 'low'
        ELSE 'active'
    END
{% endmacro %}
```

```sql
-- models/marts/fct_churn_features.sql での使用
SELECT
    user_id,
    days_since_last_active,
    {{ calculate_churn_risk('days_since_last_active') }} AS churn_risk_level
FROM user_stats
```

## dbt 実行コマンド

```bash
# モデルを実行 (テーブル/ビューを作成)
dbt run                          # 全モデル実行
dbt run --select fct_churn_features  # 特定モデルのみ
dbt run --select +fct_churn_features  # 依存関係も含めて実行

# テスト実行
dbt test                         # 全テスト
dbt test --select stg_user_events  # 特定モデルのテスト

# ドキュメント生成
dbt docs generate
dbt docs serve  # http://localhost:8080 で可視化

# データリネージ確認 (どのテーブルがどれに依存しているか)
dbt ls --select fct_churn_features+  # 下流の依存関係

# 本番実行 (CI/CD)
dbt run --target prod
dbt test --target prod
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 282→283社化: dbt 追加',
  'PS#3 S94。dbt (SQLファーストデータ変換/models/tests/macros/Jinja/増分更新incremental/dbt docs/BigQuery+Supabase対応/アナリティクスエンジニアリング/GitHub 9k+/Apache 2.0/9/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
