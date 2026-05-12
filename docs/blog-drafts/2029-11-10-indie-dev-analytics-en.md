---
title: "Indie Dev Analytics — The Metrics That Matter and Privacy-first Implementation"
tags: indiedev,webdev,buildinpublic,flutter
published: true
---

# Indie Dev Analytics — The Metrics That Matter and Privacy-first Implementation

Most analytics guides are written for growth teams at funded startups. Indie developers need a leaner approach: measure what predicts revenue, skip everything else, and keep user data off third-party servers. This guide shows you how to do that with just Supabase.

---

## Picking Your North Star Metric

Before writing a single line of tracking code, decide on one North Star Metric. It should:

1. Correlate directly with revenue or retention
2. Be measurable without PII
3. Be actionable — you can run experiments to move it

Good examples for indie SaaS:
- "% of users who complete their first task within 24 hours of signup"
- "# of users who use the core feature at least 3 times per week"

---

## The Metrics Hierarchy

```
North Star (1 metric)
├── Acquisition
│   ├── Signup conversion rate
│   └── Source / channel attribution
├── Activation
│   ├── D1 activation rate (core action on day 1)
│   └── Onboarding completion rate
├── Retention
│   ├── DAU / MAU ratio (target: 20%+)
│   ├── D7 / D30 retention
│   └── Weekly cohort retention
└── Revenue
    ├── Free → paid conversion rate
    ├── MRR / ARR
    └── NPS
```

---

## Database Schema

```sql
-- Single events table — keep it simple
create table analytics_events (
  id          bigserial primary key,
  user_id     uuid references auth.users(id) on delete set null,
  session_id  text not null,
  event_name  text not null,
  properties  jsonb not null default '{}',
  platform    text not null default 'web',
  app_version text,
  created_at  timestamptz not null default now()
);

create index idx_ae_user_id    on analytics_events(user_id);
create index idx_ae_event_name on analytics_events(event_name);
create index idx_ae_created_at on analytics_events(created_at desc);
create index idx_ae_session_id on analytics_events(session_id);

-- GIN index for fast JSONB property queries
create index idx_ae_properties on analytics_events using gin(properties);

alter table analytics_events enable row level security;

-- Users can only write their own events
create policy "insert own events"
  on analytics_events for insert
  to authenticated
  with check (auth.uid() = user_id);

-- No client-side reads — use the service role key from your Edge Functions
```

---

## Flutter Event Tracking Service

```dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class Analytics {
  Analytics._();
  static final Analytics instance = Analytics._();

  final _supabase = Supabase.instance.client;
  final String _sessionId = const Uuid().v4();
  final _buffer = <Map<String, dynamic>>[];
  Timer? _flushTimer;
  static const _bufferLimit = 20;
  static const _flushInterval = Duration(seconds: 30);

  bool _consentGiven = false;

  void setConsent(bool consent) => _consentGiven = consent;

  Future<void> track(
    String event, {
    Map<String, dynamic> props = const {},
  }) async {
    if (!_consentGiven) return; // respect opt-out

    _buffer.add({
      'user_id': _supabase.auth.currentUser?.id,
      'session_id': _sessionId,
      'event_name': event,
      // Never put email/name here — UUID only
      'properties': props,
      'platform': 'web',
      'created_at': DateTime.now().toIso8601String(),
    });

    _flushTimer ??= Timer.periodic(_flushInterval, (_) => flush());

    if (_buffer.length >= _bufferLimit) {
      await flush();
    }
  }

  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();
    try {
      await _supabase.from('analytics_events').insert(batch);
    } catch (_) {
      _buffer.insertAll(0, batch); // re-queue on failure
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    flush(); // best-effort flush on teardown
  }
}
```

### Named Event Constants

```dart
class Events {
  // Activation funnel
  static const signedUp         = 'signed_up';
  static const onboardingDone   = 'onboarding_completed';
  static const firstItemCreated = 'first_item_created';

  // Engagement
  static const featureUsed      = 'feature_used';
  static const searchRun        = 'search_run';
  static const exportStarted    = 'export_started';
  static const aiSuggestUsed    = 'ai_suggest_used';

  // Monetization
  static const upgradeViewed    = 'upgrade_prompt_viewed';
  static const upgradeClicked   = 'upgrade_cta_clicked';
  static const subscribed       = 'subscription_started';
  static const churned          = 'subscription_cancelled';

  // Quality signals
  static const errorShown       = 'error_shown';
  static const feedbackSent     = 'feedback_sent';
  static const npsAnswered      = 'nps_answered';
}

// Usage
await Analytics.instance.track(
  Events.featureUsed,
  props: {'feature': 'ai_chat', 'tokens_used': 350},
);
```

---

## Cohort Retention Query

```sql
-- Weekly cohort retention table
with cohorts as (
  select
    user_id,
    date_trunc('week', min(created_at)) as cohort_week
  from analytics_events
  where event_name = 'signed_up'
  group by user_id
),
weekly_activity as (
  select distinct
    user_id,
    date_trunc('week', created_at) as active_week
  from analytics_events
  where user_id is not null
)
select
  c.cohort_week,
  count(distinct c.user_id)                                  as cohort_size,
  count(distinct case when a.active_week = c.cohort_week + interval '1 week'
    then c.user_id end)                                      as w1,
  count(distinct case when a.active_week = c.cohort_week + interval '2 weeks'
    then c.user_id end)                                      as w2,
  count(distinct case when a.active_week = c.cohort_week + interval '4 weeks'
    then c.user_id end)                                      as w4
from cohorts c
left join weekly_activity a using (user_id)
group by c.cohort_week
order by c.cohort_week desc;
```

---

## Activation Funnel Query

```sql
with steps as (
  select 1 as ord, 'Signed up'         as step, user_id from analytics_events where event_name = 'signed_up'
  union all
  select 2,        'Onboarding done',  user_id from analytics_events where event_name = 'onboarding_completed'
  union all
  select 3,        'First item',       user_id from analytics_events where event_name = 'first_item_created'
  union all
  select 4,        'Subscribed',       user_id from analytics_events where event_name = 'subscription_started'
)
select
  step,
  count(distinct user_id) as users,
  round(
    100.0 * count(distinct user_id) /
    nullif(max(count(distinct user_id)) over (), 0),
    1
  ) as pct_of_top
from steps
group by step, ord
order by ord;
```

---

## Feature Flag Integration

Track which variant each user saw to make A/B test results trustworthy.

```sql
-- feature_flags table
create table feature_flags (
  flag_name    text primary key,
  enabled      boolean not null default false,
  rollout_pct  int not null default 0 check (rollout_pct between 0 and 100),
  description  text
);

-- RPC to evaluate flags server-side
create or replace function get_user_flags(p_user_id uuid)
returns jsonb language sql security definer as $$
  select jsonb_object_agg(
    flag_name,
    enabled and (
      rollout_pct = 100 or
      abs(hashtext(p_user_id::text || flag_name)) % 100 < rollout_pct
    )
  )
  from feature_flags;
$$;
```

```dart
class FeatureFlags {
  final _supabase = Supabase.instance.client;
  Map<String, bool> _flags = {};

  Future<void> load() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    final result = await _supabase.rpc('get_user_flags', params: {'p_user_id': uid});
    _flags = Map<String, bool>.from(result as Map);
  }

  bool isOn(String flag) => _flags[flag] ?? false;

  Future<void> trackExposure(String flag) async {
    await Analytics.instance.track(
      'flag_exposure',
      props: {'flag': flag, 'variant': isOn(flag) ? 'treatment' : 'control'},
    );
  }
}
```

---

## Privacy-First Principles

| Principle | Implementation |
|-----------|----------------|
| No third-party trackers | Supabase only — no GA/Mixpanel scripts |
| No PII in events | `user_id` is UUID; never email or name |
| Opt-out respected | `Analytics.instance.setConsent(false)` blocks all tracking |
| Data minimization | Only collect events you actually query |
| Retention limits | Auto-delete events older than 90 days |

```sql
-- Auto-delete old events (pg_cron, runs at 3 AM daily)
select cron.schedule(
  'prune-analytics',
  '0 3 * * *',
  $$delete from analytics_events
    where created_at < now() - interval '90 days'$$
);
```

---

## Dashboard Query for Admin Panel

```sql
-- 30-day KPI summary
select
  count(distinct user_id) filter (
    where created_at > now() - interval '1 day') as dau,
  count(distinct user_id) filter (
    where created_at > now() - interval '30 days') as mau,
  round(
    100.0 * count(distinct user_id) filter (
      where created_at > now() - interval '1 day') /
    nullif(count(distinct user_id) filter (
      where created_at > now() - interval '30 days'), 0),
    1
  ) as dau_mau_ratio,
  count(distinct user_id) filter (
    where event_name = 'subscription_started'
    and created_at > now() - interval '30 days') as new_subscribers
from analytics_events;
```

---

## Summary

Running your own analytics stack on Supabase costs nearly nothing, keeps user data under your control, and gives you SQL-level flexibility no third-party tool can match. Start with the activation funnel, add cohort retention once you have 100+ users, and layer in feature flag experiments when you're ready to optimize.

---

What's the single metric that surprised you most about your users' behavior? Drop it in the comments!
