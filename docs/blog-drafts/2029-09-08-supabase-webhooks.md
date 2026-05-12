---
title: "Supabase Webhooks 実践 — データベース変更をリアルタイムでトリガーする"
tags: flutter,dart,個人開発,AI
published: true
---

# Supabase Webhooks 実践 — データベース変更をリアルタイムでトリガーする

Supabase Webhooks を使うと、テーブルへの INSERT/UPDATE/DELETE をトリガーに Edge Function・外部 API・Slack 通知などを自動実行できます。pg_net + pg_cron との組み合わせで強力なイベント駆動バックエンドを構築できます。

## Webhooks の仕組み

```
DB 変更 (INSERT/UPDATE/DELETE)
  → pg_net が HTTP POST を非同期送信
  → 宛先: Edge Function / 外部 API
  → レスポンスは net.http_response_queue に保存
```

## Supabase Dashboard からの設定

1. **Database → Webhooks → Create a new hook**
2. 設定項目:
   - **Name**: `on_task_created`
   - **Table**: `tasks`
   - **Events**: INSERT にチェック
   - **Type**: Supabase Edge Functions
   - **Edge Function**: `notify-slack`

## SQL で直接設定 (より柔軟)

```sql
-- pg_net を使った Edge Function 呼び出し
CREATE OR REPLACE FUNCTION notify_on_task_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  payload jsonb;
BEGIN
  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'record', row_to_json(NEW),
    'old_record', CASE WHEN TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE NULL END
  );

  -- 非同期 HTTP POST (pg_net)
  PERFORM net.http_post(
    url     := current_setting('app.edge_function_url') || '/notify-slack',
    body    := payload::text,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    )
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER task_insert_webhook
  AFTER INSERT ON tasks
  FOR EACH ROW EXECUTE FUNCTION notify_on_task_insert();
```

## 受信側 Edge Function

```typescript
// supabase/functions/notify-slack/index.ts
import { createClient } from 'jsr:@supabase/supabase-js@2';

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  record: Record<string, unknown>;
  old_record: Record<string, unknown> | null;
}

Deno.serve(async (req) => {
  // Bearer トークン検証
  const authHeader = req.headers.get('Authorization');
  const token = authHeader?.replace('Bearer ', '');
  if (token !== Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')) {
    return new Response('Unauthorized', { status: 401 });
  }

  const payload: WebhookPayload = await req.json();

  if (payload.type === 'INSERT' && payload.table === 'tasks') {
    const task = payload.record;
    await notifySlack(`✅ 新タスク: ${task.title} (by user ${task.user_id})`);
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});

async function notifySlack(message: string) {
  const webhookUrl = Deno.env.get('SLACK_WEBHOOK_URL')!;
  await fetch(webhookUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: message }),
  });
}
```

## pg_net のレスポンス確認

```sql
-- 送信済みリクエストのステータス確認
SELECT
  id,
  status_code,
  error_msg,
  created,
  (response).body
FROM net.http_response_queue
ORDER BY created DESC
LIMIT 10;

-- 失敗したリクエストのみ
SELECT * FROM net.http_response_queue
WHERE status_code >= 400
ORDER BY created DESC;
```

## 実用パターン: ユーザー登録後のウェルカムメール

```sql
CREATE OR REPLACE FUNCTION send_welcome_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'https://<project>.supabase.co/functions/v1/send-welcome-email',
    body    := json_build_object(
      'email', NEW.email,
      'user_id', NEW.id::text
    )::text,
    headers := json_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    )
  );
  RETURN NEW;
END;
$$;

-- auth.users への INSERT をトリガー
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION send_welcome_email();
```

## pg_cron との組み合わせ (定期 Webhook)

```sql
-- 毎日 9:00 JST (0:00 UTC) にデイリーレポート送信
SELECT cron.schedule(
  'daily-report-webhook',
  '0 0 * * *',
  $$
    SELECT net.http_post(
      url     := 'https://<project>.supabase.co/functions/v1/daily-report',
      body    := '{"trigger": "cron"}'::text,
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer <key>"}'
    )
  $$
);
```

## セキュリティのポイント

```typescript
// Edge Function 側での署名検証 (HMAC)
import { createHmac } from 'node:crypto';

function verifySignature(body: string, signature: string, secret: string): boolean {
  const expected = createHmac('sha256', secret)
    .update(body)
    .digest('hex');
  return `sha256=${expected}` === signature;
}

// リクエストヘッダーに X-Webhook-Signature を含める
const sig = req.headers.get('X-Webhook-Signature') ?? '';
if (!verifySignature(await req.text(), sig, Deno.env.get('WEBHOOK_SECRET')!)) {
  return new Response('Invalid signature', { status: 403 });
}
```

## まとめ: 使いどころ

| ユースケース | 実装方法 |
|-----------|---------|
| 新規ユーザー歓迎メール | auth.users INSERT → EF → Resend |
| タスク完了通知 (Slack) | tasks UPDATE → EF → Slack Webhook |
| 決済イベント処理 | orders INSERT → EF → Stripe |
| 定期レポート | pg_cron → net.http_post → EF |
| リアルタイム同期 | Supabase Realtime (Webhook より低遅延) |

Webhook を活用してから、通知系の実装が Edge Function 1本で完結するようになりました。

---

Supabase Webhooks の活用事例があればコメントで教えてください！
