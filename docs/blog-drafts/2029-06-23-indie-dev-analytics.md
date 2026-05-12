---
title: "個人開発アプリのアナリティクス設計 — PostHog・Mixpanel・自前実装の使い分け"
tags: flutter,supabase,個人開発,AI
published: true
---

# 個人開発アプリのアナリティクス設計 — PostHog・Mixpanel・自前実装の使い分け

「誰が、何を、いつ使っているか」がわからないと改善できません。個人開発で使えるアナリティクスの選択肢と Flutter での実装を解説します。

## アナリティクスツール選択基準

| ツール | 無料枠 | セルフホスト | 個人開発向け |
|---|---|---|---|
| PostHog | 100万イベント/月 | ◎ (OSS) | ◎ |
| Mixpanel | 2万MT/月 | × | ○ |
| Amplitude | 5万MAU | × | ○ |
| Firebase Analytics | 無制限 | × | ◎ |
| 自前 (Supabase) | DB 上限のみ | ◎ | ◎ |

## PostHog 実装 (推奨)

OSS でセルフホスト可能。プライバシーファーストで EU/日本にも対応。

```yaml
dependencies:
  posthog_flutter: ^4.0.0
```

```dart
// main.dart
await Posthog().setup(
  'YOUR_API_KEY',
  host: 'https://app.posthog.com',  // or self-hosted URL
);

// イベント送信
Posthog().capture(
  eventName: 'task_completed',
  properties: {
    'task_id': taskId,
    'duration_seconds': duration,
    'category': category,
  },
);

// ユーザー識別
Posthog().identify(
  userId: user.id,
  userProperties: {
    'email': user.email,
    'plan': user.plan,
    'created_at': user.createdAt.toIso8601String(),
  },
);

// 画面追跡
Posthog().screen(screenName: 'TaskList');
```

## 自前実装 (Supabase)

コスト最小・完全コントロール。月 5 万 MAU 以下なら最安。

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

-- 分析用インデックス
CREATE INDEX ON analytics_events (event_name, created_at);
CREATE INDEX ON analytics_events (user_id, created_at);
```

```dart
class AnalyticsService {
  final SupabaseClient _client;
  final String _sessionId = const Uuid().v4();

  Future<void> track(
    String eventName, {
    Map<String, dynamic> properties = const {},
  }) async {
    final user = _client.auth.currentUser;

    await _client.from('analytics_events').insert({
      'user_id': user?.id,
      'session_id': _sessionId,
      'event_name': eventName,
      'properties': properties,
      'platform': defaultTargetPlatform.name,
      'app_version': await _getVersion(),
    });
  }

  Future<void> screen(String screenName) =>
      track('screen_view', properties: {'screen': screenName});
}
```

## GoRouter との統合 (自動画面追跡)

```dart
final router = GoRouter(
  observers: [AnalyticsObserver()],
  routes: [...],
);

class AnalyticsObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    final name = route.settings.name;
    if (name != null) analytics.screen(name);
  }
}
```

## 重要指標の設計

```dart
// 定着率に直結するイベント
class AppEvents {
  // Core actions
  static const taskCompleted = 'task_completed';
  static const journalWritten = 'journal_written';
  static const goalSet = 'goal_set';

  // Engagement
  static const streakExtended = 'streak_extended';
  static const achievementUnlocked = 'achievement_unlocked';

  // Monetization
  static const upgradePromptShown = 'upgrade_prompt_shown';
  static const subscriptionStarted = 'subscription_started';
  static const subscriptionCancelled = 'subscription_cancelled';

  // Friction (離脱の兆候)
  static const errorEncountered = 'error_encountered';
  static const featureBlocked = 'feature_blocked';
}

// 使い方
await analytics.track(AppEvents.taskCompleted, properties: {
  'category': task.category,
  'took_seconds': stopwatch.elapsedMilliseconds / 1000,
});
```

## ダッシュボード SQL クエリ

```sql
-- DAU/WAU/MAU
SELECT
  DATE_TRUNC('day', created_at) as date,
  COUNT(DISTINCT user_id) as dau
FROM analytics_events
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY 1 ORDER BY 1;

-- 機能別利用率
SELECT
  event_name,
  COUNT(*) as count,
  COUNT(DISTINCT user_id) as unique_users
FROM analytics_events
WHERE event_name NOT IN ('screen_view')
  AND created_at >= NOW() - INTERVAL '7 days'
GROUP BY event_name
ORDER BY count DESC
LIMIT 20;

-- 課金コンバージョンファネル
SELECT
  COUNT(CASE WHEN event_name = 'upgrade_prompt_shown' THEN 1 END) as shown,
  COUNT(CASE WHEN event_name = 'subscription_started' THEN 1 END) as converted,
  ROUND(
    100.0 * COUNT(CASE WHEN event_name = 'subscription_started' THEN 1 END) /
    NULLIF(COUNT(CASE WHEN event_name = 'upgrade_prompt_shown' THEN 1 END), 0),
    2
  ) as conversion_rate
FROM analytics_events
WHERE created_at >= NOW() - INTERVAL '30 days';
```

自前実装でアナリティクスを持つと、AI (Edge Function + pgvector) で異常検知や離脱予測も後から追加できます。PostHog との使い分けは「製品分析は PostHog、カスタム ML は Supabase」が最適です。

---

あなたのアプリはアナリティクスをどこまで実装していますか？コメントで教えてください！
