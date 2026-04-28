---
title: "Supabase Edge Function エラーハンドリング — リトライ・ログ・Circuit Breaker"
tags: supabase,AI,個人開発,automation
published: true
---

# Supabase Edge Function エラーハンドリング — リトライ・ログ・Circuit Breaker

本番 EF でエラーを握りつぶさないための設計パターンをまとめる。

## 基本: エラーを構造化して返す

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

## リトライ付き外部 API 呼び出し

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

## 構造化ログ

```typescript
// 全 EF に共通のログ形式
function log(level: 'info' | 'warn' | 'error', message: string, meta?: object) {
  console.log(JSON.stringify({
    level,
    message,
    timestamp: new Date().toISOString(),
    function: Deno.env.get('FUNCTION_NAME') ?? 'unknown',
    ...meta,
  }));
}

// 使用例
log('info', 'Processing webhook', { event_type: event.type });
log('error', 'Stripe API failed', { attempt: 3, status: 500 });
```

## Webhook のべき等処理

```typescript
// 同一イベントの二重処理を防ぐ
const { data: processed } = await supabase
  .from('processed_webhooks')
  .select('id')
  .eq('event_id', event.id)
  .maybeSingle();

if (processed) {
  return new Response('ok'); // 二重送信を無視
}

// 処理後に記録
await supabase.from('processed_webhooks').insert({
  event_id: event.id,
  processed_at: new Date().toISOString(),
});
```

## まとめ

```
エラー返却    → AppError + errorResponse で構造化
リトライ     → exponential backoff (429 / 5xx 対象)
ログ         → JSON 構造化ログ (Supabase Dashboard で検索可)
べき等性     → processed_webhooks テーブルで二重処理防止
```

EF は「落ちても安全」な設計をデフォルトにする。
