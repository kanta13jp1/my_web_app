---
title: "Indie SaaS Retention — Churn Analysis, Email Automation, and Habit-Forming UX"
tags: dart,flutter,webdev,indiedev
published: true
---

# Indie SaaS Retention — Churn Analysis, Email Automation, and Habit-Forming UX

"Users are signing up but MRR isn't growing." "People vanish after the trial." These are retention problems, and they're far more common in indie SaaS than acquisition problems. This article covers a practical retention stack built on Supabase, Resend, and Flutter.

## Defining Churn Prediction Signals

Churn doesn't happen suddenly — there are leading indicators. The most reliable signals:

| Signal | Threshold (example) |
|--------|---------------------|
| Login frequency drop | < 1 login in the past 7 days |
| Core feature inactivity | 0 uses of the primary feature in 30 days |
| Support ticket spike | 3+ tickets in 14 days |
| Incomplete onboarding | Profile completion < 50% after 3 days |

Track these in a `user_events` table and compute a risk score automatically on a schedule.

## Auto-detecting At-Risk Users with Supabase + pg_cron

```sql
-- View: users with no login in the past 7 days
create or replace view churn_risk_users as
select
  u.id,
  u.email,
  u.raw_user_meta_data->>'full_name' as full_name,
  max(e.created_at) as last_login,
  now() - max(e.created_at) as days_since_login
from auth.users u
left join user_events e
  on u.id = e.user_id and e.event_type = 'login'
group by u.id, u.email, u.raw_user_meta_data
having now() - max(e.created_at) > interval '7 days'
  or max(e.created_at) is null;

-- pg_cron: write at-risk users to churn_alerts every day at 01:00 UTC
select cron.schedule(
  'churn-risk-scan',
  '0 1 * * *',
  $$
  insert into churn_alerts (user_id, email, days_since_login, alerted_at)
  select id, email, days_since_login, now()
  from churn_risk_users
  where days_since_login > interval '7 days'
  on conflict (user_id) do update
    set days_since_login = excluded.days_since_login,
        alerted_at = excluded.alerted_at;
  $$
);
```

The `on conflict` clause ensures you always have the freshest data without creating duplicate rows.

## Sending Trigger Emails with the Resend API

A Database Webhook on `churn_alerts` INSERT fires an Edge Function that sends a personalized reactivation email via Resend:

```typescript
// supabase/functions/send-reactivation-email/index.ts
import { Resend } from "npm:resend@3";

const resend = new Resend(Deno.env.get("RESEND_API_KEY")!);

Deno.serve(async (req) => {
  const { record } = await req.json(); // Database Webhook payload

  const daysSince = Math.floor(
    (record.days_since_login as number) / (1000 * 60 * 60 * 24)
  );

  const { error } = await resend.emails.send({
    from: "support@yoursaas.com",
    to: record.email,
    subject: `We miss you, ${record.full_name ?? "there"}!`,
    html: `
      <p>Hi ${record.full_name ?? "there"},</p>
      <p>We noticed you haven't logged in for
        <strong>${daysSince} days</strong>.</p>
      <p>We've shipped a new AI-powered daily digest feature —
         come check it out.</p>
      <a href="https://yoursaas.com/login"
         style="background:#5ac8b8;color:#fff;padding:12px 24px;
                border-radius:6px;text-decoration:none">
        Open the app
      </a>
    `,
  });

  if (error) {
    console.error("Email send failed:", error);
    return new Response(JSON.stringify({ ok: false }), { status: 500 });
  }

  // Stamp the alert so we don't re-send tomorrow
  // (update churn_alerts.email_sent_at via service role in a second query)
  return new Response(JSON.stringify({ ok: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

Set `email_sent_at` after sending and add a `where email_sent_at is null` condition to the cron query so you never send duplicates.

## Habit-Forming UX — Streaks, Progress Bars, and Milestone Notifications

Small, repeated wins keep users coming back. Three patterns that work well:

### Streaks (Consecutive Days Active)

```dart
class StreakBadge extends StatelessWidget {
  final int streakDays;

  const StreakBadge({super.key, required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
        const SizedBox(width: 4),
        Text(
          '$streakDays-day streak',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }
}
```

### Progress Bars

Visualize goal completion as a percentage. Fetch from `user_stats` in Supabase and render with `LinearProgressIndicator`. Even displaying "You're 73% to your weekly goal" dramatically increases daily return rates.

### Milestone Notifications

Fire a push notification or in-app banner when a user hits a milestone like "30-day streak" or "100 tasks completed". The Edge Function checks the milestone table on each relevant event:

```sql
create table milestones (
  id bigint primary key generated always as identity,
  user_id uuid references auth.users,
  milestone_key text not null,        -- e.g. 'streak_30'
  achieved_at timestamptz default now(),
  unique (user_id, milestone_key)
);
```

## Implementing an In-App NPS Survey

NPS measures one thing: "Would you recommend this app to a friend? (0–10)". Show it at the right moment — after 30 days of use, or after 10 completed tasks — not on first login.

```dart
Future<void> _maybeShowNps(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final alreadyShown = prefs.getBool('nps_shown_v1') ?? false;
  final taskCount = await _fetchCompletedTaskCount(); // from Supabase

  if (!alreadyShown && taskCount >= 10 && context.mounted) {
    await prefs.setBool('nps_shown_v1', true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const NpsBottomSheet(),
    );
  }
}
```

Store responses in `nps_responses`. For scores ≤ 6 (detractors), trigger a Slack webhook so you can follow up personally within 24 hours. That single touch often converts a frustrated user into a loyal advocate.

## Summary

1. **Define churn signals** quantitatively and run detection automatically with `pg_cron`.
2. **Trigger reactivation emails** via Resend when a user goes 7+ days without logging in.
3. **Streaks + progress bars + milestones** build the habit loop that drives daily active use.
4. **NPS at the right moment** surfaces detractors early, before they quietly cancel.

Improving retention is 5× cheaper than acquiring new users. Start measuring before optimizing. Up next: the complete guide to Dart concurrency.
