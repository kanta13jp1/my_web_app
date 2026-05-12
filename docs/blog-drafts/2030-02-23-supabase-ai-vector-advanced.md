---
title: "Supabase AI・Vector 上級編 — pgvector・Embedding・RAG・Semantic Caching の実装"
tags: flutter,dart,個人開発,AI
published: true
---

# Supabase AI・Vector 上級編 — pgvector・Embedding・RAG・Semantic Caching の実装

Supabase は `pgvector` 拡張を標準サポートしており、ベクトル検索・RAG・Semantic Caching を PostgreSQL 上で直接実装できます。本記事では、実際のプロダクションコードで使えるパターンを解説します。

## pgvector のインデックス: ivfflat vs hnsw

`pgvector` には 2 種類のインデックスがあります。

| 項目 | ivfflat | hnsw |
|------|---------|------|
| 構築速度 | 速い | 遅い（大規模データで顕著） |
| 検索精度 | 中（リスト数で調整） | 高 |
| メモリ使用量 | 低 | 高 |
| 向くケース | 書き込み多・中規模 | 読み込み多・高精度要求 |

```sql
-- hnsw インデックス（コサイン類似度）
CREATE INDEX ON documents
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- ivfflat インデックス（内積）
CREATE INDEX ON documents
USING ivfflat (embedding vector_ip_ops)
WITH (lists = 100);
```

100 万件以下の個人開発規模なら `hnsw` を推奨します。インデックス構築はやや遅くなりますが、クエリ精度が安定します。

## Embedding の生成と Supabase への保存

OpenAI の `text-embedding-3-small` または Gemini の `embedding-001` でテキストをベクトル化し、Supabase に保存します。

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
  // Embedding 生成
  const embeddingResponse = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: text,
  })
  const embedding = embeddingResponse.data[0].embedding

  // Supabase に保存
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
-- テーブル定義
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT NOT NULL,
  embedding VECTOR(1536),  -- text-embedding-3-small は 1536 次元
  metadata JSONB DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## RAG パイプラインの実装

RAG（Retrieval-Augmented Generation）は「文書チャンキング → Embedding → 類似検索 → LLM 回答生成」の 4 ステップです。

```typescript
// Edge Function: rag-query.ts
export async function ragQuery(userQuery: string): Promise<string> {
  // Step 1: クエリを Embedding 化
  const queryEmbedding = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: userQuery,
  })
  const queryVector = queryEmbedding.data[0].embedding

  // Step 2: 類似文書を検索（コサイン類似度 > 0.8 上位 5 件）
  const { data: docs } = await supabase.rpc('match_documents', {
    query_embedding: queryVector,
    match_threshold: 0.8,
    match_count: 5,
  })

  // Step 3: コンテキストを組み立てて LLM に送信
  const context = docs.map((d: any) => d.content).join('\n\n')
  const completion = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      { role: 'system', content: `以下のドキュメントを参考に回答してください:\n${context}` },
      { role: 'user', content: userQuery },
    ],
  })
  return completion.choices[0].message.content ?? ''
}
```

```sql
-- 類似検索関数
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

## Semantic Caching の実装

同一クエリの Embedding 類似度でキャッシュ判定することで、LLM API コストを大幅削減できます。

```typescript
// semantic-cache.ts
export async function semanticCachedQuery(
  userQuery: string,
  similarityThreshold = 0.95
): Promise<string> {
  const queryVector = await getEmbedding(userQuery)

  // キャッシュ検索（類似度 0.95 以上なら同一クエリと見なす）
  const { data: cached } = await supabase.rpc('match_query_cache', {
    query_embedding: queryVector,
    match_threshold: similarityThreshold,
    match_count: 1,
  })

  if (cached && cached.length > 0) {
    console.log('Cache hit! similarity:', cached[0].similarity)
    return cached[0].answer
  }

  // キャッシュミス: RAG 実行 → 結果をキャッシュに保存
  const answer = await ragQuery(userQuery)
  await supabase.from('query_cache').insert({
    query: userQuery,
    embedding: queryVector,
    answer,
  })
  return answer
}
```

本番では `similarity_threshold = 0.95` が実用的です。高すぎるとキャッシュヒット率が下がり、低すぎると違う質問に同じ回答が返る誤動作が起きます。

## Flutter からの Vector 検索呼び出し

Edge Function を Flutter から呼び出す際は、`supabase.functions.invoke()` を使います。

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

// Riverpod Provider
@riverpod
VectorSearchService vectorSearch(VectorSearchRef ref) {
  return VectorSearchService(ref.watch(supabaseClientProvider));
}

@riverpod
Future<String> ragAnswer(RagAnswerRef ref, String query) async {
  return ref.watch(vectorSearchProvider).ask(query);
}
```

pgvector + Supabase Edge Functions の組み合わせは、フルマネージドな RAG バックエンドを最小コストで構築できる強力な選択肢です。月 $25 以下のコストで本格的な AI 検索機能を個人開発に組み込めます。

---

*このシリーズは Flutter × Supabase × インディー開発をテーマに毎週更新しています。*
