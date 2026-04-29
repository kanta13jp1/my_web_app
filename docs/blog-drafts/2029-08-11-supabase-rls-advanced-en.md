---
title: "Supabase RLS Deep Dive — Multi-tenant Access Control"
tags: supabase,webdev,indiedev,flutter
published: true
---

# Supabase RLS Deep Dive — Multi-tenant Access Control

Supabase Row Level Security (RLS) lets you enforce access rules at the database layer using SQL policies. Done right, your app code never needs explicit permission checks. Here are the patterns I use in a multi-tenant SaaS.

## The Basics

```sql
-- Enable RLS on a table
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Only the owner can see their own rows
CREATE POLICY "own_tasks_select"
  ON tasks FOR SELECT
  USING (user_id = auth.uid());

-- INSERT must set user_id to the caller
CREATE POLICY "own_tasks_insert"
  ON tasks FOR INSERT
  WITH CHECK (user_id = auth.uid());
```

## Multi-tenant: Organization-based Access

```sql
CREATE TABLE organizations (
  id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL
);

CREATE TABLE organization_members (
  org_id  UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role    TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member')),
  PRIMARY KEY (org_id, user_id)
);

-- Helper: return the caller's org IDs
CREATE OR REPLACE FUNCTION my_org_ids()
RETURNS SETOF UUID LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT org_id FROM organization_members WHERE user_id = auth.uid()
$$;

CREATE TABLE projects (
  id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  name   TEXT NOT NULL
);
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

-- Read: any org member
CREATE POLICY "org_projects_select"
  ON projects FOR SELECT
  USING (org_id IN (SELECT my_org_ids()));

-- Write: admin or owner only
CREATE POLICY "org_projects_write"
  ON projects FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members
      WHERE org_id = projects.org_id
        AND user_id = auth.uid()
        AND role IN ('owner', 'admin')
    )
  );
```

## Speed Up With JWT Custom Claims

Subquerying `organization_members` on every row is slow. Embed `org_ids` in the JWT instead.

```sql
-- Read from JWT app_metadata (no extra DB hit)
CREATE OR REPLACE FUNCTION auth_org_ids()
RETURNS SETOF UUID LANGUAGE SQL STABLE AS $$
  SELECT jsonb_array_elements_text(
    (auth.jwt() -> 'app_metadata' -> 'org_ids')
  )::UUID
$$;

CREATE POLICY "jwt_projects_select"
  ON projects FOR SELECT
  USING (org_id IN (SELECT auth_org_ids()));
```

```typescript
// Edge Function: refresh JWT claims after org membership changes
const { data: memberships } = await adminClient
  .from('organization_members')
  .select('org_id')
  .eq('user_id', userId);

await adminClient.auth.admin.updateUserById(userId, {
  app_metadata: { org_ids: memberships?.map(m => m.org_id) ?? [] }
});
```

## Public Read + Auth Write

```sql
CREATE TABLE posts (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID REFERENCES auth.users(id),
  title     TEXT NOT NULL,
  published BOOLEAN DEFAULT false
);
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Anyone can read published posts; authors see their own drafts
CREATE POLICY "posts_select"
  ON posts FOR SELECT
  USING (published = true OR author_id = auth.uid());

-- Only the author can write
CREATE POLICY "posts_write"
  ON posts FOR ALL
  USING (author_id = auth.uid())
  WITH CHECK (author_id = auth.uid());
```

## Service Role Bypasses RLS

```typescript
// Full access — server-side only
const adminClient = createClient(url, serviceRoleKey);
// ⚠️ This ignores ALL RLS policies

// User-scoped requests — RLS is enforced
const userClient = createClient(url, anonKey, {
  global: { headers: { Authorization: `Bearer ${userJwt}` } }
});
```

## Performance Checklist

```sql
-- Always index the columns referenced in policies
CREATE INDEX ON tasks (user_id);
CREATE INDEX ON projects (org_id);
CREATE INDEX ON organization_members (user_id);

-- Verify your policy uses an index
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM projects WHERE org_id = '<org>';
```

## Summary

| Pattern | Use when |
|---------|----------|
| `auth.uid()` direct | Personal data |
| Junction table + helper | Multi-tenant org roles |
| JWT custom claims | High-traffic tables (skip JOIN) |
| `published` flag | Public/private content |
| Service Role | Server-side admin operations |

After implementing these patterns, our security audit concluded that zero app-layer permission checks were needed — the database enforces everything.

---

What RLS patterns have you used in production? Leave a comment!
