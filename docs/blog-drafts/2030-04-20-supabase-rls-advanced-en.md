---
title: "Supabase RLS Deep Dive — Multi-Tenant Design, Dynamic Policies, and Performance"
tags: supabase,postgresql,webdev,indiedev
published: true
---

# Supabase RLS Deep Dive — Multi-Tenant Design, Dynamic Policies, and Performance

Row Level Security (RLS) is the foundation of safe multi-user Supabase apps. This post goes beyond "just enable it" — covering multi-tenant architecture, dynamic policies, JWT claims, and performance tuning from a production codebase.

## RLS Basics

```sql
-- Enable RLS on the table
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- SELECT: users see only their own rows
CREATE POLICY "users_own_tasks_select"
ON tasks FOR SELECT
USING (auth.uid() = user_id);

-- INSERT: enforce correct user_id
CREATE POLICY "users_own_tasks_insert"
ON tasks FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- UPDATE
CREATE POLICY "users_own_tasks_update"
ON tasks FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- DELETE
CREATE POLICY "users_own_tasks_delete"
ON tasks FOR DELETE
USING (auth.uid() = user_id);
```

## Multi-Tenant Architecture

### Team-Based Access Control

```sql
CREATE TABLE team_members (
  team_id  UUID REFERENCES teams(id),
  user_id  UUID REFERENCES auth.users(id),
  role     TEXT CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
  PRIMARY KEY (team_id, user_id)
);

-- Team members can read the team's projects
CREATE POLICY "team_members_can_access_projects"
ON projects FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM team_members tm
    WHERE tm.team_id = projects.team_id
      AND tm.user_id = auth.uid()
  )
);

-- Only admins and owners can delete
CREATE POLICY "team_admins_can_delete_projects"
ON projects FOR DELETE
USING (
  EXISTS (
    SELECT 1
    FROM team_members tm
    WHERE tm.team_id = projects.team_id
      AND tm.user_id = auth.uid()
      AND tm.role IN ('owner', 'admin')
  )
);
```

### JWT Custom Claims for Roles

Embed roles in the JWT so policies can read them without a DB round-trip:

```sql
CREATE POLICY "admin_full_access"
ON admin_logs FOR ALL
USING (
  (auth.jwt() ->> 'user_role') = 'admin'
);
```

Inject the claim via a Supabase Auth Hook:

```sql
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event JSONB)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  claims    JSONB;
  user_role TEXT;
BEGIN
  SELECT role INTO user_role
  FROM user_profiles
  WHERE id = (event->>'user_id')::UUID;

  claims := event->'claims';
  claims := jsonb_set(claims, '{user_role}', to_jsonb(COALESCE(user_role, 'member')));

  RETURN jsonb_set(event, '{claims}', claims);
END;
$$;
```

## Dynamic Policies

### Time-Based Access

```sql
-- Posts become public after published_at; authors always see their own
CREATE POLICY "published_posts_are_public"
ON blog_posts FOR SELECT
USING (
  published_at <= NOW()
  OR auth.uid() = author_id
);
```

### Hierarchical Resource Ownership

```sql
-- Comments inherit visibility from their parent post
CREATE POLICY "comments_visible_with_post"
ON comments FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM blog_posts bp
    WHERE bp.id = comments.post_id
      AND (bp.published_at <= NOW() OR bp.author_id = auth.uid())
  )
);
```

### Subscription-Gated Content

```sql
CREATE POLICY "premium_content_access"
ON premium_courses FOR SELECT
USING (
  NOT is_premium
  OR EXISTS (
    SELECT 1
    FROM user_subscriptions us
    WHERE us.user_id = auth.uid()
      AND us.status = 'active'
      AND us.expires_at > NOW()
  )
);
```

## Performance Optimisation

### Index Strategy

Always index the columns referenced in RLS policies:

```sql
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_projects_team_id ON projects(team_id);

-- Covering index for team membership lookups
CREATE INDEX idx_team_members_user_team
ON team_members(user_id, team_id, role);

-- Partial index: only active subscriptions
CREATE INDEX idx_active_subscriptions
ON user_subscriptions(user_id)
WHERE status = 'active' AND expires_at > NOW();
```

### Extract Policies into `SECURITY DEFINER` Functions

Complex `EXISTS` subqueries can be pulled into stable functions that the planner can cache:

```sql
CREATE OR REPLACE FUNCTION is_team_member(p_team_id UUID, p_role TEXT DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM team_members
    WHERE team_id = p_team_id
      AND user_id = auth.uid()
      AND (p_role IS NULL OR role = p_role)
  );
$$;

CREATE POLICY "team_member_access"
ON projects FOR SELECT
USING (is_team_member(team_id));

CREATE POLICY "team_admin_delete"
ON projects FOR DELETE
USING (is_team_member(team_id, 'admin') OR is_team_member(team_id, 'owner'));
```

## Debugging RLS

### Test as a Specific User

```sql
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "user-uuid-here"}';
SELECT * FROM tasks;  -- RLS applied, you see only that user's rows

EXPLAIN ANALYZE SELECT * FROM projects;  -- check policy cost
```

### Inspect Policies

```sql
SELECT
  tablename,
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

## Flutter Client

RLS is transparent from the client — write queries normally:

```dart
class TaskRepository {
  final SupabaseClient _client;
  TaskRepository(this._client);

  // RLS returns only the authenticated user's tasks
  Future<List<Task>> getTasks() async {
    final data = await _client
        .from('tasks')
        .select()
        .order('created_at', ascending: false);
    return data.map(Task.fromJson).toList();
  }

  Future<void> createTask(String title) async {
    await _client.from('tasks').insert({
      'title': title,
      'user_id': _client.auth.currentUser!.id,
    });
  }
}
```

## Summary

| Topic | Best Practice |
|---|---|
| Policy granularity | Separate SELECT / INSERT / UPDATE / DELETE policies |
| Multi-tenant | `team_members` table + `EXISTS` subqueries |
| Performance | Index RLS columns; extract to `SECURITY DEFINER` functions |
| Debugging | `SET LOCAL` to impersonate a user in psql |
| JWT claims | `custom_access_token` hook for role embedding |

Correctly designed RLS means access control gaps in the application layer can't reach your data — the database enforces it.

---

*Running a multi-user life-management app on Supabase RLS in production. Follow the build → [@kanta13jp1](https://x.com/kanta13jp1)*
