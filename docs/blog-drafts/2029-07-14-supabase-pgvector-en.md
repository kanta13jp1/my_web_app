---
title: "Supabase pgvector Guide — Semantic Search, RAG, and Recommendations in PostgreSQL"
tags: supabase,flutter,webdev,indiedev
published: true
---

# Supabase pgvector Guide — Semantic Search, RAG, and Recommendations in PostgreSQL

pgvector adds vector types to PostgreSQL. Supabase enables it by default — meaning you can build semantic search, RAG, and recommendation systems without any extra infrastructure.

## Schema Setup

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE documents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  embedding vector(1536),  -- OpenAI text-embedding-3-small dimensions
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- HNSW index (recommended for accuracy)
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops);
```

## Embedding Generation (Edge Function)

```typescript
// embed-document Edge Function
const embeddingRes = await fetch('https://api.openai.com/v1/embeddings', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY')}` },
  body: JSON.stringify({ model: 'text-embedding-3-small', input: text }),
})

const { data } = await embeddingRes.json()
await supabase.from('documents').update({ embedding: data[0].embedding }).eq('id', id)
```

## Semantic Search Function

```sql
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding vector(1536),
  match_threshold FLOAT DEFAULT 0.78,
  match_count INT DEFAULT 10
)
RETURNS TABLE (id UUID, title TEXT, content TEXT, similarity FLOAT)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT d.id, d.title, d.content,
    1 - (d.embedding <=> query_embedding) AS similarity
  FROM documents d
  WHERE 1 - (d.embedding <=> query_embedding) > match_threshold
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
```

```dart
Future<List<Document>> semanticSearch(String query) async {
  final embRes = await supabase.functions.invoke('embed-query', body: {'text': query});
  final embedding = embRes.data['embedding'] as List;

  final results = await supabase.rpc('match_documents', params: {
    'query_embedding': embedding,
    'match_threshold': 0.78,
    'match_count': 10,
  });

  return (results as List).map(Document.fromJson).toList();
}
```

## RAG Pipeline

```typescript
// rag-chat Edge Function
const queryEmbedding = await getEmbedding(question)

const { data: docs } = await supabase.rpc('match_documents', {
  query_embedding: queryEmbedding,
  match_threshold: 0.7,
  match_count: 5,
})

const context = docs.map(d => d.content).join('\n\n')

const response = await anthropic.messages.create({
  model: 'claude-haiku-4-5-20251001',
  max_tokens: 1024,
  messages: [{
    role: 'user',
    content: `Answer based on this context:\n\n${context}\n\nQuestion: ${question}`,
  }],
})

return { answer: response.content[0].text, sources: docs.map(d => d.id) }
```

## Cost Estimate

| Use case | Monthly cost |
|---|---|
| 100K document embeddings (OpenAI) | ~$2 |
| 10K search queries/day | ~$3 |
| Supabase pgvector storage | Included in plan |
| **Total** | **~$5/month** |

## Real-World Impact

I vectorized all journal entries, tasks, and notes in my app. Natural language search like "that thing I wrote last week about..." now returns 3x more relevant results than keyword search.

---

What are you building with vector search? I'd love to hear about non-obvious use cases.
