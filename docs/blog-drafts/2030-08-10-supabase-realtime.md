---
title: "Supabase Realtime 完全ガイド — Flutter で作るリアルタイム通知・プレゼンス・ブロードキャスト"
tags: Supabase,Flutter,programming,webdev
published: true
---

Supabase Realtime は PostgreSQL の変更を WebSocket でクライアントにプッシュする仕組みです。Flutter と組み合わせると、チャット・通知・オンライン状態表示・コラボ編集といった機能を数十行で実装できます。本記事では Postgres Changes、Presence、Broadcast の 3 種を実践コードとともに解説します。

## Realtime の 3 つのチャンネル

| 種別 | 用途 | データソース |
|------|------|-------------|
| **Postgres Changes** | DB 変更のリアルタイム通知 | PostgreSQL WAL |
| **Broadcast** | クライアント → クライアント メッセージ | Realtime サーバー経由 |
| **Presence** | 「誰がオンラインか」の状態同期 | Realtime サーバー経由 |

## セットアップ

```yaml
# pubspec.yaml — 2030-08-10-supabase-realtime
dependencies:
  supabase_flutter: ^2.5.0
```

```dart
// main.dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://<project>.supabase.co',
    anonKey: '<anon-key>',
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 10, // レート制限: デフォルト 10 events/sec
      logLevel: RealtimeLogLevel.info, // デバッグ時は debug に
    ),
  );
  runApp(const App());
}

// グローバルアクセス
final supabase = Supabase.instance.client;
```

## 1. Postgres Changes — DB 変更をリアルタイム受信

### テーブルに RLS + Realtime を有効化

```sql
-- Supabase Dashboard または migration で実行
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- Realtime Publication に追加
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- RLS ポリシー（ユーザー自身の通知のみ購読可能）
CREATE POLICY "users can view own notifications"
  ON notifications FOR SELECT
  USING (user_id = auth.uid());
```

### Flutter での購読

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  RealtimeChannel? _channel;

  void subscribe(String userId, void Function(Map<String, dynamic>) onNew) {
    _channel = supabase
        .channel('notifications:$userId') // チャンネル名はユニークに
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            onNew(record);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            // 既読フラグ更新など
            debugPrint('Updated: ${payload.newRecord}');
          },
        )
        .subscribe();
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
```

### Widget への統合

```dart
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _service = NotificationService();
  int _unreadCount = 0;
  final _notifications = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _service.subscribe(
      supabase.auth.currentUser!.id,
      _onNewNotification,
    );
  }

  Future<void> _loadInitial() async {
    final data = await supabase
        .from('notifications')
        .select()
        .eq('user_id', supabase.auth.currentUser!.id)
        .eq('read', false)
        .order('created_at', ascending: false)
        .limit(20);

    setState(() {
      _notifications.addAll(List<Map<String, dynamic>>.from(data));
      _unreadCount = _notifications.length;
    });
  }

  void _onNewNotification(Map<String, dynamic> notification) {
    setState(() {
      _notifications.insert(0, notification);
      _unreadCount++;
    });
    // SnackBar や OS 通知を出す
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(notification['message'] as String? ?? '新しい通知')),
    );
  }

  @override
  void dispose() {
    _service.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: _unreadCount > 0,
      label: Text('$_unreadCount'),
      child: IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: _showNotificationPanel,
      ),
    );
  }

  void _showNotificationPanel() {
    showModalBottomSheet(
      context: context,
      builder: (_) => NotificationPanel(notifications: _notifications),
    );
  }
}
```

## 2. Presence — オンライン状態の同期

Presence は各クライアントの状態（オンライン/カーソル位置/編集中ドキュメントなど）を全クライアントに同期します。

```dart
class PresenceService {
  RealtimeChannel? _channel;
  final _onlineUsers = <String, Map<String, dynamic>>{};

  // コールバック
  void Function(Map<String, Map<String, dynamic>>)? onPresenceSync;

  void join({
    required String roomId,
    required String userId,
    required String displayName,
    String? avatarUrl,
  }) {
    _channel = supabase.channel('room:$roomId')
      ..onPresenceSync((payload) {
        // 全員の状態が sync されたとき
        final state = _channel!.presenceState();
        _onlineUsers.clear();
        state.forEach((key, presences) {
          if (presences.isNotEmpty) {
            final p = presences.first;
            _onlineUsers[p['user_id'] as String] = Map<String, dynamic>.from(p);
          }
        });
        onPresenceSync?.call(Map.unmodifiable(_onlineUsers));
      })
      ..onPresenceJoin((payload) {
        for (final p in payload.newPresences) {
          debugPrint('${p['display_name']} joined');
        }
      })
      ..onPresenceLeave((payload) {
        for (final p in payload.leftPresences) {
          debugPrint('${p['display_name']} left');
          _onlineUsers.remove(p['user_id']);
        }
        onPresenceSync?.call(Map.unmodifiable(_onlineUsers));
      });

    _channel!.subscribe((status, _) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // 自分の状態をトラッキング開始
        await _channel!.track({
          'user_id': userId,
          'display_name': displayName,
          'avatar_url': avatarUrl,
          'online_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  // カーソル位置を更新（ドキュメント共同編集など）
  Future<void> updateCursor(double x, double y) async {
    await _channel?.track({'cursor': {'x': x, 'y': y}});
  }

  Future<void> leave() async {
    await _channel?.untrack();
    await _channel?.unsubscribe();
    _channel = null;
  }
}
```

### オンラインユーザー一覧 Widget

```dart
class OnlineUsersRow extends StatelessWidget {
  final Map<String, Map<String, dynamic>> users;

  const OnlineUsersRow({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    final list = users.values.toList();
    return Row(
      children: [
        ...list.take(5).map((u) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: u['display_name'] as String? ?? 'Unknown',
            child: CircleAvatar(
              radius: 16,
              backgroundImage: u['avatar_url'] != null
                  ? NetworkImage(u['avatar_url'] as String)
                  : null,
              child: u['avatar_url'] == null
                  ? Text((u['display_name'] as String? ?? '?')[0].toUpperCase())
                  : null,
            ),
          ),
        )),
        if (list.length > 5)
          Text('+${list.length - 5}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 8),
        Text('${list.length} オンライン',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
```

## 3. Broadcast — リアルタイムイベント送受信

Broadcast はデータベースを介さずクライアント間でメッセージを直送します。チャット・リアクション・ライブカーソルに最適です。

```dart
class BroadcastChatService {
  RealtimeChannel? _channel;

  void Function(ChatMessage)? onMessage;
  void Function(String userId, String emoji)? onReaction;

  void connect(String roomId) {
    _channel = supabase.channel(
      'chat:$roomId',
      opts: const RealtimeChannelConfig(
        ack: false, // 高速化のため ACK 不要
      ),
    )
      ..onBroadcast(
        event: 'chat_message',
        callback: (payload) {
          final msg = ChatMessage.fromJson(payload);
          onMessage?.call(msg);
        },
      )
      ..onBroadcast(
        event: 'reaction',
        callback: (payload) {
          onReaction?.call(
            payload['user_id'] as String,
            payload['emoji'] as String,
          );
        },
      )
      ..subscribe();
  }

  Future<void> sendMessage(ChatMessage message) async {
    await _channel?.sendBroadcastMessage(
      event: 'chat_message',
      payload: message.toJson(),
    );
  }

  Future<void> sendReaction(String userId, String emoji) async {
    await _channel?.sendBroadcastMessage(
      event: 'reaction',
      payload: {'user_id': userId, 'emoji': emoji},
    );
  }

  void disconnect() {
    _channel?.unsubscribe();
    _channel = null;
  }
}

class ChatMessage {
  final String id;
  final String userId;
  final String displayName;
  final String body;
  final DateTime sentAt;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.body,
    required this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
        body: json['body'] as String,
        sentAt: DateTime.parse(json['sent_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'display_name': displayName,
        'body': body,
        'sent_at': sentAt.toIso8601String(),
      };
}
```

## 4. レートリミットとスケーリング

```dart
// Broadcast は throttle で流量制御
class ThrottledBroadcast {
  final Duration _interval;
  Timer? _timer;
  Map<String, dynamic>? _pending;
  final Future<void> Function(Map<String, dynamic>) _send;

  ThrottledBroadcast({
    required Duration interval,
    required Future<void> Function(Map<String, dynamic>) send,
  })  : _interval = interval,
        _send = send;

  void send(Map<String, dynamic> payload) {
    _pending = payload;
    _timer ??= Timer(_interval, _flush);
  }

  void _flush() {
    if (_pending != null) {
      _send(_pending!);
      _pending = null;
    }
    _timer = null;
  }

  void dispose() {
    _timer?.cancel();
  }
}

// マウスカーソル追跡（30fps に制限）
final _cursorBroadcast = ThrottledBroadcast(
  interval: const Duration(milliseconds: 33), // ~30 fps
  send: (payload) => presenceService.updateCursor(
    payload['x'] as double,
    payload['y'] as double,
  ),
);
```

## Supabase Realtime の制限値（2030 年時点）

| プラン | 同時接続 | メッセージ/秒 | Presence メンバー |
|--------|----------|-------------|-----------------|
| Free | 200 | 10 | 100/チャンネル |
| Pro | 500 | 100 | 500/チャンネル |
| Team | 10,000 | 500 | 10,000/チャンネル |

## まとめ

Supabase Realtime の 3 チャンネルを使い分けることで:

- **Postgres Changes** → DB 変更をトリガーにした通知
- **Presence** → リアルタイムのオンライン状態管理
- **Broadcast** → DB 不要の低遅延メッセージング

Flutter アプリにリアルタイム性を加えるコストは劇的に下がりました。次回はインディー開発者向けのグロース戦略を解説します。
