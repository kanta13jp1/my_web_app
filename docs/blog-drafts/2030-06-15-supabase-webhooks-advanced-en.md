---
title: "Supabase Webhooks Deep Dive — Database Triggers, pg_net & Edge Function Patterns"
published: true
tags: supabase, postgresql, deno, webdev
canonical_url: null
---

# Supabase Webhooks Deep Dive — Database Triggers, pg_net & Edge Function Patterns

Supabase Webhooks let you react to INSERT/UPDATE/DELETE events on any table and call an external endpoint or an Edge Function automatically. Under the hood it uses the `pg_net` extension to fire non-blocking HTTP requests directly from PostgreSQL triggers.

## How it works

```
DB change → pg_net (async HTTP) → Edge Function or external endpoint
```

## Configuring via Dashboard

1. **Database → Webhooks → Create a new hook**
2. Select table and events (INSERT / UPDATE / DELETE)
3. Provide an endpoint URL
4. Set HTTP method and headers

## Controlling pg_net directly in SQL

```sql
create extension if not exists pg_net;

-- Fire a POST from within a SQL function
select net.http_post(
  url := 'https://your-project.supabase.co/functions/v1/notify-user',
  body := json_build_object(
    'user_id', NEW.user_id,
    'event', 'new_message'
  )::jsonb,
  headers := '{"Authorization": "Bearer <service-role-key>",
               "Content-Type": "application/json"}'::jsonb
);
```

## Pattern: send a welcome email on user sign-up

```sql
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  perform net.http_post(
    url := current_setting('app.settings.supabase_url')
           || '/functions/v1/send-welcome-email',
    body := json_build_object(
      'user_id', NEW.id,
      'email', NEW.email,
      'display_name', NEW.raw_user_meta_data->>'display_name'
    )::jsonb,
    headers := json_build_object(
      'Authorization', 'Bearer '
        || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    )::jsonb
  );
  return NEW;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

## Scheduled jobs with pg_cron

```sql
create extension if not exists pg_cron;

-- Delete expired sessions every night at 00:00 UTC
select cron.schedule(
  'cleanup-expired-sessions',
  '0 0 * * *',
  $$delete from user_sessions where expires_at < now();$$
);

-- Flag overdue WBS tasks every hour
select cron.schedule(
  'check-overdue-wbs-tasks',
  '0 * * * *',
  $$
    update wbs_tasks set status = 'overdue'
    where deadline < now()
      and status not in ('completed', 'overdue');
  $$
);
```

## Webhook security — HMAC signature verification

```typescript
export async function verifyWebhookSignature(
  req: Request,
  secret: string
): Promise<boolean> {
  const signature = req.headers.get("x-supabase-webhook-signature");
  if (!signature) return false;

  const body = await req.text();
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  const expected =
    "sha256=" +
    Array.from(new Uint8Array(sig))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

  return signature === expected;
}
```

## Retry failed webhooks automatically

```sql
create table if not exists webhook_logs (
  id bigint generated always as identity primary key,
  event_type text not null,
  payload jsonb not null,
  response_status int,
  retry_count int default 0,
  created_at timestamptz default now()
);

-- Retry every 5 minutes, up to 3 attempts
select cron.schedule('retry-failed-webhooks', '*/5 * * * *', $$
  select net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/process-event',
    body := payload,
    headers := '{"Content-Type":"application/json"}'::jsonb
  )
  from webhook_logs
  where response_status >= 500
    and retry_count < 3
    and created_at > now() - interval '24 hours';
$$);
```

## Real-world usage at Jibun K.K.

- **Auto-post to X on achievement insert** — `post-x-update` EF called via Database Webhook
- **WBS overdue detection** — `pg_cron` flags tasks hourly and triggers Slack notification
- **AI University sitemap update** — fires when a new provider is inserted into `ai_university_providers`

## Quick reference

| Scenario | Tool |
|---|---|
| DB change → external service | Database Webhooks (Dashboard) |
| DB change → Edge Function | `pg_net.http_post` in trigger |
| Scheduled batch | `pg_cron.schedule` |
| Webhook auth | HMAC SHA-256 signature check |

With Webhooks and pg_cron combined, you can automate entire backend workflows without touching a single line of frontend code.
