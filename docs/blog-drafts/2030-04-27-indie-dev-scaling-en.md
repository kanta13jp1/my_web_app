---
title: "Indie Dev Scaling — Serving 100k Users as a Solo Engineer"
tags: indiedev,webdev,flutter,supabase
published: true
---

# Indie Dev Scaling — Serving 100k Users as a Solo Engineer

"I built it — but what if it actually grows?" is the fear every indie developer carries. Serving 100k users as a single engineer is achievable, but only if you bake in *just enough* scalability from the start — not too early, not too late.

## Phase-Based Scaling Strategy

### Phase 1: 0–1,000 Users (Validation)

Don't optimise yet — just ship:

```dart
// ❌ Premature: CQRS + Event Sourcing on day one
class TaskCommandHandler {
  final TaskCommandBus _bus;
  Future<void> handle(CreateTaskCommand cmd) async { ... }
}

// ✅ Start simple
class TaskRepository {
  Future<void> createTask(String title) async {
    await supabase.from('tasks').insert({'title': title});
  }
}
```

**Checklist:**
- Supabase free tier covers you (500 MB DB / 2 GB bandwidth)
- Firebase Hosting free tier covers you
- Monitoring: Supabase Dashboard + Firebase Console only

### Phase 2: 1,000–10,000 Users (PMF Confirmed)

Bottlenecks start showing. Address them:

```sql
-- ❌ N+1: SELECT tasks, then loop SELECT project for each
-- ✅ JOIN everything in one query
SELECT
  t.*,
  p.name  AS project_name,
  p.color AS project_color
FROM tasks t
LEFT JOIN projects p ON t.project_id = p.id
WHERE t.user_id = $1
ORDER BY t.created_at DESC;
```

```sql
CREATE INDEX idx_tasks_user_created ON tasks(user_id, created_at DESC);
CREATE INDEX idx_tasks_project ON tasks(project_id) WHERE project_id IS NOT NULL;
```

### Phase 3: 10,000–100,000 Users (Scaling)

Time to revisit infrastructure:

```typescript
// supabase/functions/process-heavy-task/index.ts
Deno.serve(async (req) => {
  const { taskId } = await req.json();
  
  // Kick off async processing, return immediately
  await supabase.rpc('process_task_async', { task_id: taskId });
  
  return new Response(
    JSON.stringify({ status: 'processing', taskId }),
    { status: 202 }
  );
});
```

## Database Optimisation

### Connection Pooling

Supabase bundles pgBouncer — configure it correctly for serverless:

```
// .env
SUPABASE_DB_URL=postgresql://...?pgbouncer=true&connection_limit=1
// connection_limit=1 prevents connection exhaustion under concurrent Edge Function invocations
```

### Read Replicas

```typescript
// Direct read-heavy analytics queries to the replica (Supabase Pro+)
const readOnlyClient = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { global: { headers: { 'x-read-replica': 'true' } } }
);
```

### Table Partitioning

```sql
-- Partition high-volume event logs by month
CREATE TABLE activity_logs (
  id         UUID DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL,
  action     TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

CREATE TABLE activity_logs_2026_01
PARTITION OF activity_logs
FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

-- Automate with pg_partman for older partition pruning
```

## AI-Powered Monitoring

```yaml
# .github/workflows/infra-health-check.yml
name: Infra Health Check
on:
  schedule:
    - cron: '0 * * * *'
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - name: Check Supabase health
        run: |
          STATUS=$(curl -s "$SUPABASE_URL/health" | jq -r '.status')
          if [ "$STATUS" != "ok" ]; then
            echo "::error::Supabase health check failed: $STATUS"
          fi
```

## Caching Strategy

### Client-Side Cache in Flutter

```dart
class CachedTaskRepository {
  final Map<String, List<Task>> _cache = {};
  final Map<String, DateTime> _cacheTime = {};
  static const _ttl = Duration(minutes: 5);

  Future<List<Task>> getTasks(String userId) async {
    final key = 'tasks_$userId';
    final cached = _cache[key];
    final cacheAt = _cacheTime[key];

    if (cached != null &&
        cacheAt != null &&
        DateTime.now().difference(cacheAt) < _ttl) {
      return cached;
    }

    final data = await supabase
        .from('tasks')
        .select()
        .order('created_at', ascending: false);

    _cache[key] = data.map(Task.fromJson).toList();
    _cacheTime[key] = DateTime.now();
    return _cache[key]!;
  }

  void invalidate(String userId) {
    _cache.remove('tasks_$userId');
    _cacheTime.remove('tasks_$userId');
  }
}
```

### Server-Side Materialised Views

```sql
-- Cache expensive aggregations
CREATE MATERIALIZED VIEW user_stats AS
SELECT
  user_id,
  COUNT(*)                                                AS task_count,
  COUNT(*) FILTER (WHERE completed_at IS NOT NULL)       AS completed_count,
  MAX(created_at)                                         AS last_activity
FROM tasks
GROUP BY user_id;

CREATE UNIQUE INDEX idx_user_stats_user_id ON user_stats(user_id);

-- Refresh hourly from a GHA cron
REFRESH MATERIALIZED VIEW CONCURRENTLY user_stats;
```

## Cost Management

### Staged Plan Upgrades

```
Phase 1 (0–1k users):  Supabase Free + Firebase Free    → $0/month
Phase 2 (1k–10k):      Supabase Pro ($25) + Firebase    → ~$30/month
Phase 3 (10k–100k):    Supabase Pro + Add-ons + Blaze   → $100–300/month
Phase 4 (100k+):       Supabase Team ($599+) + Infra    → $600+/month
```

### Budget Alerts

```bash
# Firebase Budget Alert (GCP Console)
# Monthly budget: $100
# Alert at: 50%, 90%, 100%

# Supabase Usage Alert (Dashboard → Settings → Billing)
# DB size: alert at 80%
# API requests: alert at 80%
```

## The Solo Scaling Rulebook

```
✅ Keep it simple until you have evidence of a bottleneck
✅ Prevent N+1 queries from day one (JOINs + indexes)
✅ Cache on both client and server
✅ Delegate monitoring to AI (GHA + Claude) so you can focus on product
✅ Grow costs in stages — never over-provision
✅ Don't scale infrastructure before monetisation confirms the need
```

100k users as a solo developer is not a fantasy — it is an engineering discipline.

---

*Solo-building an AI life-management app that replaces 21 SaaS tools, scaling with Flutter + Supabase + GHA. Follow along → [@kanta13jp1](https://x.com/kanta13jp1)*
