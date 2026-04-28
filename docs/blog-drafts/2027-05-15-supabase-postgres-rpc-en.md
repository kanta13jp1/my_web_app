---
title: "Supabase Postgres Functions and RPC: Replace Edge Functions with SQL"
tags: supabase,postgresql,indiedev,ai
published: true
---

# Supabase Postgres Functions and RPC: Replace Edge Functions with SQL

As Edge Function count grows, so does management overhead. Postgres functions (RPC) handle many cases that don't need a full Edge Function. Here's how I reduced my EF count by 38%.

## What Postgres Functions Are

```sql
CREATE OR REPLACE FUNCTION function_name(param1 type1, param2 type2)
RETURNS return_type
LANGUAGE plpgsql
SECURITY DEFINER  -- runs as function owner, bypasses RLS
AS $$
BEGIN
  -- logic here
  RETURN result;
END;
$$;
```

Call from Flutter:

```dart
final result = await supabase.rpc('function_name', params: {
  'param1': value1,
  'param2': value2,
});
```

**SECURITY DEFINER**: runs as the function owner → bypasses RLS. Use for admin operations.
**SECURITY INVOKER** (default): runs as calling user → RLS applies.

## Pattern 1: Move Aggregations to RPC

Before (filtering client-side):

```dart
// Flutter: fetch all, aggregate on client
final data = await supabase.from('development_achievements').select('*');
final total = data.length;
final thisWeek = data.where((e) => isThisWeek(e['completed_at'])).length;
```

After (aggregate in DB):

```sql
CREATE OR REPLACE FUNCTION get_achievement_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE result json;
BEGIN
  SELECT json_build_object(
    'total', COUNT(*),
    'this_week', COUNT(*) FILTER (WHERE completed_at >= NOW() - INTERVAL '7 days'),
    'this_month', COUNT(*) FILTER (WHERE completed_at >= NOW() - INTERVAL '30 days')
  ) INTO result
  FROM development_achievements
  WHERE user_id = auth.uid();
  RETURN result;
END;
$$;
```

```dart
final stats = await supabase.rpc('get_achievement_stats');
```

Network transfer: all rows → one JSON object.

## Pattern 2: Transactions

```sql
CREATE OR REPLACE FUNCTION transfer_points(
  from_user uuid,
  to_user uuid,
  amount int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE user_points SET points = points - amount WHERE user_id = from_user;
  UPDATE user_points SET points = points + amount WHERE user_id = to_user;

  INSERT INTO point_transfers (from_user, to_user, amount, transferred_at)
  VALUES (from_user, to_user, amount, NOW());
END;
$$;
```

Implementing transactions in an Edge Function requires careful error handling and rollback logic. In a DB function, it's a single atomic unit by default.

## Pattern 3: Hide Complex JOINs

```sql
CREATE OR REPLACE FUNCTION get_user_dashboard(target_user_id uuid DEFAULT auth.uid())
RETURNS json
LANGUAGE sql
SECURITY INVOKER
AS $$
  SELECT json_build_object(
    'profile', (SELECT row_to_json(p) FROM profiles p WHERE p.id = target_user_id),
    'recent_achievements', (
      SELECT json_agg(a ORDER BY a.completed_at DESC)
      FROM (SELECT * FROM development_achievements
            WHERE user_id = target_user_id
            ORDER BY completed_at DESC LIMIT 5) a
    ),
    'stats', (
      SELECT json_build_object(
        'total_achievements', COUNT(*),
        'streak_days', MAX(streak_days)
      )
      FROM development_achievements WHERE user_id = target_user_id
    )
  );
$$;
```

Flutter side: `supabase.rpc('get_user_dashboard')` — one line.

## When RPC is Enough vs When You Need an Edge Function

```
RPC is enough:
  ✅ Aggregation / statistics queries
  ✅ Multi-table transactions
  ✅ Complex JOIN abstraction
  ✅ Admin operations bypassing RLS

Edge Function required:
  ✅ External API calls (Resend / Anthropic / Stripe)
  ✅ Cron tasks (schedule-hub)
  ✅ Webhook receivers
  ✅ Heavy computation (Deno Worker)
```

## The Reduction I Achieved

After migrating to RPC in my production project:

```
Before: 45 Edge Functions
After:  28 Edge Functions (-38%)

Aggregation EFs: 8 → RPC
Transaction EFs: 5 → RPC
Complex JOIN EFs: 4 → RPC
```

Less deploy time, fewer Deno dependencies, no cold start overhead for the migrated functions.

## Summary

In Supabase, the principle is "do in DB what can be done in DB." RPC is just SQL, callable from the Supabase client in one line. Before creating an Edge Function, ask: can this be a Postgres function?
