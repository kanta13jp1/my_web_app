---
title: "Supabase Edge Functions 上級編 — Deno・Webhook・スケジュール・マルチテナント対応"
tags: flutter,dart,個人開発,AI
published: true
---

# Supabase Edge Functions 上級編 — Deno・Webhook・スケジュール・マルチテナント対応

Supabase Edge Functions は Deno Deploy 上で動作する軽量なサーバーレス実行環境です。基本的な CRUD API を超えた、Webhook 受信・スケジュール実行・マルチテナント対応のパターンを解説します。

## Deno Deploy 環境の注意点

Edge Functions は Node.js ではなく **Deno** で動作します。主な違いは以下のとおりです。

- `require()` は使えません。`import` 文（ESM）のみ対応。
- Node.js 組み込みモジュール（`fs`, `crypto` など）は `node:` プレフィックスで一部利用可。
- npm パッケージは `npm:` プレフィックスで直接インポート可能（Deno 1.34 以降）。
- ファイルシステムへの永続書き込みは不可。一時ファイルは `/tmp` に限定。

```typescript
// npm パッケージを直接インポートする例
import { Resend } from "npm:resend@3";
import Stripe from "npm:stripe@14";
```

ローカル開発は `supabase functions serve --env-file .env.local` で行い、本番と同じ Deno 環境を再現できます。

## Webhook 受信と HMAC-SHA256 署名検証

外部サービス（Stripe, GitHub など）からの Webhook を安全に受け取るには、**署名検証**が必須です。`X-Signature-256` ヘッダーの値を HMAC-SHA256 で検証します。

```typescript
// supabase/functions/webhook-receiver/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const SECRET = Deno.env.get("WEBHOOK_SECRET")!;

serve(async (req) => {
  const signature = req.headers.get("x-signature-256") ?? "";
  const body = await req.arrayBuffer();

  // 署名を検証
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"]
  );

  const sigBytes = hexToBytes(signature.replace("sha256=", ""));
  const valid = await crypto.subtle.verify("HMAC", key, sigBytes, body);

  if (!valid) {
    return new Response("Unauthorized", { status: 401 });
  }

  const payload = JSON.parse(new TextDecoder().decode(body));
  // ここからビジネスロジック
  return new Response("OK", { status: 200 });
});

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.slice(i, i + 2), 16);
  }
  return bytes;
}
```

## pg_cron + Edge Function でスケジュールジョブ

Supabase は `pg_cron` 拡張を使って PostgreSQL 内からスケジュールジョブを実行できます。Edge Function を HTTP 呼び出しする cron ジョブを設定すれば、毎日の集計処理やリマインダー送信が実現できます。

```sql
-- 毎日 JST 9:00 (UTC 0:00) に Edge Function を呼び出す
select cron.schedule(
  'daily-digest',
  '0 0 * * *',
  $$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/daily-digest',
    headers := '{"Authorization": "Bearer ' || current_setting('app.service_key') || '"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
```

`pg_net` 拡張と組み合わせることで、SQL から直接 HTTP リクエストを発行できます。Edge Function 側では `Authorization` ヘッダーのサービスキーを検証して不正アクセスを防ぎます。

## マルチテナント: JWT からテナント ID を取得して RLS 適用

複数の組織がデータを持つ SaaS では、Edge Function 内でテナント ID を正確に取り出し、RLS がテナント境界を強制するようにする必要があります。

サービスロールキーを使うと RLS をバイパスしてしまうため、**ユーザーの JWT をそのまま使う**パターンが安全です。

```typescript
// supabase/functions/tenant-api/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req) => {
  // Authorization ヘッダーからユーザーの JWT を取り出す
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");

  // サービスロールではなくユーザー JWT でクライアントを生成 → RLS が自動的に適用される
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: `Bearer ${token}` } } }
  );

  // JWT の claims からテナント ID を取得（カスタムクレームを設定済みの場合）
  const { data: { user } } = await supabase.auth.getUser();
  const tenantId = user?.app_metadata?.tenant_id;

  if (!tenantId) {
    return new Response("Forbidden", { status: 403 });
  }

  // このクエリは RLS ポリシーにより tenantId に対応する行のみ返す
  const { data, error } = await supabase
    .from("projects")
    .select("*");

  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
});
```

RLS ポリシー側では `auth.jwt() -> 'app_metadata' ->> 'tenant_id'` でテナント ID を参照します。

## 環境変数の管理 — Deno.env.get()

本番シークレットは `supabase secrets set` で登録し、Edge Function 内では `Deno.env.get()` で取得します。

```bash
supabase secrets set RESEND_API_KEY=re_xxxx
supabase secrets set STRIPE_SECRET_KEY=sk_live_xxxx
```

```typescript
const resend = new Resend(Deno.env.get("RESEND_API_KEY")!);
```

ローカル開発用は `.env.local` ファイルに記載し、`.gitignore` で必ず除外してください。

## まとめ

- **Deno 環境**: `import` + `npm:` プレフィックスで Node.js 感覚で書ける
- **Webhook**: HMAC-SHA256 署名検証を必ず実装して不正リクエストを排除
- **スケジュール**: `pg_cron` + `pg_net` で DB 内から Edge Function を呼び出す
- **マルチテナント**: サービスロールを避け、ユーザー JWT をそのまま渡して RLS に委ねる

次回はインディー SaaS のリテンション戦略を解説します。
