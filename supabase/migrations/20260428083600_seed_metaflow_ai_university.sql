-- PS#3 S87: AI大学 268→269社化 — Metaflow (Netflix開発 Python ネイティブ ML ワークフロー)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'metaflow', 'overview',
  'Metaflow — Netflix開発Python ネイティブMLワークフロー・AWS/GCP/Azure対応・データサイエンティスト向け (GitHub 8k+ / 8/9)',
  $$## Metaflow とは

**Metaflow** は Netflix が開発した**データサイエンティスト向け ML ワークフローフレームワーク**。2019年 OSS 化。Python コードをほぼそのまま分散実行・バージョン管理できる設計が特徴。

GitHub 8,000+ スター。Apache 2.0 ライセンス。現在は **Outerbounds** (Netflix 元メンバー創業) が維持。AWS / GCP / Azure / オンプレ対応。

## Metaflow の設計哲学

```
"データサイエンティストが ML エンジニアリングを意識せずに
 スケールできるフレームワーク"

他ツールとの違い:
  Kubeflow → Kubernetes 知識必須 / DevOps 寄り
  Airflow  → ETL/データ基盤用 / ML 特化でない
  Metaflow → Python だけで書ける / データサイエンス寄り

Jupyter Notebook のコードを
  → @step で囲む
  → @conda でパッケージ管理
  → @batch / @kubernetes でクラウド実行
  という3ステップでスケール可能
```

## コアコンセプト: Flow と Step

```python
from metaflow import FlowSpec, step, card, Parameter

class JibunKaishaMLFlow(FlowSpec):
    """自分株式会社 ML パイプライン"""

    # パラメータ定義 (CLI から上書き可能)
    learning_rate = Parameter("lr", default=2e-5, type=float)
    epochs = Parameter("epochs", default=3, type=int)

    @step
    def start(self):
        """データ読み込み"""
        import pandas as pd
        self.train_df = pd.read_parquet("s3://jibun-kaisha-ml/train.parquet")
        self.next(self.preprocess)

    @step
    def preprocess(self):
        """前処理"""
        from sklearn.model_selection import train_test_split
        X = self.train_df["text"].tolist()
        y = self.train_df["label"].tolist()
        self.X_train, self.X_val, self.y_train, self.y_val = train_test_split(
            X, y, test_size=0.2, random_state=42
        )
        self.next(self.train)

    @step
    def train(self):
        """モデル訓練"""
        from transformers import AutoModelForSequenceClassification, Trainer
        self.model = AutoModelForSequenceClassification.from_pretrained(
            "cl-tohoku/bert-base-japanese"
        )
        # 訓練処理 ...
        self.val_accuracy = 0.92  # 実際の評価スコア
        self.next(self.evaluate)

    @card  # カード: 結果を自動ビジュアライズ
    @step
    def evaluate(self):
        """評価・レポート生成"""
        self.results = {
            "val_accuracy": self.val_accuracy,
            "learning_rate": self.learning_rate,
            "epochs": self.epochs,
        }
        self.next(self.end)

    @step
    def end(self):
        """完了"""
        print(f"Final accuracy: {self.results['val_accuracy']}")

if __name__ == "__main__":
    JibunKaishaMLFlow()
```

## 実行方法

```bash
# ローカル実行 (開発・デバッグ)
python flow.py run --lr 2e-5 --epochs 3

# AWS Batch で大規模実行 (GPU クラスター)
python flow.py run --with batch:image=jibun-kaisha/ml:latest,queue=gpu-queue

# Kubernetes で実行
python flow.py run --with kubernetes:image=jibun-kaisha/ml:latest,cpu=4,gpu=1

# 過去のラン結果を参照
python flow.py card view latest  # 最新ランのカード表示
```

## Metaflow の 4 大強み

| 強み | 説明 |
|------|------|
| **バージョン管理** | 全データ・コード・モデルを自動スナップショット |
| **再現性** | 任意の過去ランを完全再現できる |
| **スケール透過** | ローカル→クラウドをコード変更なしで切替 |
| **Cards** | 結果レポートを自動生成 (HTML) |

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **実験管理** | Flow で実験をバージョン管理 | 再現性確保 |
| **大規模処理** | @batch でクラウドスケール | ローカルPCの限界突破 |
| **データ検索** | Client API で過去結果を検索 | 知見の蓄積・活用 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'metaflow', 'api',
  'Metaflow 実践 — デコレータ活用/@batch/@kubernetes/@conda/並列実行/Client API/Outerbounds Platform',
  $$## 主要デコレータ一覧

```python
from metaflow import (
    FlowSpec, step,
    batch,         # AWS Batch 実行
    kubernetes,    # Kubernetes 実行
    conda,         # 環境隔離
    resources,     # リソース指定
    retry,         # 自動リトライ
    timeout,       # タイムアウト
    catch,         # エラーキャッチ
    card,          # 結果カード生成
    environment,   # 環境変数
    parallel,      # 並列分散
    Parameter,     # CLI パラメータ
    current,       # 実行時情報
)
```

## @batch: AWS Batch でスケール

```python
from metaflow import FlowSpec, step, batch, resources

class LLMTrainingFlow(FlowSpec):

    @step
    def start(self):
        self.next(self.train)

    # GPU インスタンスで訓練 (このステップのみクラウド実行)
    @batch(
        image="763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-training:2.1.0-gpu-py310-cu121-ubuntu20.04-ec2",
        queue="jibun-kaisha-gpu-queue",
    )
    @resources(
        gpu=4,                   # 4 GPU
        cpu=16,
        memory=64000,            # 64GB RAM
    )
    @retry(times=2)              # 失敗時 2回リトライ
    @timeout(hours=8)            # 8時間タイムアウト
    @step
    def train(self):
        import torch
        from transformers import AutoModelForCausalLM

        print(f"GPU count: {torch.cuda.device_count()}")  # 4
        model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-3-8B-Instruct")
        # ... 訓練 ...
        self.model_path = "s3://jibun-kaisha-ml/models/llama-3-8b-ja-v1/"
        self.next(self.end)

    @step
    def end(self):
        print(f"Model saved to: {self.model_path}")
```

## @conda: 環境隔離 (再現性保証)

```python
from metaflow import FlowSpec, step, conda

class ReproducibleFlow(FlowSpec):

    # このステップは指定パッケージで隔離実行
    @conda(
        packages={
            "numpy": "1.26.4",
            "pandas": "2.2.1",
            "scikit-learn": "1.4.1",
        },
        python="3.11.8",
    )
    @step
    def process(self):
        import numpy as np
        import pandas as pd
        # 常に同じ環境で実行されることが保証される
        self.result = np.mean([1, 2, 3])
        self.next(self.end)

    @step
    def end(self):
        print(self.result)
```

## 並列実行 (foreach)

```python
from metaflow import FlowSpec, step

class ParallelHPOFlow(FlowSpec):

    @step
    def start(self):
        # ハイパーパラメータの組み合わせを生成
        self.hyperparams = [
            {"lr": 1e-5, "dropout": 0.1},
            {"lr": 1e-4, "dropout": 0.2},
            {"lr": 1e-3, "dropout": 0.3},
            {"lr": 2e-5, "dropout": 0.15},
        ]
        # 各組み合わせを並列実行
        self.next(self.train, foreach="hyperparams")

    @step
    def train(self):
        # self.input = 各ハイパーパラメータ (並列実行)
        config = self.input
        # 訓練実行 ...
        self.val_loss = train_with_config(config)
        self.next(self.join)

    @step
    def join(self, inputs):
        # 全並列実行の結果を集約
        results = [(inp.input, inp.val_loss) for inp in inputs]
        self.best_config = min(results, key=lambda x: x[1])[0]
        print(f"Best config: {self.best_config}")
        self.next(self.end)

    @step
    def end(self):
        pass
```

## Client API: 過去ランの参照

```python
from metaflow import Flow, Run, get_metadata

# 全ランを取得
flow = Flow("JibunKaishaMLFlow")
for run in flow.runs():
    print(f"Run {run.id}: {run.created_at}")

# 最新のランのデータを取得
latest_run = Run("JibunKaishaMLFlow/latest")
print(f"Accuracy: {latest_run.data.val_accuracy}")
print(f"Model path: {latest_run.data.model_path}")

# 特定のランを再現
run = Run("JibunKaishaMLFlow/12345")
train_step = run["train"]
print(f"Training data used: {train_step.task.data.X_train[:5]}")

# 過去全ランの結果を比較
accuracies = [
    (run.id, run.data.val_accuracy)
    for run in flow.runs()
    if run.successful
]
best_run = max(accuracies, key=lambda x: x[1])
print(f"Best run: {best_run[0]} with accuracy {best_run[1]}")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 268→269社化: Metaflow 追加',
  'PS#3 S87。Metaflow (Netflix開発/Python ネイティブMLワークフロー/@batch AWS/@kubernetes/並列foreach/Client API/conda環境隔離/Card レポート/Outerbounds Platform/GitHub 8k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
