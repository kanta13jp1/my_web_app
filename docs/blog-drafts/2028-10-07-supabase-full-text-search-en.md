---
title: "Supabase Full-Text Search — PostgreSQL tsvector, Multilingual Support, and Index Optimization"
tags: supabase,ai,indiedev,programming
published: true
---

# Supabase Full-Text Search — PostgreSQL tsvector, Multilingual Support, and Index Optimization

Implement serious full-text search in Supabase. English and multilingual configurations explained.

## Basics: tsvector Column and Index

```sql
-- Full-text search column for English
ALTER TABLE articles ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, ''))
  ) STORED;

CREATE INDEX articles_search_idx ON articles USING GIN(search_vector);
```

```dart
// Search from Flutter
final results = await supabase
  .from('articles')
  .select('id, title, content')
  .textSearch('search_vector', query, config: 'english')
  .limit(20);
```

## Multilingual Full-Text Search with pgroonga

```sql
-- Supabase supports the pgroonga extension
CREATE EXTENSION IF NOT EXISTS pgroonga;

CREATE INDEX articles_pgroonga_idx ON articles
  USING pgroonga(title, content)
  WITH (tokenizer='TokenNgram');  -- N-gram tokenizer for CJK languages

-- Search query
SELECT id, title,
  pgroonga_score(tableoid, ctid) AS score
FROM articles
WHERE title &@~ 'Flutter performance'
   OR content &@~ 'Flutter performance'
ORDER BY score DESC
LIMIT 20;
```

## Search Results with Highlights

```sql
-- Highlight matching passages (English)
SELECT
  id,
  title,
  ts_headline(
    'english',
    content,
    plainto_tsquery('english', 'Flutter performance'),
    'StartSel=<mark>, StopSel=</mark>, MaxWords=30'
  ) AS excerpt
FROM articles
WHERE search_vector @@ plainto_tsquery('english', 'Flutter performance');
```

## Flutter Implementation (via RPC)

```dart
Future<List<SearchResult>> searchArticles(String query) async {
  final results = await supabase.rpc('search_articles', params: {
    'p_query': query,
    'p_limit': 20,
  });
  return (results as List)
      .map((r) => SearchResult.fromJson(r as Map<String, dynamic>))
      .toList();
}
```

## Summary

```
English search      → tsvector GENERATED ALWAYS + GIN index
Multilingual        → pgroonga extension + N-gram tokenizer
Highlights          → ts_headline() to emphasize matches
Query types         → plainto_tsquery (natural language) / to_tsquery (with operators)
```

Supabase full-text search delivers Elasticsearch-class capabilities with no extra service.
