---
title: "Supabase Edge Functions Advanced — Deno, Webhooks, Scheduled Jobs, and Multi-tenant Patterns"
tags: dart,flutter,webdev,indiedev
published: true
---

# Supabase Edge Functions Advanced — Deno, Webhooks, Scheduled Jobs, and Multi-tenant Patterns

Supabase Edge Functions run on Deno Deploy — a lightweight serverless runtime that's not Node.js. This article goes beyond basic CRUD to cover webhook signature verification, scheduled jobs via `pg_cron`, and secure multi-tenant data isolation.

## Understanding the Deno Environment

The biggest gotcha for developers coming from Node.js is that Edge Functions use **Deno**, not Node. Key differences:

- No `require()` — use ES module `import` syntax only.
- Node built-ins like `fs` and `crypto` are available with the `node:` prefix (partially).
- npm packages are importable directly with the `npm:` prefix (Deno 1.34+).
- No persistent filesystem writes — use `/tmp` for ephemeral data only.

```typescript
// Importing npm packages directly in Deno
import { Resend } from "npm:resend@3";
import Stripe from "npm:stripe@14";
```

For local development, run `supabase functions serve --env-file .env.local` to get a Deno environment identical to production.

## Receiving Webhooks with HMAC-SHA256 Verification

Any webhook endpoint that's publicly accessible needs **signature verification** — without it, anyone can POST fake events. Here's a complete verifier using the Web Crypto API (available natively in Deno):

```typescript
// supabase/functions/webhook-receiver/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const SECRET = Deno.env.get("WEBHOOK_SECRET")!;

serve(async (req) => {
  const signature = req.headers.get("x-signature-256") ?? "";
  const body = await req.arrayBuffer();

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"]
  );

  const sigBytes = hexToBytes(signature.replace("sha256=", ""));
  const valid = await crypto.subtle.verify("HMAC", key, sigBytes, body);

  if (!valid) {
    return new Response("Unauthorized", { status: 401 });
  }

  const payload = JSON.parse(new TextDecoder().decode(body));
  // Handle your event here
  console.log("Received event:", payload.type);

  return new Response("OK", { status: 200 });
});

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.slice(i, i + 2), 16);
  }
  return bytes;
}
```

The `crypto.subtle` API is synchronous-free and runs at near-native speed inside Deno — no external dependencies needed.

## Scheduled Jobs with pg_cron + pg_net

Supabase ships with the `pg_cron` and `pg_net` extensions, letting you trigger HTTP requests directly from PostgreSQL on a schedule. This is perfect for daily digests, churn detection, and reminder emails.

```sql
-- Run an Edge Function every day at 09:00 JST (00:00 UTC)
select cron.schedule(
  'daily-digest-job',
  '0 0 * * *',
  $$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/daily-digest',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.service_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

On the Edge Function side, validate the `Authorization` header against your service key before executing any logic — this prevents external callers from triggering your scheduled job endpoint.

## Multi-tenant Patterns: JWT → Tenant ID → RLS

In a multi-tenant SaaS, every database query must be scoped to the calling organization. Using the **service role key** bypasses Row Level Security (RLS), which is dangerous. Instead, pass the user's JWT through directly — RLS policies enforce the tenant boundary automatically.

```typescript
// supabase/functions/tenant-api/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  // Extract the user's JWT from the Authorization header
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");

  // Create a client scoped to this user — RLS applies automatically
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: `Bearer ${token}` } } }
  );

  // Pull tenant_id from custom JWT claims (set via auth hook)
  const { data: { user } } = await supabase.auth.getUser();
  const tenantId = user?.app_metadata?.tenant_id;

  if (!tenantId) {
    return new Response(JSON.stringify({ error: "No tenant context" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  // RLS policy filters rows to this tenant automatically
  const { data, error } = await supabase
    .from("projects")
    .select("id, name, created_at");

  if (error) throw error;

  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
});
```

Your RLS policy should reference the custom claim:

```sql
create policy "tenant isolation"
  on projects
  for all
  using (
    tenant_id = (auth.jwt() -> 'app_metadata' ->> 'tenant_id')::uuid
  );
```

## Managing Secrets with Deno.env

Store production secrets with `supabase secrets set`, never in source code:

```bash
supabase secrets set RESEND_API_KEY=re_xxxx
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxxx
```

Access them in your function:

```typescript
const resend = new Resend(Deno.env.get("RESEND_API_KEY")!);
```

For local development, put secrets in `.env.local` (already in `.gitignore`) and reference them with `supabase functions serve --env-file .env.local`.

## Summary

- **Deno runtime**: Use `import` + `npm:` prefix. No `require()`, no persistent filesystem.
- **Webhooks**: Always verify HMAC-SHA256 signatures before processing events.
- **Scheduled jobs**: `pg_cron` + `pg_net` let PostgreSQL drive your Edge Functions on a timer.
- **Multi-tenancy**: Pass user JWT directly; let RLS enforce the tenant boundary — never bypass with the service role key.

Next up: Indie SaaS retention strategy — churn analysis, email automation, and habit-forming UX.
