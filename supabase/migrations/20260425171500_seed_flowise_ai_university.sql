-- Session PS#3-S47: AI大学 190→191社化 — Flowise 追加
-- ノーコード LLM アプリビルダー。ドラッグ&ドロップ UI で LangChain/LlamaIndex ベースの
-- チャットフロー・エージェントフローを視覚的に構築。セルフホスト可能で OSS。
-- GitHub 28k+ Stars / MIT License / FlowiseAI Inc. 開発。
-- Step 0: 8/9 (ノーコードAI構築の民主化 / 28k+Stars / LangChain公式認定 / セルフホスト)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'flowise',
  'overview',
  'Flowise — ドラッグ&ドロップで LLM アプリを構築するノーコードプラットフォーム',
  $md$
# Flowise — No-Code LLM App Builder

**コードを書かずに LLM アプリケーションを構築する**ノーコードプラットフォーム。

LangChain・LlamaIndex のコンポーネントを**ドラッグ&ドロップ**で接続し、
チャットボット・RAG システム・AI エージェントを視覚的に設計できる。
セルフホスト可能で、API としてデプロイすることも可能。

GitHub **28,000+ Stars** / MIT ライセンス。

## なぜ Flowise か

| 対象 | Flowise の価値 |
| :--- | :--- |
| **非エンジニア** | コーディングなしで RAG・チャットボットを構築 |
| **プロトタイピング** | LangChain の概念を視覚的に確認しながら実験 |
| **小規模チーム** | バックエンドエンジニアなしで AI 機能を提供 |
| **エンタープライズ** | セルフホストで社内データを安全に処理 |

## 主要機能

### Chatflow (チャットフロー)
- LLM + ツール + メモリ を接続してチャットボットを構築
- 複数の LLM プロバイダー (OpenAI / Anthropic / Gemini / ローカル) に対応
- ベクターDB (Pinecone / Chroma / Supabase / Weaviate) との接続

### Agentflow (エージェントフロー) — v2 新機能
- Sequential Agent / Parallel Agent / Loop Agent の3パターン
- Human-in-the-Loop (承認ステップを視覚的に追加)
- マルチエージェント協調システムをノーコードで構築

### ドキュメント処理
- PDF・Word・Excel・Web ページを取り込んで RAG を構築
- Text Splitter・Embedding・Vector Store を視覚的に設定

## デプロイオプション

| 方法 | 特徴 |
| :--- | :--- |
| **Docker** | `docker run` 1行で起動 |
| **Railway** | ワンクリックデプロイ |
| **Render** | 無料プランあり |
| **AWS/GCP/Azure** | エンタープライズ向け |
| **FlowiseAI Cloud** | ホスト型 SaaS (管理不要) |

## LangChain との関係

Flowise は LangChain の**ビジュアルエディタ**として機能。
コンポーネントは 1:1 で対応しており、
Flowise で作ったフローは LangChain コードに変換することも可能。
$md$,
  'https://flowiseai.com/',
  '2026-04-25',
  1
),

(
  'flowise',
  'api',
  'Flowise 入門 — セットアップ・Chatflow 構築・API 呼び出し',
  $md$
## インストール (セルフホスト)

```bash
# npm でインストール
npm install -g flowise

# 起動
npx flowise start

# または Docker
docker run -d --name flowise \
  -p 3000:3000 \
  -v ~/.flowise:/root/.flowise \
  flowiseai/flowise

# ブラウザで開く
open http://localhost:3000
```

---

## 基本的な Chatflow の構築

### Step 1: ノードを追加
1. **Add Nodes** をクリック
2. **Chat Models** → **ChatAnthropic** を選択 (Claude)
3. **Memory** → **Buffer Memory** を選択
4. 接続: ChatAnthropic → Conversation Chain → Chat Output

### Step 2: 設定
```
Claude モデル:
  - Model Name: claude-sonnet-4-6
  - Temperature: 0.7
  - API Key: sk-ant-xxx (環境変数または直接入力)

Buffer Memory:
  - Session ID: {userId}  # ユーザーごとに会話履歴を分離
  - Memory Key: chat_history
```

### Step 3: テスト
右上の **Test Chat** ボタンで動作確認。

---

## RAG システムの構築

```
[PDF Loader] → [Text Splitter] → [OpenAI Embeddings] → [Pinecone Vector Store]
                                                               ↓
[Question Input] → [Conversational Retrieval QA Chain] ← [Retriever]
                              ↓
                    [Chat Output]
```

ノード設定例:
- **PDF Loader**: `./company-docs.pdf` をアップロード
- **Recursive Character Text Splitter**: chunkSize=1000, overlap=200
- **OpenAI Embeddings**: text-embedding-3-small
- **Pinecone**: namespace="company-docs"

---

## API として外部から呼び出す

```javascript
// Flowise の Chatflow を REST API として呼び出す
const response = await fetch(
  'http://localhost:3000/api/v1/prediction/<chatflow-id>',
  {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${process.env.FLOWISE_API_KEY}`,
    },
    body: JSON.stringify({
      question: 'この製品の返品ポリシーを教えてください',
      overrideConfig: {
        sessionId: 'user-123',  // セッション管理
      }
    })
  }
);

const data = await response.json();
console.log(data.text);  // AIの回答
```

---

## Python SDK

```python
from flowise import Flowise, PredictionData

client = Flowise(base_url="http://localhost:3000")

completion = client.create_prediction(
    PredictionData(
        chatflowId="<your-chatflow-id>",
        question="製品の保証期間は何年ですか？",
        overrideConfig={
            "sessionId": "user-123",
        }
    )
)

for chunk in completion:
    print(chunk, end="", flush=True)
```

---

## Agentflow (マルチエージェント)

```
[Supervisor Agent] ──── [Research Agent]
        ├──────────── [Writing Agent]
        └──────────── [Review Agent]
```

ノード:
- **Supervisor**: 全体の調整役 (どのエージェントに振り分けるか判断)
- **Worker Agent**: 専門タスクを実行
- **Tool**: 各エージェントが使えるツール (Web Search / Code Executor / Calculator)

設定手順:
1. **Agentflow** タブを選択
2. **Supervisor** ノードを追加 → LLM を Claude に設定
3. **Worker** ノードを追加 → 専門化させたいツールを割り当て
4. Supervisor → Worker を接続
$md$,
  'https://docs.flowiseai.com/',
  '2026-04-25',
  2
),

(
  'flowise',
  'models',
  'Flowise 本番運用 — 認証・監視・Supabase 統合・エンタープライズ設定',
  $md$
## 認証と API キー管理

```bash
# 環境変数で設定 (docker-compose.yml)
version: '3.1'
services:
  flowise:
    image: flowiseai/flowise
    restart: always
    environment:
      - PORT=3000
      - FLOWISE_USERNAME=admin
      - FLOWISE_PASSWORD=secure-password
      - FLOWISE_SECRETKEY_OVERWRITE=my-secret-key
      - DATABASE_TYPE=postgres
      - DATABASE_HOST=db
      - DATABASE_PORT=5432
      - DATABASE_USER=flowise
      - DATABASE_PASSWORD=db-password
      - DATABASE_NAME=flowise
    ports:
      - '3000:3000'
```

---

## Supabase との統合 (このプロジェクト向け)

### Supabase Vector Store ノード
```
設定:
  - Supabase URL: https://xxx.supabase.co
  - Supabase Service Role Key: eyJ...
  - Table Name: documents  # pgvector テーブル
  - Query Name: match_documents  # RPC 関数
```

必要な Supabase テーブル:
```sql
CREATE TABLE documents (
  id bigserial PRIMARY KEY,
  content text,
  metadata jsonb,
  embedding vector(1536)  -- text-embedding-3-small 用
);

CREATE OR REPLACE FUNCTION match_documents(
  query_embedding vector(1536),
  match_count int DEFAULT 5,
  filter jsonb DEFAULT '{}'
) RETURNS TABLE (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
) AS $$
SELECT id, content, metadata,
  1 - (embedding <=> query_embedding) AS similarity
FROM documents
WHERE metadata @> filter
ORDER BY embedding <=> query_embedding
LIMIT match_count;
$$ LANGUAGE sql;
```

---

## Webhook でイベント処理

```javascript
// Chatflow に Webhook ノードを追加
// URL: https://your-app.com/api/flowise-webhook

// Express サーバー側
app.post('/api/flowise-webhook', (req, res) => {
  const { question, answer, sessionId } = req.body;

  // ログや分析に記録
  console.log(`[${sessionId}] Q: ${question}`);
  console.log(`[${sessionId}] A: ${answer}`);

  // Supabase に保存
  await supabase.from('chat_logs').insert({
    session_id: sessionId,
    question,
    answer,
    created_at: new Date(),
  });

  res.status(200).json({ success: true });
});
```

---

## 監視とメトリクス

```bash
# Flowise のメトリクスエンドポイント
curl http://localhost:3000/api/v1/metrics

# レスポンス例
{
  "totalRequests": 1523,
  "totalTokensUsed": 45230,
  "averageResponseTime": 1.2,
  "errorRate": 0.02
}
```

---

## クイックスタート (3 ステップ)

1. `npm install -g flowise && npx flowise start` で起動
2. ブラウザで `http://localhost:3000` を開く
3. ドラッグ&ドロップでフローを構築 → **Test Chat** → **API Endpoint** でデプロイ完了
$md$,
  'https://docs.flowiseai.com/deployment',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
