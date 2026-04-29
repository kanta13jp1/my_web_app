---
title: "Supabase Edge Functions Complete Guide — Serverless APIs with Deno & TypeScript"
tags: supabase,ai,indiedev,flutter
published: true
---

# Supabase Edge Functions Complete Guide — Serverless APIs with Deno & TypeScript

Supabase Edge Functions run on the Deno runtime at the global edge. Native TypeScript, fast cold starts, and seamless Supabase integration make them the ideal serverless layer for Flutter apps.

## Why Edge Functions?

- **Deno runtime**: Web-standard APIs, not Node.js
- **TypeScript native**: No transpile step
- **Global edge**: Runs close to your users
- **Env vars**: `Deno.env.get('VAR_NAME')`
- **Cold start**: Under 50ms (faster than Lambda)

## Local Development

```bash
npm install -g supabase
supabase start
supabase functions serve --env-file .env.local
supabase functions new my-function
```

## Basic Function Structure

```typescript
// supabase/functions/my-function/index.ts
import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error } = await supabase.auth.getUser()
    if (error || !user) return new Response(
      JSON.stringify({ error: 'Invalid token' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

    const { message } = await req.json()
    const result = await processMessage(supabase, user.id, message)

    return new Response(JSON.stringify({ data: result }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
```

## Hub Pattern (Stay Under the 50 EF Limit)

Route multiple actions through one EF:

```typescript
// supabase/functions/schedule-hub/index.ts
type Action = 'digest.run' | 'metrics.get' | 'notifications.send' | 'competitor.check'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const { action, payload } = await req.json()

  switch (action) {
    case 'digest.run': return handleDigest(payload)
    case 'metrics.get': return handleMetrics(payload)
    case 'notifications.send': return handleNotifications(payload)
    case 'competitor.check': return handleCompetitorCheck(payload)
    default: return new Response(
      JSON.stringify({ error: `Unknown action: ${action}` }),
      { status: 400, headers: corsHeaders }
    )
  }
})
```

## External API Integration

```typescript
async function callOpenAI(prompt: string): Promise<string> {
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 500,
    }),
  })
  const data = await res.json()
  return data.choices[0].message.content
}
```

## Deploy

```bash
supabase functions deploy my-function
supabase functions deploy  # Deploy all
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set RESEND_API_KEY=re_...
```

## Calling from Flutter

```dart
class EdgeFunctionService {
  static Future<Map<String, dynamic>> callHub({
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    final response = await supabase.functions.invoke(
      'schedule-hub',
      body: {'action': action, 'payload': payload},
    );
    if (response.status != 200) throw Exception('EF Error: ${response.data['error']}');
    return response.data as Map<String, dynamic>;
  }
}

// Usage
final metrics = await EdgeFunctionService.callHub(action: 'metrics.get');
```

## Structured Logging

```typescript
console.log(JSON.stringify({
  level: 'info',
  action: 'digest.run',
  userId: user.id,
  duration_ms: Date.now() - startTime,
}))
```

## Summary

The Hub pattern lets you consolidate multiple actions into one Edge Function, keeping you well under Supabase's 50 EF limit. Deno's Web-standard APIs and native TypeScript make for clean, maintainable serverless code.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
