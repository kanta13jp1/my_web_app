-- PS#3 S85: AI大学 264→265社化 — Amazon SageMaker (AWS マネージドMLプラットフォーム)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'amazon-sagemaker', 'overview',
  'Amazon SageMaker — AWSマネージドML基盤・JumpStart・HyperPod・LLMデプロイの業界標準 (8/9)',
  $$## Amazon SageMaker とは

**Amazon SageMaker** は AWS が提供する**フルマネージド機械学習プラットフォーム**。データ準備・モデル訓練・チューニング・デプロイ・監視まで ML ライフサイクル全体をカバー。

2017年 re:Invent で発表。世界最大規模の ML インフラを提供。数万社以上が本番採用。

## SageMaker の全体像

```
SageMaker エコシステム (主要コンポーネント):

データ準備:
  SageMaker Data Wrangler   → ノーコードのデータ前処理
  SageMaker Feature Store   → 特徴量の中央管理・再利用

モデル開発:
  SageMaker Studio          → フルマネージド IDE (JupyterLab 互換)
  SageMaker Experiments     → 実験管理 (wandb に相当)
  SageMaker Debugger        → 訓練の内部状態デバッグ

LLM 特化:
  SageMaker JumpStart       → 300+ 基盤モデルのワンクリックデプロイ
  SageMaker HyperPod        → 大規模 LLM 訓練クラスター (Fault-tolerant)
  SageMaker Inference       → 推論エンドポイント (リアルタイム / バッチ)

AutoML:
  SageMaker Autopilot       → 自動 ML (特徴エンジニアリング〜モデル選択)
  SageMaker Canvas          → ノーコード ML (プログラミング不要)

MLOps:
  SageMaker Pipelines       → ML ワークフロー自動化
  SageMaker Model Registry  → モデルバージョン管理・承認フロー
  SageMaker Model Monitor   → 本番でのドリフト検出・品質監視
```

## SageMaker JumpStart (LLM即時デプロイ)

```
JumpStart で利用可能な主要 LLM (2024年):
  ・Llama 3 / 3.1 / 3.2 (Meta)
  ・Mistral 7B / Mixtral 8x7B
  ・Falcon 40B / 180B
  ・Stable Diffusion XL (画像生成)
  ・Titan Text / Embeddings (Amazon)
  ・Claude 3 (Anthropic) ← Amazon Bedrock 経由

コンソールから3クリック → 本番 API エンドポイント
```

## SageMaker HyperPod (大規模 LLM 訓練)

```
HyperPod の特徴:
  ・数千 GPU クラスターの自動管理
  ・Fault-tolerance: ノード障害時に自動復旧 (訓練継続)
  ・EFA (Elastic Fabric Adapter) で GPU 間超高速通信
  ・Slurm / Kubernetes 対応

採用例:
  ・Llama 2 の訓練 (Meta × AWS)
  ・数千億パラメータモデルの訓練
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **LLM API** | JumpStart でLlama日本語版デプロイ | OpenAI代替コスト削減 |
| **バッチ推論** | Transform Job で大量テキスト処理 | スループット最大化 |
| **モデル監視** | Model Monitor でドリフト検出 | 品質劣化を早期発見 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'amazon-sagemaker', 'api',
  'SageMaker 実践 — Training Job/リアルタイムエンドポイント/JumpStart/Pipelines/HuggingFace統合',
  $$## インストール

```bash
pip install sagemaker boto3

# AWS 認証
aws configure
# または IAM Role (EC2/ECS/Lambda 上では自動)
```

## Training Job: マネージド分散訓練

```python
import sagemaker
from sagemaker.huggingface import HuggingFace

# セッション初期化
sess = sagemaker.Session()
role = sagemaker.get_execution_role()  # IAM Role ARN

# HuggingFace Estimator 定義
huggingface_estimator = HuggingFace(
    entry_point="train.py",            # 訓練スクリプト
    source_dir="./scripts",            # スクリプトのディレクトリ
    instance_type="ml.p3.16xlarge",   # 8x V100 GPU インスタンス
    instance_count=4,                  # 4インスタンス = 32 GPU
    role=role,
    transformers_version="4.36",
    pytorch_version="2.1",
    py_version="py310",
    hyperparameters={
        "model_name_or_path": "meta-llama/Llama-3-8B",
        "num_train_epochs": 3,
        "per_device_train_batch_size": 4,
        "learning_rate": 2e-5,
        "output_dir": "/opt/ml/model",
    },
    distribution={
        "torch_distributed": {"enabled": True}  # 自動分散訓練
    },
    metric_definitions=[
        {"Name": "train:loss", "Regex": "train_loss=(\\S+)"},
        {"Name": "eval:loss", "Regex": "eval_loss=(\\S+)"},
    ],
    use_spot_instances=True,           # スポットインスタンスで70%コスト削減
    max_wait=7200,
)

# 訓練開始
huggingface_estimator.fit({
    "train": "s3://jibun-kaisha-ml/train/",
    "test": "s3://jibun-kaisha-ml/test/",
})
```

## リアルタイム推論エンドポイント

```python
from sagemaker.huggingface import HuggingFaceModel
import json

# デプロイ済みモデルから Endpoint 作成
huggingface_model = HuggingFaceModel(
    model_data="s3://jibun-kaisha-ml/model/model.tar.gz",
    role=role,
    transformers_version="4.36",
    pytorch_version="2.1",
    py_version="py310",
)

# エンドポイントデプロイ (本番 API)
predictor = huggingface_model.deploy(
    initial_instance_count=2,
    instance_type="ml.g4dn.xlarge",   # T4 GPU
    endpoint_name="jibun-kaisha-llm-prod",
)

# 推論
response = predictor.predict({
    "inputs": "自分株式会社のAI機能を教えてください",
    "parameters": {
        "max_new_tokens": 256,
        "temperature": 0.7,
        "do_sample": True,
    }
})

print(response[0]["generated_text"])

# boto3 でも呼び出し可能
import boto3
client = boto3.client("sagemaker-runtime", region_name="ap-northeast-1")
response = client.invoke_endpoint(
    EndpointName="jibun-kaisha-llm-prod",
    ContentType="application/json",
    Body=json.dumps({"inputs": "こんにちは"}),
)
```

## JumpStart: 基盤モデルのワンクリックデプロイ

```python
from sagemaker.jumpstart.model import JumpStartModel

# Llama 3 8B をワンクリックデプロイ
model = JumpStartModel(
    model_id="meta-textgeneration-llama-3-8b-instruct",
    model_version="*",               # 最新バージョン自動選択
    region_name="us-east-1",
)

predictor = model.deploy(
    accept_eula=True,                # ライセンス同意
    instance_type="ml.g5.2xlarge",  # A10G GPU
)

# OpenAI 互換フォーマット (Llama の場合)
response = predictor.predict({
    "inputs": "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n自分株式会社について教えて<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n",
    "parameters": {"max_new_tokens": 512, "temperature": 0.7},
})
```

## SageMaker Pipelines: ML ワークフロー自動化

```python
from sagemaker.workflow.pipeline import Pipeline
from sagemaker.workflow.steps import ProcessingStep, TrainingStep
from sagemaker.workflow.model_step import ModelStep
from sagemaker.sklearn.processing import SKLearnProcessor

# Step 1: データ前処理
sklearn_processor = SKLearnProcessor(
    framework_version="1.3-1",
    instance_type="ml.m5.xlarge",
    instance_count=1,
    role=role,
)

processing_step = ProcessingStep(
    name="PreprocessData",
    processor=sklearn_processor,
    inputs=[ProcessingInput(source="s3://jibun-kaisha-ml/raw/", destination="/opt/ml/processing/input")],
    outputs=[ProcessingOutput(output_name="train", source="/opt/ml/processing/output/train")],
    code="preprocessing.py",
)

# Step 2: 訓練
training_step = TrainingStep(
    name="TrainModel",
    estimator=huggingface_estimator,
    inputs={"train": processing_step.properties.ProcessingOutputConfig.Outputs["train"].S3Output.S3Uri},
)

# パイプライン定義
pipeline = Pipeline(
    name="JibunKaishaMLPipeline",
    steps=[processing_step, training_step],
    sagemaker_session=sess,
)

pipeline.upsert(role_arn=role)

# 実行 (スケジュール・手動・CI/CD から起動可)
execution = pipeline.start()
execution.wait()
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'amazon-sagemaker', 'models',
  'SageMaker 技術詳解 — コスト最適化/Model Monitor/Autopilot/マルチモデルエンドポイント/Bedrock比較',
  $$## コスト最適化戦略

```
SageMaker のコスト最適化:

1. スポットインスタンス (Training):
   → 最大 90% 割引 (中断されても自動再開)
   → use_spot_instances=True + checkpoint 設定

2. Savings Plans:
   → 1〜3年コミット → 40〜60% 割引
   → 安定した本番ワークロードに最適

3. マルチモデルエンドポイント (MME):
   → 1インスタンスで複数モデルをホスト
   → モデルをオンデマンドでロード/アンロード
   → コスト 1/N に削減可能

4. 推論コンパイラ (Neo):
   → SageMaker Neo でモデルを最適化
   → ハードウェア特化コンパイル → 推論速度 2〜3倍

5. Serverless Inference:
   → アイドル時コスト 0
   → コールドスタート ~1秒
   → 低頻度の非クリティカル API に最適
```

## マルチモデルエンドポイント (MME)

```python
from sagemaker.multidatamodel import MultiDataModel

# 1エンドポイントで複数モデルをホスト
mme = MultiDataModel(
    name="jibun-kaisha-multi",
    model_data_prefix="s3://jibun-kaisha-ml/models/",
    model=base_model,                      # ベースモデル設定
)

predictor = mme.deploy(
    initial_instance_count=1,
    instance_type="ml.g4dn.xlarge",
)

# モデルを追加 (再デプロイ不要)
mme.add_model(model_data_source="s3://jibun-kaisha-ml/models/llama-ja.tar.gz")
mme.add_model(model_data_source="s3://jibun-kaisha-ml/models/mistral-ja.tar.gz")

# 推論時にターゲットモデルを指定
response_llama = predictor.predict(
    data={"inputs": "こんにちは"},
    target_model="llama-ja.tar.gz",   # 動的にモデル切替
)
response_mistral = predictor.predict(
    data={"inputs": "こんにちは"},
    target_model="mistral-ja.tar.gz",
)
```

## Model Monitor: 本番品質監視

```python
from sagemaker.model_monitor import DataCaptureConfig, ModelMonitor

# データキャプチャ設定 (推論入出力を S3 に記録)
data_capture_config = DataCaptureConfig(
    enable_capture=True,
    sampling_percentage=20,           # 20% のリクエストをサンプリング
    destination_s3_uri="s3://jibun-kaisha-ml/captures/",
    capture_options=["REQUEST", "RESPONSE"],
)

# エンドポイントでキャプチャ有効化
predictor = model.deploy(
    data_capture_config=data_capture_config,
    ...
)

# モデルモニタリングジョブ設定
monitor = ModelMonitor(
    role=role,
    instance_count=1,
    instance_type="ml.m5.xlarge",
)

monitor.create_monitoring_schedule(
    monitor_schedule_name="jibun-kaisha-monitor",
    endpoint_input=predictor.endpoint_name,
    statistics="s3://jibun-kaisha-ml/baseline/statistics.json",
    constraints="s3://jibun-kaisha-ml/baseline/constraints.json",
    schedule_cron_expression="cron(0 * ? * * *)",  # 毎時チェック
)
# → データドリフト・モデル品質劣化を自動検出 → CloudWatch アラート
```

## SageMaker vs Amazon Bedrock

```
SageMaker:
  ✓ 自前モデルの訓練・デプロイ
  ✓ HuggingFace / OSS モデル完全制御
  ✓ カスタムファインチューニング
  ✓ データを AWS 内に閉じる (GDPR/HIPAA)
  ✗ 運用複雑・インフラ知識要

Bedrock:
  ✓ Claude / Titan / Llama / Mistral 等をAPI一発
  ✓ インフラ管理不要
  ✓ RAG (Knowledge Base) / Agent 組み込み
  ✗ モデルカスタマイズ限定
  ✗ クローズドモデルのみ

選択基準:
  OSS/自社モデル訓練・フル制御 → SageMaker
  迅速なAPI統合・マネージド → Bedrock
```$$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 264→265社化: Amazon SageMaker 追加',
  'PS#3 S85。Amazon SageMaker (AWSマネージドML/JumpStart 300+基盤モデル/HyperPod大規模LLM訓練/Pipelines/Model Monitor/マルチモデルエンドポイント/スポット90%割引/HuggingFace統合/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
