---
title: "Supabase Edge Functions Design Patterns: Hub, RLS, and Error Handling"
tags: supabase,ai,indiedev,programming
published: true
---

# Supabase Edge Functions Design Patterns: Hub, RLS, and Error Handling

Proliferating Edge Functions leads to maintenance chaos. Three patterns to keep them manageable.

## Why Edge Functions

```
Flutter Web → direct Supabase DB access: avoid it because:
  1. API keys exposed in the browser
  2. Multi-table transactions are hard
  3. Business logic on the client = security risk

→ Edge Functions = serverless TypeScript running on Deno at the edge
```

## Pattern 1: Hub Pattern (Action Routing)

Group related functionality into one Edge Function. Also helps with the 50-function deployment limit.

```typescript
// supabase/functions/schedule-hub/index.ts
serve(async (req) => {
  const { action, payload } = await req.json();
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  switch (action) {
    case "digest.run":    return handleDigest(supabase, payload);
    case "kpi.update":    return handleKpiUpdate(supabase, payload);
    case "report.generate": return handleReport(supabase, payload);
    default:
      return new Response(
        JSON.stringify({ error: `Unknown action: ${action}` }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
  }
});
```

**Calling from Flutter**:

```dart
final response = await supabase.functions.invoke(
  'schedule-hub',
  body: {'action': 'digest.run', 'payload': {}},
);
```

## Pattern 2: Service Role Key vs User JWT for RLS

```typescript
// ❌ anon key for all operations → RLS gets in the way for admin tasks
const supabase = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!);

// ✅ Service role key bypasses RLS → for admin / batch operations
const adminClient = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

// ✅ Forward user JWT → RLS applies (user sees only their own data)
serve(async (req) => {
  const authHeader = req.headers.get("Authorization")!;
  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } }
  });
  // userClient operates as the authenticated user → RLS enforced
});
```

**Decision rule**:

```
Admin / batch operations (affect all users) → SERVICE_ROLE_KEY
User-specific operations (own data only)    → forward user JWT
```

## Pattern 3: Unified Error Handling

```typescript
// shared/response.ts
export const ok = (data: unknown, status = 200): Response =>
  new Response(JSON.stringify({ data }), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  });

export const err = (message: string, status = 400): Response =>
  new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  });

// In every Edge Function
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin":  "*",
        "Access-Control-Allow-Methods": "POST",
      },
    });
  }

  try {
    const result = await processRequest(req);
    return ok(result);
  } catch (e) {
    console.error("Edge Function error:", e);
    return err(e instanceof Error ? e.message : "Internal error", 500);
  }
});
```

## Deploy and Test

```bash
# Deploy a single function
supabase functions deploy schedule-hub --no-verify-jwt

# Test locally
supabase functions serve schedule-hub
curl -X POST http://localhost:54321/functions/v1/schedule-hub \
  -H "Content-Type: application/json" \
  -d '{"action":"digest.run","payload":{}}'

# View logs
supabase functions logs schedule-hub
```

## Summary

```
Reduce function count    → Hub Pattern (action routing)
Data protection          → RLS via user JWT / admin via SERVICE_ROLE
Consistent error shape   → ok()/err() helpers + try/catch
CORS                     → OPTIONS preflight + Access-Control-Allow-Origin
```

Edge Functions are a thin wrapper between Flutter and the DB for operations that shouldn't live on the client. Hub Pattern keeps function count down; RLS keeps data safe; unified error handling keeps responses predictable.

