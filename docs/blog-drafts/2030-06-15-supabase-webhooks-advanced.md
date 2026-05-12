---
title: "Supabase Webhooks 完全ガイド — Database Trigger・pg_net・Edge Function連携の実践パターン"
emoji: "🔔"
type: "tech"
topics: ["supabase", "postgresql", "deno", "webhook"]
published: true
---

# Supabase Webhooks 完全ガイド — Database Trigger・pg_net・Edge Function連携の実践パターン

Supabase Webhooks を使うと、テーブルの INSERT/UPDATE/DELETE をトリガーにして外部サービスやEdge Functionを自動呼び出しできます。本記事では `pg_net` 拡張と Database Webhooks の仕組みを解説し、実務で役立つパターンを紹介します。

## Supabase Webhooks の仕組み

```
DB変更 → pg_net (非同期HTTP) → 外部エンドポイント or Edge Function
```

Supabase は内部で `pg_net` 拡張を使い、PostgreSQL の `AFTER INSERT/UPDATE/DELETE` トリガーからHTTPリクエストを非同期送信します。

## Supabase Dashboard での設定

1. **Database → Webhooks → Create a new hook**
2. テーブル・イベント (INSERT/UPDATE/DELETE) を選択
3. エンドポイントURLを指定 (Edge Function URL or 外部サービス)
4. HTTP Method と Headers を設定

## pg_net で直接制御する

```sql
-- pg_net 拡張の有効化 (Supabase では標準で有効)
create extension if not exists pg_net;

-- 手動でHTTPリクエストを送信
select net.http_post(
  url := 'https://your-project.supabase.co/functions/v1/notify-user',
  body := json_build_object(
    'user_id', NEW.user_id,
    'event', 'new_message',
    'content', NEW.content
  )::jsonb,
  headers := '{"Authorization": "Bearer <service-role-key>", "Content-Type": "application/json"}'::jsonb
);
```

## Edge Function と連携するパターン

### 新規ユーザー登録時にウェルカムメール送信

```sql
-- supabase/migrations/20300615000000_webhook_welcome_email.sql
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  perform net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/send-welcome-email',
    body := json_build_object(
      'user_id', NEW.id,
      'email', NEW.email,
      'display_name', NEW.raw_user_meta_data->>'display_name'
    )::jsonb,
    headers := json_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    )::jsonb
  );
  return NEW;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

```typescript
// supabase/functions/send-welcome-email/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const { user_id, email, display_name } = await req.json();

  // Resend API でメール送信
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "noreply@jibun-kk.com",
      to: email,
      subject: "自分株式会社へようこそ",
      html: `<h1>こんにちは、${display_name}さん</h1><p>登録ありがとうございます。</p>`,
    }),
  });

  return new Response(JSON.stringify({ ok: res.ok }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

## pg_cron でスケジュール実行

`pg_cron` 拡張を使うと SQL ジョブをクーロンスケジュールで実行できます。

```sql
-- pg_cron 有効化
create extension if not exists pg_cron;

-- 毎日 00:00 UTC に期限切れセッションを削除
select cron.schedule(
  'cleanup-expired-sessions',
  '0 0 * * *',
  $$
    delete from user_sessions
    where expires_at < now();
  $$
);

-- WBS タスクの期限チェック (毎時)
select cron.schedule(
  'check-overdue-wbs-tasks',
  '0 * * * *',
  $$
    update wbs_tasks
    set status = 'overdue',
        recovery_plan = 'Auto-flagged by cron'
    where deadline < now()
      and status not in ('completed', 'overdue')
      and recovery_plan is null;
  $$
);

-- 登録済みジョブ一覧
select * from cron.job;

-- ジョブ削除
select cron.unschedule('cleanup-expired-sessions');
```

## Webhook セキュリティ — HMAC 署名検証

```typescript
// supabase/functions/_shared/verify-webhook.ts
export async function verifyWebhookSignature(
  req: Request,
  secret: string
): Promise<boolean> {
  const signature = req.headers.get("x-supabase-webhook-signature");
  if (!signature) return false;

  const body = await req.text();
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signatureBytes = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(body)
  );

  const expectedSignature =
    "sha256=" +
    Array.from(new Uint8Array(signatureBytes))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

  return signature === expectedSignature;
}
```

## Webhook の失敗処理とリトライ

```sql
-- Webhook 実行ログテーブル
create table if not exists webhook_logs (
  id bigint generated always as identity primary key,
  event_type text not null,
  payload jsonb not null,
  response_status int,
  error_message text,
  retry_count int default 0,
  created_at timestamptz default now()
);

-- 失敗したWebhookを再試行するFunction
create or replace function public.retry_failed_webhooks()
returns void
language plpgsql
as $$
declare
  rec record;
begin
  for rec in
    select * from webhook_logs
    where response_status >= 500
      and retry_count < 3
      and created_at > now() - interval '24 hours'
  loop
    perform net.http_post(
      url := 'https://your-project.supabase.co/functions/v1/process-event',
      body := rec.payload,
      headers := '{"Content-Type": "application/json"}'::jsonb
    );

    update webhook_logs
    set retry_count = retry_count + 1
    where id = rec.id;
  end loop;
end;
$$;

-- 毎5分に再試行
select cron.schedule('retry-failed-webhooks', '*/5 * * * *',
  'select public.retry_failed_webhooks();');
```

## 自分株式会社での活用例

- **development_achievements 更新時に X 自動投稿**: `post-x-update` EF を Webhook で呼び出し
- **WBS タスク期限切れ検知**: `pg_cron` で毎時チェック → Slack 通知
- **AI大学コンテンツ自動更新**: `ai_university_providers` INSERT 後に sitemap 更新 Webhook

## まとめ

| シナリオ | 手段 |
|---|---|
| DB変更 → 外部サービス通知 | Database Webhooks (Dashboard) |
| DB変更 → Edge Function 呼び出し | `pg_net.http_post` in trigger |
| 定期バッチ処理 | `pg_cron.schedule` |
| Webhook 認証 | HMAC SHA-256 署名検証 |

Supabase Webhooks + pg_cron の組み合わせで、フロントエンドを一切変更せずにサーバーサイドの自動化が実現できます。
