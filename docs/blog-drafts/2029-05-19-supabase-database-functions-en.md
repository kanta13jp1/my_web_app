---
title: "Supabase Database Functions Guide — Serverless Logic with RPC and PL/pgSQL"
tags: supabase,flutter,webdev,indiedev
published: true
---

# Supabase Database Functions Guide — Serverless Logic with RPC and PL/pgSQL

Supabase Database Functions let you move complex business logic into PostgreSQL and call it from Flutter via `rpc()` — no Edge Function deployment needed.

## Why Use Database Functions

- **Atomicity**: Multi-table updates in a single transaction
- **Performance**: Fewer network round-trips, lower latency
- **Security**: Encapsulate logic without bypassing RLS
- **Simplicity**: Skip Deno deployment entirely

## Basic Function

```sql
CREATE OR REPLACE FUNCTION calculate_streak(user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  streak_count INTEGER := 0;
  check_date DATE := CURRENT_DATE;
  has_entry BOOLEAN;
BEGIN
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM journal_entries
      WHERE user_id = $1
        AND DATE(created_at) = check_date
    ) INTO has_entry;

    EXIT WHEN NOT has_entry;
    streak_count := streak_count + 1;
    check_date := check_date - INTERVAL '1 day';
  END LOOP;

  RETURN streak_count;
END;
$$;
```

## Call from Flutter

```dart
final streak = await supabase
    .rpc('calculate_streak', params: {'user_id': userId}) as int;
```

## Table-Returning Function

```sql
CREATE OR REPLACE FUNCTION get_leaderboard(limit_count INT DEFAULT 10)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  total_points INTEGER,
  rank BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id,
    u.display_name,
    COALESCE(SUM(p.points), 0)::INTEGER,
    ROW_NUMBER() OVER (ORDER BY SUM(p.points) DESC)
  FROM auth.users u
  LEFT JOIN points p ON p.user_id = u.id
  GROUP BY u.id, u.display_name
  ORDER BY 3 DESC
  LIMIT limit_count;
END;
$$;
```

## Multi-Table Transaction Function

```sql
CREATE OR REPLACE FUNCTION complete_task(p_task_id UUID, p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  task_points INTEGER;
  new_total   INTEGER;
BEGIN
  UPDATE tasks
  SET completed_at = NOW(), is_completed = TRUE
  WHERE id = p_task_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'task_not_found';
  END IF;

  SELECT points INTO task_points FROM tasks WHERE id = p_task_id;

  INSERT INTO user_points (user_id, points, source_id, source_type)
  VALUES (p_user_id, task_points, p_task_id, 'task');

  SELECT COALESCE(SUM(points), 0) INTO new_total
  FROM user_points WHERE user_id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'points_earned', task_points,
    'total_points', new_total
  );
END;
$$;
```

## SECURITY DEFINER vs INVOKER

```sql
-- DEFINER: runs as function owner (can bypass RLS — use carefully)
-- INVOKER: runs as caller (RLS applies — safer default)

CREATE OR REPLACE FUNCTION get_public_stats()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public  -- prevent search_path injection
AS $$
BEGIN
  RETURN (
    SELECT json_build_object(
      'total_users', COUNT(DISTINCT user_id),
      'total_entries', COUNT(*)
    )
    FROM journal_entries
  );
END;
$$;
```

## Real-World Impact

Moving dashboard aggregation logic from Edge Functions to Database Functions cut average latency by ~40% in my app — fewer cold starts, zero Deno overhead.

Functions I use in production:
- `calculate_streak(user_id)` — real-time streak calculation
- `get_dashboard_summary(user_id)` — single RPC for all home screen KPIs
- `award_achievement(user_id, achievement_id)` — idempotent achievement granting

---

Are you using Supabase RPC in production? How do you decide between Database Functions and Edge Functions? Drop a comment below.
