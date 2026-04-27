-- PS#3 S83: AI大学 261→262社化 — Ray / Anyscale (分散AI計算フレームワーク)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'ray', 'overview',
  'Ray / Anyscale — 分散AI計算・LLMサービング・ハイパーパラメータ最適化の統一フレームワーク (GitHub 33k+ / 9/9)',
  $$## Ray とは

**Ray** は UC Berkeley RISELab 発の**分散コンピューティングフレームワーク**。Python コードを最小限の変更でスケールアウトできる。商用版は **Anyscale** が提供。

GitHub 33,000+ スター。OpenAI・Google・Microsoft・Uber・Spotify が本番採用。

## Ray のコア哲学

```
"普通の Python コードをそのまま分散実行できる"

Before (分散化が困難):
  for i in range(1000):
      result = heavy_compute(i)  # 直列実行・1コアのみ

After (Ray で自動分散):
  @ray.remote
  def heavy_compute(i): ...

  futures = [heavy_compute.remote(i) for i in range(1000)]
  results = ray.get(futures)  # 全コア・全マシンで並列実行
```

## Ray エコシステム (5大ライブラリ)

| ライブラリ | 用途 |
|-----------|------|
| **Ray Core** | 分散タスク・アクター・オブジェクトストア |
| **Ray Train** | 分散モデル訓練 (PyTorch / HuggingFace / XGBoost) |
| **Ray Tune** | 分散 Hyperparameter 最適化 |
| **Ray Serve** | LLM / モデルの本番サービング |
| **Ray Data** | 大規模データ前処理パイプライン |

## LLM サービング (Ray Serve)

```python
# vLLM + Ray Serve でスケーラブルな LLM API
from ray import serve
from vllm import LLM, SamplingParams

@serve.deployment(
    num_replicas=2,
    ray_actor_options={"num_gpus": 1},  # 各レプリカが GPU 1 枚
)
class LLMServer:
    def __init__(self):
        self.llm = LLM(model="meta-llama/Llama-3-8B-Instruct")

    async def __call__(self, request):
        prompt = await request.json()
        outputs = self.llm.generate(
            [prompt["text"]],
            SamplingParams(temperature=0.7, max_tokens=512),
        )
        return {"response": outputs[0].outputs[0].text}

serve.run(LLMServer.bind())
# → 自動ロードバランシング・オートスケール
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **ファインチューニング分散化** | Ray Train で GPU 複数活用 | 訓練時間 1/N 短縮 |
| **LLM API** | Ray Serve で自社 LLM 提供 | コスト最適化 |
| **バッチ処理** | Ray Data で大規模前処理 | スループット向上 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'ray', 'api',
  'Ray 実践 — remote/Actor/Ray Train分散訓練/Ray Tune Sweep/Ray Serve LLMサービング/vLLM統合',
  $$## インストール

```bash
# 基本
pip install ray

# 全ライブラリ
pip install "ray[default,train,tune,serve,data]"

# LLM サービング
pip install "ray[serve]" vllm
```

## Ray Core: 基本的な分散タスク

```python
import ray

ray.init()  # ローカル or クラスターに接続

# @ray.remote で関数を分散タスク化
@ray.remote
def process_document(doc_id: str) -> dict:
    # 重い処理 (PDF解析 / 埋め込み生成 / etc.)
    text = extract_text(doc_id)
    embedding = generate_embedding(text)
    return {"id": doc_id, "embedding": embedding}

# 1000件を並列実行
doc_ids = [f"doc_{i}" for i in range(1000)]
futures = [process_document.remote(doc_id) for doc_id in doc_ids]
results = ray.get(futures)  # すべての完了を待機

# リソース指定
@ray.remote(num_cpus=2, num_gpus=0.5, memory=4 * 1024**3)
def gpu_inference(text: str) -> str:
    ...
```

## Ray Actor: ステートフルな分散オブジェクト

```python
import ray

@ray.remote
class EmbeddingCache:
    def __init__(self, model_name: str):
        from sentence_transformers import SentenceTransformer
        self.model = SentenceTransformer(model_name)
        self.cache = {}

    def embed(self, text: str) -> list:
        if text not in self.cache:
            self.cache[text] = self.model.encode(text).tolist()
        return self.cache[text]

    def cache_size(self) -> int:
        return len(self.cache)

# アクターを起動 (プロセスとして常駐)
cache_actor = EmbeddingCache.remote("intfloat/multilingual-e5-large")

# 複数ワーカーから共有キャッシュにアクセス
futures = [cache_actor.embed.remote(text) for text in texts]
embeddings = ray.get(futures)
```

## Ray Train: 分散モデル訓練

```python
import ray
from ray.train.torch import TorchTrainer
from ray.train import ScalingConfig, RunConfig

def train_func(config: dict):
    import torch
    from transformers import AutoModelForSequenceClassification, Trainer, TrainingArguments

    # Ray Train が自動でプロセスグループ初期化
    model = AutoModelForSequenceClassification.from_pretrained(
        config["model_name"],
        num_labels=config["num_labels"],
    )

    training_args = TrainingArguments(
        output_dir="./output",
        num_train_epochs=config["epochs"],
        per_device_train_batch_size=config["batch_size"],
        learning_rate=config["lr"],
        report_to="wandb",
    )

    trainer = Trainer(model=model, args=training_args, ...)
    trainer.train()

# GPU 4台で分散訓練
trainer = TorchTrainer(
    train_func,
    train_loop_config={
        "model_name": "cl-tohoku/bert-base-japanese",
        "num_labels": 3,
        "epochs": 5,
        "batch_size": 16,
        "lr": 2e-5,
    },
    scaling_config=ScalingConfig(
        num_workers=4,      # 4ワーカー
        use_gpu=True,       # 各ワーカーに GPU 1枚
        resources_per_worker={"GPU": 1, "CPU": 4},
    ),
    run_config=RunConfig(name="bert-japanese-finetune"),
)

result = trainer.fit()
print(f"Best checkpoint: {result.checkpoint}")
```

## Ray Tune: 分散 Hyperparameter 最適化

```python
from ray import tune
from ray.tune.schedulers import ASHAScheduler
from ray.tune.search.optuna import OptunaSearch

def trainable(config: dict):
    model = build_model(
        hidden_size=config["hidden_size"],
        num_layers=config["num_layers"],
        dropout=config["dropout"],
    )
    for epoch in range(10):
        loss = train_epoch(model, config["lr"])
        tune.report({"val_loss": loss, "epoch": epoch})

# Optuna + ASHA でスマートな探索
tuner = tune.Tuner(
    tune.with_resources(trainable, {"gpu": 1}),
    param_space={
        "lr": tune.loguniform(1e-5, 1e-2),
        "hidden_size": tune.choice([256, 512, 1024]),
        "num_layers": tune.randint(2, 8),
        "dropout": tune.uniform(0.1, 0.5),
    },
    tune_config=tune.TuneConfig(
        search_alg=OptunaSearch(),     # Bayesian 最適化
        scheduler=ASHAScheduler(       # 悪い試行を早期打ち切り
            max_t=10,
            grace_period=3,
        ),
        num_samples=50,                # 50回試行
        metric="val_loss",
        mode="min",
    ),
)

results = tuner.fit()
best_config = results.get_best_result().config
print(f"Best config: {best_config}")
```

## Ray Serve: LLM サービング

```python
from ray import serve
from fastapi import FastAPI
import ray

app = FastAPI()

@serve.deployment(
    num_replicas=3,                          # 3レプリカで負荷分散
    ray_actor_options={"num_gpus": 1},       # 各レプリカに GPU 1枚
    autoscaling_config={                     # オートスケール設定
        "min_replicas": 1,
        "max_replicas": 10,
        "target_num_ongoing_requests_per_replica": 5,
    },
)
@serve.ingress(app)
class JibunKaishaLLM:
    def __init__(self):
        from vllm import AsyncLLMEngine, SamplingParams
        self.engine = AsyncLLMEngine.from_engine_args(
            engine_args=AsyncEngineArgs(
                model="meta-llama/Llama-3-8B-Instruct",
                gpu_memory_utilization=0.85,
                max_model_len=8192,
            )
        )

    @app.post("/chat")
    async def chat(self, request: dict):
        outputs = await self.engine.generate(
            request["prompt"],
            SamplingParams(temperature=0.7, max_tokens=512),
            request_id=request.get("id", ""),
        )
        async for output in outputs:
            if output.finished:
                return {"response": output.outputs[0].text}

# デプロイ
serve.run(JibunKaishaLLM.bind(), host="0.0.0.0", port=8000)
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'ray', 'models',
  'Ray 技術詳解 — アーキテクチャ(GCS/Raylet/Worker)/Anyscale/Ray Data/コスト最適化/クラスター管理',
  $$## Ray アーキテクチャ

```
Ray クラスター構成:

Head Node:
  ├── GCS (Global Control Store) — クラスター状態管理
  ├── Raylet — タスクスケジューリング
  └── Autoscaler — ノード追加/削除

Worker Nodes (複数):
  ├── Raylet — ローカルスケジューリング
  ├── Worker Processes — 実際のタスク実行
  └── Object Store (Plasma) — 共有メモリ (ゼロコピー)

Object Store の仕組み:
  Worker A → put(large_tensor) → Plasma (共有メモリ)
  Worker B → get(object_ref)   → Plasma から直接読む
  → コピー不要 → 高速なデータ共有
```

## Ray Data: 大規模データパイプライン

```python
import ray

# 大規模データセット処理 (分散)
ds = ray.data.read_parquet("s3://jibun-kaisha/training-data/")

# 並列前処理
def preprocess(batch: dict) -> dict:
    # テキスト正規化・トークナイズ
    texts = batch["text"]
    tokens = tokenizer(texts, truncation=True, max_length=512, padding=True)
    return {"input_ids": tokens["input_ids"], "label": batch["label"]}

ds = ds.map_batches(
    preprocess,
    batch_size=256,
    num_cpus=2,              # バッチごとに 2 CPU
    concurrency=8,           # 8並列
)

# HuggingFace Dataset に変換
hf_dataset = ds.to_huggingface()
```

## Anyscale (商用版 Ray)

```
Anyscale = Ray のフルマネージドサービス:

機能:
  ・Ray クラスターのプロビジョニング自動化
  ・Anyscale Jobs (Ray Script をジョブとして実行)
  ・Anyscale Services (Ray Serve の本番展開)
  ・統合ダッシュボード・監視・ログ

料金体系:
  ・使用リソース (CPU/GPU) + Anyscale プラットフォーム料金
  ・AWS/GCP/Azure 対応

OSS Ray vs Anyscale:
  OSS → セルフホスト / Kubernetes / コスト最小
  Anyscale → マネージド / 運用負荷ゼロ / エンタープライズサポート
```

## コスト最適化戦略

```python
# スポットインスタンス活用 (AWS)
from ray.autoscaler.sdk import request_resources

# 訓練ノードはスポット (70%コスト削減)
# Head Node はオンデマンド (安定性確保)
cluster_config = {
    "available_node_types": {
        "head": {
            "node_config": {
                "InstanceType": "m5.xlarge",
                "SpotOptions": None,           # オンデマンド
            },
        },
        "gpu_worker": {
            "node_config": {
                "InstanceType": "g4dn.xlarge",
                "SpotOptions": {
                    "SpotInstanceType": "one-time",
                    "MaxPrice": "0.4",         # 上限価格設定
                },
            },
            "min_workers": 0,
            "max_workers": 10,                 # 最大10台まで自動スケール
        },
    },
}
```

## Ray vs 競合比較

| ツール | 強み | 弱み |
|--------|------|------|
| **Ray** | Python フレンドリー / エコシステム充実 / LLM サービング | 学習コスト高い |
| **Dask** | Pandas 互換 / データ処理特化 | ML/LLM 機能弱い |
| **Spark** | エンタープライズ実績 / SQL 統合 | Python より Java 寄り |
| **Celery** | シンプル / タスクキュー | 大規模 ML には不向き |
| **Kubernetes** | コンテナ標準 / エコシステム | ML ワークロードに抽象度高すぎ |

**Ray の優位性**: ML/LLM ワークロードに最適化された唯一のフレームワーク。

## 自分株式会社 導入ロードマップ

```
Phase 1: Ray Core 試用 (1週間)
  - ローカルで ray.init()
  - 既存の重いバッチ処理を @ray.remote で並列化
  - 効果測定 (処理時間比較)

Phase 2: Ray Tune 導入 (2週間)
  - LLM ファインチューニングの Sweep 自動化
  - wandb と連携してリアルタイム可視化

Phase 3: Ray Serve 検討 (1ヶ月)
  - 自社 LLM API の提供が必要になった時点で導入
  - vLLM + Ray Serve でコスト最適化
```$$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 261→262社化: Ray / Anyscale 追加',
  'PS#3 S83。Ray / Anyscale (UC Berkeley RISELab/分散AI計算/Ray Train+Tune+Serve+Data/vLLM統合/HuggingFace/PyTorch/Optuna Bayesian最適化/オートスケール/スポットインスタンス/GitHub 33k+/Apache 2.0/9/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
