---
title: "6 Supabase RLS Patterns for Solo SaaS — auth.uid() and Beyond"
tags: Supabase,PostgreSQL,buildinpublic,security,webdev
published: false
---

# 6 Supabase RLS Patterns for Solo SaaS

## Why You Can't Skip RLS

Supabase exposes tables directly via PostgREST HTTP API. Without RLS, any authenticated user can read anyone else's data:

```
GET /rest/v1/notes?select=*  →  returns ALL notes
```

With RLS enabled, the same query only returns the authenticated user's notes.

## Pattern 1: Own Data Only

```sql
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own read"
  ON notes FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "own write"
  ON notes FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

`auth.uid()` is populated from the JWT automatically. This is Supabase's core security primitive.

## Pattern 2: Admin Sees Everything

```sql
CREATE POLICY "own or admin read"
  ON notes FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.user_id = auth.uid()
        AND user_profiles.is_admin = true
    )
  );
```

Subquery checks the `user_profiles` table (not `profiles` — don't mix them up).

## Pattern 3: Public Content

```sql
-- AI University content is readable by anyone
CREATE POLICY "public read"
  ON ai_university_content FOR SELECT
  USING (true);

-- Only service_role can write
CREATE POLICY "service write"
  ON ai_university_content FOR ALL
  USING (auth.role() = 'service_role');
```

`auth.role() = 'service_role'` means only Edge Functions (server-side) can write. No client can bypass this.

## Pattern 4: Reusable Policy Function

```sql
CREATE OR REPLACE FUNCTION is_own_or_admin(row_user_id uuid)
RETURNS bool AS $$
  SELECT row_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid() AND is_admin = true
    );
$$ LANGUAGE sql SECURITY DEFINER;

CREATE POLICY "use function"
  ON notes FOR SELECT
  USING (is_own_or_admin(user_id));
```

Factor out repeated admin-check logic into a function. Reuse across tables.

## Pattern 5: Leaderboard (Aggregate Without Identity)

```sql
CREATE VIEW ai_university_leaderboard AS
  SELECT
    ROW_NUMBER() OVER (ORDER BY total_score DESC) as rank,
    -- user_id deliberately excluded
    total_score,
    quiz_count,
    updated_at
  FROM ai_university_scores;

GRANT SELECT ON ai_university_leaderboard TO authenticated, anon;
```

The view never exposes `user_id`. Rankings are public; identity stays private. No RLS needed because the sensitive column isn't in the view.

## Pattern 6: Bypass RLS in Edge Functions

```typescript
// Edge Function — service_role bypasses RLS
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

// Safe because this runs server-side only
// NEVER send service_role key to the client
```

Use `service_role` only in Edge Functions. Never in Flutter/browser code.

## Common Mistakes

**1. Missing `WITH CHECK` on INSERT:**
```sql
-- ❌ Only USING — lets users INSERT with another user's user_id
CREATE POLICY "bad" ON notes FOR INSERT USING (user_id = auth.uid());

-- ✅ WITH CHECK prevents forged user_id on INSERT
CREATE POLICY "good" ON notes FOR INSERT WITH CHECK (user_id = auth.uid());
```

**2. Table name confusion:** Supabase docs use `profiles`, but if your table is `user_profiles`, the RLS policy silently fails with 403. Always double-check the table name in every policy.

**3. anon vs authenticated:**
```sql
GRANT SELECT ON notes TO authenticated;       -- login required
GRANT SELECT ON public_content TO anon;       -- open to everyone
```

`anon` is the unauthenticated role. Many "public" endpoints should grant to `anon`.

## Summary

| Pattern | Use case |
|---------|---------|
| Own data | Notes, settings, scores |
| Admin bypass | Admin dashboard |
| Public read | Content, leaderboards |
| Aggregate view | Leaderboard (identity hidden) |
| service_role | Edge Function writes |

Set up RLS at schema design time. Retrofitting is painful. In Flutter + Supabase apps where the client accesses the DB directly, RLS is the only barrier between users' data.

---
Building in public: https://my-web-app-b67f4.web.app/
#Supabase #PostgreSQL #buildinpublic #security
