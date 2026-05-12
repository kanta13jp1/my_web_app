-- PS#3 S92: AI大学 279→280社化 — Pachyderm (データバージョン管理 + コンテナ化 ML パイプライン)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'pachyderm', 'overview',
  'Pachyderm — データバージョン管理・コンテナ化MLパイプライン・Git for Data・自動再処理 (GitHub 6k+ / 8/9)',
  $$## Pachyderm とは

**Pachyderm** は**データバージョン管理と ML パイプラインを統合した次世代 MLops プラットフォーム**。2014年創業、米国サンフランシスコ。2023年 HPE (Hewlett Packard Enterprise) が買収。

GitHub 6,000+ スター。OSS 版 + Pachyderm Enterprise。「Git for Data」コンセプト — データの変更履歴を完全追跡し、差分データだけを処理して効率化する。

## 核心概念: Git for Data

```
Pachyderm の設計思想:

  Git でコードを管理するように、データを管理する

  コードの Git:
    ✓ commit: 変更を記録
    ✓ branch: 並行開発
    ✓ diff: 変更差分
    ✓ revert: 過去に戻す

  Pachyderm のデータバージョン管理:
    ✓ commit: データ変更を記録 (ファイル単位で追跡)
    ✓ branch: 並行実験 (同じデータの別バージョン)
    ✓ diff: データ変更差分を自動検出
    ✓ 差分データだけパイプラインを再実行 (効率化)
```

## 自動差分再処理の威力

```
従来 (Airflow / Prefect):
  → データが 1 件追加されても全データを再処理

Pachyderm:
  → 変更されたデータ (diff) だけを再処理
  → 1000 万件のデータに 100 件追加 → 100 件だけ処理

実例:
  ・月次: 新規ラベルデータ 500 件が追加
  ・Pachyderm: 500 件だけ特徴量抽出 → モデル再訓練
  ・vs Airflow: 全 10 万件を毎月再処理
  → 処理時間 99.5% 削減
```

## パイプラインとリポジトリ

```
Pachyderm のアーキテクチャ:

  Data Repository (バージョン管理されたストレージ)
      │
      ▼
  Pipeline (コンテナで実行される変換処理)
      │
      ▼
  Output Repository (結果データ)
      │
      ▼
  次の Pipeline... (チェーン可能)

すべて Kubernetes 上で動作
すべてのデータ変換がコンテナとして実行 → 再現性 100%
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **増分学習** | 新規ラベルデータだけ再訓練 | 訓練コストを大幅削減 |
| **データ系譜** | 全データ変換の追跡 | 規制対応・監査に対応 |
| **A/B データ実験** | ブランチで異なる前処理を並行比較 | データ品質実験の効率化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'pachyderm', 'api',
  'Pachyderm 実践 — pachctl/リポジトリ/コミット/パイプライン定義/差分処理/データ系譜/Python SDK',
  $$## インストール & セットアップ

```bash
# pachctl CLI インストール (Mac/Linux)
brew tap pachyderm/tap && brew install pachyderm/tap/pachctl@2.7

# または curl でインストール
curl -o /tmp/pachctl.deb -L \
  https://github.com/pachyderm/pachyderm/releases/download/v2.7.0/pachctl_2.7.0_amd64.deb
sudo dpkg -i /tmp/pachctl.deb

# Kubernetes (minikube) へのデプロイ
pachctl deploy local

# 接続確認
pachctl version
```

## リポジトリとデータのバージョン管理

```bash
# データリポジトリ作成
pachctl create repo jibun-kaisha-training-data
pachctl create repo jibun-kaisha-labels

# データをアップロード (コミット)
pachctl put file jibun-kaisha-training-data@main:/train.parquet \
  -f ./data/train.parquet

# ラベルデータを追加 (差分コミット)
pachctl put file jibun-kaisha-labels@main:/batch_001.json \
  -f ./labels/batch_001.json

# コミット履歴確認 (git log 相当)
pachctl list commit jibun-kaisha-labels

# リポジトリ内のファイル確認
pachctl list file jibun-kaisha-training-data@main

# 過去のバージョンのデータを取得
pachctl get file jibun-kaisha-training-data@<commit-id>:/train.parquet \
  -o ./data/train_v1.parquet
```

## パイプライン定義 (JSON/YAML)

```yaml
# preprocess-pipeline.yaml
pipeline:
  name: preprocess

description: "日本語テキストの前処理パイプライン"

input:
  pfs:
    repo: jibun-kaisha-training-data
    glob: "/*.parquet"   # 変更されたParquetファイルだけ処理

transform:
  image: jibun-kaisha/ml-preprocess:v1   # Docker イメージ
  cmd:
    - python
    - /app/preprocess.py
  env:
    SUPABASE_URL: "https://xxx.supabase.co"

resource_requests:
  cpu: "2"
  memory: "4Gi"

autoscaling: true   # 負荷に応じて自動スケール
```

```bash
# パイプラインをデプロイ
pachctl create pipeline -f preprocess-pipeline.yaml

# パイプラインの状態確認
pachctl list pipeline
pachctl list job

# ログ確認
pachctl logs --pipeline preprocess
```

## 差分処理の実装例 (コンテナ内のスクリプト)

```python
# preprocess.py (Pachyderm コンテナ内で実行)
import os
import pandas as pd
from pathlib import Path

# Pachyderm が差分ファイルを /pfs/input/ に配置
# 出力は /pfs/out/ に書く
INPUT_DIR = Path("/pfs/jibun-kaisha-training-data")
OUTPUT_DIR = Path("/pfs/out")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Pachyderm は変更されたファイルだけを /pfs/input/ に入れる
# → 全件処理不要!
for parquet_file in INPUT_DIR.glob("*.parquet"):
    df = pd.read_parquet(parquet_file)

    # 前処理
    df["text_clean"] = df["text"].str.strip()
    df["text_len"] = df["text"].str.len()
    df = df[df["text_len"] > 10]  # 短すぎるテキストを除外

    # 出力ファイルに保存 (同名で保存)
    output_path = OUTPUT_DIR / parquet_file.name
    df.to_parquet(output_path, index=False)
    print(f"Processed {parquet_file.name}: {len(df)} records")
```

## 連鎖パイプライン (前処理 → 特徴量抽出 → 訓練)

```yaml
# feature-extraction-pipeline.yaml
pipeline:
  name: feature-extraction

input:
  pfs:
    repo: preprocess   # 前のパイプラインの出力を入力に
    glob: "/*"

transform:
  image: jibun-kaisha/ml-features:v1
  cmd: ["python", "/app/extract_features.py"]
```

```yaml
# training-pipeline.yaml
pipeline:
  name: training

input:
  cross:              # 2つのリポジトリのクロス積
    - pfs:
        repo: feature-extraction
        glob: "/*"
    - pfs:
        repo: jibun-kaisha-labels
        glob: "/*"

transform:
  image: jibun-kaisha/ml-train:v1
  cmd: ["python", "/app/train.py"]
  gpu_limit: "1"
```

## データ系譜 (Lineage) の確認

```bash
# データの系譜を可視化 (どのデータがどのモデルを生成したか)
pachctl inspect pipeline training

# 特定の出力がどの入力データから生成されたか追跡
pachctl list file training@main
pachctl inspect file training@main:/model.pt

# データ系譜のグラフ表示
pachctl draw pipeline  # Mermaid グラフを生成
```

## Python SDK

```python
from python_pachyderm import Client

client = Client()  # ローカル pachd に接続

# リポジトリ一覧
for repo in client.list_repo():
    print(repo.repo.name)

# ファイルをアップロード (Python から)
with client.commit("jibun-kaisha-labels", "main") as commit:
    client.put_file_bytes(
        commit,
        "/batch_002.json",
        open("./labels/batch_002.json", "rb").read(),
    )

# パイプラインの実行結果を取得
for job in client.list_job(pipeline_name="training"):
    print(f"Job {job.job.id}: {job.state}")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 279→280社化: Pachyderm 追加',
  'PS#3 S92。Pachyderm (Git for Data/データバージョン管理/差分自動再処理/コンテナ化pipeline/データ系譜Lineage/クロス入力/Python SDK/HPE買収/GitHub 6k+/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
