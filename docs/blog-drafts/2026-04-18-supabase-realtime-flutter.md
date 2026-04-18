---
title: "Supabase Realtime × Flutter でリアルタイムアクティビティフィードを作った"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: false
---

# Supabase Realtime × Flutter でリアルタイムアクティビティフィードを作った

## はじめに

自分株式会社に「アクティビティフィード」を実装しました。ルート: `/activity-feed`

ユーザーがページを開いた瞬間から、他ユーザーの行動（参加・実績解除・マイルストーン達成）が**WebSocket経由でリアルタイム反映**されます。Supabase Realtime の `.stream()` API と Flutter の `StreamSubscription` を組み合わせるだけで、ほぼボイラープレートなしに実現できました。

## Supabase Realtime とは

Supabase Realtime は PostgreSQL の Change Data Capture (CDC) を WebSocket で配信するサービスです。

3つのモード:
- **Broadcast** — クライアント間の任意メッセージ送受信
- **Presence** — ユーザーのオンライン状態共有
- **Postgres Changes** — DB の INSERT/UPDATE/DELETE をリアルタイム受信

今回は Flutter SDK の `.stream()` を使います。内部的には Postgres Changes を使いつつ、初回データ取得も自動でやってくれる便利な API です。

## 実装

### データモデル

```dart
class ActivityItem {
  final String id;
  final String type;      // new_user / achievement / milestone / share / level_up
  final String userName;
  final String action;
  final DateTime timestamp;

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id'].toString(),
      type: json['type'] as String? ?? 'general',
      userName: json['user_name'] ?? '匿名ユーザー',
      action: json['action'] as String? ?? '新しいアクティビティ',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
```

### Realtime ストリーム購読

```dart
class _ActivityFeedPageState extends State<ActivityFeedPage> {
  final _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _activitySubscription;
  List<ActivityItem> _activities = [];

  @override
  void initState() {
    super.initState();
    _startRealTimeSubscription();
  }

  void _startRealTimeSubscription() {
    _activitySubscription = _supabase
        .from('activities')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(30)
        .listen(
          _handleRealTimeData,
          onError: (e) {
            // WebSocket エラー時は通常の HTTP クエリにフォールバック
            _loadActivities();
          },
        );
  }

  void _handleRealTimeData(List<Map<String, dynamic>> data) {
    if (mounted) {
      setState(() {
        _activities = data.map(ActivityItem.fromJson).toList();
      });
    }
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();  // ← 必須: メモリリーク防止
    super.dispose();
  }
}
```

ポイントは3つ:
1. **`stream(primaryKey: ['id'])`** — PK を渡すだけで差分更新が有効になる
2. **`onError` フォールバック** — WebSocket が切れても HTTP クエリで継続
3. **`dispose()` でキャンセル** — ページ離脱時に購読を確実に解除

### エラー時フォールバック (HTTP クエリ)

```dart
Future<void> _loadActivities() async {
  try {
    final response = await _supabase
        .from('activities')
        .select('id, type, user_name, action, timestamp')
        .order('timestamp', ascending: false)
        .limit(30);

    if (mounted) {
      setState(() {
        _activities = (response as List)
            .map((json) => ActivityItem.fromJson(json as Map<String, dynamic>))
            .toList();
      });
    }
  } catch (e) {
    // 両方失敗したらサンプルデータを表示
    if (mounted) setState(() => _activities = _generateSampleActivities());
  }
}
```

### アクティビティタイプ別スタイリング

```dart
Map<String, dynamic> _getActivityStyle(String type) {
  switch (type) {
    case 'new_user':    return {'icon': Icons.person_add,   'color': Colors.green};
    case 'achievement': return {'icon': Icons.emoji_events, 'color': Colors.amber};
    case 'milestone':   return {'icon': Icons.celebration,  'color': Colors.purple};
    case 'share':       return {'icon': Icons.share,        'color': Colors.blue};
    case 'level_up':    return {'icon': Icons.trending_up,  'color': Colors.teal};
    default:            return {'icon': Icons.timeline,     'color': Colors.grey};
  }
}
```

## Supabase Realtime 有効化 (DB設定)

Supabase ダッシュボードの **Database > Replication** で `activities` テーブルを有効化:

```sql
-- supabase/migrations/ に追加
ALTER PUBLICATION supabase_realtime ADD TABLE activities;
```

これを忘れると `.stream()` が初回データしか返さず、リアルタイム更新が来ません。

## `.stream()` と `channel()` の使い分け

| API | 用途 | コード量 |
| --- | --- | --- |
| `.stream()` | テーブル全体のリアルタイム同期 | 少 |
| `.channel().on()` | 細かい条件 (WHERE句など) や Broadcast/Presence | 多 |

単純に「テーブルの最新 N 件をリアルタイムで見たい」なら `.stream()` が最短です。

## まとめ

Supabase Realtime + Flutter の `.stream()` API を使えば、WebSocket の面倒な接続管理を書かずにリアルタイムUIが完成します。`onError` フォールバックと `dispose()` キャンセルを忘れずに実装すれば、本番でも安定して動きます。

無料で体験できます: https://my-web-app-b67f4.web.app/

---
#FlutterWeb #Supabase #RealtimeDB #buildinpublic #個人開発
