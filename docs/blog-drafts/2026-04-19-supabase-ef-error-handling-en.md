---
title: "Complete Error Handling Patterns for Supabase Edge Functions — 4-Stage Fallback Design"
tags: Supabase,Deno,TypeScript,buildinpublic,webdev
published: false
---

# Complete Error Handling Patterns for Supabase Edge Functions

## Why Error Handling Matters

Edge Functions have three error sources: external APIs, database access, and user input. Without proper handling:
- Flutter clients crash on unexpected 500s
- Supabase logs fill up with noise
- Debugging takes forever

## The 4-Stage Fallback Template

```typescript
Deno.serve(async (req: Request) => {
  // Stage 1: CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders, status: 204 });
  }

  try {
    // Stage 2: Input validation
    const { action, ...params } = await parseBody(req);
    if (!action) {
      return errorResponse(400, 'action is required');
    }

    // Stage 3: Routing
    switch (action) {
      case 'get': return await handleGet(params);
      case 'upsert': return await handleUpsert(params);
      default: return errorResponse(400, `Unknown action: ${action}`);
    }
  } catch (err) {
    // Stage 4: Unexpected errors
    console.error('[EF Error]', err);
    return errorResponse(500, 'Internal server error');
  }
});
```

## Input Validation

```typescript
async function parseBody(req: Request): Promise<Record<string, unknown>> {
  const contentType = req.headers.get('content-type') ?? '';

  if (contentType.includes('application/json')) {
    try {
      return await req.json();
    } catch {
      throw new ValidationError('Invalid JSON body');
    }
  }

  if (contentType.includes('application/x-www-form-urlencoded')) {
    const text = await req.text();
    return Object.fromEntries(new URLSearchParams(text));
  }

  return {};
}

class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}
```

## Unified Error Response Format

```typescript
function errorResponse(status: number, message: string, details?: unknown): Response {
  return new Response(
    JSON.stringify({
      error: message,
      details: details ?? null,
      timestamp: new Date().toISOString(),
    }),
    {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  );
}

function successResponse(data: unknown, status = 200): Response {
  return new Response(
    JSON.stringify({ data, success: true }),
    {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  );
}
```

## Supabase Client Errors

```typescript
async function handleGet(params: Record<string, unknown>): Promise<Response> {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data, error } = await supabase
    .from('my_table')
    .select('*')
    .eq('id', params.id);

  if (error) {
    // Branch on PostgreSQL error code
    if (error.code === '42P01') { // table doesn't exist
      return errorResponse(500, 'Database schema error', error);
    }
    if (error.code === '23505') { // unique violation
      return errorResponse(409, 'Duplicate entry', error.details);
    }
    return errorResponse(500, error.message, error);
  }

  return successResponse(data);
}
```

## External API Calls with Timeout

```typescript
async function fetchWithTimeout(url: string, options: RequestInit, timeoutMs = 10000): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    });
    clearTimeout(timeoutId);
    return response;
  } catch (err) {
    clearTimeout(timeoutId);
    if (err instanceof Error && err.name === 'AbortError') {
      throw new Error(`Request timed out after ${timeoutMs}ms`);
    }
    throw err;
  }
}
```

## Keeping deno lint at Zero Errors

Common violations:

```typescript
// ❌ no-explicit-any
async function handle(data: any) {}

// ✅ unknown + type guard
async function handle(data: unknown) {
  if (typeof data !== 'object' || data === null) throw new Error('Invalid data');
  const typed = data as Record<string, unknown>;
}

// ❌ prefer-const
let result = await fetch(url);

// ✅
const result = await fetch(url);
```

## Summary

| Layer | Defense |
|---|---|
| Input | JSON/form support + type validation |
| Routing | action switch + unknown action → 400 |
| DB | Branch on error.code |
| External API | Timeout + AbortController |
| Unexpected | try/catch → 500 |

Applying this 5-layer pattern across all hub EFs dramatically cuts debugging time in production.

---
Building in public: https://my-web-app-b67f4.web.app/
#Supabase #Deno #TypeScript #buildinpublic #webdev
