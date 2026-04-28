---
title: "Supabase Edge Functions + Deno 実践 — 本番で使える設計パターン"
tags: supabase,AI,個人開発,postgresql
published: true
---

# Supabase Edge Functions + Deno 実践 — 本番で使える設計パターン

Supabase Edge Functions は Deno で動く。Node.js と似ているが細かい差がある。本番で45本以上の EF を運用してきた経験から、使える設計パターンをまとめる。

## Edge Function の基本構造

```typescript
// supabase/functions/my-function/index.ts
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const body = await req.json();
    // ... ロジック

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

## Hub パターン: EF を束ねる

45本を1本ずつ管理するのはコストが高い。関連する EF を1つの hub にまとめる:

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

Flutter から呼ぶ:

```dart
final response = await supabase.functions.invoke(
  'schedule-hub',
  body: {'action': 'digest.run', 'date': DateTime.now().toIso8601String()},
);
```

## 環境変数とシークレット管理

```bash
# ローカル開発: supabase/functions/.env
OPENAI_API_KEY=sk-...
RESEND_API_KEY=re_...

# 本番: Supabase Dashboard → Project Settings → Secrets
# または CLI で設定
supabase secrets set OPENAI_API_KEY=sk-...
```

```typescript
// コード内で参照
const openaiKey = Deno.env.get('OPENAI_API_KEY');
if (!openaiKey) throw new Error('OPENAI_API_KEY not set');
```

## 外部 API 呼び出し: リトライパターン

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

      // 429 Rate Limit → 指数バックオフ
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

## Supabase Postgres 直呼び: RPC 活用

```typescript
// Edge Function から Postgres 関数を呼ぶ
const { data, error } = await supabase.rpc('get_user_achievements', {
  p_user_id: userId,
  p_limit: 10,
});
```

```sql
-- Postgres 側の関数
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

RPC は REST API より型安全で、N+1 クエリも防げる。

## ローカルテスト

```bash
# Supabase を起動
supabase start

# 関数を単体で実行
supabase functions serve my-function --no-verify-jwt

# curl でテスト
curl -X POST http://localhost:54321/functions/v1/my-function \
  -H "Content-Type: application/json" \
  -d '{"action": "test"}'
```

## デプロイ

```bash
# 単一関数のみデプロイ
supabase functions deploy my-function

# 全関数デプロイ (GHA で自動化)
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

## まとめ

```
設計原則:
  1. Hub パターン: 関連 EF を束ねてデプロイコスト削減
  2. シークレット管理: Deno.env.get + Supabase Secrets
  3. CORS: preflight 必須 + Allow-Origin 適切設定
  4. リトライ: 429/500 は指数バックオフ
  5. RPC 優先: 複雑なクエリは Postgres 関数に移す
```

Edge Function は小さく保つほど管理が楽になる。Hub パターンで整理すると、50本超えても追いつける。
