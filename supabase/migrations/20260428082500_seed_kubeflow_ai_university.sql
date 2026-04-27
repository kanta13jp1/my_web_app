-- PS#3 S86: AI大学 267→268社化 — Kubeflow (Kubernetes ネイティブ ML パイプライン)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'kubeflow', 'overview',
  'Kubeflow — Kubernetes ネイティブMLパイプライン・Google主導OSS・Vertex AI Pipelines基盤 (GitHub 14k+ / 8/9)',
  $$## Kubeflow とは

**Kubeflow** は Kubernetes 上で ML ワークフローを実行するための **OSS フレームワーク**。Google が主導し、CNCF (Cloud Native Computing Foundation) でホストされる。

GitHub 14,000+ スター。Apache 2.0 ライセンス。Google Vertex AI Pipelines の基盤技術でもある。

## Kubeflow の設計思想

```
"ML を Kubernetes ネイティブに"

Kubernetes を使う理由:
  ・コンテナ化 → 再現性・移植性
  ・宣言的 API → インフラをコードで管理
  ・オートスケール → GPU をオンデマンド確保
  ・マルチクラウド → AWS/GCP/Azure/オンプレ対応

Kubeflow = ML に特化した Kubernetes 拡張
  (CRD: Custom Resource Definition として ML コンセプトを定義)
```

## Kubeflow エコシステム

| コンポーネント | 役割 |
|--------------|------|
| **Kubeflow Pipelines** | ML ワークフロー定義・実行・追跡 |
| **Katib** | Hyperparameter 最適化 (AutoML) |
| **KServe** | モデルサービング (旧 KFServing) |
| **Notebooks** | JupyterHub マネージド |
| **Training Operator** | 分散訓練 (PyTorch / TensorFlow / MPI) |

## Kubeflow Pipelines (KFP)

```python
# KFP v2 SDK でパイプライン定義

from kfp import dsl, compiler
from kfp.dsl import Dataset, Model, Output, Input

# コンポーネント定義
@dsl.component(
    base_image="python:3.11",
    packages_to_install=["pandas", "scikit-learn"],
)
def preprocess_data(
    raw_data_path: str,
    processed_data: Output[Dataset],
) -> None:
    import pandas as pd
    df = pd.read_csv(raw_data_path)
    # 前処理
    df_clean = df.dropna()
    df_clean.to_csv(processed_data.path, index=False)

@dsl.component(
    base_image="python:3.11",
    packages_to_install=["transformers", "torch"],
)
def train_model(
    processed_data: Input[Dataset],
    trained_model: Output[Model],
    epochs: int = 3,
    learning_rate: float = 2e-5,
) -> None:
    from transformers import AutoModelForSequenceClassification, Trainer
    # 訓練処理
    model = AutoModelForSequenceClassification.from_pretrained("cl-tohoku/bert-base-japanese")
    # ... 訓練 ...
    model.save_pretrained(trained_model.path)

@dsl.component(
    base_image="python:3.11",
    packages_to_install=["kserve"],
)
def deploy_model(
    trained_model: Input[Model],
    endpoint_name: str,
) -> None:
    from kserve import KServeClient, V1beta1InferenceService
    # KServe でデプロイ
    ...

# パイプライン定義
@dsl.pipeline(
    name="jibun-kaisha-ml-pipeline",
    description="JibunKaisha ML 訓練・デプロイパイプライン",
)
def ml_pipeline(
    raw_data_path: str = "gs://jibun-kaisha-ml/data/raw.csv",
    epochs: int = 3,
    lr: float = 2e-5,
):
    # ステップを繋げるだけ (DAG 自動生成)
    preprocess_task = preprocess_data(raw_data_path=raw_data_path)

    train_task = train_model(
        processed_data=preprocess_task.outputs["processed_data"],
        epochs=epochs,
        learning_rate=lr,
    )

    deploy_task = deploy_model(
        trained_model=train_task.outputs["trained_model"],
        endpoint_name="jibun-kaisha-bert-ja",
    )

# パイプラインをコンパイル
compiler.Compiler().compile(ml_pipeline, "pipeline.yaml")
```

## Katib: Hyperparameter 最適化

```yaml
# katib-experiment.yaml
apiVersion: kubeflow.org/v1beta1
kind: Experiment
metadata:
  name: jibun-kaisha-hpo
  namespace: kubeflow
spec:
  objective:
    type: minimize
    goal: 0.001
    objectiveMetricName: val-loss
  algorithm:
    algorithmName: bayesianoptimization   # Bayesian最適化
  parallelTrialCount: 4                   # 4並列で試行
  maxTrialCount: 20
  maxFailedTrialCount: 3
  parameters:
    - name: lr
      parameterType: double
      feasibleSpace:
        min: "1e-5"
        max: "1e-2"
        step: "1e-5"
    - name: batch-size
      parameterType: int
      feasibleSpace:
        list: ["16", "32", "64", "128"]
    - name: dropout
      parameterType: double
      feasibleSpace:
        min: "0.1"
        max: "0.5"
  trialTemplate:
    primaryContainerName: training-container
    trialParameters:
      - name: learningRate
        description: Learning rate
        reference: lr
    trialSpec:
      apiVersion: batch/v1
      kind: Job
      spec:
        template:
          spec:
            containers:
              - name: training-container
                image: jibun-kaisha/trainer:latest
                command:
                  - python
                  - train.py
                  - --lr=${trialParameters.learningRate}
```

## KServe: モデルサービング

```yaml
# inference-service.yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: jibun-kaisha-bert-ja
  namespace: kubeflow
spec:
  predictor:
    model:
      modelFormat:
        name: huggingface
      storageUri: "gs://jibun-kaisha-ml/models/bert-japanese-v1/"
      resources:
        limits:
          cpu: "4"
          memory: 8Gi
          nvidia.com/gpu: "1"
      minReplicas: 1
      maxReplicas: 5                     # オートスケール
```

```python
# KServe エンドポイントに推論リクエスト
import requests

response = requests.post(
    "https://jibun-kaisha-bert-ja.default.svc.cluster.local/v1/models/bert-ja:predict",
    headers={"Content-Type": "application/json"},
    json={
        "inputs": [{
            "name": "input-0",
            "shape": [1],
            "datatype": "BYTES",
            "data": ["このアプリは最高です"]
        }]
    }
)
print(response.json())
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **ML CI/CD** | KFP でモデル訓練自動化 | 毎週の再訓練を自動化 |
| **HPO** | Katib で最適パラメータ探索 | 手動チューニング不要 |
| **本番サービング** | KServe でスケーラブル API | 需要変動に自動対応 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'kubeflow', 'models',
  'Kubeflow 技術詳解 — KFP v2アーキテクチャ/Training Operator分散訓練/マルチクラウド/Argo Workflows/SageMaker比較',
  $$## KFP v2 アーキテクチャ

```
Kubeflow Pipelines v2 の内部構造:

クライアント (Python SDK)
  ↓ YAML コンパイル
Pipeline YAML
  ↓ API Server に登録
KFP API Server (Kubernetes Pod)
  ↓ スケジュール・実行管理
Argo Workflows (実行エンジン)
  ↓ 各ステップを Kubernetes Pod で実行
Worker Pods (コンテナ化されたコンポーネント)
  ↓ メタデータ記録
ML Metadata (MLMD)
  ↓ 可視化
KFP UI (Argo ダッシュボード)
```

## Training Operator: 分散訓練

```yaml
# pytorch-job.yaml (PyTorchJob CRD)
apiVersion: kubeflow.org/v1
kind: PyTorchJob
metadata:
  name: llama-distributed-training
  namespace: kubeflow
spec:
  pytorchReplicaSpecs:
    Master:
      replicas: 1
      template:
        spec:
          containers:
            - name: pytorch
              image: jibun-kaisha/llm-trainer:latest
              args:
                - --model=meta-llama/Llama-3-8B-Instruct
                - --epochs=3
                - --batch-size=8
              resources:
                limits:
                  nvidia.com/gpu: "4"      # 4 GPU / マスター
    Worker:
      replicas: 3                          # 3ワーカー × 4GPU = 12GPU 計
      template:
        spec:
          containers:
            - name: pytorch
              image: jibun-kaisha/llm-trainer:latest
              resources:
                limits:
                  nvidia.com/gpu: "4"
```

## マルチクラウド対応

```
Kubeflow の強み = クラウド非依存:

GKE (Google):
  → Vertex AI Pipelines は Kubeflow Pipelines 基盤
  → シームレス統合

EKS (AWS):
  → SageMaker Pipelines と並行利用可
  → 自己管理でコスト削減

AKS (Azure):
  → Azure ML Pipelines の基盤として使用可

オンプレミス:
  → NVIDIA DGX クラスター
  → データ主権要件のある金融・医療

→ 同じ KFP パイプラインを複数環境で実行可能
```

## Kubeflow vs SageMaker vs Vertex AI

| 比較軸 | Kubeflow | SageMaker | Vertex AI |
|--------|----------|-----------|-----------|
| **ライセンス** | OSS (Apache 2.0) | プロプライエタリ | プロプライエタリ |
| **クラウド** | マルチクラウド/オンプレ | AWS 専用 | GCP 専用 |
| **運用負荷** | 高 (K8s 知識必要) | 低 (マネージド) | 低 (マネージド) |
| **コスト** | インフラ費のみ | 高 (マネージドプレミアム) | 中 |
| **カスタマイズ** | 完全制御 | 制限あり | 制限あり |
| **採用企業** | AirBnB/Spotify/Twitter | Netflix/Pinterest | Google/Lyft |

**選択基準**:
- オンプレ/マルチクラウド必須 → Kubeflow
- AWS 中心・運用楽にしたい → SageMaker
- GCP 中心・Gemini 使いたい → Vertex AI

## CI/CD 統合パターン

```yaml
# GitHub Actions + Kubeflow Pipelines
name: ML Pipeline CI

on:
  push:
    branches: [main]
    paths: ["ml/**"]

jobs:
  compile-and-run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Compile Pipeline
        run: |
          pip install kfp
          python ml/pipeline.py --compile pipeline.yaml

      - name: Submit Pipeline Run
        env:
          KFP_ENDPOINT: ${{ secrets.KFP_ENDPOINT }}
        run: |
          python scripts/submit_pipeline.py \
            --pipeline pipeline.yaml \
            --experiment jibun-kaisha-ci \
            --run-name "ci-$(date +%Y%m%d-%H%M%S)"
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 267→268社化: Kubeflow 追加',
  'PS#3 S86。Kubeflow (KubernetesネイティブML/KFP v2 Pipelines/Katib Bayesian HPO/KServe モデルサービング/PyTorchJob分散訓練/マルチクラウド対応/CNCF/GitHub 14k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
