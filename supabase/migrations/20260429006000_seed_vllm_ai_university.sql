-- PS#3 S106: AI大学 306→307社化 — vLLM (高速LLM推論エンジン/PagedAttention/continuous batching)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'vllm', 'overview',
  'vLLM — 高速LLM推論エンジン・PagedAttention・OpenAI互換API (UC Berkeley / GitHub 25k+ / 9/9)',
  $$## vLLM とは

**vLLM** は **UC Berkeley が開発した最速クラスのオープンソース LLM 推論・サービングエンジン**。GitHub 25,000+ スター。**PagedAttention** と呼ばれる革新的なメモリ管理アルゴリズムにより、従来手法比で最大 **24倍** のスループットを実現。

**OpenAI 互換 API** をワンコマンドで起動でき、既存の ChatGPT クライアントをそのまま vLLM に切り替えられる点が最大の強み。HuggingFace のほぼ全モデルをサポート。

## vLLM の核心技術: PagedAttention

```
LLM 推論の課題と vLLM の解法:

  従来の KV Cache 管理:
    ・各リクエストに連続したメモリ領域を確保
    ・メモリの断片化 → 平均 60-80% が無駄
    ・同時処理できるリクエスト数が少ない

  PagedAttention:
    ・OS の仮想メモリ/ページング機構をKVキャッシュに応用
    ・非連続なメモリブロック (logical → physical mapping)
    ・ほぼゼロのメモリ断片化
    ・Copy-on-Write による プレフィックス共有 (System Prompt 等)

  結果:
    ・スループット最大 24x 向上 (vs HuggingFace Transformers)
    ・同一 GPU で 10-50x 多くの並行リクエストを処理
```

## Continuous Batching

```
静的バッチング (従来):
  リクエスト A [====]
  リクエスト B [========]
  リクエスト C [==]
  → A,C 完了後もBが終わるまで次のリクエストを受け付けない

Continuous Batching (vLLM):
  ・生成が終了したリクエストをリアルタイムでバッチから除外
  ・新しいリクエストを即座に空きスロットに挿入
  ・GPU 稼働率を常に最大化
  ・レイテンシを大幅削減
```

## サポートモデル・機能

```
モデルファミリー:
  ・LLaMA 2/3/3.1/3.2/3.3 (Meta)
  ・Mistral / Mixtral (MoE)
  ・Qwen 2/2.5 (Alibaba)
  ・Gemma 2 (Google)
  ・Phi-3/4 (Microsoft)
  ・Command R+ (Cohere)
  ・DeepSeek V2/V3/R1
  ・Falcon, Bloom, GPT-NeoX...

量子化サポート:
  ・AWQ (Activation-aware Weight Quantization)
  ・GPTQ
  ・FP8 (NVIDIA H100)
  ・INT4/INT8

特殊機能:
  ・Speculative Decoding (小モデルで先読み)
  ・LoRA 動的ロード (マルチ LoRA サービング)
  ・チャンク Prefill (大きい Prompt の分割処理)
  ・Vision Language Models (LLaVA, InternVL 等)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **AI アシスタント** | Llama 3.1 8B を vLLM でセルフホスト | Anthropic API コスト 90%削減 |
| **競馬予想 AI** | Fine-tuned Qwen 2.5 をローカル高速推論 | レスポンス <100ms / 低レイテンシ |
| **バッチ処理** | 大量テキスト分類を Continuous Batching で高速化 | GPU 1枚で本番スループット確保 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'vllm', 'api',
  'vLLM 実践 — インストール/OpenAI互換サーバー/Python API/量子化/LoRA/Docker/GHA統合',
  $$## インストール

```bash
# pip (CUDA 12.1)
pip install vllm

# 特定バージョン指定
pip install vllm==0.6.6

# Docker (推奨 — CUDA 環境を統一)
docker pull vllm/vllm-openai:latest
```

## OpenAI 互換サーバー起動

```bash
# Llama 3.1 8B を OpenAI 互換 API として起動
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-8B-Instruct \
  --host 0.0.0.0 \
  --port 8000 \
  --max-model-len 4096

# Docker で起動
docker run --runtime nvidia --gpus all \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -p 8000:8000 \
  vllm/vllm-openai:latest \
  --model meta-llama/Llama-3.1-8B-Instruct

# → http://localhost:8000/v1 (OpenAI 互換エンドポイント)
```

## OpenAI SDK からアクセス (ドロップイン置き換え)

```python
from openai import OpenAI

# vLLM サーバーに向ける (base_url だけ変更)
client = OpenAI(
    api_key="EMPTY",  # vLLM は API Key 不要 (認証なし設定の場合)
    base_url="http://localhost:8000/v1",
)

# Chat Completions
response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[
        {"role": "system", "content": "あなたは競馬予想の専門家です。"},
        {"role": "user", "content": "今週の重賞レースの注目馬を教えてください。"}
    ],
    temperature=0.7,
    max_tokens=500,
)
print(response.choices[0].message.content)
```

## Python ネイティブ API (LLM クラス)

```python
from vllm import LLM, SamplingParams

# モデルロード
llm = LLM(
    model="meta-llama/Llama-3.1-8B-Instruct",
    max_model_len=4096,
    gpu_memory_utilization=0.90,  # GPU メモリ使用率
    tensor_parallel_size=1,        # GPU 枚数
)

# サンプリングパラメータ
sampling_params = SamplingParams(
    temperature=0.8,
    top_p=0.95,
    max_tokens=256,
    stop=["</s>", "<|eot_id|>"],
)

# バッチ推論 (複数プロンプトを一括処理)
prompts = [
    "競馬で三連複を的中させるコツは？",
    "ダート短距離の穴馬を見つける方法を教えて",
    "G1 レースでの騎手選びのポイントは？",
]

outputs = llm.generate(prompts, sampling_params)

for output in outputs:
    prompt = output.prompt
    generated_text = output.outputs[0].text
    print(f"Prompt: {prompt!r}")
    print(f"Generated: {generated_text!r}")
    print()
```

## AWQ 量子化モデルの使用

```python
from vllm import LLM, SamplingParams

# AWQ 量子化済みモデル (メモリ 4x 節約)
llm = LLM(
    model="TheBloke/Llama-2-13B-chat-AWQ",
    quantization="awq",
    max_model_len=4096,
    gpu_memory_utilization=0.95,
)

sampling_params = SamplingParams(temperature=0.7, max_tokens=200)
outputs = llm.generate(["競馬の魅力を一言で教えて"], sampling_params)
print(outputs[0].outputs[0].text)
```

## マルチ LoRA サービング

```python
# 複数の LoRA アダプターを動的にロード
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-8B-Instruct \
  --enable-lora \
  --max-loras 4 \
  --lora-modules \
    horse-racing=./lora/horse_racing_lora \
    sentiment=./lora/sentiment_lora
```

```python
from openai import OpenAI

client = OpenAI(api_key="EMPTY", base_url="http://localhost:8000/v1")

# LoRA モデルを指定して呼び出し
response = client.chat.completions.create(
    model="horse-racing",  # LoRA アダプター名を指定
    messages=[{"role": "user", "content": "今日のおすすめ馬は？"}],
)
print(response.choices[0].message.content)
```

## Docker Compose + Nginx (本番構成)

```yaml
# docker-compose.yml
version: "3.9"
services:
  vllm:
    image: vllm/vllm-openai:latest
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - HF_TOKEN=${HF_TOKEN}
    volumes:
      - ~/.cache/huggingface:/root/.cache/huggingface
    command: >
      --model meta-llama/Llama-3.1-8B-Instruct
      --host 0.0.0.0
      --port 8000
      --max-model-len 8192
      --gpu-memory-utilization 0.90
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  nginx:
    image: nginx:alpine
    ports: ["443:443"]
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./certs:/etc/nginx/certs
    depends_on: [vllm]
```

## GHA でのモデルベンチマーク自動化

```yaml
# .github/workflows/vllm-benchmark.yml
name: vLLM Benchmark

on:
  workflow_dispatch:
    inputs:
      model:
        description: 'Model to benchmark'
        default: 'meta-llama/Llama-3.1-8B-Instruct'

jobs:
  benchmark:
    runs-on: [self-hosted, gpu]
    steps:
      - uses: actions/checkout@v4

      - name: Run Benchmark
        run: |
          pip install vllm

          python -c "
          from vllm import LLM, SamplingParams
          import time

          llm = LLM(model='${{ inputs.model }}', max_model_len=2048)
          params = SamplingParams(max_tokens=100)

          start = time.time()
          outputs = llm.generate(['Hello'] * 100, params)
          elapsed = time.time() - start

          total_tokens = sum(len(o.outputs[0].token_ids) for o in outputs)
          print(f'Throughput: {total_tokens/elapsed:.1f} tokens/sec')
          print(f'Latency: {elapsed/100*1000:.1f} ms/request')
          "
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 306→307社化: vLLM 追加',
  'PS#3 S106。vLLM (UC Berkeley/PagedAttention/Continuous Batching/OpenAI互換API/AWQ+GPTQ量子化/マルチLoRAサービング/Speculative Decoding/HuggingFace全モデル対応/GitHub 25k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
