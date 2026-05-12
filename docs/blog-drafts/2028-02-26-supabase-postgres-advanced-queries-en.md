---
title: "Supabase PostgreSQL Advanced Queries: JSON, Full-Text Search, and Window Functions"
tags: supabase,ai,indiedev,programming
published: true
---

# Supabase PostgreSQL Advanced Queries: JSON, Full-Text Search, and Window Functions

When `.select()` isn't enough. Complex queries in Edge Functions using raw SQL.

## JSON Column Operations

```sql
-- JSONB column queries
-- e.g. tags: ["flutter", "supabase", "ai"]

-- Posts containing a specific tag
SELECT id, title
FROM blog_posts
WHERE tags @> '["flutter"]'::jsonb;  -- @> = contains

-- Posts with any of these tags (OR)
SELECT id, title
FROM blog_posts
WHERE tags ?| array['flutter', 'dart'];  -- ?| = has any key

-- Extract values from JSONB
SELECT
  id,
  metadata->>'author' AS author,
  (metadata->>'view_count')::int AS view_count
FROM blog_posts
WHERE (metadata->>'published')::boolean = true;
```

**Call via RPC from Flutter**:

```dart
final posts = await supabase.rpc('search_posts_by_tag', params: {
  'tag_name': 'flutter',
});
```

```sql
CREATE OR REPLACE FUNCTION search_posts_by_tag(tag_name text)
RETURNS TABLE(id uuid, title text, tags jsonb) AS $$
  SELECT id, title, tags
  FROM blog_posts
  WHERE tags @> jsonb_build_array(tag_name)
  ORDER BY created_at DESC;
$$ LANGUAGE sql SECURITY DEFINER;
```

## Full-Text Search

```sql
-- English FTS (no extra extension needed in Supabase)
ALTER TABLE blog_posts
ADD COLUMN fts tsvector
GENERATED ALWAYS AS (
  to_tsvector('english',
    coalesce(title, '') || ' ' || coalesce(body, ''))
) STORED;

CREATE INDEX blog_posts_fts_idx ON blog_posts USING gin(fts);
```

```dart
// Flutter SDK textSearch
final posts = await supabase
  .from('blog_posts')
  .select()
  .textSearch('fts', 'flutter supabase', config: 'english');
```

```sql
-- With ranking
SELECT
  id,
  title,
  ts_rank(fts, to_tsquery('english', 'flutter & supabase')) AS rank
FROM blog_posts
WHERE fts @@ to_tsquery('english', 'flutter & supabase')
ORDER BY rank DESC
LIMIT 20;
```

## Window Functions: Rank and Cumulative Without GROUP BY

```sql
-- Monthly MAU with running total
SELECT
  date_trunc('month', created_at) AS month,
  COUNT(DISTINCT user_id) AS mau,
  SUM(COUNT(DISTINCT user_id)) OVER (
    ORDER BY date_trunc('month', created_at)
  ) AS cumulative_users
FROM user_events
GROUP BY date_trunc('month', created_at)
ORDER BY month;

-- Leaderboard rank
SELECT
  user_id,
  total_score,
  RANK() OVER (ORDER BY total_score DESC) AS rank,
  PERCENT_RANK() OVER (ORDER BY total_score DESC) AS percentile
FROM user_scores;

-- Month-over-month growth
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

## CTE: Readable Multi-Step Queries

```sql
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

## Summary

```
JSON ops        → @> (contains) / ?| (any key) for flexible searches
Full-text       → tsvector + GIN index (English: built-in, Japanese: pg_bigm)
Window funcs    → cumulative totals, rankings, MoM growth without extra GROUP BY
CTE (WITH)      → break complex queries into readable steps
```

Put SQL in Edge Functions and keep your Dart layer thin.

