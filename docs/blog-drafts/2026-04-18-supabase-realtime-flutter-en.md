---
title: "Building a Realtime Activity Feed with Supabase and Flutter"
tags: Flutter,Supabase,buildinpublic,webdev,AI
published: false
---

# Building a Realtime Activity Feed with Supabase and Flutter

I added a realtime activity feed to my Flutter Web app using Supabase Realtime's `.stream()` API. When a user opens `/activity-feed`, they see live updates — new members joining, achievements unlocked, milestones hit — all pushed via WebSocket without polling.

## The Stack

- **Supabase Realtime** — PostgreSQL CDC over WebSocket
- **Flutter** — `StreamSubscription<List<Map<String, dynamic>>>` listens to the stream
- **Fallback** — HTTP query if WebSocket drops

## Data Model

```dart
class ActivityItem {
  final String id;
  final String type;     // new_user / achievement / milestone / share / level_up
  final String userName;
  final String action;
  final DateTime timestamp;

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id'].toString(),
      type: json['type'] as String? ?? 'general',
      userName: json['user_name'] ?? 'anonymous',
      action: json['action'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
```

## Realtime Subscription

```dart
class _ActivityFeedPageState extends State<ActivityFeedPage> {
  final _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _activitySubscription;

  void _startRealTimeSubscription() {
    _activitySubscription = _supabase
        .from('activities')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(30)
        .listen(
          (data) {
            if (mounted) {
              setState(() => _activities = data.map(ActivityItem.fromJson).toList());
            }
          },
          onError: (_) => _loadActivities(), // fallback to HTTP on WS error
        );
  }

  @override
  void dispose() {
    _activitySubscription?.cancel(); // critical — prevents memory leaks
    super.dispose();
  }
}
```

Three things to get right:
1. **Pass the primary key** to `.stream(primaryKey: ['id'])` — enables differential updates
2. **`onError` fallback** — gracefully handles WebSocket disconnection
3. **Cancel on dispose** — the most commonly forgotten step

## HTTP Fallback

```dart
Future<void> _loadActivities() async {
  final response = await _supabase
      .from('activities')
      .select('id, type, user_name, action, timestamp')
      .order('timestamp', ascending: false)
      .limit(30);

  if (mounted) {
    setState(() => _activities = (response as List)
        .map((j) => ActivityItem.fromJson(j as Map<String, dynamic>))
        .toList());
  }
}
```

## Enable Realtime on the Table

Don't forget to add the table to the Supabase Realtime publication — either from the dashboard (**Database > Replication**) or via migration:

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE activities;
```

Skipping this means `.stream()` only returns the initial snapshot — no live updates.

## `.stream()` vs `.channel()`

| API | When to use | Complexity |
|-----|-------------|------------|
| `.stream()` | Full table sync, latest N rows | Low |
| `.channel().on()` | Filtered changes (WHERE), Broadcast, Presence | Higher |

For a simple "show latest N rows live" use case, `.stream()` is the shortest path. Switch to `.channel()` when you need row-level filtering or cross-client messaging.

## Result

The activity feed updates in real time with zero polling. Supabase handles the WebSocket lifecycle; Flutter's `StreamSubscription` maps it directly to `setState`. Total implementation: ~100 lines.

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #RealtimeDB #buildinpublic
