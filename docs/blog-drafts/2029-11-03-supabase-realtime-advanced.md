---
title: "Supabase Realtime 実践 — Postgres Changes・Broadcast・Presence の使い分け"
tags: flutter,dart,個人開発,AI
published: true
---

# Supabase Realtime 実践 — Postgres Changes・Broadcast・Presence の使い分け

Supabase Realtime は WebSocket を通じてリアルタイムな通信を提供する機能です。大きく 3 つのサブシステム — **Postgres Changes**、**Broadcast**、**Presence** — があり、ユースケースに合わせて使い分けることが重要です。本記事では Flutter での実装を中心に、それぞれの特性と実践的な使い方を解説します。

---

## 3 つのサブシステムの概要

| 機能 | 用途 | 永続性 | コスト |
|------|------|--------|--------|
| Postgres Changes | DB 更新をリアルタイム配信 | ✅ DB に保存 | Message 数課金 |
| Broadcast | エフェメラルなイベント配信 | ❌ 揮発性 | Message 数課金 |
| Presence | オンラインユーザーの状態同期 | ❌ 揮発性 | PresenceState 課金 |

---

## チャネルの基本設定

Flutter アプリでは `supabase_flutter` パッケージを使います。

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.5.0
```

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;
```

---

## Postgres Changes — DB 変更のリアルタイム購読

### 基本的な INSERT 購読

```dart
class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final List<Map<String, dynamic>> _tasks = [];
  late final RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subscribeToChanges();
  }

  Future<void> _loadInitialData() async {
    final data = await supabase
        .from('tasks')
        .select()
        .order('created_at', ascending: false);
    if (mounted) {
      setState(() => _tasks.addAll(List<Map<String, dynamic>>.from(data)));
    }
  }

  void _subscribeToChanges() {
    _channel = supabase
        .channel('tasks_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            if (!mounted) return;
            setState(() => _tasks.insert(0, payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            if (!mounted) return;
            setState(() {
              final idx = _tasks.indexWhere(
                  (t) => t['id'] == payload.newRecord['id']);
              if (idx != -1) _tasks[idx] = payload.newRecord;
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            if (!mounted) return;
            setState(() =>
                _tasks.removeWhere((t) => t['id'] == payload.oldRecord['id']));
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return ListTile(
          title: Text(task['title'] as String),
          subtitle: Text(task['status'] as String),
        );
      },
    );
  }
}
```

### フィルタリング — 特定ユーザーの行だけ購読

```dart
void _subscribeToUserTasks(String userId) {
  _channel = supabase
      .channel('user_tasks_$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tasks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          debugPrint('Change: ${payload.eventType} — ${payload.newRecord}');
        },
      )
      .subscribe();
}
```

利用可能なフィルタタイプ: `eq`、`neq`、`lt`、`lte`、`gt`、`gte`、`in`

---

## Broadcast — エフェメラルなイベント配信

カーソル位置、入力中インジケータ、ゲームアクションなど、DB に保存する必要がないイベントに最適です。

```dart
class CollaborativeEditor extends StatefulWidget {
  final String documentId;
  final String userId;

  const CollaborativeEditor({
    super.key,
    required this.documentId,
    required this.userId,
  });

  @override
  State<CollaborativeEditor> createState() => _CollaborativeEditorState();
}

class _CollaborativeEditorState extends State<CollaborativeEditor> {
  late final RealtimeChannel _channel;
  final Map<String, Offset> _cursorPositions = {};

  @override
  void initState() {
    super.initState();
    _setupBroadcast();
  }

  void _setupBroadcast() {
    _channel = supabase
        .channel('doc_${widget.documentId}')
        .onBroadcast(
          event: 'cursor_move',
          callback: (payload) {
            if (!mounted) return;
            final senderId = payload['user_id'] as String?;
            if (senderId == null || senderId == widget.userId) return;

            setState(() {
              _cursorPositions[senderId] = Offset(
                (payload['x'] as num).toDouble(),
                (payload['y'] as num).toDouble(),
              );
            });
          },
        )
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            debugPrint('${payload['user_id']} is typing...');
          },
        )
        .subscribe();
  }

  Future<void> _broadcastCursorMove(Offset position) async {
    await _channel.sendBroadcastMessage(
      event: 'cursor_move',
      payload: {
        'user_id': widget.userId,
        'x': position.dx,
        'y': position.dy,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> _broadcastTyping() async {
    await _channel.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': widget.userId},
    );
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => _broadcastCursorMove(details.localPosition),
      child: Stack(
        children: [
          const Placeholder(),
          for (final entry in _cursorPositions.entries)
            Positioned(
              left: entry.value.dx,
              top: entry.value.dy,
              child: _CursorIndicator(userId: entry.key),
            ),
        ],
      ),
    );
  }
}

class _CursorIndicator extends StatelessWidget {
  final String userId;
  const _CursorIndicator({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(userId, style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }
}
```

---

## Presence — オンラインユーザーの状態管理

Presence は分散型のオンライン状態管理を提供します。接続が切れると自動でクリーンアップされます。

```dart
class OnlineUsersWidget extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String displayName;

  const OnlineUsersWidget({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.displayName,
  });

  @override
  State<OnlineUsersWidget> createState() => _OnlineUsersWidgetState();
}

class _OnlineUsersWidgetState extends State<OnlineUsersWidget> {
  late final RealtimeChannel _channel;
  Map<String, dynamic> _onlineUsers = {};

  @override
  void initState() {
    super.initState();
    _setupPresence();
  }

  void _setupPresence() {
    _channel = supabase.channel(
      'room_${widget.roomId}',
      opts: const RealtimeChannelConfig(ack: true),
    );

    _channel
        .onPresenceSync(callback: (_) {
          if (!mounted) return;
          setState(() {
            _onlineUsers = _channel.presenceState();
          });
        })
        .onPresenceJoin(callback: (payload) {
          debugPrint('${payload.newPresences.map((p) => p.payload['name'])} joined');
        })
        .onPresenceLeave(callback: (payload) {
          debugPrint('${payload.leftPresences.map((p) => p.payload['name'])} left');
        })
        .subscribe((status, [err]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _channel.track({
              'user_id': widget.currentUserId,
              'name': widget.displayName,
              'online_at': DateTime.now().toIso8601String(),
            });
          }
        });
  }

  @override
  void dispose() {
    _channel.untrack();
    _channel.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = _onlineUsers.values
        .expand((presences) => presences as List)
        .map((p) => (p as Map<String, dynamic>)['name'] as String? ?? 'Unknown')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'オンライン (${users.length})',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: users
              .map((name) => Chip(
                    avatar: CircleAvatar(child: Text(name[0].toUpperCase())),
                    label: Text(name),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
```

---

## 複数機能を 1 チャネルに束ねる

```dart
void _setupChannel(String roomId, String userId) {
  _channel = supabase
      .channel('room_$roomId')
      // Postgres Changes
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (payload) => _addMessage(payload.newRecord),
      )
      // Broadcast
      .onBroadcast(
        event: 'typing',
        callback: (payload) => _setTyping(payload['user_id'] as String),
      )
      // Presence
      .onPresenceSync(callback: (_) {
        setState(() => _onlineUsers = _channel.presenceState());
      })
      .subscribe((status, [_]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _channel.track({'user_id': userId});
        }
      });
}
```

---

## クリーンアップのベストプラクティス

```dart
@override
void dispose() {
  // track を解除してから unsubscribe
  _channel.untrack();
  _channel.unsubscribe();
  // または全チャネルを一括削除
  // supabase.removeAllChannels();
  super.dispose();
}
```

`unsubscribe` 忘れは WebSocket 接続のリークにつながります。`StatefulWidget` の `dispose` で必ず解除してください。

---

## まとめ

| シナリオ | 推奨機能 |
|----------|----------|
| チャット・通知・タスク同期 | Postgres Changes |
| カーソル・タイピング・ゲームアクション | Broadcast |
| オンライン状態・ルームメンバー | Presence |
| チャット + タイピング + オンライン | 3 機能を 1 チャネルに集約 |

---

Supabase Realtime を使って実装した一番面白い機能は何ですか？コメントで教えてください！
