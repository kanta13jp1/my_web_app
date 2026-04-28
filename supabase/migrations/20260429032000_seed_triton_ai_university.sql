-- PS#3 S109: AI大学 313→314社化 — NVIDIA Triton Inference Server (エンタープライズML推論)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'triton-inference-server', 'overview',
  'NVIDIA Triton Inference Server — エンタープライズML推論基盤・マルチフレームワーク対応 (GitHub 8k+ / 9/9)',
  $$## Triton Inference Server とは

**NVIDIA Triton Inference Server** は **NVIDIA が開発・維持するエンタープライズグレードの AI 推論サーバー**。GitHub 8,000+ スター。PyTorch / TensorFlow / TensorRT / ONNX / OpenVINO など **あらゆる ML フレームワークのモデルを単一サーバーで提供** できる。

Google Cloud / AWS / Azure の ML サービングインフラで内部的に使われており、**大規模本番 ML システムのデファクトスタンダード**。HTTP/gRPC 両対応、動的バッチング、モデルアンサンブルなど本番に必要な機能が全て揃っている。

## Triton の主要機能

```
マルチフレームワーク対応:
  ・TensorRT        — NVIDIA GPU 最適化 (最高パフォーマンス)
  ・PyTorch TorchScript — PyTorch モデルそのまま
  ・TensorFlow SavedModel — TF2 モデル
  ・ONNX Runtime    — フレームワーク非依存
  ・OpenVINO        — Intel CPU 最適化
  ・Python Backend  — 任意の Python コード
  ・RAPIDS FIL      — XGBoost / LightGBM

高性能推論:
  ・Dynamic Batching — リクエストを自動でバッチ化 (GPU 効率最大化)
  ・Concurrent Model Execution — 複数モデルを同時実行
  ・Model Instances — 同一モデルを複数インスタンスで並列
  ・Pinned Memory — CPU/GPU 間データ転送最適化

マルチGPU / マルチノード:
  ・Tensor Parallelism (TensorRT-LLM 連携)
  ・Model Parallelism
  ・Kubernetes + Helm Chart 対応

API:
  ・HTTP/REST (KFServing V2 互換)
  ・gRPC (高スループット向け)
  ・C++ / Python クライアントライブラリ
```

## Triton + TensorRT-LLM (LLM 特化)

```
TensorRT-LLM = NVIDIA の LLM 最適化ライブラリ:
  ・FP8/INT8/INT4 量子化 (H100/A100 最適化)
  ・In-flight Batching (Continuous Batching 相当)
  ・Paged KV Cache
  ・Tensor Parallelism (マルチGPU)
  ・Flash Attention v2

対応モデル:
  ・LLaMA 3.1 / 3.2 (Meta)
  ・Mistral / Mixtral
  ・Falcon / GPT-NeoX
  ・GPT-J / OPT
  ・Gemma / Phi-3

vLLM との比較:
  ・vLLM: 使いやすさ・HuggingFace互換を優先
  ・Triton+TRT-LLM: 最大パフォーマンスを優先 (複雑な設定)
  ・GPU H100: Triton+TRT-LLM の方が 20-30% 高スループット
```

## モデルリポジトリ構造

```
models/
  horse-detector/
    config.pbtxt        ← モデル設定
    1/
      model.plan        ← TensorRT エンジン
  sentiment-classifier/
    config.pbtxt
    1/
      model.onnx        ← ONNX モデル
  ensemble-pipeline/
    config.pbtxt        ← 複数モデルの連結
    1/
      (ensemble に実ファイル不要)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬CV推論** | 馬検出モデル (YOLO → TensorRT) を Triton で本番サービング | GPU 効率最大化・低レイテンシ |
| **マルチモデル管理** | 競馬予想モデル複数バージョンを同時管理 | A/B テスト・カナリアデプロイ |
| **スケーリング** | K8s + Triton で自動スケール | ピーク時 (レース当日) のトラフィック対応 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'triton-inference-server', 'api',
  'Triton 実践 — Docker起動/モデル設定/Python Client/Dynamic Batching/TensorRT/K8s/Prometheus監視',
  $$## Docker で起動

```bash
# NGC カタログから公式イメージを取得
docker pull nvcr.io/nvidia/tritonserver:24.01-py3

# モデルリポジトリを用意して起動
docker run --gpus=all \
  -p 8000:8000 \   # HTTP
  -p 8001:8001 \   # gRPC
  -p 8002:8002 \   # Metrics (Prometheus)
  -v $PWD/models:/models \
  nvcr.io/nvidia/tritonserver:24.01-py3 \
  tritonserver --model-repository=/models

# ヘルスチェック
curl http://localhost:8000/v2/health/ready
# → {"ready": true}

# モデル一覧
curl http://localhost:8000/v2/models
```

## モデル設定ファイル (config.pbtxt)

```protobuf
# models/sentiment-classifier/config.pbtxt
name: "sentiment-classifier"
backend: "onnxruntime"
max_batch_size: 32

input [
  {
    name: "input_ids"
    data_type: TYPE_INT64
    dims: [ 128 ]         # シーケンス長
  },
  {
    name: "attention_mask"
    data_type: TYPE_INT64
    dims: [ 128 ]
  }
]

output [
  {
    name: "logits"
    data_type: TYPE_FP32
    dims: [ 3 ]           # ネガティブ/ニュートラル/ポジティブ
  }
]

# 動的バッチング設定
dynamic_batching {
  preferred_batch_size: [ 4, 8, 16 ]
  max_queue_delay_microseconds: 5000  # 最大5ms待機してバッチ化
}

# 並列実行インスタンス数
instance_group [
  {
    count: 2              # GPU を2インスタンスで並列実行
    kind: KIND_GPU
    gpus: [ 0 ]
  }
]
```

## Python クライアント

```python
import tritonclient.http as httpclient
import numpy as np

# Triton サーバーに接続
client = httpclient.InferenceServerClient(url="localhost:8000")

# サーバー & モデルの状態確認
print(f"Server ready: {client.is_server_ready()}")
print(f"Model ready: {client.is_model_ready('sentiment-classifier')}")

# モデルメタデータ取得
metadata = client.get_model_metadata("sentiment-classifier")
print(f"Inputs: {[inp['name'] for inp in metadata['inputs']]}")

# 推論リクエスト
def infer_sentiment(texts: list[str], tokenizer) -> np.ndarray:
    # トークナイズ
    encoded = tokenizer(
        texts,
        padding="max_length",
        max_length=128,
        truncation=True,
        return_tensors="np",
    )

    # 入力テンソル準備
    inputs = [
        httpclient.InferInput("input_ids", encoded["input_ids"].shape, "INT64"),
        httpclient.InferInput("attention_mask", encoded["attention_mask"].shape, "INT64"),
    ]
    inputs[0].set_data_from_numpy(encoded["input_ids"])
    inputs[1].set_data_from_numpy(encoded["attention_mask"])

    # 出力テンソル定義
    outputs = [httpclient.InferRequestedOutput("logits")]

    # 推論実行
    response = client.infer("sentiment-classifier", inputs, outputs=outputs)
    logits = response.as_numpy("logits")

    return np.argmax(logits, axis=-1)  # 0=ネガ, 1=中立, 2=ポジ


# バッチ推論
from transformers import AutoTokenizer

tokenizer = AutoTokenizer.from_pretrained("cl-tohoku/bert-base-japanese")
texts = [
    "シャフリヤールが圧勝！完璧なレースだった",
    "本命が外れた...次こそ当てたい",
    "今日のレースは接戦だった",
]

labels = infer_sentiment(texts, tokenizer)
label_map = {0: "ネガティブ", 1: "ニュートラル", 2: "ポジティブ"}
for text, label in zip(texts, labels):
    print(f"  [{label_map[label]}] {text}")
```

## gRPC クライアント (高スループット)

```python
import tritonclient.grpc as grpcclient
import numpy as np

# gRPC クライアント (大量リクエスト時に HTTP より高効率)
client = grpcclient.InferenceServerClient(url="localhost:8001")

def batch_infer(batch_data: np.ndarray) -> np.ndarray:
    inputs = [grpcclient.InferInput("images", batch_data.shape, "FP32")]
    inputs[0].set_data_from_numpy(batch_data)
    outputs = [grpcclient.InferRequestedOutput("detections")]

    response = client.infer("horse-detector", inputs, outputs=outputs)
    return response.as_numpy("detections")

# 非同期バッチ推論
import asyncio
import tritonclient.grpc.aio as grpcclient_aio

async def async_infer(client, data):
    inputs = [grpcclient_aio.InferInput("images", data.shape, "FP32")]
    inputs[0].set_data_from_numpy(data)
    outputs = [grpcclient_aio.InferRequestedOutput("detections")]
    return await client.infer("horse-detector", inputs, outputs=outputs)
```

## Kubernetes デプロイ (Helm Chart)

```yaml
# helm install triton nvcr.io/nvidia/triton-inference-server-helm
# values.yaml
image:
  repository: nvcr.io/nvidia/tritonserver
  tag: "24.01-py3"

resources:
  limits:
    nvidia.com/gpu: 1
  requests:
    nvidia.com/gpu: 1
    memory: "8Gi"
    cpu: "4"

modelRepository:
  storageType: s3
  s3:
    bucket: my-models-bucket
    region: ap-northeast-1

service:
  type: LoadBalancer
  httpPort: 8000
  grpcPort: 8001
  metricsPort: 8002

autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 4
  targetGPUUtilization: 70
```

## Prometheus + Grafana 監視

```yaml
# Triton はデフォルトで Prometheus メトリクスを /metrics で公開
# prometheus.yml
scrape_configs:
  - job_name: triton
    static_configs:
      - targets: ["triton-service:8002"]
```

```python
# 主要メトリクス
# nv_inference_request_success_total   — 成功推論数
# nv_inference_request_failure_total   — 失敗推論数
# nv_inference_queue_duration_us       — キュー待機時間
# nv_inference_compute_infer_duration_us — 推論実行時間
# nv_gpu_utilization                   — GPU 使用率
# nv_gpu_memory_used_bytes             — GPU メモリ使用量
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 313→314社化: NVIDIA Triton Inference Server 追加',
  'PS#3 S109。Triton Inference Server (NVIDIA/TensorRT+PyTorch+ONNX+TF/Dynamic Batching/TensorRT-LLM連携/gRPC+HTTP/K8s Helm/Prometheus監視/マルチGPU/Python+C++ Client/GitHub 8k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
