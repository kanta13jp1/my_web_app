-- PS#3 S108: AI大学 310→311社化 — LM Studio (GUI LLMランチャー/GGUF/OpenAI互換サーバー)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lm-studio', 'overview',
  'LM Studio — GUI でローカルLLMを管理・実行・サーバー化 (Windows/Mac/Linux / 無料 / 9/9)',
  $$## LM Studio とは

**LM Studio** は **ローカル LLM を GUI で管理・実行・サーバー化できる無料デスクトップアプリ**。Windows / Mac (Apple Silicon/Intel) / Linux に対応。プログラミング知識ゼロでも **HuggingFace から GGUF モデルをダウンロード → 対話 → OpenAI 互換サーバー起動** まで完結できる。

**llama.cpp をバックエンドに使用**しており、技術的な深みを持ちながら、エンドユーザーにも使いやすい UI を提供。開発者がローカルで素早くモデルを試したい場合の最初の選択肢として広く使われている。

## LM Studio の主要機能

```
1. モデル管理 (Model Browser):
   ・HuggingFace Hub から GGUF モデルを検索・ダウンロード
   ・量子化レベル比較 (Q4/Q5/Q6/Q8) とファイルサイズ一覧
   ・インストール済みモデルの一覧・削除

2. Chat UI:
   ・ChatGPT ライクな対話インターフェース
   ・システムプロンプト設定
   ・温度・Max Tokens などパラメータをスライダーで調整
   ・チャット履歴の保存・エクスポート

3. OpenAI 互換ローカルサーバー:
   ・1クリックで http://localhost:1234/v1 を起動
   ・/v1/chat/completions・/v1/completions・/v1/embeddings
   ・既存 OpenAI SDK クライアントからドロップイン切り替え可

4. Playground:
   ・Raw Completion モード (プロンプト補完)
   ・JSON モード・Grammar 制約出力

5. マルチモデル比較:
   ・複数モデルに同じプロンプトを送って出力を並べて比較
```

## 対応モデル (GGUF 形式)

```
汎用:
  Llama 3.1 / 3.2 / 3.3 (Meta) — 推奨: Llama-3.1-8B-Instruct Q4_K_M
  Mistral 7B / Mixtral 8x7B (Mistral AI)
  Qwen 2.5 / 2.5-Coder     (Alibaba) — 日本語強い
  Gemma 2 9B / 27B          (Google)
  Phi-4 / Phi-3.5           (Microsoft) — 軽量高品質

推論特化:
  DeepSeek-R1-Distill-Qwen-7B — 思考プロセス可視化

マルチモーダル (画像入力):
  LLaVA 1.6 / LLaVA-Phi-3
  Moondream 2

埋め込み:
  nomic-embed-text-v1.5      — テキスト埋め込み
  mxbai-embed-large-v1
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **開発プロトタイプ** | LM Studio でモデルを素早く試してから本番 API を選定 | モデル選定コストゼロ |
| **オフライン作業** | 出張中・機内でも LLM をローカル利用 | API 依存ゼロ・データ流出なし |
| **チームデモ** | OpenAI 互換サーバーで既存アプリをそのまま接続 | デモ環境を即構築 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lm-studio', 'api',
  'LM Studio 実践 — セットアップ/OpenAI互換API/Python接続/埋め込み/curl/パラメータ調整',
  $$## セットアップ (3ステップ)

```
1. lmstudio.ai からインストーラーをダウンロード・実行
2. Search タブで「llama-3.1-8b」を検索 → Q4_K_M を Download
3. Local Server タブ → Start Server → http://localhost:1234/v1 起動
```

## OpenAI SDK から接続 (ドロップイン)

```python
from openai import OpenAI

# base_url だけ変更
client = OpenAI(
    base_url="http://localhost:1234/v1",
    api_key="lm-studio",   # 任意の文字列
)

# Chat Completions
response = client.chat.completions.create(
    model="meta-llama/Meta-Llama-3.1-8B-Instruct-GGUF",  # LM Studio が返すモデル名
    messages=[
        {"role": "system", "content": "あなたは競馬予想の専門家です。"},
        {"role": "user", "content": "今週の重賞レースで注目すべき馬を教えてください。"},
    ],
    temperature=0.7,
    max_tokens=400,
)
print(response.choices[0].message.content)
```

## ストリーミング

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:1234/v1", api_key="lm-studio")

stream = client.chat.completions.create(
    model="meta-llama/Meta-Llama-3.1-8B-Instruct-GGUF",
    messages=[{"role": "user", "content": "G1レースの魅力を詳しく教えて"}],
    stream=True,
    max_tokens=500,
)

for chunk in stream:
    content = chunk.choices[0].delta.content
    if content:
        print(content, end="", flush=True)
print()
```

## curl で直接呼び出し

```bash
# Chat Completions
curl http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Meta-Llama-3.1-8B-Instruct-GGUF",
    "messages": [{"role": "user", "content": "競馬で三連複を的中させるコツは？"}],
    "temperature": 0.7,
    "max_tokens": 200,
    "stream": false
  }'

# モデル一覧取得
curl http://localhost:1234/v1/models
```

## Embeddings API

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:1234/v1", api_key="lm-studio")

# テキストの埋め込みベクター生成
response = client.embeddings.create(
    model="nomic-ai/nomic-embed-text-v1.5-GGUF",
    input=[
        "シャフリヤール 東京 芝 1600m",
        "タイトルホルダー 中山 芝 3600m",
        "イクイノックス 東京 芝 2000m",
    ],
)

embeddings = [item.embedding for item in response.data]
print(f"Embedding dimensions: {len(embeddings[0])}")

# コサイン類似度検索
import numpy as np

def cosine_sim(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

query_response = client.embeddings.create(
    model="nomic-ai/nomic-embed-text-v1.5-GGUF",
    input=["長距離G1レース 強い馬"],
)
query_vec = query_response.data[0].embedding

texts = ["シャフリヤール 東京 芝 1600m", "タイトルホルダー 中山 芝 3600m", "イクイノックス 東京 芝 2000m"]
scores = [(texts[i], cosine_sim(query_vec, emb)) for i, emb in enumerate(embeddings)]
scores.sort(key=lambda x: x[1], reverse=True)
for text, score in scores:
    print(f"  {score:.4f}: {text}")
```

## LangChain 統合

```python
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage

# LM Studio を LangChain で使用
llm = ChatOpenAI(
    base_url="http://localhost:1234/v1",
    api_key="lm-studio",
    model="meta-llama/Meta-Llama-3.1-8B-Instruct-GGUF",
    temperature=0.7,
)

messages = [
    SystemMessage(content="あなたは競馬予想の専門家です。"),
    HumanMessage(content="今週の注目レースを教えてください。"),
]

response = llm.invoke(messages)
print(response.content)
```

## パラメータ設定 (GUI スライダーに対応)

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:1234/v1", api_key="lm-studio")

response = client.chat.completions.create(
    model="meta-llama/Meta-Llama-3.1-8B-Instruct-GGUF",
    messages=[{"role": "user", "content": "競馬の予想方法を教えて"}],
    temperature=0.8,       # 多様性 (0.0-2.0)
    top_p=0.9,             # nucleus sampling
    max_tokens=300,        # 最大生成トークン数
    frequency_penalty=0.1, # 繰り返しペナルティ
    presence_penalty=0.1,  # 新トピック促進
    stop=["</s>", "User:"] # 停止トークン
)
print(response.choices[0].message.content)
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 310→311社化: LM Studio 追加',
  'PS#3 S108。LM Studio (GUI LLMランチャー/HuggingFace GGUF管理/OpenAI互換サーバー localhost:1234/v1/埋め込みAPI/LangChain統合/マルチモデル比較/Windows+Mac+Linux/無料/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
