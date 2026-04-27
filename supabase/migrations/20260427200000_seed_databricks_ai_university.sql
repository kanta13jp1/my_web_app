-- PS#3 S77: AI大学 248→249社化 — Databricks 追加
-- Databricks: データ+AIプラットフォーム / Lakehouse / Apache Spark創始者 / MLflow / MosaicAI / DBRX / Delta Lake

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'databricks',
  'overview',
  'Databricks — データ+AIプラットフォーム (Lakehouse / Apache Spark / MLflow / MosaicAI / DBRX / Delta Lake)',
  $$## Databricks — Unified Data + AI Platform

**カテゴリ**: Data Platform / MLOps / Lakehouse / Enterprise AI / Apache Spark
**開発元**: Databricks, Inc.
**本社**: San Francisco, California
**設立**: 2013年 (UC Berkeley AMPLab 発、Apache Spark 創始者チーム)
**創業者**: Matei Zaharia (Apache Spark 発明者) + Ali Ghodsi (CEO) + 他5名
**評価額**: $62B (2024年 Series J) — 未上場最大級ユニコーン
**日本法人**: Databricks Japan 合同会社 (東京)
**OSSプロジェクト**: Apache Spark / Delta Lake / MLflow / Delta Sharing
**評価**: 8/9

### 概要
Databricks は **「データエンジニアリングと機械学習を1プラットフォームに統合する」** Lakehouse プラットフォーム。2013年に UC Berkeley の研究者たちが Apache Spark の商業化を目指して設立。その後、Delta Lake (信頼性の高いデータ湖)・MLflow (MLOps) を OSSで公開し、エンタープライズデータ市場のリーダーとなった。

**2023年の転換点**: MosaicAI (旧 MosaicML) を $1.3B で買収。LLM の学習・ファインチューニング・推論を Databricks プラットフォームで完結できるようにし、「データ+AI の統合プラットフォーム」としての地位を確立。

**競合**: Snowflake (データウェアハウス寄り) / Google BigQuery / AWS Redshift

### 主要製品

**1. Databricks Lakehouse Platform**
```
[Lakehouse = Data Lake + Data Warehouse の統合]

従来のアーキテクチャ:
  Data Lake (S3/GCS) → ETL → Data Warehouse (Snowflake) → BI
  → 二重管理 / データ鮮度の問題 / ETL コスト大

Lakehouse:
  Delta Lake (S3/GCS/ADLS 上の Delta テーブル) → Apache Spark で直接BI/ML
  → 単一ストレージ / リアルタイムデータ / ACID トランザクション
  → コスト 1/5 でデータウェアハウス相当の信頼性
```

**2. Delta Lake**
- Parquet ベースのオープンフォーマット + ACIDトランザクション
- タイムトラベル: 過去のデータバージョンをSQLで参照
- Schema Enforcement: データ品質を強制
- OSS: Apache License 2.0 (GitHub 7k+ スター)

**3. MLflow**
- ML実験管理・モデルレジストリ・サービング
- 前回の AI大学コンテンツ (MLflow 単体) で詳細解説済み

**4. MosaicAI (旧 MosaicML)**
- LLM の学習・ファインチューニング・推論を Databricks 上で実行
- Mosaic AI Training: FSDP / DeepSpeed で大規模LLM学習
- Mosaic AI Model Serving: エンタープライズ向けLLM推論エンドポイント
- DBRX: Databricks 独自 MoE LLM (132B params / 36B active)

**5. Unity Catalog**
- データ・テーブル・モデル・ファイルの統合ガバナンス
- 誰がどのデータを使ったかの監査ログ
- AI ガバナンス: MLflow モデルの lineage (出典) 追跡

### DBRX: Databricks 独自 LLM

```
[DBRX の特徴 (2024年3月発表)]

アーキテクチャ:
  MoE (Mixture-of-Experts): 132B 総パラメータ / 36B 活性パラメータ
  Transformer 基本構造 + GQA (Grouped Query Attention)

ベンチマーク (発表時):
  Hellaswag / ARC / PIQA: Llama 2 70B を上回る
  HumanEval (コード): GPT-3.5 相当
  MMLU: Mixtral 8x7B と同等以上

ライセンス:
  オープンウェイト (Commercial Use OK)
  Databricks Open Model License

推論:
  DBRX Instruct: チャット用
  DBRX Base: 継続学習用
```

### 日本での導入事例

| 企業 | 用途 | 成果 |
|------|------|------|
| NTTデータ | 全社データ基盤統合 / ML パイプライン | ETL処理時間 60% 削減 |
| トヨタ自動車 | 生産データ分析 / 品質予測 | 不良品検出精度 +25% |
| 野村ホールディングス | 金融データ分析 / リスク管理 | データ準備工数 70% 削減 |
| ソフトバンク | 顧客データ活用 / AI推薦システム | 推薦精度 +30% |

### 自分株式会社との関連性
```
位置付け:
  自分株式会社の技術スタック (Supabase + Flutter + Edge Functions) は
  スタートアップ・個人向けの軽量スタック。
  Databricks は大企業・データエンジニアリング特化。

AI大学コンテンツとしての価値:
  「Supabase から Databricks Lakehouse へのスケールアップ戦略」
  「MLflow × Databricks で本格的なMLOps基盤を構築」
  「Apache Spark が必要になる時: Supabase を超えるデータ量とは」

Supabase → Databricks 移行シナリオ:
  現在: Supabase PostgreSQL (数GBのデータ)
  将来 (IPO後): 数TB〜PBのデータ → Databricks Lakehouse + Delta Lake
  → 今から Databricks のアーキテクチャを理解しておく価値がある$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'databricks',
  'api',
  'Databricks API — REST API / Python SDK / Delta Lake操作 / MLflow統合 / Supabase → Databricks パターン',
  $$## Databricks API / 統合ガイド

### セットアップ
```bash
pip install databricks-sdk  # 公式 Python SDK
pip install databricks-connect  # ローカルからSparkクラスター接続用
pip install delta-spark  # Delta Lake OSS

# 認証: Personal Access Token
export DATABRICKS_HOST="https://adb-xxxx.azuredatabricks.net"
export DATABRICKS_TOKEN="dapi_xxxx"
```

### Python SDK 基本操作
```python
from databricks.sdk import WorkspaceClient

# クライアント初期化 (環境変数から自動認証)
w = WorkspaceClient()

# クラスター一覧
clusters = w.clusters.list()
for c in clusters:
    print(f"{c.cluster_id}: {c.cluster_name} ({c.state})")

# Notebook 実行
job_run = w.jobs.run_now(job_id=12345)
print(f"Job run ID: {job_run.run_id}")

# ファイルアップロード (DBFS)
with open("model.pkl", "rb") as f:
    w.dbfs.upload("/FileStore/models/model.pkl", f.read(), overwrite=True)
```

### Delta Lake 操作 (PySpark)
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, current_timestamp
from delta.tables import DeltaTable

spark = SparkSession.builder \
    .appName("DeltaLakeExample") \
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.4.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# Delta テーブル作成
data = [
    ("user_001", "太郎", "taro@example.com", "2026-01-01"),
    ("user_002", "花子", "hanako@example.com", "2026-01-02"),
]
df = spark.createDataFrame(data, ["user_id", "name", "email", "created_at"])
df.write.format("delta").save("/mnt/datalake/users")

# ACID アップサート (MERGE)
delta_table = DeltaTable.forPath(spark, "/mnt/datalake/users")
updates = spark.createDataFrame(
    [("user_001", "太郎 更新版", "taro_new@example.com", "2026-02-01")],
    ["user_id", "name", "email", "created_at"],
)
delta_table.alias("old").merge(
    updates.alias("new"),
    "old.user_id = new.user_id",
).whenMatchedUpdateAll().whenNotMatchedInsertAll().execute()

# タイムトラベル (過去バージョン参照)
df_v0 = spark.read.format("delta").option("versionAsOf", 0).load("/mnt/datalake/users")
df_v0.show()
```

### Supabase → Databricks データパイプライン
```python
# Supabase PostgreSQL → Databricks Delta Lake 同期
import psycopg2
from databricks.sdk import WorkspaceClient
from pyspark.sql import SparkSession

def sync_supabase_to_databricks(
    table_name: str,
    supabase_conn_str: str,
    delta_path: str,
) -> int:
    """Supabase のテーブルを Databricks Delta Lake に同期"""
    # Supabase からデータ取得
    conn = psycopg2.connect(supabase_conn_str)
    cursor = conn.cursor()
    cursor.execute(f"SELECT * FROM {table_name}")
    rows = cursor.fetchall()
    columns = [desc[0] for desc in cursor.description]
    conn.close()

    # Spark DataFrame に変換
    spark = SparkSession.builder.appName("SupabaseSync").getOrCreate()
    df = spark.createDataFrame(rows, columns)

    # Delta Lake に書き込み (upsert)
    df.write.format("delta").mode("overwrite").save(delta_path)
    return df.count()

# 毎日 Databricks Jobs でスケジュール実行
count = sync_supabase_to_databricks(
    table_name="ai_university_content",
    supabase_conn_str="postgresql://...",
    delta_path="/mnt/datalake/ai_university/content",
)
print(f"Synced {count} rows")
```

### Databricks SQL Warehouse (サーバーレスSQL)
```sql
-- Delta Lake テーブルを標準 SQL で操作
-- Databricks SQL Editor から実行

SELECT
    provider,
    category,
    COUNT(*) as content_count
FROM delta.`/mnt/datalake/ai_university/content`
GROUP BY provider, category
ORDER BY content_count DESC
LIMIT 20;

-- タイムトラベルクエリ
SELECT * FROM delta.`/mnt/datalake/ai_university/content`
TIMESTAMP AS OF '2026-04-01 00:00:00'
WHERE provider = 'openai';
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'databricks',
  'models',
  'Databricks 技術詳細 — Apache Spark アーキテクチャ / MosaicAI LLM学習 / Lakehouse設計 / Snowflake対比',
  $$## Databricks 技術詳細

### Apache Spark の仕組み

```
[Spark の分散処理アーキテクチャ]

Driver Program (コードを書く場所)
      ↓ タスク分散
Cluster Manager (YARN / Kubernetes / Databricks)
  ├── Executor 1 (Worker Node): タスクA実行
  ├── Executor 2 (Worker Node): タスクB実行
  └── Executor N (Worker Node): タスクN実行
      ↓ 結果を集約
Driver に返す

[なぜ速いか]
  - インメモリ処理: Hadoop MapReduce (ディスクI/O) の100倍速
  - Lazy Evaluation: transformationは実際に必要になるまで実行しない
  - Catalyst Optimizer: SQLクエリをコンパイル時に最適化
  - Tungsten: CPU/メモリの効率を最大化するコード生成
```

### Delta Lake の技術設計

```
[Delta Lake = Parquet + トランザクションログ]

Storage Layer (S3 / GCS / ADLS):
  /mnt/datalake/users/
    ├── _delta_log/         ← トランザクションログ (JSON)
    │   ├── 00000.json      ← Version 0: テーブル作成
    │   ├── 00001.json      ← Version 1: データ追加
    │   └── 00002.json      ← Version 2: UPDATE 実行
    ├── part-0001.parquet   ← 実データ
    ├── part-0002.parquet
    └── part-0003.parquet   ← 新規追加データ

[ACIDトランザクション]
  Atomicity: 全て成功 or 全て失敗 (途中失敗でもデータ破損なし)
  Consistency: Schemaが強制される
  Isolation: 同時書き込みでも競合なし (楽観的同時実行制御)
  Durability: クラッシュしても_delta_logから復元可能

[タイムトラベルの仕組み]
  Version N のデータ = _delta_logを Version 0 → N まで再生
  → 任意の時点のデータスナップショットを瞬時に取得
```

### MosaicAI: LLM 学習インフラ

```
[MosaicAI の構成]

Mosaic AI Training (LLM 学習):
  FSDP (Fully Sharded Data Parallel):
    モデルをGPU間で分割 → 1GPU 80GBでは入らない70Bモデルを学習可能
  DeepSpeed ZeRO-3:
    Optimizer状態・勾配・パラメータを全GPU分散
  Gradient Checkpointing:
    メモリ使用量を大幅削減 (速度と引き換え)

[DBRX 学習規模]
  GPU: NVIDIA H100 × 3072台
  学習データ: 12T (12兆) トークン
  学習時間: 数週間
  コスト: $1,000万〜数千万ドル級

Mosaic AI Model Serving (LLM 推論):
  - サーバーレス推論エンドポイント (自動スケール)
  - vLLM / TensorRT-LLM ベースの高速推論
  - A/B テスト: 複数モデルのトラフィック分割
  - MLflow での監視: レイテンシ / スループット / エラー率
```

### Databricks vs Snowflake

```
[市場ポジション比較]

       Databricks                Snowflake
データ処理   ✅ Spark (最速)          ○ 独自エンジン
AI/ML     ✅ MosaicAI統合          △ Snowpark ML
LLM学習   ✅ ネイティブ対応          △ 制限あり
SQL       ✅ Delta Live Tables     ✅ 最適化済み
価格      処理量課金 (コンピュート)   ストレージ+クレジット
OSS貢献   ✅ Spark/MLflow/Delta    △ 少ない
時価総額   $62B (未上場推定)        $50B (NYSE: SNOW)
```

### 自分株式会社との関連性

```
スタートアップ → スケールアップへの道筋:

Phase 1 (現在): Supabase PostgreSQL
  データ量: GB級 / ユーザー数: 数千〜数万
  → 現状で十分 / 余計なインフラコスト不要

Phase 2 (上場後): ハイブリッド構成
  Supabase: アプリケーションデータ (リアルタイム)
  Databricks: 分析・ML用データ (バッチ)
  → Supabase → Databricks 日次同期パイプライン

Phase 3 (大規模化): Databricks 中心化
  Delta Lake: 全データの Single Source of Truth
  MosaicAI: 自社LLMのファインチューニング
  Unity Catalog: データガバナンス + コンプライアンス

AI大学コンテンツとしての価値:
  「スタートアップがいつ Databricks を導入すべきか」
  「Supabase エンジニアが知るべき Databricks の基礎」
  データエンジニア / ML エンジニア向け高品質コンテンツ
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 248→249社化: Databricks 追加',
  'PS#3 S77。Databricks (データ+AIプラットフォーム/Lakehouse/Apache Spark創始者/Delta Lake/MLflow/MosaicAI/$1.3B買収/DBRX独自LLM/Unity Catalog/日本大手企業採用/8/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
