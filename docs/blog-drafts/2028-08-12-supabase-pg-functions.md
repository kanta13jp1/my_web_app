---
title: "Supabase PostgreSQL 関数 — RPC で複雑ロジックをサーバーサイドへ移す"
tags: supabase,AI,個人開発,programming
published: true
---

# Supabase PostgreSQL 関数 — RPC で複雑ロジックをサーバーサイドへ移す

Flutter クライアントに複雑なクエリを書くとネットワーク往復が増える。
PostgreSQL 関数 + RPC で解決する。

## 基本: カスタム RPC 関数を作る

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

## Flutter から呼び出す

```dart
final stats = await supabase.rpc('get_user_stats', params: {
  'p_user_id': supabase.auth.currentUser!.id,
});
print(stats['post_count']);    // 42
print(stats['follower_count']); // 128
```

## テーブルを返す関数

```sql
CREATE OR REPLACE FUNCTION search_posts(p_query TEXT, p_limit INT DEFAULT 10)
RETURNS SETOF posts AS $$
BEGIN
  RETURN QUERY
    SELECT *
    FROM posts
    WHERE to_tsvector('japanese', title || ' ' || content) @@ plainto_tsquery('japanese', p_query)
    ORDER BY ts_rank(to_tsvector('japanese', title || ' ' || content),
                     plainto_tsquery('japanese', p_query)) DESC
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

## RLS との組み合わせ

```sql
-- SECURITY DEFINER で RLS をバイパスして管理者用統計を取得
CREATE OR REPLACE FUNCTION admin_get_daily_stats(p_date DATE)
RETURNS JSON AS $$
BEGIN
  -- この関数を呼べるのは service_role のみ
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

## まとめ

```
RPC 使うケース → 複数テーブルの集計 / 全文検索 / 権限分岐ロジック
SECURITY DEFINER → 管理者専用 (呼び出し権限を必ずチェック)
STABLE          → 副作用なしの関数 (クエリプランナーが最適化可能)
Flutter 呼び出し → supabase.rpc('func_name', params: {...})
```

ロジックをサーバーに移すとクライアントのコードが単純になり、ネットワーク往復も減る。
