---
title: "Supabase PostgreSQL 高度クエリ — JSON操作 / Full-text Search / Window関数"
tags: supabase,AI,個人開発,programming
published: true
---

# Supabase PostgreSQL 高度クエリ — JSON操作 / Full-text Search / Window関数

Supabase の `.select()` だけでは実現できない複雑なクエリを Edge Function + SQL で解決する。

## JSON カラムの操作

```sql
-- JSONB カラムへの効率的なクエリ
-- tags: ["flutter", "supabase", "ai"] のような配列を持つ場合

-- 特定タグを含む記事を検索
SELECT id, title
FROM blog_posts
WHERE tags @> '["flutter"]'::jsonb;  -- @> = contains

-- タグのいずれかを含む (OR 検索)
SELECT id, title
FROM blog_posts
WHERE tags ?| array['flutter', 'dart'];  -- ?| = has any key

-- JSONBカラムから値を抽出
SELECT
  id,
  metadata->>'author' AS author,
  (metadata->>'view_count')::int AS view_count
FROM blog_posts
WHERE (metadata->>'published')::boolean = true;
```

**Flutter から RPC で呼ぶ**:

```dart
final posts = await supabase.rpc('search_posts_by_tag', params: {
  'tag_name': 'flutter',
});
```

```sql
-- supabase/functions/search_posts_by_tag.sql
CREATE OR REPLACE FUNCTION search_posts_by_tag(tag_name text)
RETURNS TABLE(id uuid, title text, tags jsonb) AS $$
  SELECT id, title, tags
  FROM blog_posts
  WHERE tags @> jsonb_build_array(tag_name)
  ORDER BY created_at DESC;
$$ LANGUAGE sql SECURITY DEFINER;
```

## Full-text Search: 日本語全文検索

```sql
-- tsvector + tsquery による全文検索
-- 日本語は pg_bigm 拡張が必要 (Supabase Pro 以上)

-- インデックス作成 (マイグレーション)
CREATE INDEX blog_posts_fts_idx
ON blog_posts USING gin(to_tsvector('japanese', title || ' ' || body));

-- 全文検索クエリ
SELECT
  id,
  title,
  ts_rank(
    to_tsvector('japanese', title || ' ' || body),
    to_tsquery('japanese', 'flutter & supabase')
  ) AS rank
FROM blog_posts
WHERE to_tsvector('japanese', title || ' ' || body)
  @@ to_tsquery('japanese', 'flutter & supabase')
ORDER BY rank DESC
LIMIT 20;
```

**英語の場合 (Supabase 標準対応)**:

```sql
-- 英語は追加拡張不要
ALTER TABLE blog_posts
ADD COLUMN fts tsvector
GENERATED ALWAYS AS (
  to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
) STORED;

CREATE INDEX blog_posts_fts_idx ON blog_posts USING gin(fts);

-- Supabase JS SDK の textSearch
```

```dart
final posts = await supabase
  .from('blog_posts')
  .select()
  .textSearch('fts', 'flutter supabase', config: 'english');
```

## Window 関数: 集計なしで順位・累計を計算

```sql
-- 月別 MAU の累計推移
SELECT
  date_trunc('month', created_at) AS month,
  COUNT(DISTINCT user_id) AS mau,
  SUM(COUNT(DISTINCT user_id)) OVER (
    ORDER BY date_trunc('month', created_at)
  ) AS cumulative_users
FROM user_events
GROUP BY date_trunc('month', created_at)
ORDER BY month;

-- ユーザー別のランキング (RANK)
SELECT
  user_id,
  total_score,
  RANK() OVER (ORDER BY total_score DESC) AS rank,
  PERCENT_RANK() OVER (ORDER BY total_score DESC) AS percentile
FROM user_scores;

-- 前月比成長率
SELECT
  month,
  mau,
  LAG(mau) OVER (ORDER BY month) AS prev_mau,
  ROUND(
    (mau - LAG(mau) OVER (ORDER BY month))::numeric
    / NULLIF(LAG(mau) OVER (ORDER BY month), 0) * 100,
    1
  ) AS growth_pct
FROM monthly_mau;
```

## CTE: 複雑なクエリを読みやすく分解

```sql
-- WITH 句で段階的に計算
WITH
active_users AS (
  SELECT DISTINCT user_id
  FROM user_events
  WHERE created_at >= NOW() - INTERVAL '30 days'
),
user_revenue AS (
  SELECT user_id, SUM(amount) AS total_revenue
  FROM payments
  WHERE status = 'completed'
  GROUP BY user_id
),
summary AS (
  SELECT
    au.user_id,
    COALESCE(ur.total_revenue, 0) AS revenue
  FROM active_users au
  LEFT JOIN user_revenue ur USING (user_id)
)
SELECT
  COUNT(*) AS active_users,
  SUM(revenue) AS total_revenue,
  AVG(revenue) AS arpu
FROM summary;
```

## まとめ

```
JSON 操作       → @> (contains) / ?| (any key) で柔軟な検索
Full-text Search → tsvector + GIN インデックス (英語は標準対応)
Window 関数      → 累計/ランキング/前月比を GROUP BY なしで計算
CTE (WITH 句)    → 複雑なクエリを段階的に分解して可読性向上
```

Edge Function 内で直接 SQL を実行することで、Dart 側のロジックを最小化できる。

