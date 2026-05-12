---
title: "インディー開発者のメールマーケティング完全ガイド — Resend × Supabase で自動化する"
tags: 個人開発,AI,indiedev,flutter
published: true
---

# インディー開発者のメールマーケティング完全ガイド — Resend × Supabase で自動化する

メールはSNSより高いコンバージョンを生みます。インディー開発者が Resend × Supabase でメールマーケティングを自動化する方法を解説します。

## なぜメールが重要か

| チャネル | 平均開封率 | クリック率 | コンバージョン率 |
| --- | --- | --- | --- |
| メール | 21-28% | 2-5% | 2-4% |
| Twitter/X | 0.5-1% | 0.1-0.3% | 0.1-0.5% |
| Push通知 | 4-8% | 0.5-1% | 0.5-1% |

SNSアルゴリズムに左右されない「自社資産」としてのメールリストは、インディー開発者の最も重要なグロース施策の一つです。

## Resend でメール送信

```bash
# セットアップ
npm install resend
```

```typescript
// Supabase Edge Function: send-email
import { Resend } from 'npm:resend';

const resend = new Resend(Deno.env.get('RESEND_API_KEY')!);

Deno.serve(async (req) => {
  const { to, subject, html } = await req.json();

  const { data, error } = await resend.emails.send({
    from: '自分株式会社 <hello@jibun.ai>',
    to,
    subject,
    html,
  });

  if (error) return Response.json({ error }, { status: 400 });
  return Response.json({ id: data?.id });
});
```

## ウェルカムシーケンスの設計

```
登録 → Day 0: ウェルカム (機能紹介)
     → Day 3: 活用事例 (具体的なユースケース)
     → Day 7: ヒントと Tips (上級者向け機能)
     → Day 14: コミュニティ紹介
     → Day 30: 有料プランへの誘導
```

### Supabase で自動化する

```sql
-- メールシーケンステーブル
CREATE TABLE email_sequences (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  sequence_name TEXT NOT NULL,
  step INTEGER NOT NULL DEFAULT 0,
  scheduled_at TIMESTAMPTZ NOT NULL,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ユーザー登録時にシーケンスを生成
CREATE OR REPLACE FUNCTION create_welcome_sequence()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO email_sequences (user_id, sequence_name, step, scheduled_at)
  VALUES
    (NEW.id, 'welcome', 0, NOW()),
    (NEW.id, 'welcome', 1, NOW() + INTERVAL '3 days'),
    (NEW.id, 'welcome', 2, NOW() + INTERVAL '7 days'),
    (NEW.id, 'welcome', 3, NOW() + INTERVAL '14 days'),
    (NEW.id, 'welcome', 4, NOW() + INTERVAL '30 days');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_welcome_sequence();
```

```sql
-- pg_cron で毎時メールを送信
SELECT cron.schedule(
  'process-email-sequences',
  '0 * * * *',  -- 毎時0分
  $$
    SELECT net.http_post(
      url := 'https://<project>.supabase.co/functions/v1/process-email-sequences',
      headers := '{"Authorization": "Bearer <service_role_key>"}'::jsonb,
      body := '{}'::jsonb
    );
  $$
);
```

## メールテンプレート (React Email)

```typescript
// emails/welcome.tsx
import {
  Html, Head, Body, Container, Text, Button, Hr
} from 'npm:@react-email/components';

export function WelcomeEmail({ name }: { name: string }) {
  return (
    <Html>
      <Head />
      <Body style={{ fontFamily: 'sans-serif', backgroundColor: '#f4f4f5' }}>
        <Container style={{ maxWidth: 600, margin: '40px auto', padding: '0 20px' }}>
          <Text style={{ fontSize: 24, fontWeight: 'bold', color: '#1e1b4b' }}>
            {name} さん、ようこそ!
          </Text>
          <Text style={{ color: '#374151', lineHeight: 1.7 }}>
            自分株式会社のAIライフマネジメントアプリへご登録ありがとうございます。
          </Text>
          <Button
            href="https://my-web-app-b67f4.web.app/"
            style={{
              backgroundColor: '#4f46e5',
              color: '#fff',
              padding: '12px 24px',
              borderRadius: 6,
              fontWeight: 'bold',
            }}
          >
            アプリを使い始める →
          </Button>
          <Hr />
          <Text style={{ fontSize: 12, color: '#9ca3af' }}>
            配信停止は{' '}
            <a href="{{ unsubscribe_url }}">こちら</a>
          </Text>
        </Container>
      </Body>
    </Html>
  );
}
```

## セグメント別送信

```typescript
// ユーザーセグメントに応じてメールを変える
async function sendSegmentedEmail(userId: string) {
  const { data: user } = await supabase
    .from('user_profiles')
    .select('plan, usage_count, last_active')
    .eq('user_id', userId)
    .single();

  if (!user) return;

  // セグメント判定
  const isHighEngagement = user.usage_count > 50;
  const isDormant = new Date(user.last_active) < new Date(Date.now() - 14 * 24 * 3600 * 1000);
  const isFree = user.plan === 'free';

  let template: string;
  let subject: string;

  if (isDormant) {
    subject = '最近お会いできていませんね — 戻ってきてください';
    template = 'reactivation';
  } else if (isHighEngagement && isFree) {
    subject = '使い込んでいただいてありがとうございます！プレミアムのご提案';
    template = 'upgrade_offer';
  } else {
    subject = '今週のヒント: AI活用術';
    template = 'weekly_tips';
  }

  await sendEmail({ userId, subject, template });
}
```

## 開封率・クリック率の計測

```sql
-- メールトラッキングテーブル
CREATE TABLE email_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email_id TEXT NOT NULL,
  event_type TEXT NOT NULL,  -- 'sent', 'opened', 'clicked', 'bounced', 'unsubscribed'
  user_id UUID REFERENCES auth.users(id),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Resend Webhook で受信して記録
-- open rate by template
SELECT
  template_name,
  COUNT(*) FILTER (WHERE event_type = 'sent') AS sent,
  COUNT(*) FILTER (WHERE event_type = 'opened') AS opened,
  ROUND(
    COUNT(*) FILTER (WHERE event_type = 'opened')::NUMERIC /
    NULLIF(COUNT(*) FILTER (WHERE event_type = 'sent'), 0) * 100, 1
  ) AS open_rate_pct
FROM email_events
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY template_name;
```

## まとめ

Resend × Supabase のメールマーケティングで:

- **ウェルカムシーケンス**でオンボーディング自動化
- **セグメント配信**でエンゲージメント最大化
- **pg_cron 連携**で外部サービス不要の完全自動化
- **開封率・クリック率追跡**でデータ駆動改善

インディー開発者でも大企業並みのメールマーケティングが実現できます。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
