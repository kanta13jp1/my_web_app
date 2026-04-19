---
title: "Supabase Migration Best Practices — Timestamp Naming, Conflict Prevention, Seed Separation"
tags: Supabase,PostgreSQL,buildinpublic,database,webdev
published: true
---

# Supabase Migration Best Practices

## File Naming Convention

```text
YYYYMMDDXXXXXX_descriptive_name.sql
e.g. 20260419120000_add_tags_to_notes.sql
```

The 6-digit suffix (XXXXXX) is a sequence counter for same-day files:

```text
20260419000000_create_users.sql
20260419010000_create_notes.sql
20260419020000_add_tags_to_notes.sql
```

## Common Collision Patterns

### Problem: Multiple Instances Use the Same Timestamp

With 5 parallel dev instances, `20260419000000_xxx.sql` collisions happen regularly.

**Fix**: Check the latest timestamp before creating a new file:

```bash
ls supabase/migrations/ | tail -5
# 20260419040000_fix_feature_releases_routes.sql
# → Next file: 20260419050000_
```

### Problem: SQLSTATE 42P10 — ON CONFLICT Column Not in UNIQUE Constraint

```sql
-- ❌ Specifying id, but id has no UNIQUE constraint
INSERT INTO notes (user_id, title)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;

-- ✅ Use the column that actually has a UNIQUE constraint
INSERT INTO notes (user_id, title)
ON CONFLICT (user_id, slug) DO UPDATE SET title = EXCLUDED.title;
```

`ON CONFLICT` columns must have a UNIQUE constraint or be a PRIMARY KEY.

### Problem: Table Name Confusion

```sql
-- ❌ Supabase docs say 'profiles', but this project uses 'user_profiles'
SELECT is_admin FROM profiles WHERE user_id = auth.uid();

-- ✅ Always check the actual table name
SELECT is_admin FROM user_profiles WHERE user_id = auth.uid();
```

RLS policies silently fail with 403 if you use the wrong table name.

## Separate Schema Changes from Seed Data

```text
# Schema
20260419000000_create_ai_university_content.sql

# Seed data (separate files)
20260419010000_seed_openai_ai_university.sql
20260419020000_seed_anthropic_ai_university.sql
```

Seed file pattern for idempotency:

```sql
INSERT INTO ai_university_content (provider, category, title, content)
VALUES
  ('openai', 'overview', 'OpenAI Overview', '...'),
  ('openai', 'models', 'GPT-4o, o3 mini...', '...')
ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      updated_at = now();
```

`ON CONFLICT DO UPDATE` makes seeds safe to re-run — idempotent migrations prevent double-apply bugs.

## Local vs Production Sync

```bash
# Test locally
supabase db reset

# Apply to production (via GitHub Actions)
supabase db push --db-url $PROD_DB_URL
```

In `deploy-prod.yml`:

```yaml
- name: Apply migrations
  run: supabase db push --db-url ${{ secrets.SUPABASE_DB_URL }}
```

Migrations auto-apply on every push to `main`.

## Track Development Achievements as Migrations

Make it a habit to write a seed after every feature:

```sql
-- 20260419000000_seed_achievements_session160.sql
INSERT INTO development_achievements (title, description, completed_at)
VALUES ('CS Automation', 'Claude Schedule cs-check implemented', '2026-04-19')
ON CONFLICT DO NOTHING;
```

Your Supabase dashboard becomes a live changelog of what's shipped.

## Summary

| Issue | Fix |
|-------|-----|
| Timestamp collision | Check `ls migrations/ | tail` before naming |
| SQLSTATE 42P10 | ON CONFLICT column must have UNIQUE constraint |
| Table name confusion | Always `\dt` or check schema before writing RLS |
| Seed idempotency | `ON CONFLICT DO UPDATE` everywhere |
| Schema vs data separation | Two files per feature |

Migrations are the single source of truth for your database state. Treat them like code: name them well, make them idempotent, and let CI apply them automatically.

---
Building in public: https://my-web-app-b67f4.web.app/
#Supabase #PostgreSQL #buildinpublic #database #migrations
