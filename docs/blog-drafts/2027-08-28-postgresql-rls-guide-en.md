---
title: "PostgreSQL RLS Guide: Multi-Tenant Security with Supabase"
tags: supabase,postgresql,indiedev,ai
published: true
---

# PostgreSQL RLS Guide: Multi-Tenant Security with Supabase

Row Level Security (RLS) is one of PostgreSQL's most powerful features. In Supabase, it's essential — and a misconfiguration means data leaks. Here's how to get it right.

## The Basics

```sql
-- Enable RLS on a table
ALTER TABLE user_notes ENABLE ROW LEVEL SECURITY;

-- With RLS enabled and no policies, nobody can access any rows (default deny)
-- Always add policies after enabling
```

## Core Pattern: Users Can Only See Their Own Data

```sql
-- SELECT: read own rows only
CREATE POLICY "user_can_read_own_notes"
  ON user_notes
  FOR SELECT
  USING (auth.uid() = user_id);

-- INSERT: only allowed with matching user_id
CREATE POLICY "user_can_insert_own_notes"
  ON user_notes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- UPDATE: own rows only
CREATE POLICY "user_can_update_own_notes"
  ON user_notes
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: own rows only
CREATE POLICY "user_can_delete_own_notes"
  ON user_notes
  FOR DELETE
  USING (auth.uid() = user_id);
```

`USING` = filter on read / `WITH CHECK` = filter on write.

## Admin Access: service_role Bypasses RLS

```sql
CREATE POLICY "service_role_full_access"
  ON user_notes
  FOR ALL
  USING (auth.jwt() ->> 'role' = 'service_role');
```

Edge Functions use `SUPABASE_SERVICE_ROLE_KEY` → RLS bypassed. Flutter clients use `anon` key → RLS enforced.

## Public/Private Toggle Pattern

```sql
CREATE POLICY "public_notes_readable_by_all"
  ON public_notes
  FOR SELECT
  USING (is_public = true OR auth.uid() = user_id);

-- Public notes: anyone can read
-- Private notes: only owner can read
```

## Team Access: Share Within Organization

```sql
CREATE POLICY "team_members_can_read_team_notes"
  ON team_notes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = team_notes.team_id
        AND team_members.user_id = auth.uid()
    )
  );
```

## Flutter Integration

```dart
// Flutter uses anon key — RLS is automatically enforced
final supabase = Supabase.instance.client;

// Only returns rows belonging to the current user
final notes = await supabase
    .from('user_notes')
    .select('*');

// INSERT: user_id is checked by WITH CHECK policy
await supabase.from('user_notes').insert({
  'title': 'New note',
  'user_id': supabase.auth.currentUser!.id,
});
```

## Debugging RLS

```sql
-- Test policies as a specific user
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "user-uuid-here"}';

SELECT * FROM user_notes;  -- returns policy-filtered results
RESET role;
```

## Common Mistakes

```sql
-- ❌ BAD: INSERT without user_id — fails RLS check
INSERT INTO user_notes (title) VALUES ('test');
-- ERROR: new row violates row-level security policy

-- ✅ GOOD: always include user_id
INSERT INTO user_notes (title, user_id)
VALUES ('test', auth.uid());

-- BETTER: set user_id as default
ALTER TABLE user_notes
  ALTER COLUMN user_id SET DEFAULT auth.uid();
```

## Checklist

```
RLS design checklist:
  ☑ ENABLE ROW LEVEL SECURITY on every table
  ☑ Create policies for SELECT / INSERT / UPDATE / DELETE
  ☑ Use auth.uid() to scope access to own rows
  ☑ service_role key stays server-side (never in Flutter)
  ☑ Set DEFAULT auth.uid() on user_id columns
```

With RLS correctly designed, you don't need application-layer filtering. Security is enforced at the database level — the right place for it.
