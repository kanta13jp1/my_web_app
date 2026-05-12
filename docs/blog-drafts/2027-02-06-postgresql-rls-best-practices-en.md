---
title: "PostgreSQL Row Level Security: The Right Way to Lock Down Your Data"
tags: supabase,postgresql,ai,indiedev
published: true
---

# PostgreSQL Row Level Security: The Right Way to Lock Down Your Data

Row Level Security (RLS) enforces access control inside the database, not the application layer. After running 12 parallel AI instances touching the same Supabase database, this is the pattern that keeps the data clean.

## Why Application-Layer Checks Aren't Enough

```
App-layer check:
  request → Edge Function → "Does this user have access?" → SQL
  Problem: EF bug / new instance forgets the check → full table exposed

RLS:
  request → SQL runs → PostgreSQL filters automatically → only visible rows returned
  Problem: none. The filter runs inside the engine
```

RLS-enabled tables return zero rows to anyone with no policy. **Deny-by-default is automatic.** You opt in to access explicitly.

## Basic Pattern: Users See Their Own Data

```sql
-- Enable RLS
ALTER TABLE user_notes ENABLE ROW LEVEL SECURITY;

-- SELECT: own rows only
CREATE POLICY "users_select_own" ON user_notes
  FOR SELECT
  USING (auth.uid() = user_id);

-- INSERT: must match own user_id
CREATE POLICY "users_insert_own" ON user_notes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- UPDATE: own rows, own user_id only
CREATE POLICY "users_update_own" ON user_notes
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: own rows only
CREATE POLICY "users_delete_own" ON user_notes
  FOR DELETE
  USING (auth.uid() = user_id);
```

`USING` = which rows are visible. `WITH CHECK` = which rows can be written. UPDATE needs both.

## How auth.uid() Works

```sql
-- auth.uid() is parsed from the JWT automatically
-- Supabase client sends Authorization: Bearer <token>
-- PostgreSQL resolves auth.uid() from the claim

-- Verify in psql
SELECT auth.uid();   -- returns current session's user_id
SELECT auth.role();  -- 'anon' or 'authenticated'
```

Edge Functions use the Service Role Key, so `auth.uid()` returns NULL there. EFs bypass RLS entirely — which means **EFs are responsible for their own access checks**.

## Shared Data Pattern

```sql
-- Notes: public OR own
CREATE POLICY "notes_select" ON notes
  FOR SELECT
  USING (
    is_public = true
    OR auth.uid() = user_id
  );
```

## Admin Pattern

```sql
CREATE TABLE admin_users (user_id UUID PRIMARY KEY);

CREATE POLICY "admin_select_all" ON user_notes
  FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM admin_users WHERE user_id = auth.uid()
    )
  );
```

The EXISTS subquery hits the PK index. Fast even at scale.

## Tenant Pattern (Teams / Organizations)

```sql
CREATE POLICY "org_members_select" ON org_documents
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM organization_members
      WHERE user_id = auth.uid()
    )
  );
```

This project is single-tenant, but if it ever goes multi-tenant SaaS, this is the policy shape.

## RLS + Edge Functions: The Right Split

```typescript
// Service Role Key: bypasses RLS (for admin ops)
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

// Pass user JWT: RLS applies automatically
const supabaseUser = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_ANON_KEY')!,
  { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
);

// supabaseUser queries are filtered by RLS
// supabaseAdmin queries return everything — handle with care
```

## Debugging RLS

```sql
-- List all policies on a table
SELECT schemaname, tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'user_notes';

-- Test as a specific user
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "user-uuid-here"}';
SELECT * FROM user_notes;  -- RLS-filtered result
RESET ROLE;
```

## Performance Notes

**1. `auth.uid()` evaluates per row.**  
Policies with `user_id = auth.uid()` use an index — fast. Subquery-heavy policies (e.g. checking team membership) need careful indexing.

**2. Cache expensive checks with `SECURITY DEFINER` functions.**

```sql
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid());
$$;

CREATE POLICY "admin_select" ON user_notes
  FOR SELECT
  USING (auth.uid() = user_id OR is_admin());
```

`STABLE` lets PostgreSQL cache the result within a single statement.

## The Four Rules

1. **`ENABLE ROW LEVEL SECURITY` on every table.** Forgetting this is the #1 RLS mistake.
2. **Trust deny-by-default.** Zero policies = zero rows exposed. No fallback needed.
3. **EFs use Service Role Key — they bypass RLS.** Write your own checks inside EFs, or switch to the user JWT.
4. **Index `user_id`.** The RLS filter runs on every query; the index makes it free.

Don't put auth logic in the application layer. Put it in the database, where it can't be skipped.
