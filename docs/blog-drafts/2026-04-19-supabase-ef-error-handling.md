---
title: "Supabase Edge Functionのエラーハンドリング完全パターン — 4段階フォールバック設計"
tags: Supabase,Deno,TypeScript,個人開発,buildinpublic
published: true
---

# Supabase Edge Functionのエラーハンドリング完全パターン

## なぜエラーハンドリングが重要か

EFは外部API・DBアクセス・ユーザー入力の3つのエラー発生源を持つ。適切に処理しないと:
- 500エラーが返りFlutterがクラッシュ
- Supabaseのログが無用なノイズで埋まる
- デバッグに時間がかかる

## 4段階フォールバック設計

```typescript
// 基本テンプレート
Deno.serve(async (req: Request) => {
  // 1. CORSプリフライト
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders, status: 204 });
  }

  try {
    // 2. 入力バリデーション
    const { action, ...params } = await parseBody(req);
    if (!action) {
      return errorResponse(400, 'action is required');
    }

    // 3. ルーティング
    switch (action) {
      case 'get': return await handleGet(params);
      case 'upsert': return await handleUpsert(params);
      default: return errorResponse(400, `Unknown action: ${action}`);
    }
  } catch (err) {
    // 4. 予期せぬエラー
    console.error('[EF Error]', err);
    return errorResponse(500, 'Internal server error');
  }
});
```

## 入力バリデーション

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

## エラーレスポンスの統一フォーマット

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

## Supabase クライアントエラー

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
    // PostgreSQLエラーコードに応じて分岐
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

## 外部API呼び出しのタイムアウト

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

## deno lint で0エラー維持

よくある違反パターン:

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

## まとめ

| 層 | 対策 |
|---|---|
| 入力 | JSON/form 両対応 + 型検証 |
| ルーティング | actionスイッチ + 不明action 400 |
| DB | error.code で分岐 |
| 外部API | タイムアウト + AbortController |
| 予期せぬ | try/catch で500 |

この5層パターンをhubの全EFに適用すると、本番でのデバッグ時間が大幅に減る。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Supabase #Deno #TypeScript #buildinpublic #個人開発
