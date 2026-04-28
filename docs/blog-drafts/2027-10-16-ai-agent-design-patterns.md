---
title: "AI エージェント設計パターン — Tool Use / RAG / Memory の実装"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# AI エージェント設計パターン — Tool Use / RAG / Memory の実装

「LLM を呼び出すだけ」から「自律的に動くエージェント」へ。3つのパターンで実用的な AI エージェントを作る。

## パターン1: Tool Use (関数呼び出し)

LLM が自分で「どのツールをいつ使うか」を判断する。

```python
import anthropic

client = anthropic.Anthropic()

# ツールを定義
tools = [
  {
    "name": "get_supabase_data",
    "description": "Supabase からユーザーデータを取得する",
    "input_schema": {
      "type": "object",
      "properties": {
        "table": {"type": "string", "description": "テーブル名"},
        "user_id": {"type": "string", "description": "ユーザー ID"}
      },
      "required": ["table", "user_id"]
    }
  },
  {
    "name": "send_email",
    "description": "Resend API でメールを送信する",
    "input_schema": {
      "type": "object",
      "properties": {
        "to": {"type": "string"},
        "subject": {"type": "string"},
        "body": {"type": "string"}
      },
      "required": ["to", "subject", "body"]
    }
  }
]

# エージェントループ
def run_agent(user_message: str):
  messages = [{"role": "user", "content": user_message}]

  while True:
    response = client.messages.create(
      model="claude-haiku-4-5",
      max_tokens=1024,
      tools=tools,
      messages=messages,
    )

    # ツール呼び出しがない → 完了
    if response.stop_reason == "end_turn":
      return response.content[0].text

    # ツール呼び出しを実行
    tool_results = []
    for block in response.content:
      if block.type == "tool_use":
        result = execute_tool(block.name, block.input)
        tool_results.append({
          "type": "tool_result",
          "tool_use_id": block.id,
          "content": str(result)
        })

    # 結果をメッセージに追加して続行
    messages.append({"role": "assistant", "content": response.content})
    messages.append({"role": "user", "content": tool_results})
```

## パターン2: RAG (検索拡張生成)

外部ドキュメントを検索して回答精度を上げる。

```python
# Supabase pgvector を使った RAG
import openai  # Embedding 生成用

def create_embedding(text: str) -> list[float]:
  response = openai.embeddings.create(
    input=text,
    model="text-embedding-3-small"
  )
  return response.data[0].embedding

# ドキュメントを登録
def index_document(content: str, metadata: dict):
  embedding = create_embedding(content)
  supabase.table('documents').insert({
    'content': content,
    'metadata': metadata,
    'embedding': embedding  # pgvector で格納
  }).execute()

# 検索
def search_documents(query: str, limit: int = 5) -> list[dict]:
  query_embedding = create_embedding(query)
  result = supabase.rpc('match_documents', {
    'query_embedding': query_embedding,
    'match_threshold': 0.7,
    'match_count': limit
  }).execute()
  return result.data

# RAG 回答
def answer_with_rag(question: str) -> str:
  docs = search_documents(question)
  context = "\n\n".join([d['content'] for d in docs])

  response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{
      "role": "user",
      "content": f"Context:\n{context}\n\nQuestion: {question}"
    }]
  )
  return response.content[0].text
```

**pgvector SQL**:

```sql
-- Supabase migration
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT NOT NULL,
  metadata JSONB,
  embedding vector(1536)  -- text-embedding-3-small の次元数
);

-- コサイン類似度検索
CREATE FUNCTION match_documents(
  query_embedding vector(1536),
  match_threshold FLOAT,
  match_count INT
) RETURNS TABLE (id UUID, content TEXT, similarity FLOAT)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT id, content, 1 - (embedding <=> query_embedding) AS similarity
  FROM documents
  WHERE 1 - (embedding <=> query_embedding) > match_threshold
  ORDER BY similarity DESC
  LIMIT match_count;
END;
$$;
```

## パターン3: Memory (長期記憶)

会話をまたいで文脈を保持する。

```python
# セッション間記憶: Supabase に保存
async def save_memory(user_id: str, key: str, value: str):
  await supabase.table('agent_memories').upsert({
    'user_id': user_id,
    'key': key,
    'value': value,
    'updated_at': 'now()'
  }).execute()

async def load_memories(user_id: str) -> dict:
  result = await supabase.table('agent_memories') \
    .select('key, value') \
    .eq('user_id', user_id) \
    .execute()
  return {row['key']: row['value'] for row in result.data}

# エージェントに記憶を組み込む
async def agent_with_memory(user_id: str, message: str) -> str:
  memories = await load_memories(user_id)
  memory_text = "\n".join([f"- {k}: {v}" for k, v in memories.items()])

  response = client.messages.create(
    model="claude-haiku-4-5",
    max_tokens=1024,
    system=f"ユーザーの記憶:\n{memory_text}",
    messages=[{"role": "user", "content": message}]
  )

  # 重要な情報を記憶として保存
  if "好き" in message or "嫌い" in message:
    await save_memory(user_id, "preference", message)

  return response.content[0].text
```

## 3パターンの組み合わせ

```
実用的なエージェント = Tool Use + RAG + Memory の組み合わせ

例: CS (カスタマーサポート) エージェント
  1. Memory: ユーザー履歴・過去の問い合わせを読み込み
  2. RAG: FAQ ドキュメントから関連情報を検索
  3. Tool Use: チケット作成・メール送信・DB 更新を実行
```

## まとめ

```
シンプルな Q&A   → プロンプトエンジニアリングのみ
外部データ参照   → RAG (pgvector + Supabase)
アクション実行   → Tool Use (Claude API tools)
文脈の維持       → Memory (Supabase upsert)
本番エージェント → 3つの組み合わせ
```

個人開発では「まず Tool Use から始めて、精度が足りなければ RAG を追加し、体験を改善したければ Memory を加える」の順で段階的に構築するのが最も効率的。

