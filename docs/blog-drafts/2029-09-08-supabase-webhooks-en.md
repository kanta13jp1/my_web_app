---
title: "Supabase Webhooks — Event-driven Backend With pg_net"
tags: supabase,webdev,indiedev,flutter
published: true
---

# Supabase Webhooks — Event-driven Backend With pg_net

Supabase Webhooks let database INSERT/UPDATE/DELETE events trigger Edge Functions or external APIs automatically. Combined with `pg_net` and `pg_cron`, you can build a powerful event-driven backend without any extra infrastructure.

## How It Works

```
DB change (INSERT / UPDATE / DELETE)
  → pg_net sends async HTTP POST
  → destination: Edge Function or external API
  → response saved to net.http_response_queue
```

## Dashboard Setup

1. Go to **Database → Webhooks → Create a new hook**
2. Configure:
   - **Name**: `on_task_created`
   - **Table**: `tasks`
   - **Events**: INSERT
   - **Type**: Supabase Edge Functions
   - **Function**: `notify-slack`

## SQL Setup (more flexible)

```sql
CREATE OR REPLACE FUNCTION notify_on_task_insert()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  payload jsonb;
BEGIN
  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'record', row_to_json(NEW),
    'old_record', CASE WHEN TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE NULL END
  );

  PERFORM net.http_post(
    url     := current_setting('app.edge_function_url') || '/notify-slack',
    body    := payload::text,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    )
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER task_insert_webhook
  AFTER INSERT ON tasks
  FOR EACH ROW EXECUTE FUNCTION notify_on_task_insert();
```

## Receiving Edge Function

```typescript
// supabase/functions/notify-slack/index.ts
interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  record: Record<string, unknown>;
}

Deno.serve(async (req) => {
  // Verify service role key
  const token = req.headers.get('Authorization')?.replace('Bearer ', '');
  if (token !== Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')) {
    return new Response('Unauthorized', { status: 401 });
  }

  const payload: WebhookPayload = await req.json();

  if (payload.type === 'INSERT' && payload.table === 'tasks') {
    const task = payload.record;
    await fetch(Deno.env.get('SLACK_WEBHOOK_URL')!, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: `✅ New task: ${task.title}` }),
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
```

## Monitoring With pg_net

```sql
-- Check recent webhook calls
SELECT id, status_code, error_msg, created
FROM net.http_response_queue
ORDER BY created DESC
LIMIT 10;

-- Failed calls only
SELECT * FROM net.http_response_queue
WHERE status_code >= 400
ORDER BY created DESC;
```

## Welcome Email on User Signup

```sql
CREATE OR REPLACE FUNCTION send_welcome_email()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'https://<project>.supabase.co/functions/v1/send-welcome-email',
    body    := json_build_object('email', NEW.email, 'user_id', NEW.id::text)::text,
    headers := '{"Content-Type":"application/json","Authorization":"Bearer <key>"}'
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION send_welcome_email();
```

## Scheduled Webhooks With pg_cron

```sql
-- Trigger daily report at 9:00 AM JST (0:00 UTC)
SELECT cron.schedule(
  'daily-report',
  '0 0 * * *',
  $$
    SELECT net.http_post(
      url     := 'https://<project>.supabase.co/functions/v1/daily-report',
      body    := '{"trigger":"cron"}'::text,
      headers := '{"Content-Type":"application/json","Authorization":"Bearer <key>"}'
    )
  $$
);
```

## Security: HMAC Signature Verification

```typescript
import { createHmac } from 'node:crypto';

function verifySignature(body: string, sig: string, secret: string): boolean {
  const expected = `sha256=${createHmac('sha256', secret).update(body).digest('hex')}`;
  return expected === sig;
}

// In your Edge Function:
const rawBody = await req.text();
const sig = req.headers.get('X-Webhook-Signature') ?? '';
if (!verifySignature(rawBody, sig, Deno.env.get('WEBHOOK_SECRET')!)) {
  return new Response('Invalid signature', { status: 403 });
}
const payload = JSON.parse(rawBody);
```

## Common Use Cases

| Use case | Implementation |
|----------|---------------|
| Welcome email | auth.users INSERT → EF → Resend |
| Slack notification | tasks UPDATE → EF → Slack |
| Payment processing | orders INSERT → EF → Stripe |
| Scheduled reports | pg_cron → net.http_post → EF |
| Real-time sync | Supabase Realtime (lower latency) |

After adopting Webhooks, our notification logic consolidated from 3 services into a single Edge Function.

---

What events are you triggering with Supabase Webhooks? Comment below!
