-- PS#3 S115: AI大学 325→326社化 — Flowise (ノーコードLangChain/LLMアプリビルダー)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'flowise', 'overview',
  'Flowise — ノーコード LLM アプリビルダー・ドラッグ&ドロップ・LangChain UI (GitHub 32k+ / 9/9)',
  $$## Flowise とは

**Flowise** は **ノーコードで LangChain / LlamaIndex ベースの LLM アプリケーションを構築できるオープンソースビルダー**。GitHub 32,000+ スター。「**ドラッグ&ドロップで RAG パイプライン・AI エージェント・チャットボットを作れる**」ツール。

React Flow ベースのビジュアルエディタ上で、LangChain のコンポーネント (LLM・Retriever・Tool・Memory など) をノードとして配置・接続するだけで、コードなしに本番レベルの LLM アプリを構築できる。Node.js で動作し、**ローカル / Docker / クラウドで自己ホスト可能**。埋め込みチャットウィジェットで任意のサイトに組み込める。

## Flowise のアーキテクチャ

```
Flowise のコンポーネント:

  Chatflow (チャットフロー):
    ・ドラッグ&ドロップで LLM パイプラインを構築
    ・Chat / Completion の 2 種類
    ・テンプレートから即座に作成可能

  Agentflow (エージェントフロー):
    ・マルチエージェントワークフロー
    ・Tool Call / ReAct / Plan-and-Execute
    ・Human-in-the-Loop 対応

  対応コンポーネント:
    ・LLM: Claude / GPT / Gemini / Ollama / LiteLLM
    ・VectorStore: Qdrant / Pinecone / Chroma / pgvector
    ・Document Loader: PDF / Web / CSV / Notion / Confluence
    ・Memory: Buffer / Redis / Zep / Motorhead
    ・Tool: Calculator / WebSearch / Custom API

  デプロイ:
    ・REST API で外部から呼び出し可能
    ・埋め込みウィジェット (iframe / Web Component)
    ・WebSocket / Streaming 対応
    ・Docker Compose で簡単デプロイ
```

## 主要機能

```
ノーコード機能:
  ・100+ 組み込みコンポーネント
  ・テンプレートギャラリー (RAG / Agent など)
  ・Marketplace でコミュニティフロー共有

API & 統合:
  ・REST API で任意のアプリから呼び出し
  ・Python / JavaScript SDK
  ・Zapier / Make.com 連携

セキュリティ:
  ・API キー認証
  ・ユーザー管理 (Commercial 版)
  ・オンプレミス自己ホスト
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **AI大学チャットボット** | ai_university_content の RAG フローをコードなしで構築 | 開発時間 90% 削減 |
| **競馬予想 UI** | Flowise チャットウィジェットをサイトに埋め込み | 非エンジニアでも予想 AI を改善 |
| **プロトタイプ検証** | 新しい RAG 設定を Flowise で即試行 → 確認後コード化 | アイデア検証サイクル高速化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'flowise', 'api',
  'Flowise 実践 — インストール/Docker/RAGフロー構築/Claude統合/REST API/埋め込みウィジェット/Python SDK',
  $$## インストール

```bash
# npx で即起動
npx flowise start

# または npm グローバルインストール
npm install -g flowise
flowise start

# 環境変数 (オプション)
# PORT=3000 (デフォルト)
# FLOWISE_USERNAME=admin
# FLOWISE_PASSWORD=password
```

## Docker Compose でデプロイ

```yaml
# docker-compose.yml
version: '3.1'

services:
  flowise:
    image: flowiseai/flowise:latest
    restart: always
    environment:
      - PORT=3000
      - FLOWISE_USERNAME=admin
      - FLOWISE_PASSWORD=your-password
      - APIKEY_PATH=/root/.flowise
      - SECRETKEY_PATH=/root/.flowise
      - LOG_LEVEL=info
      - DATABASE_PATH=/root/.flowise
    ports:
      - '3000:3000'
    volumes:
      - ~/.flowise:/root/.flowise
    command: /bin/sh -c "sleep 3; flowise start"
```

```bash
docker-compose up -d
# → http://localhost:3000 でアクセス
```

## RAG フローの構築手順 (UI)

```text
1. Flowise UI (http://localhost:3000) を開く

2. "Add New" → Chatflow を選択

3. ノードを追加:
   a. Document Loader: PDF File / Web URL / CSV
   b. Text Splitter: Recursive Character Text Splitter
      - Chunk Size: 1000
      - Chunk Overlap: 200
   c. Embeddings: HuggingFace Embeddings
      - Model: BAAI/bge-small-en-v1.5
   d. Vector Store: In-Memory Vector Store (開発用)
      または Qdrant / Pinecone (本番用)
   e. Retriever: Vector Store Retriever
      - Top K: 3
   f. Chat Model: ChatAnthropic
      - Model: claude-haiku-4-5
      - API Key: YOUR_ANTHROPIC_API_KEY
   g. Conversational Retrieval QA Chain

4. ノードを接続:
   Document Loader → Text Splitter → Embeddings → Vector Store
   Vector Store → Retriever → QA Chain
   Chat Model → QA Chain

5. "Save" → "Test Chat" で動作確認
```

## REST API での呼び出し

```python
import requests

FLOWISE_URL = "http://localhost:3000"
CHATFLOW_ID = "your-chatflow-id"  # UI で確認
API_KEY = "your-api-key"  # Flowise API Keys から生成

def ask_flowise(question: str, session_id: str = "default") -> str:
    """Flowise API に質問を投げて回答を得る"""
    response = requests.post(
        f"{FLOWISE_URL}/api/v1/prediction/{CHATFLOW_ID}",
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
        },
        json={
            "question": question,
            "overrideConfig": {
                "sessionId": session_id,
            },
        },
    )
    return response.json()["text"]

# 使用例
answer = ask_flowise("LlamaIndex と LangChain の違いは？", session_id="user-123")
print(answer)

# 競馬予想チャットボット
prediction = ask_flowise("天皇賞春2026でシャフリヤールの予想を教えて", session_id="keiba-session")
print(prediction)
```

## Python SDK (flowiseai)

```python
from flowise import Flowise, PredictionData

client = Flowise(base_url="http://localhost:3000", api_key="your-api-key")

# ストリーミング
def ask_with_streaming(question: str):
    completion = client.create_prediction(
        PredictionData(
            chatflowId="your-chatflow-id",
            question=question,
            streaming=True,
        )
    )
    for chunk in completion:
        print(chunk, end="", flush=True)
    print()

ask_with_streaming("AI大学で学べる LLM 推論ツールを教えて")
```

## 埋め込みウィジェット (HTML)

```html
<!-- サイトに Flowise チャットを埋め込む -->
<script type="module">
  import Chatbot from "https://cdn.jsdelivr.net/npm/flowise-embed/dist/web.js"
  Chatbot.init({
    chatflowid: "your-chatflow-id",
    apiHost: "http://localhost:3000",
    chatflowConfig: {
      // オーバーライド設定
    },
    theme: {
      button: {
        backgroundColor: "#4F46E5",
        right: 20,
        bottom: 20,
        size: "medium",
        iconColor: "white",
      },
      chatWindow: {
        title: "AI大学アシスタント",
        welcomeMessage: "こんにちは！AI・競馬に関する質問をどうぞ。",
        backgroundColor: "#ffffff",
        height: 700,
        width: 400,
      },
    }
  })
</script>
```

## Agentflow (マルチエージェント)

```text
Agentflow でノーコードマルチエージェント:

1. "Add New" → Agentflow を選択

2. ノードを配置:
   ・Supervisor: タスク管理エージェント (Claude Sonnet)
   ・Worker 1: リサーチャー + Web Search Tool
   ・Worker 2: アナリスト + Calculator Tool
   ・Worker 3: ライター + File Write Tool

3. Supervisor が入力を受けてワーカーに割り振り

4. REST API で外部から呼び出し可能
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 325→326社化: Flowise 追加',
  'PS#3 S115。Flowise (ノーコードLLMアプリビルダー/ドラッグ&ドロップ/LangChain UI/100+コンポーネント/Claude統合/REST API/埋め込みウィジェット/Docker自己ホスト/Agentflow/GitHub 32k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
