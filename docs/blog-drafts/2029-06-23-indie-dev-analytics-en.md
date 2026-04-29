---
title: "Indie Dev Analytics — PostHog vs Mixpanel vs Self-Hosted Supabase"
tags: supabase,flutter,webdev,indiedev
published: true
---

# Indie Dev Analytics — PostHog vs Mixpanel vs Self-Hosted Supabase

You can't improve what you can't measure. Here's how to pick the right analytics stack for your indie app and implement it in Flutter.

## Tool Comparison

| Tool | Free tier | Self-host | Indie-friendly |
|---|---|---|---|
| PostHog | 1M events/month | ◎ (OSS) | ◎ |
| Mixpanel | 20K MT/month | × | ○ |
| Firebase Analytics | Unlimited | × | ◎ |
| Self-hosted (Supabase) | DB limit only | ◎ | ◎ |

## PostHog Implementation (Recommended)

Open source, self-hostable, GDPR-friendly.

```yaml
dependencies:
  posthog_flutter: ^4.0.0
```

```dart
await Posthog().setup('YOUR_API_KEY', host: 'https://app.posthog.com');

// Track event
Posthog().capture(
  eventName: 'task_completed',
  properties: {'category': category, 'duration_seconds': duration},
);

// Identify user
Posthog().identify(
  userId: user.id,
  userProperties: {'plan': user.plan, 'email': user.email},
);

// Screen view
Posthog().screen(screenName: 'TaskList');
```

## Self-Hosted Supabase Analytics

Minimum cost, full control. Best under 50K MAU.

```sql
CREATE TABLE analytics_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  session_id TEXT NOT NULL,
  event_name TEXT NOT NULL,
  properties JSONB DEFAULT '{}',
  platform TEXT,
  app_version TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON analytics_events (event_name, created_at);
CREATE INDEX ON analytics_events (user_id, created_at);
```

```dart
class AnalyticsService {
  final SupabaseClient _client;
  final String _sessionId = const Uuid().v4();

  Future<void> track(String event, {Map<String, dynamic> props = const {}}) async {
    await _client.from('analytics_events').insert({
      'user_id': _client.auth.currentUser?.id,
      'session_id': _sessionId,
      'event_name': event,
      'properties': props,
      'platform': defaultTargetPlatform.name,
    });
  }
}
```

## Auto Screen Tracking with GoRouter

```dart
class AnalyticsObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    final name = route.settings.name;
    if (name != null) analytics.track('screen_view', props: {'screen': name});
  }
}

final router = GoRouter(observers: [AnalyticsObserver()], routes: [...]);
```

## Events That Matter

```dart
class AppEvents {
  // Core value actions
  static const taskCompleted = 'task_completed';
  static const journalWritten = 'journal_written';

  // Engagement signals
  static const streakExtended = 'streak_extended';

  // Monetization funnel
  static const upgradePromptShown = 'upgrade_prompt_shown';
  static const subscriptionStarted = 'subscription_started';
  static const subscriptionCancelled = 'subscription_cancelled';

  // Friction signals (churn precursors)
  static const errorEncountered = 'error_encountered';
  static const featureBlocked = 'feature_blocked';
}
```

## Analysis Queries

```sql
-- DAU trend
SELECT DATE_TRUNC('day', created_at) as date, COUNT(DISTINCT user_id) as dau
FROM analytics_events
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY 1 ORDER BY 1;

-- Conversion funnel
SELECT
  COUNT(CASE WHEN event_name = 'upgrade_prompt_shown' THEN 1 END) as shown,
  COUNT(CASE WHEN event_name = 'subscription_started' THEN 1 END) as converted,
  ROUND(100.0 * COUNT(CASE WHEN event_name = 'subscription_started' THEN 1 END) /
    NULLIF(COUNT(CASE WHEN event_name = 'upgrade_prompt_shown' THEN 1 END), 0), 2
  ) as cvr
FROM analytics_events WHERE created_at >= NOW() - INTERVAL '30 days';
```

## My Stack

I use PostHog for product analytics (funnels, cohorts, feature flags) and Supabase for custom ML signals (churn prediction, anomaly detection). The self-hosted data feeds Edge Functions that trigger re-engagement nudges.

---

What analytics stack are you using for your indie app? I'm curious what conversion rates look like at different scales.
