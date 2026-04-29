---
title: "Supabase Postgres Advanced — Partitioning, Full-Text Search, Generated Columns, and Triggers"
tags: dart,flutter,webdev,indiedev
published: true
---

## Introduction

Once you're comfortable with basic CRUD in Supabase, you can leverage PostgreSQL's advanced features to dramatically improve performance and maintainability. This article covers table partitioning, full-text search, generated columns, and trigger-based real-time notifications — patterns that pay off in production.

---

## 1. Table Partitioning (Date Range) for Log Data Management

Cramming massive log data into a single table degrades query performance. Use date-range partitioning to isolate older data.

```sql
-- Declare parent table with partitioning strategy
CREATE TABLE user_events (
  id          BIGSERIAL,
  user_id     UUID NOT NULL,
  event_type  TEXT NOT NULL,
  payload     JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create monthly child partitions
CREATE TABLE user_events_2026_04
  PARTITION OF user_events
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE user_events_2026_05
  PARTITION OF user_events
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- Add indexes per partition (not inherited automatically)
CREATE INDEX ON user_events_2026_04 (user_id, created_at DESC);
CREATE INDEX ON user_events_2026_05 (user_id, created_at DESC);
```

Query the parent table — PostgreSQL will automatically prune irrelevant partitions. Archiving old partitions is as simple as `DETACH PARTITION`, with zero delete cost.

---

## 2. Full-Text Search with tsvector + GIN Index

PostgreSQL's built-in FTS works well for English. For a more flexible trigram/bigram approach, use the `pg_trgm` extension.

```sql
-- Enable trigram extension
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create GIN trigram indexes for fast LIKE/ILIKE search
CREATE INDEX articles_title_trgm_idx ON articles
  USING gin (title gin_trgm_ops);

CREATE INDEX articles_body_trgm_idx ON articles
  USING gin (body gin_trgm_ops);

-- Full-text search query with ranking
SELECT id, title,
       ts_rank(to_tsvector('english', body), query) AS rank
FROM articles,
     to_tsquery('english', 'flutter & testing') AS query
WHERE to_tsvector('english', title || ' ' || body) @@ query
ORDER BY rank DESC
LIMIT 20;
```

Store the `tsvector` as a generated column for automatic updates (see next section).

---

## 3. Generated Columns — Move Business Logic to the Database

Calculations like tax-inclusive pricing or normalized text fields are often duplicated in the frontend. Move them to generated columns for consistency across all clients.

```sql
CREATE TABLE products (
  id            BIGSERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  price_ex_tax  NUMERIC(10,2) NOT NULL,
  tax_rate      NUMERIC(4,3) NOT NULL DEFAULT 0.10,

  -- STORED generated column: recomputed on every change
  price_incl_tax NUMERIC(10,2) GENERATED ALWAYS AS
    (ROUND(price_ex_tax * (1 + tax_rate), 2)) STORED,

  -- Auto-maintained tsvector for full-text search
  search_vector  TSVECTOR GENERATED ALWAYS AS
    (to_tsvector('english', name)) STORED
);

-- GIN index on the generated search vector
CREATE INDEX products_search_idx ON products USING gin (search_vector);
```

Your Flutter app simply reads `price_incl_tax` directly — no frontend calculation required. When the tax rate changes, update the column default and the DB recalculates everything automatically.

---

## 4. Trigger + pg_notify for Real-Time Event Notifications

Supabase Realtime uses `pg_notify` internally. You can fire the same mechanism from your own business logic triggers.

```sql
-- Notify listeners when an order status changes
CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status <> OLD.status THEN
    PERFORM pg_notify(
      'order_updates',
      json_build_object(
        'order_id', NEW.id,
        'old_status', OLD.status,
        'new_status', NEW.status,
        'updated_at', NOW()
      )::text
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_status_trigger
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_order_status_change();
```

On the Flutter side, subscribe to a Supabase Realtime channel and update the UI without polling:

```dart
supabase.channel('order_updates').onBroadcast(
  event: 'order_updates',
  callback: (payload) {
    setState(() {
      _updateOrderStatus(payload['order_id'], payload['new_status']);
    });
  },
).subscribe();
```

---

## 5. Query Optimization with EXPLAIN ANALYZE

When a query is slow, `EXPLAIN ANALYZE` reveals the execution plan and actual timing.

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.id, u.email, COUNT(t.id) AS task_count
FROM users u
LEFT JOIN tasks t ON t.user_id = u.id
WHERE u.created_at > NOW() - INTERVAL '30 days'
GROUP BY u.id, u.email
ORDER BY task_count DESC
LIMIT 50;
```

Key things to look for in the output:

- **`Seq Scan`** — no index used; consider adding one
- **`Hash Join` vs `Nested Loop`** — understanding join strategies helps tune larger queries
- **`Buffers: shared hit=X read=Y`** — a high hit/(hit+read) ratio means good cache utilization
- **`actual rows` vs `estimated rows` divergence** — run `ANALYZE` to refresh table statistics

```sql
-- Refresh statistics if autovacuum is lagging
ANALYZE users;
ANALYZE tasks;
```

---

## Summary

| Feature | Benefit |
|---------|---------|
| Partitioning | Faster queries on large tables, trivial archiving |
| Full-text search + GIN | Scalable search without external services |
| Generated Columns | DB-enforced business logic, consistent across clients |
| Trigger + pg_notify | Custom real-time event streaming |
| EXPLAIN ANALYZE | Pinpoint and fix query bottlenecks |

The biggest advantage of Supabase is that it gives you raw PostgreSQL power. Offloading calculations and business rules to the database simplifies your Flutter code and naturally maintains consistency across all clients — web, mobile, and edge functions alike.
