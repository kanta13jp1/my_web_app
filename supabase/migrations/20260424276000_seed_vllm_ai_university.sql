-- Session PS#3-S43: AI大学 181社化 — vLLM 追加
-- UC Berkeley (Woosuk Kwon + Zhuohan Li) が開発する高スループット LLM 推論・サービングエンジン。
-- PagedAttention: OS の仮想メモリ技術を KV キャッシュに適用し、メモリ効率を劇的に向上。
-- OpenAI 互換 API サーバー / Continuous Batching / Speculative Decoding 対応。
-- GitHub 35k+ Stars / pip install vllm / LLaMA・Mistral・Qwen・Gemma・GPT-NeoX 対応。
-- Step 0: 9/9 (UC Berkeley / PagedAttention革新 / 35k+ Stars / OpenAI互換 / 本番実績多数)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'vllm',
  'overview',
  'vLLM — 高スループット LLM 推論エンジン (UC Berkeley / PagedAttention / 35k+ Stars)',
  $md$
# vLLM — Easy, Fast, and Cheap LLM Serving

**UC Berkeley** の Woosuk Kwon・Zhuohan Li らが開発した
高スループット・低レイテンシの LLM 推論・サービングライブラリ。

2023 年の論文「**Efficient Memory Management for Large Language Model Serving with PagedAttention**」で
KV キャッシュ管理に革新をもたらし、既存手法比で **スループット最大 24倍** を実現。

GitHub Stars **35,000+** / PyPI 週次 DL 数百万件。

## PagedAttention — 核心技術

| 従来手法 | PagedAttention |
| :--- | :--- |
| KV キャッシュを連続メモリに確保 | ブロック単位 (非連続) でページ管理 |
| メモリ断片化・無駄が大きい | OS 仮想メモリ技術を転用 |
| バッチサイズを小さくしか組めない | 大バッチ = 高スループット |

**Continuous Batching**: リクエストが届き次第、完了した sequence のスロットを即時解放して次のリクエストを受け付ける。GPU 使用率が大幅向上。

## 主要機能

| 機能 | 説明 |
| :--- | :--- |
| **OpenAI 互換 API** | `v1/completions` / `v1/chat/completions` / `v1/embeddings` |
| **Tensor Parallelism** | 複数 GPU に分散して巨大モデルを推論 |
| **Quantization** | AWQ / GPTQ / SqueezeLLM / INT4 / INT8 / FP8 |
| **Speculative Decoding** | ドラフトモデルで候補生成 → 検証で高速化 |
| **Prefix Caching** | 共通プレフィックスをキャッシュして再計算を省略 |
| **LoRA** | 複数の LoRA アダプタを動的に切り替え |

## 対応モデル

LLaMA (Meta) / Mistral / Qwen (Alibaba) / Gemma (Google) /
GPT-NeoX / Falcon / StarCoder / Bloom /
HuggingFace Hub の 300+ モデル

## 本番採用

Anyscale / Databricks / OctoAI / Lepton AI / LMSys など
大手 LLM API サービスプロバイダーの多くが推論バックエンドに採用。
$md$,
  'https://docs.vllm.ai/',
  '2026-04-24',
  1
),

(
  'vllm',
  'models',
  'vLLM サーバー設定 & 量子化 / マルチ GPU 構成 (2026)',
  $md$
## サーバー起動オプション

```bash
# 基本起動
vllm serve meta-llama/Llama-3-8b-instruct \
  --host 0.0.0.0 \
  --port 8000

# マルチ GPU (Tensor Parallelism)
vllm serve mistralai/Mixtral-8x7B-Instruct-v0.1 \
  --tensor-parallel-size 4

# 量子化 (AWQ / GPTQ)
vllm serve TheBloke/Mistral-7B-Instruct-v0.2-AWQ \
  --quantization awq \
  --dtype auto

# 最大コンテキスト / バッチサイズ調整
vllm serve Qwen/Qwen2-72B-Instruct \
  --max-model-len 32768 \
  --max-num-seqs 256 \
  --tensor-parallel-size 4
```

## エンジン設定パラメータ

| パラメータ | 説明 | 推奨値 |
| :--- | :--- | :--- |
| `--gpu-memory-utilization` | GPU メモリ使用率上限 | 0.90 (デフォルト) |
| `--max-num-seqs` | 並列処理リクエスト数 | GPU VRAM に合わせて調整 |
| `--max-model-len` | 最大コンテキスト長 | モデルのネイティブ値以下 |
| `--enforce-eager` | CUDA graph 無効化 (デバッグ用) | デフォルト OFF |
| `--enable-prefix-caching` | プレフィックスキャッシュ有効化 | 同一プロンプト多用時に ON |

## 量子化比較

| 手法 | 精度低下 | メモリ削減 | 速度向上 |
| :--- | :--- | :--- | :--- |
| FP16 (基準) | なし | 基準 | 基準 |
| INT8 | 微小 | 50% | 1.2× |
| AWQ INT4 | 小さい | 75% | 1.5-2.0× |
| GPTQ INT4 | 小さい | 75% | 1.3-1.8× |
| FP8 (H100) | 微小 | 50% | 1.5-2.0× |

## Speculative Decoding

小さいドラフトモデル (例: LLaMA-68M) でトークン候補を生成し、
大きいターゲットモデルで検証。投機的生成で **1.5-2.5× 高速化** 。

```bash
vllm serve meta-llama/Llama-3-8b-instruct \
  --speculative-model lm-sys/vicuna-68m \
  --num-speculative-tokens 5
```
$md$,
  'https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html',
  '2026-04-24',
  2
),

(
  'vllm',
  'api',
  'vLLM API 入門 — OpenAI 互換サーバー & Python クライアント',
  $md$
## vLLM の始め方

### インストール

```bash
# CUDA 12.1 環境
pip install vllm

# ROCm (AMD GPU)
pip install vllm --extra-index-url https://download.pytorch.org/whl/rocm5.7
```

### OpenAI 互換サーバー起動

```bash
# Llama 3 8B をローカルでサービング
vllm serve meta-llama/Llama-3-8b-instruct --api-key token-abc123

# 起動後: http://localhost:8000 で OpenAI API 互換エンドポイント
```

### OpenAI SDK でそのまま呼び出し

```python
from openai import OpenAI

# vLLM サーバーを OpenAI SDK で呼び出す (ドロップイン互換)
client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="token-abc123",
)

response = client.chat.completions.create(
    model="meta-llama/Llama-3-8b-instruct",
    messages=[
        {"role": "system", "content": "あなたは AI 大学のアシスタントです。"},
        {"role": "user", "content": "vLLM の PagedAttention を簡単に説明してください。"},
    ],
    temperature=0.7,
    max_tokens=512,
)
print(response.choices[0].message.content)
```

### Python インプロセス推論

```python
from vllm import LLM, SamplingParams

# モデルをロード
llm = LLM(
    model="meta-llama/Llama-3-8b-instruct",
    tensor_parallel_size=1,  # GPU 数
    gpu_memory_utilization=0.90,
    max_model_len=8192,
)

# バッチ推論 (高スループット)
sampling_params = SamplingParams(
    temperature=0.8,
    top_p=0.95,
    max_tokens=256,
)

prompts = [
    "AI大学で学べる最も重要なスキルは？",
    "CrewAI と AutoGen の主な違いは？",
    "vLLM が OpenAI より速い理由は？",
]

outputs = llm.generate(prompts, sampling_params)

for output in outputs:
    print(f"プロンプト: {output.prompt!r}")
    print(f"回答: {output.outputs[0].text!r}\n")
```

### Claude → ローカル LLM フォールバックパターン

```python
import os
from anthropic import Anthropic
from openai import OpenAI

def get_ai_response(prompt: str, use_local: bool = False) -> str:
    if use_local:
        # vLLM ローカルサーバー (コスト0)
        client = OpenAI(
            base_url="http://localhost:8000/v1",
            api_key="local",
        )
        response = client.chat.completions.create(
            model="meta-llama/Llama-3-8b-instruct",
            messages=[{"role": "user", "content": prompt}],
        )
        return response.choices[0].message.content
    else:
        # Claude API (クラウド)
        client = Anthropic()
        response = client.messages.create(
            model="claude-haiku-4-5",
            max_tokens=512,
            messages=[{"role": "user", "content": prompt}],
        )
        return response.content[0].text

# コスト節約: 非クリティカルなタスクはローカル LLM で処理
response = get_ai_response("AI大学の概要を教えて", use_local=True)
```

### Docker デプロイ

```bash
docker run --runtime nvidia --gpus all \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -p 8000:8000 \
  --ipc=host \
  vllm/vllm-openai:latest \
  --model meta-llama/Llama-3-8b-instruct
```

## クイックスタート

1. `pip install vllm` でインストール (CUDA 12.1+ 必須)
2. `vllm serve <model-name>` でサーバー起動
3. OpenAI SDK の `base_url` を `http://localhost:8000/v1` に向ける
4. 量子化: `--quantization awq` で VRAM 75% 削減
5. スケール: `--tensor-parallel-size N` で N GPU に分散
$md$,
  'https://docs.vllm.ai/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
