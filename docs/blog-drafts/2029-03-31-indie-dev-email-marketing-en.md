---
title: "Indie Dev Email Marketing Complete Guide — Automate with Resend × Supabase"
tags: indiedev,ai,buildinpublic,supabase
published: true
---

# Indie Dev Email Marketing Complete Guide — Automate with Resend × Supabase

Email drives higher conversions than social media. Here's how indie developers can automate email marketing using Resend and Supabase.

## Why Email Matters

| Channel | Avg Open Rate | Click Rate | Conversion Rate |
| --- | --- | --- | --- |
| Email | 21-28% | 2-5% | 2-4% |
| Twitter/X | 0.5-1% | 0.1-0.3% | 0.1-0.5% |
| Push Notifications | 4-8% | 0.5-1% | 0.5-1% |

Unlike social media, your email list is an asset you own — algorithm changes can't take it away.

## Sending Email with Resend

```typescript
// Supabase Edge Function: send-email
import { Resend } from 'npm:resend';

const resend = new Resend(Deno.env.get('RESEND_API_KEY')!);

Deno.serve(async (req) => {
  const { to, subject, html } = await req.json();

  const { data, error } = await resend.emails.send({
    from: 'Jibun AI <hello@jibun.ai>',
    to,
    subject,
    html,
  });

  if (error) return Response.json({ error }, { status: 400 });
  return Response.json({ id: data?.id });
});
```

## Welcome Sequence Design

```
Sign-up → Day 0: Welcome (feature overview)
        → Day 3: Use cases (concrete examples)
        → Day 7: Tips (advanced features)
        → Day 14: Community introduction
        → Day 30: Paid plan offer
```

### Automate with Supabase

```sql
CREATE TABLE email_sequences (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  sequence_name TEXT NOT NULL,
  step INTEGER NOT NULL DEFAULT 0,
  scheduled_at TIMESTAMPTZ NOT NULL,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

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
-- Trigger sequence processing hourly via pg_cron
SELECT cron.schedule(
  'process-email-sequences',
  '0 * * * *',
  $$
    SELECT net.http_post(
      url := 'https://<project>.supabase.co/functions/v1/process-email-sequences',
      headers := '{"Authorization": "Bearer <service_role_key>"}'::jsonb,
      body := '{}'::jsonb
    );
  $$
);
```

## Email Templates with React Email

```typescript
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
            Welcome, {name}!
          </Text>
          <Text style={{ color: '#374151', lineHeight: 1.7 }}>
            Thanks for signing up for Jibun AI — your AI Life Management app.
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
            Get Started →
          </Button>
          <Hr />
          <Text style={{ fontSize: 12, color: '#9ca3af' }}>
            <a href="{{ unsubscribe_url }}">Unsubscribe</a>
          </Text>
        </Container>
      </Body>
    </Html>
  );
}
```

## Segmented Campaigns

```typescript
async function sendSegmentedEmail(userId: string) {
  const { data: user } = await supabase
    .from('user_profiles')
    .select('plan, usage_count, last_active')
    .eq('user_id', userId)
    .single();

  if (!user) return;

  const isDormant = new Date(user.last_active) < new Date(Date.now() - 14 * 24 * 3600 * 1000);
  const isHighEngagement = user.usage_count > 50;
  const isFree = user.plan === 'free';

  let template: string;
  let subject: string;

  if (isDormant) {
    subject = 'We miss you — come back';
    template = 'reactivation';
  } else if (isHighEngagement && isFree) {
    subject = "You're a power user — here's an upgrade offer";
    template = 'upgrade_offer';
  } else {
    subject = 'This week\'s tips & tricks';
    template = 'weekly_tips';
  }

  await sendEmail({ userId, subject, template });
}
```

## Tracking Opens and Clicks

```sql
CREATE TABLE email_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email_id TEXT NOT NULL,
  event_type TEXT NOT NULL,  -- 'sent', 'opened', 'clicked', 'bounced', 'unsubscribed'
  user_id UUID REFERENCES auth.users(id),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Open rate by template (last 30 days)
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

## Summary

Resend × Supabase email marketing delivers:

- **Welcome sequences** that automate onboarding
- **Segmented campaigns** for maximum engagement
- **pg_cron integration** — fully automated, no external tools
- **Open/click tracking** for data-driven optimization

Even solo indie developers can run enterprise-grade email marketing.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
