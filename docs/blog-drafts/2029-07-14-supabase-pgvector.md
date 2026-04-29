---
title: "Supabase pgvector 完全ガイド — セマンティック検索・RAG・レコメンド を PostgreSQL で実装する"
tags: flutter,supabase,個人開発,AI
published: true
---

# Supabase pgvector 完全ガイド — セマンティック検索・RAG・レコメンド を PostgreSQL で実装する

pgvector は PostgreSQL にベクトル型を追加する拡張です。Supabase では標準で有効化されており、セマンティック検索・RAG (Retrieval-Augmented Generation)・レコメンドシステムを PostgreSQL だけで構築できます。

## pgvector の有効化

```sql
-- Supabase では既にインストール済み
CREATE EXTENSION IF NOT EXISTS vector;
```

## テーブル設計

```sql
-- ドキュメント埋め込みテーブル
CREATE TABLE documents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  embedding vector(1536),  -- OpenAI text-embedding-3-small の次元数
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ベクトルインデックス (IVFFlat — 近似最近傍、高速)
CREATE INDEX ON documents
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- HNSW インデックス (より高精度、Supabase 推奨)
CREATE INDEX ON documents
USING hnsw (embedding vector_cosine_ops);
```

## 埋め込み生成 (Edge Function)

```typescript
// supabase/functions/embed-document/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  const { text, documentId } = await req.json()

  // OpenAI Embeddings API
  const embeddingRes = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'text-embedding-3-small',
      input: text,
    }),
  })

  const { data } = await embeddingRes.json()
  const embedding = data[0].embedding

  // Supabase に保存
  const { createClient } = await import('npm:@supabase/supabase-js')
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  await supabase.from('documents')
    .update({ embedding })
    .eq('id', documentId)

  return new Response(JSON.stringify({ success: true }))
})
```

## セマンティック検索 (RPC)

```sql
-- 類似ドキュメント検索関数
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding vector(1536),
  match_threshold FLOAT DEFAULT 0.78,
  match_count INT DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  content TEXT,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.title,
    d.content,
    1 - (d.embedding <=> query_embedding) AS similarity
  FROM documents d
  WHERE 1 - (d.embedding <=> query_embedding) > match_threshold
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
```

```dart
// Flutter から検索
Future<List<Document>> semanticSearch(String query) async {
  // 1. クエリをベクトル化 (Edge Function 経由)
  final embeddingRes = await supabase.functions.invoke(
    'embed-query',
    body: {'text': query},
  );
  final embedding = embeddingRes.data['embedding'] as List;

  // 2. RPC で類似検索
  final results = await supabase.rpc('match_documents', params: {
    'query_embedding': embedding,
    'match_threshold': 0.78,
    'match_count': 10,
  });

  return (results as List).map(Document.fromJson).toList();
}
```

## RAG (Retrieval-Augmented Generation)

```typescript
// Edge Function: rag-chat
serve(async (req) => {
  const { question } = await req.json()

  // Step 1: 関連ドキュメントを取得
  const queryEmbedding = await getEmbedding(question)
  const { data: docs } = await supabase.rpc('match_documents', {
    query_embedding: queryEmbedding,
    match_threshold: 0.7,
    match_count: 5,
  })

  // Step 2: コンテキストを構築
  const context = docs.map(d => d.content).join('\n\n')

  // Step 3: Claude で回答生成
  const response = await anthropic.messages.create({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 1024,
    messages: [{
      role: 'user',
      content: `以下のコンテキストに基づいて質問に答えてください。\n\nコンテキスト:\n${context}\n\n質問: ${question}`,
    }],
  })

  return new Response(JSON.stringify({
    answer: response.content[0].text,
    sources: docs.map(d => ({ id: d.id, title: d.title })),
  }))
})
```

## コスト試算

| 用途 | 月間コスト目安 |
|---|---|
| 10万ドキュメント埋め込み (OpenAI) | ~$2 |
| 1万回/日 検索クエリ | ~$3 |
| Supabase pgvector ストレージ | 既存プランに含む |
| **合計** | **~$5/月** |

自分株式会社アプリでは日記・タスク・ノートをすべてベクトル化し、「先週書いたあれ」という自然言語検索を実装しました。検索の質がキーワード検索の 3 倍以上になりました。

---

pgvector を試したことがありますか？どんなユースケースに活用していますか？
