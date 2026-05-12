---
title: "Supabase Edge Functions 設計パターン — Hub / RLS / エラーハンドリング"
tags: supabase,AI,個人開発,programming
published: true
---

# Supabase Edge Functions 設計パターン — Hub / RLS / エラーハンドリング

Edge Functions を乱立させると管理が破綻する。3つのパターンで整理する。

## なぜ Edge Functions が必要か

```
Flutter Web → 直接 Supabase DB は避けるべき理由:
  1. APIキーがブラウザに露出する
  2. 複数テーブルのトランザクションが難しい
  3. ビジネスロジックをクライアントに置くとセキュリティリスク

→ Edge Functions = Deno で動くサーバーレス関数 (TypeScript)
```

## パターン1: Hub Pattern (action ルーティング)

関連する機能を1つの Edge Function にまとめる。50 関数制限対策にも有効。

```typescript
// supabase/functions/schedule-hub/index.ts
import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";

serve(async (req) => {
  const { action, payload } = await req.json();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  switch (action) {
    case "digest.run":
      return await handleDigest(supabase, payload);
    case "kpi.update":
      return await handleKpiUpdate(supabase, payload);
    case "report.generate":
      return await handleReport(supabase, payload);
    default:
      return new Response(
        JSON.stringify({ error: `Unknown action: ${action}` }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
  }
});

async function handleDigest(supabase, payload) {
  const { data, error } = await supabase
    .from("weekly_kpis")
    .select("*")
    .order("week_start", { ascending: false })
    .limit(4);

  if (error) throw error;
  return new Response(JSON.stringify({ data }), {
    headers: { "Content-Type": "application/json" }
  });
}
```

**Flutter からの呼び出し**:

```dart
final response = await supabase.functions.invoke(
  'schedule-hub',
  body: {'action': 'digest.run', 'payload': {}},
);
```

## パターン2: サービスロールキーと RLS の使い分け

```typescript
// NG: anon キーで全データ操作 → RLS が邪魔になる
const supabase = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!);

// OK: サービスロールキーは RLS をバイパスする
// → Edge Function 内での管理者操作に使用
const adminClient = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

// OK: ユーザーの JWT を使う → RLS が適用される (ユーザーは自分のデータのみ)
serve(async (req) => {
  const authHeader = req.headers.get("Authorization")!;
  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } }
  });
  // この userClient は認証ユーザーとして動作 → RLS 適用
});
```

**判断基準**:

```
管理者タスク (全ユーザーへの一斉操作など) → SERVICE_ROLE_KEY
ユーザー固有の操作 (自分のデータ更新)     → ユーザー JWT を転送
```

## パターン3: 統一エラーハンドリング

```typescript
// shared/response.ts
export function ok(data: unknown, status = 200): Response {
  return new Response(JSON.stringify({ data }), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

export function err(message: string, status = 400): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

// Edge Function 内で統一使用
serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "POST" }
    });
  }

  try {
    const result = await processRequest(req);
    return ok(result);
  } catch (e) {
    console.error("Edge Function error:", e);
    return err(e instanceof Error ? e.message : "Internal error", 500);
  }
});
```

## デプロイと確認

```bash
# 単一関数のデプロイ
supabase functions deploy schedule-hub --no-verify-jwt

# ローカルテスト
supabase functions serve schedule-hub
curl -X POST http://localhost:54321/functions/v1/schedule-hub \
  -H "Content-Type: application/json" \
  -d '{"action":"digest.run","payload":{}}'

# ログ確認
supabase functions logs schedule-hub
```

## まとめ

```
関数数を減らす    → Hub Pattern (action ルーティング)
データ保護        → RLS (ユーザー JWT) / 管理操作 (SERVICE_ROLE)
エラー統一        → ok()/err() ヘルパー + try/catch
CORS 対応         → OPTIONS preflight + Access-Control-Allow-Origin
```

Edge Functions は「Flutter が直接 DB を触れない処理」のラッパー。Hub Pattern で関数数を抑えながら、RLS と組み合わせてデータを保護する設計が長期運用に向く。

