-- PS#3 S106: AI大学 307→308社化 — TGI (Text Generation Inference / HuggingFace製)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'text-generation-inference', 'overview',
  'TGI (Text Generation Inference) — HuggingFace製LLMサービング・Flash Attention・OpenAI互換 (GitHub 8k+ / 9/9)',
  $$## TGI (Text Generation Inference) とは

**TGI** は **HuggingFace が開発・維持する本番グレードの LLM サービングフレームワーク**。GitHub 8,000+ スター。**HuggingFace Hub の全モデルと最高の互換性**を持ち、HuggingFace Inference Endpoints の内部エンジンとしても使われている。

Rust + Python のハイブリッドアーキテクチャで、サーバーコアは Rust で実装されているため**超低レイテンシ**を実現。Flash Attention 2 / Paged Attention を内蔵し、**本番ワークロードに必要な機能が全てデフォルトで有効**。

## TGI の主要特徴

```
アーキテクチャ:
  ・サーバーコア: Rust (gRPC + HTTP/2)
  ・推論バックエンド: PyTorch (Flash Attention 2)
  ・内部通信: 高効率 Protobuf / 低レイテンシ

本番対応機能 (デフォルト有効):
  ・Continuous Batching — GPU 稼働率最大化
  ・Flash Attention 2 — Transformer Attention の高速化
  ・Paged Attention — KV キャッシュ最適化
  ・Tensor Parallelism — 複数 GPU 分散推論
  ・Speculative Decoding (Medusa) — 生成速度 2-3x 向上
  ・Watermarking — 生成テキストへの透かし埋め込み
  ・Token Streaming (SSE) — リアルタイムストリーミング

量子化:
  ・AWQ / GPTQ / EETQ (FP8) / bitsandbytes (INT4/INT8)
  ・MARLIN (高速 INT4 カーネル)

OpenAI 互換:
  ・/v1/chat/completions
  ・/v1/completions
  ・ストリーミング対応
```

## HuggingFace Hub との統合

```
TGI の最大強み = HuggingFace Hub との深い統合:

  ・HUGGING_FACE_HUB_TOKEN でプライベートモデルも直接ロード
  ・Gated モデル (Llama 3, Gemma 等) を認証済みで使用可
  ・HuggingFace Inference Endpoints = TGI の内部エンジン
  ・HuggingFace Hub の全メタデータ (tokenizer/config) を自動取得
  ・モデルシャーディング (大モデルを自動で複数GPU分割)
```

## 対応モデル

```
Llama 3.1 / 3.2 / 3.3 (Meta)
Mistral / Mixtral (Mistral AI)
Gemma 2 (Google)
Qwen 2.5 (Alibaba)
Phi-3 / 3.5 (Microsoft)
Command R+ (Cohere)
DeepSeek V2 / V3 / R1
Falcon / Bloom / GPT-NeoX
IDEFICS 2 / LLaVA (マルチモーダル)
...その他 HuggingFace Hub の主要モデル
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **セルフホスト LLM** | Llama 3.1 8B を TGI で Docker 起動 | API コスト削減・データプライバシー確保 |
| **ストリーミング応答** | SSE Token Streaming で逐次表示 | ユーザー体験向上 (体感速度改善) |
| **マルチモーダル** | LLaVA で競馬場の画像解析 | 馬の状態・コンディション分析 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'text-generation-inference', 'api',
  'TGI 実践 — Docker起動/OpenAI互換API/ストリーミング/量子化/マルチGPU/Rust gRPC/Python Client',
  $$## Docker で起動 (最速セットアップ)

```bash
# Llama 3.1 8B を TGI で起動
model=meta-llama/Llama-3.1-8B-Instruct
volume=$PWD/data

docker run --gpus all \
  --shm-size 1g \
  -e HUGGING_FACE_HUB_TOKEN=$HF_TOKEN \
  -p 8080:80 \
  -v $volume:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id $model \
  --max-input-tokens 4096 \
  --max-total-tokens 8192

# → http://localhost:8080 (HTTP API)
# → http://localhost:8080/docs (Swagger UI)
```

## OpenAI 互換 API (curl)

```bash
# Chat Completions
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tgi",
    "messages": [
      {"role": "system", "content": "あなたは競馬予想AIです。"},
      {"role": "user", "content": "今週の中山記念の本命馬を教えて"}
    ],
    "stream": false,
    "max_tokens": 200
  }'

# Text Generation (非 Chat)
curl http://localhost:8080/generate \
  -H "Content-Type: application/json" \
  -d '{"inputs": "競馬で穴馬を見つけるコツは", "parameters": {"max_new_tokens": 100}}'
```

## Python Client (huggingface_hub)

```python
from huggingface_hub import InferenceClient

# TGI サーバーに接続
client = InferenceClient(model="http://localhost:8080")

# テキスト生成
response = client.text_generation(
    "競馬で三連複を当てるための戦略を3つ教えてください。",
    max_new_tokens=300,
    temperature=0.8,
    do_sample=True,
    stream=False,
)
print(response)
```

## ストリーミング (Token by Token)

```python
from huggingface_hub import InferenceClient

client = InferenceClient(model="http://localhost:8080")

# ストリーミング生成 (リアルタイム表示)
for token in client.text_generation(
    "競馬場の雰囲気を詳しく描写してください。",
    max_new_tokens=500,
    stream=True,
):
    print(token, end="", flush=True)
print()  # 改行
```

```python
# OpenAI SDK でストリーミング
from openai import OpenAI

client = OpenAI(
    api_key="EMPTY",
    base_url="http://localhost:8080/v1",
)

stream = client.chat.completions.create(
    model="tgi",
    messages=[{"role": "user", "content": "今日のレースの見どころを教えて"}],
    stream=True,
    max_tokens=300,
)

for chunk in stream:
    content = chunk.choices[0].delta.content
    if content:
        print(content, end="", flush=True)
print()
```

## AWQ 量子化モデル

```bash
# AWQ 量子化 Llama 3 13B (4-bit / VRAM 8GB でも動作)
docker run --gpus all \
  -p 8080:80 \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id TheBloke/Llama-2-13B-chat-AWQ \
  --quantize awq \
  --max-input-tokens 2048 \
  --max-total-tokens 4096
```

## マルチ GPU (Tensor Parallelism)

```bash
# 2 GPU で 70B モデルをシャーディング
docker run --gpus '"device=0,1"' \
  -p 8080:80 \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id meta-llama/Llama-3.1-70B-Instruct \
  --sharded true \
  --num-shard 2 \
  --max-input-tokens 8192 \
  --max-total-tokens 16384
```

## Docker Compose (本番構成)

```yaml
# docker-compose.yml
version: "3.9"
services:
  tgi:
    image: ghcr.io/huggingface/text-generation-inference:latest
    runtime: nvidia
    environment:
      - HUGGING_FACE_HUB_TOKEN=${HF_TOKEN}
      - RUST_LOG=info
    command: >
      --model-id meta-llama/Llama-3.1-8B-Instruct
      --max-input-tokens 4096
      --max-total-tokens 8192
      --max-batch-prefill-tokens 4096
    volumes:
      - ./models:/data
    ports:
      - "8080:80"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## Supabase Edge Function から呼び出し

```typescript
// supabase/functions/ai-assistant/index.ts
// TGI セルフホスト LLM を使う場合

const TGI_BASE_URL = Deno.env.get("TGI_BASE_URL") || "http://tgi:8080";

async function generateWithTGI(prompt: string): Promise<string> {
  const response = await fetch(`${TGI_BASE_URL}/v1/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "tgi",
      messages: [
        { role: "system", content: "あなたは競馬予想の専門家AIです。" },
        { role: "user", content: prompt },
      ],
      max_tokens: 500,
      temperature: 0.7,
    }),
  });

  const data = await response.json();
  return data.choices[0].message.content;
}

Deno.serve(async (req) => {
  const { prompt } = await req.json();
  const result = await generateWithTGI(prompt);
  return new Response(JSON.stringify({ result }), {
    headers: { "Content-Type": "application/json" },
  });
});
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 307→308社化: TGI (Text Generation Inference) 追加',
  'PS#3 S106。TGI (HuggingFace製/Rust+Python/Flash Attention 2/Paged Attention/Continuous Batching/Tensor Parallelism/OpenAI互換/Watermarking/Speculative Decoding/AWQ+GPTQ+FP8/GitHub 8k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
