---
title: "Supabase Edge Function Error Handling — Retries, Logging, and Idempotency"
tags: supabase,ai,indiedev,automation
published: true
---

# Supabase Edge Function Error Handling — Retries, Logging, and Idempotency

Design patterns to prevent errors from being swallowed silently in production EFs.

## Basics: Return Structured Errors

```typescript
// supabase/functions/_shared/error.ts
export class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly status: number = 500,
  ) {
    super(message);
  }
}

export function errorResponse(error: unknown): Response {
  if (error instanceof AppError) {
    return new Response(
      JSON.stringify({ error: error.message, code: error.code }),
      { status: error.status, headers: { 'Content-Type': 'application/json' } },
    );
  }
  console.error('Unexpected error:', error);
  return new Response(
    JSON.stringify({ error: 'Internal server error', code: 'INTERNAL' }),
    { status: 500, headers: { 'Content-Type': 'application/json' } },
  );
}
```

## Fetch with Retry

```typescript
async function fetchWithRetry(
  url: string,
  options: RequestInit,
  maxRetries = 3,
): Promise<Response> {
  let lastError: Error | undefined;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const res = await fetch(url, options);
      if (res.status === 429) {
        // Rate limit: exponential backoff
        const wait = Math.pow(2, attempt) * 1000;
        await new Promise(r => setTimeout(r, wait));
        continue;
      }
      if (!res.ok && res.status >= 500) {
        throw new Error(`HTTP ${res.status}`);
      }
      return res;
    } catch (e) {
      lastError = e as Error;
      if (attempt < maxRetries) {
        await new Promise(r => setTimeout(r, attempt * 500));
      }
    }
  }
  throw lastError ?? new Error('Max retries exceeded');
}
```

## Structured Logging

```typescript
// Common log format across all EFs
function log(level: 'info' | 'warn' | 'error', message: string, meta?: object) {
  console.log(JSON.stringify({
    level,
    message,
    timestamp: new Date().toISOString(),
    function: Deno.env.get('FUNCTION_NAME') ?? 'unknown',
    ...meta,
  }));
}

// Usage
log('info', 'Processing webhook', { event_type: event.type });
log('error', 'Stripe API failed', { attempt: 3, status: 500 });
```

## Idempotent Webhook Processing

```typescript
// Prevent double-processing the same event
const { data: processed } = await supabase
  .from('processed_webhooks')
  .select('id')
  .eq('event_id', event.id)
  .maybeSingle();

if (processed) {
  return new Response('ok'); // silently ignore duplicates
}

// Record after processing
await supabase.from('processed_webhooks').insert({
  event_id: event.id,
  processed_at: new Date().toISOString(),
});
```

## Summary

```
Error responses  → AppError + errorResponse (structured JSON)
Retries          → exponential backoff (for 429 and 5xx)
Logging          → structured JSON logs (searchable in Supabase Dashboard)
Idempotency      → processed_webhooks table prevents double-processing
```

Design EFs to be "safe to fail" by default.
