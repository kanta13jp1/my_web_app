-- PS#3 S107: AI大学 309→310社化 — llama.cpp (CPU LLM推論/GGUF/量子化/クロスプラットフォーム)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'llama-cpp', 'overview',
  'llama.cpp — CPU/GPU 高速LLM推論・GGUF量子化・クロスプラットフォーム (GitHub 65k+ / 9/9)',
  $$## llama.cpp とは

**llama.cpp** は **Georgi Gerganov 氏が開発した、純粋な C/C++ で書かれた超軽量 LLM 推論エンジン**。GitHub 65,000+ スター。**GPU がなくても CPU だけで LLM を動かせる** ことが最大の特徴。Apple Silicon / x86 / ARM 全てで動作し、Raspberry Pi でも動く。

**GGUF (GPT-Generated Unified Format)** という独自の量子化フォーマットを導入し、70B モデルを 4-bit 量子化で 40GB → **4GB 未満** に圧縮。通常の PC でも大型モデルを扱える。

## llama.cpp の核心: 量子化技術

```
GGUF 量子化レベル比較 (Llama 3.1 8B の例):

  FP16  (非量子化): ~16 GB VRAM  — 最高精度
  Q8_0  (8-bit):    ~8.5 GB      — 精度損失ほぼなし
  Q5_K_M (5-bit):   ~5.7 GB      — 推奨 (精度/速度バランス)
  Q4_K_M (4-bit):   ~4.8 GB      — RAM 8GB PC で動作
  Q3_K_M (3-bit):   ~3.9 GB      — 精度低下あり
  Q2_K  (2-bit):    ~2.9 GB      — 最軽量 (品質低下大)

推奨選択:
  VRAM/RAM 16GB+ → Q6_K または Q5_K_M
  VRAM/RAM 8GB   → Q4_K_M (黄金比)
  VRAM/RAM 4GB   → Q3_K_M (最小構成)
```

## マルチプラットフォーム対応

```
CPU バックエンド:
  ・x86 / x86_64 (AVX2/AVX-512 最適化)
  ・ARM (Apple Silicon M1/M2/M3 — Metal GPU)
  ・ARM (Raspberry Pi / スマートフォン)
  ・RISC-V

GPU バックエンド:
  ・CUDA (NVIDIA)
  ・ROCm (AMD)
  ・Metal (Apple)
  ・OpenCL (汎用)
  ・Vulkan (クロスプラットフォーム GPU)

特殊デバイス:
  ・llama.cpp for Android (JNI)
  ・llama.cpp for iOS (Swift bindings)
  ・WebAssembly (ブラウザ実行)
  ・Raspberry Pi 4/5
```

## llama.cpp エコシステム

```
派生プロジェクト・ラッパー:
  ・Ollama     — llama.cpp を内部エンジンとして使用
  ・LM Studio  — GUI フロントエンド
  ・Jan        — デスクトップアプリ
  ・llama-cpp-python — Python バインディング (最重要)
  ・node-llama-cpp — Node.js バインディング
  ・go-llama.cpp — Go バインディング
  ・llama.rn   — React Native
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **エッジ AI** | Raspberry Pi に llama.cpp をデプロイ | クラウド不要・完全オフライン |
| **低コスト推論** | GPU なしのサーバーで量子化モデル | サーバーコスト 90%削減 |
| **Fine-tuned モデル** | GGUF 変換した競馬特化モデルをローカル実行 | データプライバシー + 高速推論 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'llama-cpp', 'api',
  'llama.cpp 実践 — ビルド/CLI推論/llama-cpp-python/OpenAI互換サーバー/GGUF変換/量子化/Fine-tuning',
  $$## インストール & ビルド

```bash
# ソースからビルド (Linux/macOS)
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp

# CPU のみ (基本)
make -j4

# CUDA 対応ビルド (NVIDIA GPU)
make LLAMA_CUDA=1 -j4

# Metal 対応 (Apple Silicon)
make LLAMA_METAL=1 -j4

# Homebrew (macOS 簡単インストール)
brew install llama.cpp
```

## モデルのダウンロード (HuggingFace から GGUF)

```bash
# huggingface-cli でダウンロード
pip install huggingface_hub
huggingface-cli download \
  bartowski/Meta-Llama-3.1-8B-Instruct-GGUF \
  Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf \
  --local-dir ./models/
```

## CLI 推論

```bash
# 基本的な推論
./llama-cli \
  -m ./models/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf \
  -p "競馬で三連複を的中させるコツは？" \
  -n 200

# 対話モード
./llama-cli \
  -m ./models/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf \
  --interactive \
  --chat-template llama3

# パフォーマンス設定
./llama-cli \
  -m ./models/model.gguf \
  -p "Hello" \
  -n 100 \
  --n-gpu-layers 35 \   # GPU にオフロードするレイヤー数 (35=全層)
  --ctx-size 4096 \     # コンテキスト長
  --threads 8           # CPU スレッド数
```

## OpenAI 互換サーバー起動

```bash
# HTTP サーバーモードで起動
./llama-server \
  -m ./models/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --n-gpu-layers 35 \
  --ctx-size 8192

# → http://localhost:8080/v1/chat/completions (OpenAI 互換)
# → http://localhost:8080 (Web UI)
```

## llama-cpp-python (Python バインディング)

```bash
# インストール
pip install llama-cpp-python

# GPU サポート付き (CUDA)
CMAKE_ARGS="-DLLAMA_CUDA=on" pip install llama-cpp-python

# Metal サポート (Apple Silicon)
CMAKE_ARGS="-DLLAMA_METAL=on" pip install llama-cpp-python
```

```python
from llama_cpp import Llama

# モデルロード
llm = Llama(
    model_path="./models/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf",
    n_ctx=4096,          # コンテキスト長
    n_gpu_layers=35,     # GPU オフロード (-1 で全層)
    n_threads=8,         # CPU スレッド数
    verbose=False,
)

# Chat Completions (OpenAI 互換インターフェース)
response = llm.create_chat_completion(
    messages=[
        {"role": "system", "content": "あなたは競馬予想の専門家です。"},
        {"role": "user", "content": "今週の中山記念の本命馬を予想してください。"},
    ],
    temperature=0.7,
    max_tokens=300,
)
print(response["choices"][0]["message"]["content"])

# ストリーミング
for chunk in llm.create_chat_completion(
    messages=[{"role": "user", "content": "競馬場の雰囲気を詳しく描写して"}],
    stream=True,
    max_tokens=500,
):
    delta = chunk["choices"][0]["delta"]
    if "content" in delta:
        print(delta["content"], end="", flush=True)
print()
```

## Embeddings 生成

```python
from llama_cpp import Llama

# 埋め込みモデルのロード
embed_model = Llama(
    model_path="./models/nomic-embed-text-v1.5.Q4_K_M.gguf",
    embedding=True,      # 埋め込みモードを有効化
    n_ctx=512,
)

# テキストのベクトル化
texts = [
    "シャフリヤール 東京競馬場 1600m 芝",
    "タイトルホルダー 中山競馬場 3600m 芝",
    "イクイノックス 天皇賞 秋 3200m",
]

embeddings = [embed_model.embed(text) for text in texts]
print(f"Embedding shape: ({len(embeddings)}, {len(embeddings[0])})")

# コサイン類似度で近似検索
import numpy as np

def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

query = embed_model.embed("G1レースで強い馬")
similarities = [(texts[i], cosine_similarity(query, emb)) for i, emb in enumerate(embeddings)]
similarities.sort(key=lambda x: x[1], reverse=True)

for text, score in similarities:
    print(f"  {score:.4f}: {text}")
```

## HuggingFace モデルを GGUF に変換

```bash
# 変換スクリプト (llama.cpp 付属)
python convert_hf_to_gguf.py \
  ./models/my-fine-tuned-model/ \
  --outtype f16 \
  --outfile ./models/my_model_f16.gguf

# 量子化 (F16 → Q4_K_M)
./llama-quantize \
  ./models/my_model_f16.gguf \
  ./models/my_model_Q4_K_M.gguf \
  Q4_K_M
```

## Docker デプロイ

```dockerfile
# Dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    build-essential cmake git curl \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ggerganov/llama.cpp /llama.cpp \
    && cd /llama.cpp \
    && make -j4

WORKDIR /llama.cpp

# モデルは volume でマウント
VOLUME ["/models"]

EXPOSE 8080

CMD ["./llama-server", \
     "-m", "/models/model.gguf", \
     "--host", "0.0.0.0", \
     "--port", "8080", \
     "--n-gpu-layers", "0"]
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 309→310社化: llama.cpp 追加',
  'PS#3 S107。llama.cpp (Georgi Gerganov/C++/CPU+GPU対応/GGUF量子化Q2-Q8/Apple Silicon Metal/CUDA/ROCm/Vulkan/OpenAI互換サーバー/llama-cpp-python/Embeddings/GGUF変換/GitHub 65k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
