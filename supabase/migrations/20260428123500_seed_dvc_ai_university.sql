-- PS#3 S90: AI大学 275→276社化 — DVC (Data Version Control / Git for ML)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dvc', 'overview',
  'DVC — Git for ML・データ/モデルバージョン管理・再現性・CI/CD統合 (GitHub 13k+ / 9/9)',
  $$## DVC とは

**DVC** (Data Version Control) は**大容量データ・ML モデルを Git で管理するためのツール**。イタリア発スタートアップ Iterative.ai (2017年創業) が開発。「ML エンジニアリングに Git を持ち込む」という発想。

GitHub 13,000+ スター。Apache 2.0 ライセンス。CML (Continuous Machine Learning) と組み合わせてGHA CI/CD の中核ツールとして広く採用。

## 解決する課題

```
ML プロジェクトの再現性問題:

  問題:
  ✗ 大容量データ (GB〜TB) は git に入らない
  ✗ モデルファイル (.pt / .h5) も git に入らない
  ✗ 「あの精度が出た実験」を再現できない
  ✗ データとコードのバージョンが対応していない

  DVC の解決:
  ✓ データ/モデルは S3/GCS/Azure に保存
  ✓ git には軽量なポインタファイル (.dvc) だけ追加
  ✓ git checkout + dvc pull で完全な状態を復元
  ✓ dvc repro でパイプライン全体を再現
```

## Git + DVC の組み合わせ

```
プロジェクトのバージョン管理:

  git 管理:
    ├── src/           ← Python コード
    ├── params.yaml    ← ハイパーパラメータ
    ├── dvc.yaml       ← パイプライン定義
    ├── data/train.dvc ← データへのポインタ (軽量)
    └── models/best.dvc ← モデルへのポインタ (軽量)

  DVC リモート (実体):
    └── s3://jibun-kaisha-ml/
        ├── data/train.parquet  ← 実データ
        └── models/best.pt      ← 実モデル
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **データ管理** | S3 の学習データを DVC で追跡 | チーム全員が同じデータで実験 |
| **モデル管理** | 全 checkpoint を DVC でバージョン管理 | 任意時点のモデルを復元可能 |
| **CI/CD** | GHA + CML でモデル評価を自動化 | PR に精度変化を自動コメント |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dvc', 'api',
  'DVC 実践 — init/add/push/pull/repro/pipeline/params/metrics/CML CI/GHA統合',
  $$## インストール & セットアップ

```bash
pip install dvc
pip install dvc[s3]    # S3 リモートストレージ
pip install dvc[gcs]   # GCS リモートストレージ
pip install cml        # CML (CI/CD 統合)

# DVC を既存 git リポジトリに追加
cd jibun-kaisha-ml
git init  # (既に git がある場合は不要)
dvc init  # .dvc/ ディレクトリを作成
git add .dvc .gitignore
git commit -m "Initialize DVC"
```

## リモートストレージの設定

```bash
# S3 をリモートとして設定
dvc remote add -d storage s3://jibun-kaisha-ml/dvc-store
dvc remote modify storage region ap-northeast-1

# GCS の場合
dvc remote add -d storage gs://jibun-kaisha-ml/dvc-store

# 設定を git に保存
git add .dvc/config
git commit -m "Configure DVC remote (S3)"
```

## データのバージョン管理

```bash
# 大容量データを DVC で追跡 (git ではなく DVC が管理)
dvc add data/train.parquet
dvc add data/val.parquet

# .dvc ポインタファイルを git に追加
git add data/train.parquet.dvc data/.gitignore
git commit -m "Add training data v1.0 (DVC)"

# データを S3 にアップロード
dvc push

# 別環境で同じデータを取得
git pull
dvc pull  # S3 からデータをダウンロード
```

## パイプライン定義 (dvc.yaml)

```yaml
# dvc.yaml (パイプライン全体を定義)
stages:
  prepare:
    cmd: python src/prepare.py
    deps:
      - data/raw/input.parquet
      - src/prepare.py
    params:
      - params.yaml:
          - prepare.test_size
          - prepare.random_seed
    outs:
      - data/prepared/train.parquet
      - data/prepared/val.parquet

  train:
    cmd: python src/train.py
    deps:
      - data/prepared/train.parquet
      - src/train.py
    params:
      - params.yaml:
          - train.learning_rate
          - train.batch_size
          - train.epochs
    outs:
      - models/model.pt
    metrics:
      - metrics/train_metrics.json

  evaluate:
    cmd: python src/evaluate.py
    deps:
      - models/model.pt
      - data/prepared/val.parquet
      - src/evaluate.py
    metrics:
      - metrics/eval_metrics.json:
          cache: false   # git で直接追跡 (軽量)
```

```yaml
# params.yaml (ハイパーパラメータ管理)
prepare:
  test_size: 0.2
  random_seed: 42

train:
  learning_rate: 2e-5
  batch_size: 32
  epochs: 3
  model: "cl-tohoku/bert-base-japanese"
```

```bash
# パイプライン実行 (変更があったステージのみ再実行)
dvc repro

# メトリクス確認
dvc metrics show

# パラメータを変えて実験
dvc params diff  # パラメータ変更差分確認
```

## 実験管理 (dvc exp)

```bash
# 実験実行 (ブランチを切らずに実験)
dvc exp run --set-param train.learning_rate=1e-4

# 複数実験を並列実行
dvc exp run --set-param train.learning_rate=1e-4,1e-5,2e-5 --jobs 3

# 実験一覧を比較
dvc exp show
# ┃ Experiment      ┃ accuracy ┃ lr    ┃
# ┡━━━━━━━━━━━━━━━━━┿━━━━━━━━━━┿━━━━━━━┩
# │ workspace       │ 0.923    │ 2e-05 │
# │ exp-a1b2c       │ 0.934    │ 1e-04 │
# │ exp-d3e4f       │ 0.901    │ 1e-05 │

# 最良の実験を main ブランチに適用
dvc exp apply exp-a1b2c
git commit -m "Apply best experiment (lr=1e-4, acc=0.934)"
```

## CML + GHA: PR に評価結果を自動コメント

```yaml
# .github/workflows/ml-ci.yml
name: ML CI

on: [push, pull_request]

jobs:
  train-and-evaluate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: iterative/setup-cml@v2

      - name: Setup DVC
        run: pip install dvc[s3]

      - name: Pull Data
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: dvc pull data/prepared/

      - name: Run Pipeline
        run: dvc repro evaluate

      - name: Post Metrics to PR
        env:
          REPO_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # 評価メトリクスを PR にコメント
          cat metrics/eval_metrics.json
          cml comment create --token $REPO_TOKEN <<EOF
          ## 🤖 Model Evaluation Results

          $(dvc metrics show --md)

          $(dvc params diff HEAD~1 --md)
          EOF
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 275→276社化: DVC 追加',
  'PS#3 S90。DVC (Git for ML/データ・モデルバージョン管理/S3+GCS対応/dvc.yaml パイプライン/dvc exp 実験管理/CML+GHA CI/PRに精度自動コメント/GitHub 13k+/Apache 2.0/9/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
