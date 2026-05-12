---
title: "Supabase Migrations Advanced — Zero-Downtime Schema Changes in Production"
tags: supabase,postgresql,webdev,indiedev
published: true
---

# Supabase Migrations Advanced — Zero-Downtime Schema Changes in Production

Schema changes on a live PostgreSQL database demand care. Lock contention, full-table scans, and irreversible operations can bring your service down. This article covers Supabase migration best practices from a zero-downtime perspective.

## Supabase Migration Basics

Supabase executes SQL files in `supabase/migrations/` sequentially by timestamp.

```
supabase/migrations/
  20260101000000_create_users.sql
  20260102000000_add_profile_fields.sql
  20260103000000_create_posts.sql
```

The timestamp determines execution order. Applied migrations are never re-run.

```bash
# Apply locally
supabase db push

# Apply to production
supabase db push --db-url postgresql://...
```

## Safe Column Addition

### ❌ Dangerous: Adding NOT NULL + DEFAULT simultaneously

```sql
-- Acquires full table lock and rewrites all rows
ALTER TABLE posts ADD COLUMN view_count INTEGER NOT NULL DEFAULT 0;
```

On PostgreSQL < 12, adding `NOT NULL DEFAULT` rewrites every row in the table.

### ✅ Safe: Staged column addition

```sql
-- Step 1: Add column as nullable (instant)
ALTER TABLE posts ADD COLUMN view_count INTEGER;

-- Step 2: Backfill in batches (background)
UPDATE posts SET view_count = 0
WHERE view_count IS NULL AND id BETWEEN 1 AND 10000;
-- ... repeat for all batches

-- Step 3: Add NOT NULL constraint
ALTER TABLE posts ALTER COLUMN view_count SET NOT NULL;
ALTER TABLE posts ALTER COLUMN view_count SET DEFAULT 0;
```

PostgreSQL 11+ handles `ADD COLUMN ... DEFAULT` instantly, but NOT NULL enforcement still requires caution.

## Zero-Downtime Index Creation

Standard `CREATE INDEX` acquires a shared lock on the table.

```sql
-- ❌ Blocks writes (minutes to hours on large tables)
CREATE INDEX idx_posts_user_id ON posts(user_id);

-- ✅ Zero-downtime (CONCURRENTLY)
CREATE INDEX CONCURRENTLY idx_posts_user_id ON posts(user_id);
```

`CONCURRENTLY` takes about 2× longer but never blocks writes. Always use it in Supabase migrations.

```sql
-- Inside a migration file
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_posts_created_at
  ON posts(created_at DESC);
```

## Safe Foreign Key Addition

```sql
-- ❌ Table lock + full scan to validate all existing rows
ALTER TABLE comments ADD CONSTRAINT fk_comments_posts
  FOREIGN KEY (post_id) REFERENCES posts(id);

-- ✅ Two-step safe addition
-- Step 1: Add constraint without validating existing rows
ALTER TABLE comments ADD CONSTRAINT fk_comments_posts
  FOREIGN KEY (post_id) REFERENCES posts(id)
  NOT VALID;

-- Step 2: Validate in background (only ShareUpdateExclusiveLock)
ALTER TABLE comments VALIDATE CONSTRAINT fk_comments_posts;
```

## Column Type Changes

Direct type changes almost always lock the table. The safe pattern uses a parallel new column.

```sql
-- ❌ Direct type change acquires full lock
ALTER TABLE events ALTER COLUMN metadata TYPE jsonb USING metadata::jsonb;

-- ✅ Staged migration with dual-column approach
-- Step 1: Add new column
ALTER TABLE events ADD COLUMN metadata_jsonb jsonb;

-- Step 2: Keep in sync with a trigger
CREATE OR REPLACE FUNCTION sync_metadata()
RETURNS TRIGGER AS $$
BEGIN
  NEW.metadata_jsonb = NEW.metadata::jsonb;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_metadata_trigger
  BEFORE INSERT OR UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION sync_metadata();

-- Step 3: Backfill existing rows
UPDATE events SET metadata_jsonb = metadata::jsonb WHERE metadata_jsonb IS NULL;

-- Step 4: After switching the app to the new column, drop old
ALTER TABLE events DROP COLUMN metadata;
ALTER TABLE events RENAME COLUMN metadata_jsonb TO metadata;
```

## Rollback Strategy

Supabase migrations have no built-in rollback files. Production rollbacks are manual SQL.

```sql
-- down migration (managed separately)
-- 20260103000000_create_posts_down.sql
DROP TABLE IF EXISTS posts;
```

A safe production pattern uses Feature Flags:

```sql
-- Add a feature flag column
ALTER TABLE users ADD COLUMN IF NOT EXISTS new_dashboard_enabled BOOLEAN DEFAULT FALSE;

-- Emergency rollback
ALTER TABLE users DROP COLUMN IF EXISTS new_dashboard_enabled;
```

## Automated Migration Safety Checks in CI/CD

```yaml
# .github/workflows/migration-check.yml
name: Migration Safety Check
on: [pull_request]

jobs:
  migration-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install squawk
        run: pip install squawk-cli
      - name: Lint migrations
        run: |
          for f in supabase/migrations/*.sql; do
            echo "Checking $f"
            squawk "$f"
          done
```

[Squawk](https://squawkhq.com/) detects dangerous patterns including:

- `ADD COLUMN NOT NULL DEFAULT` (older PG versions)
- Missing `CONCURRENTLY` on index creation
- Unguarded `DROP TABLE` / `DROP COLUMN`

## Row Level Security Migration Order

```sql
-- RLS activation is instant, but enabling it before policies exist blocks all access
-- ✅ Correct order: define policies FIRST, then enable RLS
CREATE POLICY "Users can read own data"
  ON profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own data"
  ON profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- Enable RLS only after policies are defined
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
```

## Estimating Migration Impact

```sql
-- Estimate migration duration
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM posts WHERE view_count IS NULL;

-- Check table sizes
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
  pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) AS indexes_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Summary Checklist

| Operation | Safe Approach |
|---|---|
| Add column | Nullable first → backfill → add NOT NULL |
| Create index | Always use `CONCURRENTLY` |
| Add foreign key | `NOT VALID` → `VALIDATE CONSTRAINT` |
| Change column type | New parallel column → switch → drop old |
| Enable RLS | Define all policies → `ENABLE ROW LEVEL SECURITY` |

Mastering zero-downtime migrations lets you evolve your schema continuously without service interruption.

---

*Building a life-management app that replaces 21 competing SaaS tools with Flutter + Supabase. Follow the journey → [@kanta13jp1](https://x.com/kanta13jp1)*
