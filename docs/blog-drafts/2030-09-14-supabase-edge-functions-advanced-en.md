---
title: "Supabase Edge Functions Advanced — Streaming, WebSockets, and Background Jobs"
tags: supabase,flutter,webdev,programming
published: true
---

Supabase Edge Functions run on Deno Deploy and are far more capable than simple REST handlers. This guide covers three advanced patterns every indie developer should know: streaming responses (for LLM integrations), WebSocket upgrades (for real-time features), and background jobs using `EdgeRuntime.waitUntil`.

## Pattern 1: Streaming Responses (SSE)

The most common use case is streaming LLM output without blocking the client.

```typescript
// supabase/functions/stream-ai/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  const { prompt } = await req.json()

  const upstream = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': Deno.env.get('ANTHROPIC_API_KEY')!,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5',
      max_tokens: 1024,
      stream: true,
      messages: [{ role: 'user', content: prompt }],
    }),
  })

  // Pipe the upstream SSE stream directly to the client
  return new Response(upstream.body, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    },
  })
})
```

### Flutter Client for SSE

```dart
Stream<String> streamAiResponse(String prompt) async* {
  final request = http.Request(
    'POST',
    Uri.parse('$supabaseUrl/functions/v1/stream-ai'),
  )
    ..headers['Authorization'] = 'Bearer $anonKey'
    ..headers['Content-Type'] = 'application/json'
    ..body = jsonEncode({'prompt': prompt});

  final response = await request.send();

  await for (final line in response.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    if (!line.startsWith('data: ')) continue;
    final data = line.substring(6).trim();
    if (data == '[DONE]') return;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final delta = json['delta']?['text'] as String?;
      if (delta != null) yield delta;
    } catch (_) {
      // skip malformed chunks
    }
  }
}
```

## Pattern 2: WebSocket Upgrades

Edge Functions can be upgraded to full WebSocket connections, enabling real-time bidirectional communication without Supabase Realtime channels.

```typescript
// supabase/functions/ws-relay/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

// In-memory room registry (per isolate)
const rooms = new Map<string, Set<WebSocket>>()

serve((req) => {
  if (req.headers.get('upgrade')?.toLowerCase() !== 'websocket') {
    return new Response('WebSocket upgrade required', { status: 426 })
  }

  const url = new URL(req.url)
  const room = url.searchParams.get('room') ?? 'default'

  const { socket, response } = Deno.upgradeWebSocket(req)

  socket.onopen = () => {
    if (!rooms.has(room)) rooms.set(room, new Set())
    rooms.get(room)!.add(socket)
  }

  socket.onmessage = (event) => {
    const peers = rooms.get(room) ?? new Set()
    for (const peer of peers) {
      if (peer !== socket && peer.readyState === WebSocket.OPEN) {
        peer.send(event.data)
      }
    }
  }

  socket.onclose = () => rooms.get(room)?.delete(socket)

  return response
})
```

### Important Caveat

Each Edge Function invocation runs in its own Deno isolate. The in-memory `rooms` map is local to one instance. For production multi-room chat, use Supabase Realtime or a Redis-backed pub/sub.

## Pattern 3: Background Jobs with waitUntil

Return a fast response to the client while doing heavy work asynchronously:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { user_id, event_type } = await req.json()

  // Kick off background work — fires-and-forgets after response is sent
  EdgeRuntime.waitUntil(
    runAnalyticsPipeline(user_id, event_type)
  )

  // Respond immediately — client doesn't wait for pipeline
  return new Response(JSON.stringify({ queued: true }), {
    headers: { 'Content-Type': 'application/json' },
  })
})

async function runAnalyticsPipeline(userId: string, event: string) {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Heavy operations: aggregation, external API calls, email sending
  await supabase.rpc('update_user_metrics', { p_user_id: userId, p_event: event })
  await notifySlack(`User ${userId} triggered ${event}`)
}
```

## Scheduled Execution via pg_cron

Run an Edge Function on a schedule using Supabase's built-in pg_cron extension:

```sql
SELECT cron.schedule(
  'morning-digest',
  '0 9 * * *',
  $$
  SELECT net.http_post(
    url        := current_setting('app.supabase_url') || '/functions/v1/morning-digest',
    headers    := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    ),
    body       := '{}'::jsonb
  );
  $$
);
```

## Retry with Exponential Backoff

For external API calls inside Edge Functions:

```typescript
async function fetchWithRetry(
  url: string,
  init: RequestInit,
  maxAttempts = 3
): Promise<Response> {
  for (let i = 0; i < maxAttempts; i++) {
    const res = await fetch(url, init)
    if (res.ok || res.status < 500) return res

    if (i < maxAttempts - 1) {
      const jitter = Math.random() * 1000
      await new Promise(r => setTimeout(r, (2 ** i) * 1000 + jitter))
    }
  }
  throw new Error(`All ${maxAttempts} attempts failed for ${url}`)
}
```

## Key Limitations to Know

| Constraint | Value | Workaround |
|-----------|-------|-----------|
| CPU time limit | 400ms (free) / 2s (pro) | Use `waitUntil` for heavy work |
| Memory per invocation | 150MB | Stream large payloads |
| WebSocket in-memory state | Per isolate only | Use Realtime for multi-node |
| Max response size | 6MB | Stream or paginate |

## Indie Dev Cost Profile

On Supabase Free: 500K invocations/month. Streaming 1K tokens via Claude Haiku costs ~$0.001. For a 1,000-user app with 10 AI queries/day: ~10M tokens/month = $10 on Haiku. Edge Function invocations: ~10M/month — well within the Pro plan limits.

## Summary

Three patterns unlock the full power of Supabase Edge Functions for production apps: SSE streaming for LLM output, WebSocket upgrades for real-time features, and `EdgeRuntime.waitUntil` for fire-and-forget background work. Combined with pg_cron scheduling, Edge Functions can replace a significant chunk of traditional backend infrastructure.

Next up: Indie Dev SaaS Launch — pricing strategy, Stripe integration, and freemium-to-paid conversion design.
