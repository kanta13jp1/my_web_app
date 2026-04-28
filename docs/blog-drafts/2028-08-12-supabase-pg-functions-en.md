---
title: "Supabase PostgreSQL Functions — Move Complex Logic Server-Side with RPC"
tags: supabase,ai,indiedev,programming
published: true
---

# Supabase PostgreSQL Functions — Move Complex Logic Server-Side with RPC

Writing complex queries on the Flutter client multiplies network round-trips. PostgreSQL functions + RPC solve this.

## Basics: Create a Custom RPC Function

```sql
-- supabase/migrations/20280812000000_create_get_user_stats.sql
CREATE OR REPLACE FUNCTION get_user_stats(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'post_count',     (SELECT COUNT(*) FROM posts WHERE user_id = p_user_id),
    'comment_count',  (SELECT COUNT(*) FROM comments WHERE user_id = p_user_id),
    'follower_count', (SELECT COUNT(*) FROM follows WHERE followee_id = p_user_id),
    'joined_at',      (SELECT created_at FROM profiles WHERE id = p_user_id)
  ) INTO result;
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Calling from Flutter

```dart
final stats = await supabase.rpc('get_user_stats', params: {
  'p_user_id': supabase.auth.currentUser!.id,
});
print(stats['post_count']);     // 42
print(stats['follower_count']); // 128
```

## Functions That Return Sets

```sql
CREATE OR REPLACE FUNCTION search_posts(p_query TEXT, p_limit INT DEFAULT 10)
RETURNS SETOF posts AS $$
BEGIN
  RETURN QUERY
    SELECT *
    FROM posts
    WHERE to_tsvector('english', title || ' ' || content) @@ plainto_tsquery('english', p_query)
    ORDER BY ts_rank(to_tsvector('english', title || ' ' || content),
                     plainto_tsquery('english', p_query)) DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;
```

```dart
final List results = await supabase.rpc('search_posts', params: {
  'p_query': 'Flutter Riverpod',
  'p_limit': 20,
});
```

## Combining with RLS

```sql
-- SECURITY DEFINER bypasses RLS to fetch admin stats
CREATE OR REPLACE FUNCTION admin_get_daily_stats(p_date DATE)
RETURNS JSON AS $$
BEGIN
  -- Only service_role may call this function
  IF auth.role() != 'service_role' THEN
    RAISE EXCEPTION 'permission denied';
  END IF;

  RETURN json_build_object(
    'new_users',    (SELECT COUNT(*) FROM profiles WHERE created_at::date = p_date),
    'new_posts',    (SELECT COUNT(*) FROM posts WHERE created_at::date = p_date),
    'active_users', (SELECT COUNT(DISTINCT user_id) FROM posts WHERE created_at::date = p_date)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Summary

```
Use RPC when   → aggregating multiple tables / full-text search / permission branching
SECURITY DEFINER → admin-only (always verify the caller's role)
STABLE         → side-effect-free functions (query planner can optimize)
Flutter call   → supabase.rpc('func_name', params: {...})
```

Moving logic server-side simplifies the client and reduces network round-trips.
