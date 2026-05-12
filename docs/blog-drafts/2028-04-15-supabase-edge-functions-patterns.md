---
title: "Supabase Edge Functions パターン集 — JWT認証 / CORS / エラーハンドリング"
tags: supabase,AI,個人開発,programming
published: true
---

# Supabase Edge Functions パターン集 — JWT認証 / CORS / エラーハンドリング

Deno ランタイムで動く Edge Function の実用パターン3選。

## 1. JWT 認証: ログインユーザーのみ許可

```typescript
// supabase/functions/secure-action/index.ts
import { createClient } from "npm:@supabase/supabase-js";

Deno.serve(async (req) => {
  // JWT を検証してユーザー情報を取得
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

  // ここから先は認証済みユーザーのみ
  const { data } = await supabase
    .from("user_data")
    .select("*")
    .eq("user_id", user.id);

  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
});
```

**Flutter から呼ぶ**:

```dart
final response = await supabase.functions.invoke(
  'secure-action',
  // Authorization ヘッダーは SDK が自動付与
);
```

## 2. CORS: ブラウザからの直接呼び出し

```typescript
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  // Preflight リクエスト (OPTIONS) を処理
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { name } = await req.json();

    return new Response(
      JSON.stringify({ message: `Hello, ${name}!` }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
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

## 3. 構造化エラーハンドリング

```typescript
// 共通エラー型
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

## ローカル開発: supabase start + serve

```bash
# ローカル Supabase 起動
supabase start

# EF をローカルで実行
supabase functions serve secure-action --env-file .env.local

# 別ターミナルでテスト
curl -X POST http://localhost:54321/functions/v1/secure-action \
  -H "Authorization: Bearer <local-anon-key>" \
  -H "Content-Type: application/json" \
  -d '{"action": "test"}'
```

## まとめ

```
JWT 認証      → Authorization ヘッダー → supabase.auth.getUser()
CORS          → OPTIONS プリフライト処理 + corsHeaders を全レスポンスに付与
エラー処理    → 構造化 AppError 型 + try/catch で一元管理
ローカル開発  → supabase functions serve でホット リロード
```

Edge Function はコールドスタートが数十ms。Lambda より圧倒的に高速。
Flutter SDK の `functions.invoke()` は Authorization ヘッダーを自動付与する。
