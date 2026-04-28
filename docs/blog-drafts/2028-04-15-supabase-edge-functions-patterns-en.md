---
title: "Supabase Edge Functions Patterns: JWT Auth, CORS, and Error Handling"
tags: supabase,ai,indiedev,programming
published: true
---

# Supabase Edge Functions Patterns: JWT Auth, CORS, and Error Handling

Three production-ready patterns for Deno-powered Edge Functions.

## 1. JWT Auth: Authenticated Users Only

```typescript
// supabase/functions/secure-action/index.ts
import { createClient } from "npm:@supabase/supabase-js";

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } }
  );

  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) {
    return new Response("Unauthorized", { status: 401 });
  }

  const { data } = await supabase
    .from("user_data")
    .select("*")
    .eq("user_id", user.id);

  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
});
```

**Calling from Flutter** (SDK auto-attaches Authorization):

```dart
final response = await supabase.functions.invoke('secure-action');
```

## 2. CORS: Direct Browser Calls

```typescript
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { name } = await req.json();

    return new Response(
      JSON.stringify({ message: `Hello, ${name}!` }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
```

## 3. Structured Error Handling

```typescript
type AppError = {
  code: string;
  message: string;
  status: number;
};

function errorResponse(err: AppError): Response {
  return new Response(
    JSON.stringify({ error: err.code, message: err.message }),
    {
      status: err.status,
      headers: { "Content-Type": "application/json" },
    }
  );
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();

    if (!body.user_id) {
      return errorResponse({
        code: "MISSING_PARAM",
        message: "user_id is required",
        status: 400,
      });
    }

    const result = await processAction(body.user_id);
    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Unexpected error:", err);
    return errorResponse({
      code: "INTERNAL_ERROR",
      message: "An unexpected error occurred",
      status: 500,
    });
  }
});
```

## Local Development

```bash
supabase start
supabase functions serve secure-action --env-file .env.local

curl -X POST http://localhost:54321/functions/v1/secure-action \
  -H "Authorization: Bearer <local-anon-key>" \
  -H "Content-Type: application/json" \
  -d '{"action": "test"}'
```

## Summary

```
JWT auth      → Authorization header → supabase.auth.getUser()
CORS          → handle OPTIONS preflight + corsHeaders on all responses
Error handling → typed AppError + centralized try/catch
Local dev      → supabase functions serve with hot reload
```

Edge Functions cold-start in tens of milliseconds — much faster than Lambda.
The Flutter SDK's `functions.invoke()` attaches the Authorization header automatically.
