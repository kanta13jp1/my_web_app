---
title: "Supabase Edge Functions 高度活用 — ストリーミング・WebSocket・バックグラウンドジョブ"
tags: Supabase,Flutter,webdev,個人開発
published: true
---

Supabase Edge Functions は Deno ベースの軽量サーバーレス環境です。シンプルな REST API を超えて、ストリーミングレスポンス・WebSocket・バックグラウンドジョブ処理など高度なユースケースを実装する方法を解説します。

## ストリーミングレスポンス

LLM API などのロングランニング処理をリアルタイムにクライアントへ届ける:

```typescript
// supabase/functions/stream-ai/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  const { prompt } = await req.json()

  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder()

      // Claude API ストリーミング呼び出し
      const response = await fetch('https://api.anthropic.com/v1/messages', {
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

      const reader = response.body!.getReader()
      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        controller.enqueue(value)
      }
      controller.close()
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  })
})
```

### Flutter 側でストリーム受信

```dart
Future<void> streamAiResponse(String prompt) async {
  final uri = Uri.parse('$_supabaseUrl/functions/v1/stream-ai');
  final request = http.Request('POST', uri)
    ..headers['Authorization'] = 'Bearer $_anonKey'
    ..headers['Content-Type'] = 'application/json'
    ..body = jsonEncode({'prompt': prompt});

  final streamedResponse = await request.send();
  final stream = streamedResponse.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  await for (final line in stream) {
    if (line.startsWith('data: ')) {
      final data = line.substring(6);
      if (data == '[DONE]') break;
      // SSE イベントを UI に反映
      setState(() => _buffer += _parseChunk(data));
    }
  }
}
```

## WebSocket 接続

Edge Function を WebSocket サーバーとして使う:

```typescript
// supabase/functions/ws-chat/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const connections = new Map<string, WebSocket>()

serve((req) => {
  const upgrade = req.headers.get('upgrade') || ''
  if (upgrade.toLowerCase() !== 'websocket') {
    return new Response('WebSocket only', { status: 426 })
  }

  const { socket, response } = Deno.upgradeWebSocket(req)
  const id = crypto.randomUUID()

  socket.onopen = () => {
    connections.set(id, socket)
    console.log(`Client ${id} connected`)
  }

  socket.onmessage = async (event) => {
    const msg = JSON.parse(event.data)
    // ブロードキャスト
    for (const [clientId, ws] of connections) {
      if (clientId !== id && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ from: id, ...msg }))
      }
    }
  }

  socket.onclose = () => connections.delete(id)

  return response
})
```

## バックグラウンドジョブ (EdgeRuntime.waitUntil)

レスポンスを返した後も処理を継続:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  const payload = await req.json()

  // バックグラウンドで重い処理を非同期実行
  EdgeRuntime.waitUntil(
    processHeavyTask(payload)
      .catch(err => console.error('Background task failed:', err))
  )

  // 即座にレスポンスを返す
  return new Response(JSON.stringify({ status: 'accepted' }), {
    headers: { 'Content-Type': 'application/json' },
  })
})

async function processHeavyTask(payload: unknown) {
  // メール送信・外部API呼び出し・DB集計など
  await new Promise(resolve => setTimeout(resolve, 5000))
  console.log('Heavy task completed for:', payload)
}
```

## 定期スケジュール (pg_cron + Edge Function)

```sql
-- Supabase SQL Editor
SELECT cron.schedule(
  'daily-digest',
  '0 9 * * *',  -- 毎日9時
  $$
  SELECT net.http_post(
    url := 'https://xxxx.supabase.co/functions/v1/daily-digest',
    headers := '{"Authorization": "Bearer SERVICE_KEY"}'::jsonb,
    body := '{}'::jsonb
  )
  $$
);
```

## レート制限とリトライ

```typescript
// Exponential backoff retry
async function fetchWithRetry(
  url: string,
  options: RequestInit,
  maxRetries = 3
): Promise<Response> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const res = await fetch(url, options)
    if (res.status !== 429 && res.status !== 503) return res

    const delay = Math.pow(2, attempt) * 1000 + Math.random() * 1000
    await new Promise(r => setTimeout(r, delay))
  }
  throw new Error(`Max retries exceeded for ${url}`)
}
```

## まとめ

Supabase Edge Functions はストリーミング・WebSocket・バックグラウンドジョブをサポートし、本格的なリアルタイム機能を安価に構築できます。pg_cron との組み合わせでスケジュール実行も可能です。

次回: 個人開発 SaaS ローンチ戦略 (価格設定・課金・フリーミアム設計) を解説します。
