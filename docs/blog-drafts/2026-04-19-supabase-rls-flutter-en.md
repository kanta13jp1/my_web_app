---
title: "Supabase Row Level Security in Flutter Web — 3 Real Patterns from Production"
tags: Flutter,Supabase,security,webdev,buildinpublic
published: true
---

# Supabase Row Level Security in Flutter Web — 3 Real Patterns from Production

## Why RLS Matters

When you use Supabase's client-side SDK in Flutter Web, your `anon` key is exposed in the browser. Without Row Level Security (RLS), anyone who finds your key can read or modify all your data.

This article shows 3 RLS patterns used in [Jibun Kabushiki Kaisha](https://my-web-app-b67f4.web.app/), a Flutter Web + Supabase app — from the actual SQL migrations in production.

## The Basics

```sql
-- Enable RLS on a table (default: blocks everything)
ALTER TABLE my_table ENABLE ROW LEVEL SECURITY;

-- auth.uid() = the currently authenticated user's ID (null for anon)
```

- **Flutter client (anon/authenticated key)**: subject to RLS policies
- **Edge Functions (service_role key)**: bypasses RLS by default

## Pattern 1: Personal Data (Quiz Scores)

`ai_university_scores` stores each user's quiz results per AI provider. Users can only read/write their own records.

```sql
CREATE TABLE ai_university_scores (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id text NOT NULL,           -- 'google' | 'openai' | 'deepseek' etc.
  quiz_correct boolean NOT NULL DEFAULT false,
  studied_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider_id)
);

ALTER TABLE ai_university_scores ENABLE ROW LEVEL SECURITY;

-- USING applies to SELECT/UPDATE/DELETE
-- WITH CHECK applies to INSERT/UPDATE (new row check)
CREATE POLICY "users_own_scores" ON ai_university_scores
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

Flutter UPSERT (safe — RLS rejects any row where `user_id` doesn't match):

```dart
await supabase.from('ai_university_scores').upsert({
  'user_id': supabase.auth.currentUser!.id,
  'provider_id': 'google',
  'quiz_correct': true,
  'studied_at': DateTime.now().toIso8601String(),
}, onConflict: 'user_id,provider_id');
```

## Pattern 2: Per-Operation Policies (Learning Streaks)

Sometimes you want fine-grained control — read-only for some operations, write for others. Split policies with `FOR SELECT / FOR INSERT / FOR UPDATE`:

```sql
CREATE TABLE ai_university_streaks (
  user_id         uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  current_streak  int NOT NULL DEFAULT 0,
  longest_streak  int NOT NULL DEFAULT 0,
  last_studied_date date
);

ALTER TABLE ai_university_streaks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "streaks_select_own" ON ai_university_streaks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "streaks_insert_own" ON ai_university_streaks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "streaks_update_own" ON ai_university_streaks
  FOR UPDATE USING (auth.uid() = user_id);
```

For complex update logic (today-vs-yesterday streak calculation), use `SECURITY DEFINER` to run with elevated privileges:

```sql
CREATE OR REPLACE FUNCTION update_ai_university_streak(p_user_id uuid)
  RETURNS TABLE (current_streak int, longest_streak int, is_new_streak_day boolean)
  LANGUAGE plpgsql
  SECURITY DEFINER  -- bypasses RLS, runs as function owner
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Tokyo')::date;
BEGIN
  -- Skip if already studied today
  IF (SELECT last_studied_date FROM ai_university_streaks WHERE user_id = p_user_id) = v_today THEN
    RETURN QUERY SELECT current_streak, longest_streak, false
      FROM ai_university_streaks WHERE user_id = p_user_id;
    RETURN;
  END IF;
  -- ... streak increment / reset logic
END;
$$;
```

Call from Flutter:

```dart
final result = await supabase.rpc('update_ai_university_streak', params: {
  'p_user_id': supabase.auth.currentUser!.id,
});
final streak = result[0]['current_streak'] as int;
```

## Pattern 3: Public Leaderboard + Private Records

The leaderboard aggregates scores for all users, but individual records stay private. The trick: expose a **VIEW** with explicit GRANT instead of the table directly.

```sql
-- Leaderboard view — aggregates across all users
CREATE VIEW ai_university_leaderboard AS
SELECT
  user_id,
  COUNT(*) FILTER (WHERE quiz_correct)::int AS total_correct,
  COUNT(DISTINCT provider_id) AS providers_studied,
  RANK() OVER (ORDER BY COUNT(*) FILTER (WHERE quiz_correct) DESC) AS rank
FROM ai_university_scores
GROUP BY user_id;

-- Grant SELECT to anon and authenticated (bypasses underlying table's RLS)
GRANT SELECT ON ai_university_leaderboard TO anon, authenticated;
```

Key point: **views don't inherit RLS from their base tables**. GRANT on the view lets you expose computed/aggregated data publicly without exposing raw rows.

## Common Pitfalls

### "All my data disappeared after enabling RLS"

No policies = no access. Always add policies immediately after enabling:

```sql
-- Check current policies
SELECT policyname, cmd, qual FROM pg_policies WHERE tablename = 'my_table';
```

### auth.uid() returns null

Unauthenticated (`anon`) requests return `null` for `auth.uid()`. To allow public reads:

```sql
CREATE POLICY "public_read" ON my_table
  FOR SELECT USING (true);
```

### service_role still respects RLS?

By default, `service_role` bypasses RLS. If you created the role without `BYPASSRLS`, grant it explicitly:

```sql
ALTER ROLE service_role BYPASSRLS;
```

## Summary

| Use Case | Pattern |
|----------|---------|
| Personal data | `USING (auth.uid() = user_id)` |
| Per-operation control | Split `FOR SELECT / INSERT / UPDATE` policies |
| Complex server logic | `SECURITY DEFINER` function |
| Public aggregates | VIEW + GRANT (no table exposure) |

Enable RLS on every table the moment you create it — it's much harder to add correctly after data is in production.

---
Building in public with Flutter + Supabase: https://my-web-app-b67f4.web.app/
#Flutter #Supabase #RLS #security #buildinpublic
