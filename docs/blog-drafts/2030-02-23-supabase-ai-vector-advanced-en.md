---
title: "Supabase AI and Vector Advanced — pgvector, Embeddings, RAG, and Semantic Caching"
tags: dart,flutter,webdev,indiedev
published: true
---

# Supabase AI and Vector Advanced — pgvector, Embeddings, RAG, and Semantic Caching

Supabase ships with `pgvector` support out of the box, enabling vector search, RAG pipelines, and semantic caching directly on PostgreSQL. This article covers production-ready patterns for building AI-powered search features with Supabase and Flutter.

## pgvector Index Types: ivfflat vs hnsw

pgvector supports two index algorithms, each with different trade-offs:

| Criteria | ivfflat | hnsw |
|----------|---------|------|
| Build Speed | Fast | Slow (noticeable at scale) |
| Search Accuracy | Medium (tunable via lists) | High |
| Memory Usage | Low | High |
| Best For | Write-heavy, mid-scale | Read-heavy, high-accuracy |

```sql
-- hnsw index for cosine similarity (recommended for most cases)
CREATE INDEX ON documents
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- ivfflat index for inner product
CREATE INDEX ON documents
USING ivfflat (embedding vector_ip_ops)
WITH (lists = 100);
```

For indie projects under one million rows, `hnsw` is recommended. The slower build time is a one-time cost, and query accuracy is consistently better.

## Generating Embeddings and Storing in Supabase

Use OpenAI's `text-embedding-3-small` or Google's `embedding-001` to vectorize text, then store the results in Supabase.

```typescript
// Supabase Edge Function: embed-and-store.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import OpenAI from 'https://esm.sh/openai@4'

const openai = new OpenAI({ apiKey: Deno.env.get('OPENAI_API_KEY')! })
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

export async function embedAndStore(text: string, metadata: Record<string, unknown>) {
  const embeddingResponse = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: text,
  })
  const embedding = embeddingResponse.data[0].embedding

  const { data, error } = await supabase.from('documents').insert({
    content: text,
    embedding,
    metadata,
  })
  if (error) throw error
  return data
}
```

```sql
-- Table schema
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT NOT NULL,
  embedding VECTOR(1536),  -- 1536 dimensions for text-embedding-3-small
  metadata JSONB DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Building a RAG Pipeline

RAG (Retrieval-Augmented Generation) follows four steps: document chunking → embedding → similarity search → LLM answer generation.

```typescript
// Edge Function: rag-query.ts
export async function ragQuery(userQuery: string): Promise<string> {
  // Step 1: Embed the query
  const queryEmbedding = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: userQuery,
  })
  const queryVector = queryEmbedding.data[0].embedding

  // Step 2: Find similar documents (cosine similarity > 0.8, top 5)
  const { data: docs } = await supabase.rpc('match_documents', {
    query_embedding: queryVector,
    match_threshold: 0.8,
    match_count: 5,
  })

  // Step 3: Build context and call LLM
  const context = docs.map((d: any) => d.content).join('\n\n')
  const completion = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      { role: 'system', content: `Answer using the following documents:\n${context}` },
      { role: 'user', content: userQuery },
    ],
  })
  return completion.choices[0].message.content ?? ''
}
```

```sql
-- Similarity search function
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding VECTOR(1536),
  match_threshold FLOAT DEFAULT 0.8,
  match_count INT DEFAULT 5
)
RETURNS TABLE(id UUID, content TEXT, similarity FLOAT)
LANGUAGE SQL STABLE AS $$
  SELECT id, content, 1 - (embedding <=> query_embedding) AS similarity
  FROM documents
  WHERE 1 - (embedding <=> query_embedding) > match_threshold
  ORDER BY similarity DESC
  LIMIT match_count;
$$;
```

## Implementing Semantic Caching

Semantic caching checks if an incoming query's embedding is similar enough to a cached query, avoiding redundant LLM API calls and cutting costs significantly.

```typescript
// semantic-cache.ts
export async function semanticCachedQuery(
  userQuery: string,
  similarityThreshold = 0.95
): Promise<string> {
  const queryVector = await getEmbedding(userQuery)

  // Look for a cached answer with similarity >= 0.95
  const { data: cached } = await supabase.rpc('match_query_cache', {
    query_embedding: queryVector,
    match_threshold: similarityThreshold,
    match_count: 1,
  })

  if (cached && cached.length > 0) {
    console.log('Cache hit! similarity:', cached[0].similarity)
    return cached[0].answer
  }

  // Cache miss: run RAG and store the result
  const answer = await ragQuery(userQuery)
  await supabase.from('query_cache').insert({
    query: userQuery,
    embedding: queryVector,
    answer,
  })
  return answer
}
```

A threshold of `0.95` works well in production. Too high and the cache hit rate suffers; too low and semantically different questions receive the same answer.

## Calling Vector Search from Flutter

Invoke the Edge Function from Flutter using `supabase.functions.invoke()`:

```dart
// vector_search_service.dart
class VectorSearchService {
  final SupabaseClient _supabase;

  VectorSearchService(this._supabase);

  Future<String> ask(String query) async {
    final response = await _supabase.functions.invoke(
      'rag-query',
      body: {'query': query},
    );
    if (response.status != 200) {
      throw Exception('RAG query failed: ${response.data}');
    }
    return response.data['answer'] as String;
  }
}

// Riverpod provider
@riverpod
VectorSearchService vectorSearch(VectorSearchRef ref) {
  return VectorSearchService(ref.watch(supabaseClientProvider));
}

@riverpod
Future<String> ragAnswer(RagAnswerRef ref, String query) async {
  return ref.watch(vectorSearchProvider).ask(query);
}
```

The combination of pgvector, Supabase Edge Functions, and Flutter gives you a fully managed AI search backend for well under $25/month — a practical choice for indie products that need smart search without infrastructure overhead.

---

*This series covers Flutter, Supabase, and indie SaaS development. New articles every week.*
