---
title: "Supabase 全文検索 — PostgreSQL tsvector・日本語対応・インデックス最適化"
tags: supabase,AI,個人開発,programming
published: true
---

# Supabase 全文検索 — PostgreSQL tsvector・日本語対応・インデックス最適化

Supabase で本格的な全文検索を実装する。英語・日本語それぞれの設定を解説する。

## 基本: tsvector カラムとインデックス

```sql
-- 英語 全文検索列
ALTER TABLE articles ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, ''))
  ) STORED;

CREATE INDEX articles_search_idx ON articles USING GIN(search_vector);
```

```dart
// Flutter から検索
final results = await supabase
  .from('articles')
  .select('id, title, content')
  .textSearch('search_vector', query, config: 'english')
  .limit(20);
```

## 日本語全文検索: pgroonga 拡張

```sql
-- Supabase は pgroonga 拡張をサポート
CREATE EXTENSION IF NOT EXISTS pgroonga;

CREATE INDEX articles_pgroonga_idx ON articles
  USING pgroonga(title, content)
  WITH (tokenizer='TokenMecab');  -- MeCab トークナイザー

-- 検索
SELECT id, title,
  pgroonga_score(tableoid, ctid) AS score
FROM articles
WHERE title &@~ '個人開発 Flutter'
   OR content &@~ '個人開発 Flutter'
ORDER BY score DESC
LIMIT 20;
```

## ハイライト付き検索結果

```sql
-- 一致箇所をハイライト (英語)
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

## Flutter での実装 (RPC 経由)

```dart
// supabase/functions で RPC を使う
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

## まとめ

```
英語検索     → tsvector GENERATED ALWAYS + GIN インデックス
日本語検索   → pgroonga 拡張 + MeCab トークナイザー
ハイライト   → ts_headline() で一致箇所を強調
検索精度     → plainto_tsquery (自然文) / to_tsquery (演算子付き)
```

Supabase の全文検索は追加サービス不要で Elasticsearch 相当の機能が使える。
