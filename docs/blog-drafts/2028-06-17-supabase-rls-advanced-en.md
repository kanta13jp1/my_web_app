---
title: "Supabase RLS Advanced Patterns — Team Sharing, Multi-Tenancy, and Admin Access"
tags: supabase,ai,indiedev,programming
published: true
---

# Supabase RLS Advanced Patterns — Team Sharing, Multi-Tenancy, and Admin Access

Go beyond "only see your own data" and model complex permission structures with RLS.

## Team Sharing Pattern

```sql
-- Team membership table
CREATE TABLE team_members (
  team_id  UUID NOT NULL,
  user_id  UUID NOT NULL REFERENCES auth.users,
  role     TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
  PRIMARY KEY (team_id, user_id)
);

-- All team members can read projects
CREATE POLICY "team members can view projects"
  ON projects FOR SELECT
  USING (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid()
    )
  );

-- Only owners and editors can update
CREATE POLICY "editors can update projects"
  ON projects FOR UPDATE
  USING (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid()
        AND role IN ('owner', 'editor')
    )
  );
```

## Multi-Tenancy: Isolate by org_id

```sql
-- Read org_id from a JWT custom claim
CREATE OR REPLACE FUNCTION get_org_id()
RETURNS UUID AS $$
  SELECT (auth.jwt() ->> 'org_id')::UUID;
$$ LANGUAGE SQL STABLE;

-- Restrict all access to the current org
CREATE POLICY "org isolation"
  ON tasks FOR ALL
  USING (org_id = get_org_id());
```

```typescript
// Attach custom claims in an Edge Function or via app_metadata
const { data: { session } } = await supabase.auth.getSession();
// supabase.auth.updateUser() with app_metadata: { org_id: '...' }
```

## Admin Access Without service_role

```sql
-- Admin whitelist table
CREATE TABLE admins (
  user_id UUID PRIMARY KEY REFERENCES auth.users
);

-- Admins can see everything; owners can still see their own data
CREATE POLICY "admins can view all"
  ON projects FOR SELECT
  USING (
    auth.uid() IN (SELECT user_id FROM admins)
    OR owner_id = auth.uid()
  );
```

## RLS Performance Optimization

```sql
-- SLOW: subquery is evaluated for every row
USING (team_id IN (SELECT team_id FROM team_members WHERE user_id = auth.uid()));

-- FAST: rewrite as EXISTS so the planner can use indexes
USING (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_id = projects.team_id
      AND user_id = auth.uid()
  )
);

-- Always add a supporting index
CREATE INDEX idx_team_members_user_id ON team_members(user_id);
```

## Summary

```
Team sharing    → team_members table + role column for RBAC
Multi-tenancy   → JWT custom claim (org_id) for org isolation
Admin access    → admins table + OR condition layered on top
Performance     → EXISTS + index beats IN subquery every time
```

RLS is the single choke point for "who can see what." Always validate your policies with tests.
