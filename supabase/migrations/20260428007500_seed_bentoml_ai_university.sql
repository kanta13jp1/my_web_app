-- PS#3 S84: AI大学 263→264社化 — BentoML (本番LLMサービング / MLOpsデプロイ)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'bentoml', 'overview',
  'BentoML — 本番LLMサービング・モデルデプロイ自動化・OpenLLM統合 (GitHub 7k+ / 8/9)',
  $$## BentoML とは

**BentoML** は ML モデル・LLM を**本番環境に高速デプロイ**するための OSS フレームワーク。モデルを "Bento"（お弁当）としてパッケージ化し、API サーバー・Docker・Kubernetes・クラウドに一貫してデプロイできる。

GitHub 7,000+ スター。Apache 2.0 ライセンス。2021年創業、$30M 調達。

## BentoML の設計思想

```
"モデルをどこへでも持ち運べるお弁当箱"

Bento = モデル + コード + 依存関係 + 設定 を1つにパッケージ化

開発 → Bento 作成 → デプロイ先を選ぶだけ:
  ・ローカル API サーバー (開発・テスト)
  ・Docker コンテナ (任意のクラウド)
  ・BentoCloud (マネージドサービス)
  ・Kubernetes (大規模本番)
```

## 主要コンポーネント

| コンポーネント | 役割 |
|--------------|------|
| **Service** | API エンドポイント定義 (Python クラス) |
| **Runner** | モデル推論の並列実行ユニット |
| **Bento** | デプロイ可能なパッケージ (モデル + サービス) |
| **OpenLLM** | LLM 特化サービング (vLLM / TGI バックエンド) |

## OpenLLM (LLM 特化機能)

```bash
# Llama 3 を1コマンドで起動
openllm start meta-llama/Meta-Llama-3-8B-Instruct

# OpenAI 互換 API として動作
curl http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Meta-Llama-3-8B-Instruct",
    "messages": [{"role": "user", "content": "自分株式会社について教えて"}]
  }'
```

## 競合との差別化

| ツール | 強み | 弱み |
|--------|------|------|
| **BentoML** | マルチモデル / OSS / Kubernetes | LLM 特化機能は OpenLLM |
| **Ray Serve** | 分散スケール / Python 統合 | 設定複雑 |
| **TorchServe** | PyTorch 公式 / 本番実績 | 柔軟性低い |
| **Triton Server** | NVIDIA 最適化 / 高性能 | GPU 環境前提 |

**BentoML の優位性**: マルチフレームワーク対応 × シンプルな API 定義 × OSS

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **日本語 LLM 提供** | Swallow / Llama 日本語版を BentoML でラップ | OpenAI 代替 API |
| **マルチモデル A/B** | 複数 LLM を同じ API で切り替え | コスト最適化 |
| **バッチ推論** | Runner で並列バッチ処理 | スループット向上 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'bentoml', 'api',
  'BentoML 実践 — Service定義/Runner/Bento build・containerize/OpenLLM/LangChain統合/Kubernetes デプロイ',
  $$## インストール

```bash
pip install bentoml

# LLM サービング
pip install "bentoml[io-image,grpc]"
pip install openllm  # LLM 特化
```

## 基本: Service 定義

```python
import bentoml
from bentoml.io import JSON, Text
from pydantic import BaseModel

# Pydantic で入出力スキーマ定義
class ChatRequest(BaseModel):
    message: str
    system_prompt: str = "あなたは自分株式会社のAIアシスタントです。"
    max_tokens: int = 512
    temperature: float = 0.7

class ChatResponse(BaseModel):
    response: str
    model: str
    tokens_used: int

# Service 定義 (FastAPI に似た記法)
svc = bentoml.Service("jibun-kaisha-llm")

@svc.api(input=JSON(pydantic_model=ChatRequest), output=JSON(pydantic_model=ChatResponse))
async def chat(request: ChatRequest) -> ChatResponse:
    # モデルロード (Runner 経由)
    response = await llm_runner.predict.async_run(
        prompt=request.message,
        system=request.system_prompt,
        max_tokens=request.max_tokens,
        temperature=request.temperature,
    )

    return ChatResponse(
        response=response.text,
        model="llama-3-8b-japanese",
        tokens_used=response.usage.total_tokens,
    )
```

## Runner: モデル推論の並列化

```python
import bentoml
from transformers import pipeline

# モデルを BentoML に保存
jibun_model = bentoml.transformers.save_model(
    "jibun-kaisha-sentiment",
    pipeline("text-classification", model="koheiduck/bert-japanese-finetuned-sentiment"),
    metadata={"language": "ja", "task": "sentiment"},
)

# Runner 定義 (自動で並列化・バッチ化)
sentiment_runner = jibun_model.to_runner()

# Service で Runner を使う
svc = bentoml.Service("sentiment-api", runners=[sentiment_runner])

@svc.api(input=Text(), output=JSON())
async def analyze(text: str) -> dict:
    result = await sentiment_runner.predict.async_run(text)
    return {"label": result[0]["label"], "score": result[0]["score"]}
```

## Bento Build とデプロイ

```python
# bentofile.yaml
service: "service:svc"
labels:
  owner: jibun-kaisha
  project: ai-assistant
include:
  - "*.py"
  - "models/"
python:
  packages:
    - transformers
    - torch
    - sentencepiece
docker:
  python_version: "3.11"
  cuda_version: "12.1"
  system_packages:
    - git
```

```bash
# Bento をビルド
bentoml build

# Docker イメージ化
bentoml containerize jibun-kaisha-llm:latest

# ローカルで動作確認
bentoml serve jibun-kaisha-llm:latest

# Docker で実行
docker run -p 3000:3000 jibun-kaisha-llm:latest
```

## OpenLLM: LLM 高速サービング

```python
import openllm
import bentoml

# OpenLLM でモデル設定
llm_config = openllm.AutoConfig.for_model(
    "meta-llama/Meta-Llama-3-8B-Instruct",
    max_new_tokens=512,
    top_p=0.9,
    temperature=0.7,
)

# vLLM バックエンドで高速推論
llm = openllm.LLM(
    "meta-llama/Meta-Llama-3-8B-Instruct",
    backend="vllm",          # vLLM で PagedAttention 活用
    quantize="awq",          # AWQ 量子化で VRAM 削減
)

# Runner として BentoML Service に統合
llm_runner = llm.to_runner()
svc = bentoml.Service("llm-api", runners=[llm_runner])

@svc.api(input=JSON(), output=JSON())
async def generate(request: dict) -> dict:
    result = await llm_runner.generate.async_run(
        request["prompt"],
        max_new_tokens=request.get("max_tokens", 512),
    )
    return {"response": result}
```

## LangChain との統合

```python
from langchain_community.llms import BentoML as BentoMLLLM
from langchain.chains import RetrievalQA

# デプロイ済み BentoML エンドポイントを LangChain LLM として使用
bentoml_llm = BentoMLLLM(
    server_url="http://localhost:3000",
    timeout=30,
)

# 通常の LangChain チェーンで使える
qa_chain = RetrievalQA.from_chain_type(
    llm=bentoml_llm,
    retriever=vectorstore.as_retriever(),
)

result = qa_chain.invoke({"query": "自分株式会社の競合は？"})
```

## Kubernetes デプロイ

```yaml
# bentoml generate-helm-values > values.yaml で自動生成
apiVersion: serving.kubeflow.org/v1beta1
kind: InferenceService
metadata:
  name: jibun-kaisha-llm
spec:
  predictor:
    containers:
      - name: kserve-container
        image: jibun-kaisha-llm:latest
        resources:
          limits:
            nvidia.com/gpu: "1"
            memory: "16Gi"
          requests:
            nvidia.com/gpu: "1"
            memory: "16Gi"
        env:
          - name: BENTOML_PORT
            value: "8080"
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'bentoml', 'models',
  'BentoML 技術詳解 — Adaptive Batching/Runner並列化/BentoCloud/マルチモデルアーキテクチャ/コスト最適化',
  $$## Adaptive Batching (バッチ推論最適化)

```python
import bentoml
from bentoml.io import NumpyNdarray
import numpy as np

# Runner でバッチ推論を設定
embedding_runner = bentoml.picklable_model.get("embedding-model").to_runner()

svc = bentoml.Service("embedding-api", runners=[embedding_runner])

# adaptive_batch_size: リクエストを自動バッチ化
@svc.api(
    input=NumpyNdarray(shape=(-1, 512), dtype=np.float32),
    output=NumpyNdarray(shape=(-1, 768), dtype=np.float32),
    route="/embed",
)
async def embed(texts: np.ndarray) -> np.ndarray:
    # 複数リクエストを自動バッチ化して推論
    # → GPU 使用効率を最大化
    embeddings = await embedding_runner.predict.async_run(texts)
    return embeddings
```

## Runner の並列設定

```python
# 複数 GPU での並列推論
llm_runner = bentoml.picklable_model.get("llm").to_runner(
    name="llm-runner",
    max_batch_size=32,           # バッチサイズ上限
    max_latency_ms=100,          # 最大レイテンシ (ms)
    method_configs={
        "predict": {
            "max_batch_size": 32,
            "max_latency_ms": 100,
        }
    },
)

# マルチ GPU 設定 (Kubernetes)
# env:
#   CUDA_VISIBLE_DEVICES: "0,1,2,3"
#   BENTOML_NUM_RUNNERS: "4"
```

## マルチモデルアーキテクチャ

```python
# 複数モデルを1つの Service に統合
embedding_runner = embedding_model.to_runner()
reranker_runner = reranker_model.to_runner()
llm_runner = llm_model.to_runner()

svc = bentoml.Service(
    "jibun-kaisha-rag-pipeline",
    runners=[embedding_runner, reranker_runner, llm_runner],
)

@svc.api(input=JSON(), output=JSON())
async def rag_query(request: dict) -> dict:
    query = request["query"]

    # Step 1: 埋め込み生成 (非同期並列)
    query_embedding = await embedding_runner.encode.async_run([query])

    # Step 2: ベクター検索
    candidates = vector_db.search(query_embedding[0], top_k=20)

    # Step 3: Reranking (非同期)
    reranked = await reranker_runner.rerank.async_run(query, candidates)
    top_contexts = reranked[:5]

    # Step 4: LLM 生成
    response = await llm_runner.generate.async_run(
        f"Context: {top_contexts}\n\nQuestion: {query}"
    )

    return {"response": response, "contexts": top_contexts}
```

## BentoCloud (マネージドサービス)

```bash
# BentoCloud にデプロイ (1コマンド)
bentoml deploy jibun-kaisha-llm:latest \
  --name production-llm \
  --cloud aws \
  --region ap-northeast-1 \
  --instance-type gpu.t4.small \
  --min-replicas 1 \
  --max-replicas 10

# ステータス確認
bentoml deployments list

# スケール調整
bentoml deployments update production-llm --min-replicas 2
```

## コスト最適化戦略

```
BentoML でのコスト最適化:

1. Adaptive Batching:
   → 同時リクエストをバッチ化
   → GPU 使用率 40% → 85% に向上
   → 同じ GPU でスループット 2〜3倍

2. 量子化 (OpenLLM + AWQ/GPTQ):
   → VRAM 使用量 4bit で 1/4
   → A100 (80GB) → T4 (16GB) に降格可能
   → GPU コスト 70% 削減

3. スポットインスタンス:
   → BentoCloud はスポット対応
   → Stateless 設計なら安全

4. オートスケール:
   → min-replicas: 0 → アイドル時コスト0
   → リクエスト来たら自動起動 (コールドスタート ~10秒)
```$$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 263→264社化: BentoML 追加',
  'PS#3 S84。BentoML (本番LLMサービング/OpenLLM/vLLM+AWQ量子化/Adaptive Batching/BentoCloud/LangChain統合/Kubernetes/マルチモデルアーキテクチャ/GitHub 7k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
