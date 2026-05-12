---
title: "Supabase Edge Functions 完全ガイド — Deno × TypeScript でサーバーレス API を作る"
tags: supabase,dart,AI,個人開発
published: true
---

# Supabase Edge Functions 完全ガイド — Deno × TypeScript でサーバーレス API を作る

Supabase Edge Functions は Deno ランタイムで動くサーバーレス関数です。TypeScript のフルサポート・高速コールドスタート・グローバルエッジデプロイが特徴です。Flutter から安全に呼び出す方法まで解説します。

## Edge Functions の特徴

- **Deno ランタイム**: Node.js 互換ではなく Web 標準 API ベース
- **TypeScript ネイティブ**: トランスパイル不要
- **グローバルエッジ**: ユーザーに近いリージョンで実行
- **環境変数**: `Deno.env.get('VAR_NAME')` でアクセス
- **コールドスタート**: 50ms 以下 (Lambda より高速)

## ローカル開発環境

```bash
# Supabase CLI インストール
npm install -g supabase

# ローカル起動
supabase start
supabase functions serve --env-file .env.local

# 新しい関数を作成
supabase functions new my-function
```

## 基本的な関数の構造

```typescript
// supabase/functions/my-function/index.ts
import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 認証確認
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Supabase クライアント (ユーザーの JWT で初期化)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    // ユーザー確認
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // リクエストボディ解析
    const { message } = await req.json()

    // ビジネスロジック
    const result = await processMessage(supabase, user.id, message)

    return new Response(
      JSON.stringify({ data: result }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

## Hub パターン (EF-CAP-50 対策)

1 つの EF を複数 action のハブにすることで、50 EF 上限を回避:

```typescript
// supabase/functions/schedule-hub/index.ts
type Action =
  | 'digest.run'
  | 'metrics.get'
  | 'notifications.send'
  | 'competitor.check'

interface HubRequest {
  action: Action
  payload?: Record<string, unknown>
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const { action, payload }: HubRequest = await req.json()

  switch (action) {
    case 'digest.run':
      return handleDigest(payload)
    case 'metrics.get':
      return handleMetrics(payload)
    case 'notifications.send':
      return handleNotifications(payload)
    case 'competitor.check':
      return handleCompetitorCheck(payload)
    default:
      return new Response(
        JSON.stringify({ error: `Unknown action: ${action}` }),
        { status: 400, headers: corsHeaders }
      )
  }
})
```

## 外部 API との連携 (OpenAI 例)

```typescript
async function callOpenAI(prompt: string): Promise<string> {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
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

  const data = await response.json()
  return data.choices[0].message.content
}
```

## デプロイ

```bash
# 単一関数のデプロイ
supabase functions deploy my-function

# 全関数のデプロイ
supabase functions deploy

# 環境変数の設定
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set RESEND_API_KEY=re_...
```

## Flutter からの呼び出し

```dart
// lib/services/edge_function_service.dart
class EdgeFunctionService {
  static Future<Map<String, dynamic>> callHub({
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    final response = await supabase.functions.invoke(
      'schedule-hub',
      body: {'action': action, 'payload': payload},
    );

    if (response.status != 200) {
      throw Exception('EF Error: ${response.data['error']}');
    }
    return response.data as Map<String, dynamic>;
  }
}

// 使用例
final metrics = await EdgeFunctionService.callHub(action: 'metrics.get');
```

## ログとモニタリング

```bash
# ローカルログ確認
supabase functions logs my-function

# 本番ログ
supabase functions logs my-function --project-ref xxxx
```

```typescript
// 構造化ログ (Supabase Dashboard で検索可)
console.log(JSON.stringify({
  level: 'info',
  action: 'digest.run',
  userId: user.id,
  duration_ms: Date.now() - startTime,
}))
```

## まとめ

Supabase Edge Functions の Hub パターンで、1 つの EF に複数 action を集約することで EF 上限を効率的に管理できます。Deno の Web 標準 API と TypeScript の組み合わせで、保守しやすいサーバーレス API を構築できます。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
