---
title: "Supabase pg_cron Complete Guide — Automate Scheduled Jobs in PostgreSQL"
tags: supabase,postgresql,indiedev,ai
published: true
---

# Supabase pg_cron Complete Guide — Automate Scheduled Jobs in PostgreSQL

Supabase ships with built-in pg_cron support, letting you run scheduled jobs directly inside PostgreSQL — no external scheduler needed.

## What is pg_cron?

A PostgreSQL extension that runs SQL or functions on a cron schedule.

**Benefits**:
- Runs inside the DB — no external infrastructure
- Full PostgreSQL feature access
- Transaction-safe
- Configurable from the Supabase dashboard

## Enable pg_cron

Supabase Dashboard → Database → Extensions → enable `pg_cron`:

```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;
```

## Basic Usage

```sql
-- Run every minute
SELECT cron.schedule('every-minute-job', '* * * * *', $$
  UPDATE counters SET value = value + 1 WHERE name = 'tick';
$$);

-- Run daily at midnight UTC
SELECT cron.schedule('daily-cleanup', '0 0 * * *', $$
  DELETE FROM temp_data WHERE created_at < NOW() - INTERVAL '24 hours';
$$);

-- Run every Monday at 9:00 UTC
SELECT cron.schedule('weekly-report', '0 9 * * 1', $$
  INSERT INTO weekly_reports (week_start, total_users)
  SELECT DATE_TRUNC('week', NOW()), COUNT(*) FROM users WHERE is_active = TRUE;
$$);

-- List all scheduled jobs
SELECT * FROM cron.job;

-- Remove a job
SELECT cron.unschedule('daily-cleanup');
```

## Cron Syntax

```
┌───────── minute (0-59)
│ ┌───────── hour (0-23)
│ │ ┌───────── day of month (1-31)
│ │ │ ┌───────── month (1-12)
│ │ │ │ ┌───────── day of week (0=Sun...7=Sun)
│ │ │ │ │
* * * * *

Examples:
0 9 * * 1-5   → Weekdays 9:00 UTC
*/15 * * * *  → Every 15 minutes
0 0 1 * *     → First of every month at midnight
```

## Practical: Clean Up Expired Sessions

```sql
SELECT cron.schedule(
  'cleanup-old-sessions',
  '0 2 * * *',  -- 2:00 UTC daily
  $$
    DELETE FROM user_sessions
    WHERE last_active < NOW() - INTERVAL '30 days';
  $$
);
```

## Practical: Daily Report Generation

```sql
CREATE OR REPLACE FUNCTION generate_daily_report()
RETURNS void AS $$
DECLARE
  report_date DATE := CURRENT_DATE - 1;
BEGIN
  INSERT INTO daily_reports (report_date, new_users, active_users, total_events)
  SELECT
    report_date,
    COUNT(*) FILTER (WHERE DATE(created_at) = report_date) AS new_users,
    COUNT(DISTINCT user_id) FILTER (WHERE DATE(last_active) = report_date) AS active_users,
    (SELECT COUNT(*) FROM events WHERE DATE(created_at) = report_date) AS total_events
  FROM users;

  RAISE LOG 'Daily report generated for %', report_date;
END;
$$ LANGUAGE plpgsql;

SELECT cron.schedule(
  'generate-daily-report',
  '0 1 * * *',
  'SELECT generate_daily_report()'
);
```

## Trigger Edge Functions via HTTP

```sql
-- Combine with pg_net to call Edge Functions on schedule
SELECT cron.schedule(
  'trigger-weekly-digest',
  '0 9 * * 1',
  $$
    SELECT net.http_post(
      url := 'https://<project>.supabase.co/functions/v1/growth-weekly-digest',
      headers := '{"Authorization": "Bearer <anon_key>", "Content-Type": "application/json"}'::jsonb,
      body := '{"trigger": "pg_cron"}'::jsonb
    );
  $$
);
```

## Monitoring Job Runs

```sql
-- Last 10 executions
SELECT
  jobname,
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 10;

-- Failed jobs only
SELECT jobname, status, return_message, start_time
FROM cron.job_run_details
WHERE status = 'failed'
ORDER BY start_time DESC;
```

## Time Zone Note (UTC vs JST)

pg_cron runs in UTC. JST = UTC+9:

```sql
-- 9:00 JST = 0:00 UTC
SELECT cron.schedule('morning-job', '0 0 * * *', 'SELECT morning_report()');

-- 17:00 JST = 8:00 UTC
SELECT cron.schedule('evening-job', '0 8 * * *', 'SELECT evening_summary()');
```

## Summary

pg_cron enables:

- **In-database scheduling** — no external cron infrastructure
- **Flexible cron syntax** for any schedule
- **pg_net integration** to trigger Edge Functions
- **Built-in job history** for monitoring

Automate your Supabase app's recurring tasks entirely within PostgreSQL.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
