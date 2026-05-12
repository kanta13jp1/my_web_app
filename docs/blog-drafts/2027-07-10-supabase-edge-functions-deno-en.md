---
title: "Supabase Edge Functions with Deno: Production-Ready Design Patterns"
tags: supabase,ai,indiedev,postgresql
published: true
---

# Supabase Edge Functions with Deno: Production-Ready Design Patterns

Supabase Edge Functions run on Deno. Similar to Node.js, but with subtle differences. Here are the patterns I use running 45+ Edge Functions in production.

## Basic Structure

```typescript
// supabase/functions/my-function/index.ts
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const body = await req.json();
    // ... logic

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
```

## The Hub Pattern: Bundle Related Functions

Managing 45 separate functions is expensive. Group related functions into a single hub:

```typescript
// supabase/functions/schedule-hub/index.ts
serve(async (req) => {
  const { action, ...params } = await req.json();

  switch (action) {
    case 'digest.run':
      return await handleDigest(supabase, params);
    case 'digest.weekly':
      return await handleWeeklyDigest(supabase, params);
    case 'competitor.check':
      return await handleCompetitorCheck(supabase, params);
    default:
      return new Response(
        JSON.stringify({ error: `Unknown action: ${action}` }),
        { status: 400, headers: corsHeaders },
      );
  }
});
```

Flutter call:

```dart
final response = await supabase.functions.invoke(
  'schedule-hub',
  body: {'action': 'digest.run', 'date': DateTime.now().toIso8601String()},
);
```

## Secrets Management

```bash
# Local dev: supabase/functions/.env
OPENAI_API_KEY=sk-...
RESEND_API_KEY=re_...

# Production: Supabase Dashboard → Project Settings → Secrets
# or via CLI:
supabase secrets set OPENAI_API_KEY=sk-...
```

```typescript
const openaiKey = Deno.env.get('OPENAI_API_KEY');
if (!openaiKey) throw new Error('OPENAI_API_KEY not set');
```

## External API Calls: Retry Pattern

```typescript
async function fetchWithRetry(
  url: string,
  options: RequestInit,
  maxRetries = 3,
): Promise<Response> {
  let lastError: Error;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch(url, options);
      if (response.ok) return response;

      // 429 Rate Limit → exponential backoff
      if (response.status === 429) {
        const delay = Math.pow(2, attempt) * 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }

      throw new Error(`HTTP ${response.status}: ${await response.text()}`);
    } catch (error) {
      lastError = error;
      if (attempt < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
      }
    }
  }

  throw lastError!;
}
```

## Calling Postgres Functions via RPC

```typescript
// From Edge Function, call a Postgres function
const { data, error } = await supabase.rpc('get_user_achievements', {
  p_user_id: userId,
  p_limit: 10,
});
```

```sql
-- Postgres side
CREATE OR REPLACE FUNCTION get_user_achievements(
  p_user_id UUID,
  p_limit INT DEFAULT 10
)
RETURNS TABLE (id UUID, title TEXT, completed_at TIMESTAMPTZ)
LANGUAGE sql STABLE
AS $$
  SELECT id, title, completed_at
  FROM development_achievements
  WHERE user_id = p_user_id
  ORDER BY completed_at DESC
  LIMIT p_limit;
$$;
```

RPC is more type-safe than REST and prevents N+1 queries.

## Local Testing

```bash
supabase start

supabase functions serve my-function --no-verify-jwt

curl -X POST http://localhost:54321/functions/v1/my-function \
  -H "Content-Type: application/json" \
  -d '{"action": "test"}'
```

## Deployment

```bash
supabase functions deploy my-function

# or deploy all (automated via GHA)
supabase functions deploy
```

```yaml
# .github/workflows/deploy-prod.yml
- name: Deploy Edge Functions
  run: supabase functions deploy
  env:
    SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
    SUPABASE_PROJECT_ID: ${{ secrets.SUPABASE_PROJECT_ID }}
```

## Summary

```
Design principles:
  1. Hub pattern: bundle related EFs to reduce deploy overhead
  2. Secrets: Deno.env.get + Supabase Secrets (never hardcode)
  3. CORS: always handle OPTIONS preflight
  4. Retries: exponential backoff for 429/500
  5. RPC first: push complex queries into Postgres functions
```

Keep each Edge Function small. The hub pattern lets you scale past 50 functions without losing your mind.
