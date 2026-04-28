-- PS#3 S107: AI大学 308→309社化 — Ollama (ローカルLLM簡単起動/OpenAI互換/Docker)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'ollama', 'overview',
  'Ollama — ローカルLLM 1コマンド起動・OpenAI互換・Modelfile カスタマイズ (GitHub 85k+ / 9/9)',
  $$## Ollama とは

**Ollama** は **「LLM をローカルで動かすための最も簡単なツール」**。GitHub 85,000+ スター (LLM ツール最多クラス)。`brew install ollama` と `ollama run llama3` の **2コマンドだけ** で、モデルのダウンロードからサーバー起動まで全自動。

**開発者体験を最優先した設計** — API キー不要、クラウド依存ゼロ、プライバシー完全保護。Mac (Apple Silicon MPS) / Linux (CUDA) / Windows (DirectML) に対応。

## Ollama の設計哲学

```
1コマンドで全て解決:
  ollama run llama3.2        # ダウンロード + 起動 + 対話
  ollama run mistral         # 別モデルも同じコマンド
  ollama run phi4            # Microsoft Phi-4
  ollama run deepseek-r1     # DeepSeek R1 推論モデル
  ollama run gemma3          # Google Gemma 3

自動処理される内容:
  ・モデルファイルのダウンロード (HuggingFace GGUF 形式)
  ・量子化レベルの自動選択 (VRAM に合わせ Q4/Q5/Q8)
  ・バックグラウンドサーバー起動 (localhost:11434)
  ・GPU/CPU 自動検出・最適化
```

## 対応モデル一覧

```
汎用会話:
  llama3.2 / llama3.1 / llama3        (Meta)
  mistral / mixtral                   (Mistral AI)
  qwen2.5 / qwen2                     (Alibaba)
  gemma3 / gemma2                     (Google)
  phi4 / phi3                         (Microsoft)
  command-r / command-r-plus          (Cohere)
  deepseek-r1 / deepseek-v2           (DeepSeek)

コーディング特化:
  codellama                           (Meta)
  qwen2.5-coder                       (Alibaba)
  deepseek-coder-v2
  starcoder2

多言語 / 日本語:
  qwen2.5 (日本語強い)
  elyza:jp8b (日本語特化)

マルチモーダル (画像入力):
  llava / llava-phi3
  moondream
  llama3.2-vision
```

## Modelfile: カスタムモデル定義

```dockerfile
# Modelfile — 競馬予想AIカスタマイズ例

FROM llama3.1:8b

# システムプロンプト固定
SYSTEM """
あなたは日本競馬専門のAIアドバイザーです。
JRA/NARレースの予想・分析を専門としています。
オッズ・血統・騎手・コース適性を総合的に判断し、
根拠ある予想と資金管理アドバイスを提供します。
"""

# パラメータ調整
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER num_ctx 4096

# テンプレート設定
TEMPLATE """{{ .System }}

ユーザー: {{ .Prompt }}
アシスタント: """
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **開発環境 AI** | Ollama をローカルで起動して IDE 補完 | API コストゼロ・オフライン対応 |
| **競馬予想 AI** | Modelfile でカスタム競馬 AI を定義 | システムプロンプト固定・プライバシー確保 |
| **プロトタイプ検証** | 新機能を Ollama でローカル検証後、本番は Anthropic API | コスト削減しながら品質担保 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'ollama', 'api',
  'Ollama 実践 — インストール/CLI/REST API/OpenAI互換/Python SDK/Modelfile/Docker/LangChain統合',
  $$## インストール

```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh

# Windows (winget)
winget install Ollama.Ollama

# Docker
docker run -d -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
# GPU 付き Docker
docker run -d --gpus=all -v ollama:/root/.ollama -p 11434:11434 ollama/ollama
```

## CLI 基本操作

```bash
# モデルを起動して対話
ollama run llama3.2
ollama run mistral "日本語で挨拶してください"   # 非対話モード

# モデル管理
ollama pull llama3.2         # ダウンロードのみ
ollama list                  # インストール済みモデル一覧
ollama show llama3.2         # モデル詳細表示
ollama rm llama3.2           # 削除
ollama ps                    # 実行中モデル確認

# Modelfile からカスタムモデル作成
ollama create horse-racing-ai -f ./Modelfile
ollama run horse-racing-ai "今週の重賞の注目馬は？"
```

## REST API (ネイティブ)

```bash
# 生成 (非ストリーム)
curl http://localhost:11434/api/generate \
  -d '{"model": "llama3.2", "prompt": "競馬の魅力を一言で", "stream": false}'

# Chat API
curl http://localhost:11434/api/chat \
  -d '{
    "model": "llama3.2",
    "messages": [
      {"role": "system", "content": "あなたは競馬予想の専門家です"},
      {"role": "user", "content": "三連複の買い方を教えて"}
    ],
    "stream": false
  }'

# ストリーミング (NDJSON)
curl http://localhost:11434/api/chat \
  -d '{"model": "llama3.2", "messages": [{"role": "user", "content": "Hello"}]}'
```

## OpenAI 互換 API (ドロップイン置き換え)

```python
from openai import OpenAI

# base_url だけ変更で OpenAI SDK がそのまま使える
client = OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="ollama",  # 任意の文字列
)

response = client.chat.completions.create(
    model="llama3.2",
    messages=[
        {"role": "system", "content": "あなたは競馬予想AIです。"},
        {"role": "user", "content": "今週の中山記念を予想してください"},
    ],
    temperature=0.7,
)
print(response.choices[0].message.content)
```

## Python 公式ライブラリ (ollama-python)

```python
import ollama

# シンプルなチャット
response = ollama.chat(
    model="llama3.2",
    messages=[
        {"role": "user", "content": "競馬の三連複とは何ですか？"},
    ],
)
print(response["message"]["content"])

# ストリーミング
for chunk in ollama.chat(
    model="llama3.2",
    messages=[{"role": "user", "content": "競馬場の雰囲気を詳しく教えて"}],
    stream=True,
):
    print(chunk["message"]["content"], end="", flush=True)

# Embeddings 生成
embeddings = ollama.embeddings(
    model="nomic-embed-text",
    prompt="競馬 天皇賞 春 長距離",
)
print(f"Embedding dim: {len(embeddings['embedding'])}")
```

## Modelfile 完全版

```dockerfile
# horse-racing-advisor/Modelfile
FROM qwen2.5:7b

SYSTEM """
あなたは日本競馬の専門AIアドバイザー「競馬マスター」です。

専門領域:
- JRA/NAR全レースの予想と分析
- 血統・騎手・調教師・コース適性の総合評価
- オッズ分析と期待値計算
- 資金管理とベット戦略

回答スタイル:
- 簡潔で根拠のある予想を提供
- 馬名・騎手名は正確に
- 日本語で回答
"""

PARAMETER temperature 0.6
PARAMETER top_p 0.9
PARAMETER num_ctx 8192
PARAMETER num_predict 1024
PARAMETER stop "<|im_end|>"
PARAMETER stop "<|endoftext|>"
```

```bash
# カスタムモデル作成・実行
ollama create horse-racing-advisor -f ./Modelfile
ollama run horse-racing-advisor
```

## LangChain / LlamaIndex 統合

```python
# LangChain
from langchain_community.llms import Ollama
from langchain_core.prompts import ChatPromptTemplate

llm = Ollama(model="llama3.2", base_url="http://localhost:11434")

prompt = ChatPromptTemplate.from_messages([
    ("system", "あなたは競馬予想の専門家です。"),
    ("human", "{question}"),
])

chain = prompt | llm
result = chain.invoke({"question": "今週の重賞の注目馬を教えて"})
print(result)
```

## Docker Compose (サービス化)

```yaml
# docker-compose.yml
version: "3.9"
services:
  ollama:
    image: ollama/ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    # GPU 使用時: `deploy` ブロックを追加
    # deploy:
    #   resources:
    #     reservations:
    #       devices:
    #         - driver: nvidia
    #           count: 1
    #           capabilities: [gpu]
    restart: unless-stopped

  # 起動後に自動でモデルをプル
  ollama-init:
    image: ollama/ollama
    depends_on:
      - ollama
    entrypoint: >
      sh -c "
        sleep 5 &&
        ollama pull llama3.2 &&
        ollama pull nomic-embed-text
      "
    environment:
      - OLLAMA_HOST=http://ollama:11434
    volumes:
      - ollama_data:/root/.ollama

volumes:
  ollama_data:
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 308→309社化: Ollama 追加',
  'PS#3 S107。Ollama (ローカルLLM 1コマンド起動/GitHub 85k+最多クラス/Modelfile カスタマイズ/OpenAI互換API/Mac MPS+Linux CUDA+Win DirectML/LangChain統合/Docker対応/埋め込みモデル対応/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
