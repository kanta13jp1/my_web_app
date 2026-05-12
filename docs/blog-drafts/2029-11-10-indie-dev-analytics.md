---
title: "インディー開発者のアナリティクス設計 — 計測すべき指標とプライバシー配慮の実装"
tags: flutter,dart,個人開発,AI
published: true
---

# インディー開発者のアナリティクス設計 — 計測すべき指標とプライバシー配慮の実装

「計測していないものは改善できない」。しかし、インディー開発者が Google Analytics や Mixpanel を盛りだくさんに入れると、プライバシーリスクとコストが膨らみます。本記事では Supabase のみを使ったプライバシーファーストなアナリティクス設計を解説します。

---

## 計測すべき指標の優先順位

### 北極星指標の選び方

インディー SaaS では「Weekly Active Users が機能 X を 3 回以上使った割合」など、**収益と相関する行動指標**を北極星に置くのが鉄則です。

```
North Star Metric (1つだけ)
  ├── 獲得ファネル: 訪問 → 登録 → アクティベーション
  ├── 継続ファネル: DAU / MAU / 週次リテンション
  └── 収益ファネル: 無料→有料転換 / NPS
```

### 必須指標一覧

| カテゴリ | 指標 | 計算方法 |
|----------|------|----------|
| 獲得 | Signup Conversion Rate | signups / visitors × 100 |
| アクティベーション | D1 Activation Rate | 登録翌日に core action を実行した割合 |
| 継続 | DAU/MAU Ratio | DAU ÷ MAU (30%+ が健全) |
| 収益 | MRR | 月次経常収益 |
| 満足度 | NPS | Promoter% − Detractor% |

---

## Supabase でのイベント収集設計

### スキーマ定義

```sql
-- analytics_events テーブル
create table analytics_events (
  id          bigserial primary key,
  user_id     uuid references auth.users(id) on delete set null,
  session_id  text not null,
  event_name  text not null,
  properties  jsonb default '{}',
  platform    text not null default 'web', -- web / ios / android
  app_version text,
  created_at  timestamptz not null default now()
);

-- 頻繁に使うクエリのためのインデックス
create index idx_events_user_id on analytics_events(user_id);
create index idx_events_event_name on analytics_events(event_name);
create index idx_events_created_at on analytics_events(created_at desc);
create index idx_events_session on analytics_events(session_id);

-- RLS: 書き込みは認証ユーザーのみ、読み取りは Service Role のみ
alter table analytics_events enable row level security;

create policy "users can insert own events"
  on analytics_events for insert
  to authenticated
  with check (auth.uid() = user_id);

-- 管理画面用ビュー (Service Role からのみアクセス)
create view daily_active_users as
  select
    date_trunc('day', created_at) as day,
    count(distinct user_id) as dau
  from analytics_events
  group by 1
  order by 1 desc;
```

---

## Flutter でのイベントトラッキング実装

### AnalyticsService クラス

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  AnalyticsService._();

  final _supabase = Supabase.instance.client;
  final _sessionId = const Uuid().v4();
  final _queue = <Map<String, dynamic>>[];
  bool _flushing = false;

  // サードパーティ不使用 — Supabase のみ
  Future<void> track(
    String eventName, {
    Map<String, dynamic> properties = const {},
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    // 未認証ユーザーは session_id のみ記録 (user_id は null)
    _queue.add({
      'user_id': userId,
      'session_id': _sessionId,
      'event_name': eventName,
      'properties': properties,
      'platform': 'web',
      'app_version': '1.0.0',
      'created_at': DateTime.now().toIso8601String(),
    });
    _maybeFlush();
  }

  Future<void> _maybeFlush() async {
    if (_flushing || _queue.length < 10) return;
    _flushing = true;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    try {
      await _supabase.from('analytics_events').insert(batch);
    } catch (e) {
      // 失敗したら再キュー (簡易リトライ)
      _queue.insertAll(0, batch);
    } finally {
      _flushing = false;
    }
  }

  /// アプリ終了 / バックグラウンド移行時に残りを flush
  Future<void> flush() async {
    if (_queue.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    await _supabase.from('analytics_events').insert(batch);
  }
}
```

### ページビュートラッキング (RouteObserver)

```dart
class AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final _analytics = AnalyticsService();

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _analytics.track('page_view', properties: {
        'page': route.settings.name ?? 'unknown',
        'from': previousRoute?.settings.name,
      });
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) {
      _analytics.track('page_view', properties: {
        'page': previousRoute.settings.name ?? 'unknown',
        'from': route.settings.name,
      });
    }
  }
}

// MaterialApp への組み込み
MaterialApp(
  navigatorObservers: [AnalyticsRouteObserver()],
  // ...
)
```

### よく使うイベント定義

```dart
abstract class AnalyticsEvents {
  // アクティベーション
  static const firstTaskCreated = 'first_task_created';
  static const onboardingCompleted = 'onboarding_completed';

  // エンゲージメント
  static const featureUsed = 'feature_used';
  static const searchPerformed = 'search_performed';
  static const exportTriggered = 'export_triggered';

  // 収益
  static const upgradePromptShown = 'upgrade_prompt_shown';
  static const upgradeButtonClicked = 'upgrade_button_clicked';
  static const subscriptionStarted = 'subscription_started';

  // 離脱シグナル
  static const errorEncountered = 'error_encountered';
  static const feedbackSubmitted = 'feedback_submitted';
}

// 呼び出し例
await AnalyticsService().track(
  AnalyticsEvents.featureUsed,
  properties: {'feature': 'ai_summarize', 'input_length': 512},
);
```

---

## コホート分析 SQL

```sql
-- 週次リテンション (D1/D7/D30)
with first_seen as (
  select
    user_id,
    min(date_trunc('day', created_at)) as cohort_day
  from analytics_events
  where user_id is not null
  group by user_id
),
activity as (
  select distinct
    e.user_id,
    date_trunc('day', e.created_at) as active_day
  from analytics_events e
  where e.user_id is not null
)
select
  f.cohort_day,
  count(distinct f.user_id) as cohort_size,
  count(distinct case
    when a.active_day = f.cohort_day + interval '1 day' then f.user_id
  end) as d1_retained,
  count(distinct case
    when a.active_day = f.cohort_day + interval '7 days' then f.user_id
  end) as d7_retained,
  count(distinct case
    when a.active_day = f.cohort_day + interval '30 days' then f.user_id
  end) as d30_retained
from first_seen f
left join activity a using (user_id)
group by f.cohort_day
order by f.cohort_day desc;
```

```sql
-- 機能別 DAU (機能の定着度チェック)
select
  date_trunc('day', created_at) as day,
  properties->>'feature' as feature,
  count(distinct user_id) as unique_users,
  count(*) as total_events
from analytics_events
where event_name = 'feature_used'
  and created_at > now() - interval '30 days'
group by 1, 2
order by 1 desc, 4 desc;
```

```sql
-- アクティベーションファネル
select
  step,
  count(distinct user_id) as users,
  round(
    100.0 * count(distinct user_id) /
    first_value(count(distinct user_id)) over (order by step_order),
    1
  ) as pct_of_top
from (
  select 1 as step_order, 'signup' as step, user_id
    from analytics_events where event_name = 'user_signed_up'
  union all
  select 2, 'onboarding_done', user_id
    from analytics_events where event_name = 'onboarding_completed'
  union all
  select 3, 'first_task', user_id
    from analytics_events where event_name = 'first_task_created'
  union all
  select 4, 'upgraded', user_id
    from analytics_events where event_name = 'subscription_started'
) funnel
group by step, step_order
order by step_order;
```

---

## フィーチャーフラグとの連携

```dart
// フィーチャーフラグテーブル
// feature_flags: { flag_name, enabled, rollout_pct, user_ids[] }

class FeatureFlagService {
  final _supabase = Supabase.instance.client;
  final _analytics = AnalyticsService();
  Map<String, bool> _flags = {};

  Future<void> load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final rows = await _supabase.rpc('get_feature_flags', params: {
      'p_user_id': userId,
    });
    _flags = Map.fromEntries(
      (rows as List).map((r) => MapEntry(r['flag'] as String, r['enabled'] as bool)),
    );
  }

  bool isEnabled(String flag) => _flags[flag] ?? false;

  Future<void> trackExposure(String flag) async {
    await _analytics.track('feature_flag_exposure', properties: {
      'flag': flag,
      'enabled': isEnabled(flag),
    });
  }
}
```

---

## プライバシーファースト原則

1. **サードパーティトラッカー不使用** — Google Analytics / Mixpanel などを入れない
2. **PII を events に含めない** — メール・氏名は `properties` に絶対入れない
3. **user_id は UUID のみ** — メールアドレスではなく Supabase の `auth.users.id`
4. **オプトアウト尊重** — `analytics_consent` フラグを確認してから送信
5. **データ保持期間を設定** — 90 日以上古いイベントは pg_cron で定期削除

```sql
-- 90日超のイベントを毎晩削除 (pg_cron)
select cron.schedule(
  'delete-old-analytics',
  '0 3 * * *',
  $$delete from analytics_events where created_at < now() - interval '90 days'$$
);
```

---

## まとめ

| フェーズ | 優先指標 |
|----------|----------|
| 0〜100 ユーザー | アクティベーション率・D1 リテンション |
| 100〜1,000 ユーザー | DAU/MAU・機能別エンゲージメント |
| 1,000 ユーザー〜 | コホートリテンション・NPS・MRR |

Supabase 1 つで完結するアナリティクスは、インディー開発者にとって運用コストを最小化しながら必要な洞察を得る最善策です。

---

あなたのサービスで最も重要だった「気づきの指標」は何でしたか？コメントで教えてください！
