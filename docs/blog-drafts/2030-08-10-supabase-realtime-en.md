---
title: "Supabase Realtime with Flutter — Postgres Changes, Presence, and Broadcast in Practice"
tags: supabase,flutter,webdev,programming
published: true
---

Supabase Realtime streams PostgreSQL changes to clients over WebSocket. Combine it with Flutter and you can ship live notifications, "who's online" indicators, and collaborative editing in dozens of lines of code. This guide covers all three channel types — Postgres Changes, Presence, and Broadcast — with production-ready examples.

## The Three Channel Types

| Type | Use Case | Data Source |
|------|----------|-------------|
| **Postgres Changes** | React to INSERT/UPDATE/DELETE | PostgreSQL WAL |
| **Broadcast** | Client-to-client events | Realtime server |
| **Presence** | "Who's online" state sync | Realtime server |

## Setup

```yaml
# pubspec.yaml — 2030-08-10-supabase-realtime-en
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
      eventsPerSecond: 10,
      logLevel: RealtimeLogLevel.info,
    ),
  );
  runApp(const App());
}

final supabase = Supabase.instance.client;
```

## 1. Postgres Changes — Real-time DB Events

### Enable Realtime on Your Table

```sql
-- Run in Supabase Dashboard or a migration file
ALTER TABLE notifications REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- RLS: users see only their own notifications
CREATE POLICY "users can view own notifications"
  ON notifications FOR SELECT
  USING (user_id = auth.uid());
```

### Subscribe in Flutter

```dart
class NotificationService {
  RealtimeChannel? _channel;

  void subscribe(String userId, void Function(Map<String, dynamic>) onNew) {
    _channel = supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onNew(payload.newRecord),
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
            // Handle read-status updates
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

### Notification Bell Widget

```dart
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _service = NotificationService();
  int _unreadCount = 0;
  final _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _service.subscribe(supabase.auth.currentUser!.id, _onNew);
  }

  Future<void> _loadInitial() async {
    final data = await supabase
        .from('notifications')
        .select()
        .eq('user_id', supabase.auth.currentUser!.id)
        .eq('read', false)
        .order('created_at', ascending: false)
        .limit(20);

    if (!mounted) return;
    setState(() {
      _items.addAll(List<Map<String, dynamic>>.from(data));
      _unreadCount = _items.length;
    });
  }

  void _onNew(Map<String, dynamic> notification) {
    setState(() {
      _items.insert(0, notification);
      _unreadCount++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(notification['message'] as String? ?? 'New notification')),
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
        onPressed: () => showModalBottomSheet(
          context: context,
          builder: (_) => _NotificationPanel(items: _items),
        ),
      ),
    );
  }
}
```

## 2. Presence — Track Who's Online

Presence syncs each client's arbitrary state object (online status, cursor position, active document…) to every subscriber in the channel.

```dart
class PresenceService {
  RealtimeChannel? _channel;
  final _users = <String, Map<String, dynamic>>{};

  void Function(Map<String, Map<String, dynamic>>)? onSync;

  void join({
    required String roomId,
    required String userId,
    required String displayName,
    String? avatarUrl,
  }) {
    _channel = supabase.channel('room:$roomId')
      ..onPresenceSync((_) {
        _users.clear();
        _channel!.presenceState().forEach((_, presences) {
          if (presences.isNotEmpty) {
            final p = presences.first;
            _users[p['user_id'] as String] = Map<String, dynamic>.from(p);
          }
        });
        onSync?.call(Map.unmodifiable(_users));
      })
      ..onPresenceJoin((payload) {
        for (final p in payload.newPresences) {
          debugPrint('${p['display_name']} joined');
        }
      })
      ..onPresenceLeave((payload) {
        for (final p in payload.leftPresences) {
          _users.remove(p['user_id']);
        }
        onSync?.call(Map.unmodifiable(_users));
      });

    _channel!.subscribe((status, _) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _channel!.track({
          'user_id': userId,
          'display_name': displayName,
          'avatar_url': avatarUrl,
          'online_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  /// Update cursor position for live collaboration
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

### Online Users Avatars Widget

```dart
class OnlineAvatarRow extends StatelessWidget {
  final Map<String, Map<String, dynamic>> users;
  final int maxVisible;

  const OnlineAvatarRow({
    super.key,
    required this.users,
    this.maxVisible = 5,
  });

  @override
  Widget build(BuildContext context) {
    final list = users.values.toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...list.take(maxVisible).map((u) {
          final name = u['display_name'] as String? ?? '?';
          final avatar = u['avatar_url'] as String?;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
              message: name,
              child: CircleAvatar(
                radius: 14,
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null ? Text(name[0].toUpperCase()) : null,
              ),
            ),
          );
        }),
        if (list.length > maxVisible)
          Text(
            '+${list.length - maxVisible}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        const SizedBox(width: 6),
        Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text('${list.length} online',
              style: Theme.of(context).textTheme.labelSmall),
        ]),
      ],
    );
  }
}
```

## 3. Broadcast — Low-latency Peer Messaging

Broadcast skips the database entirely — perfect for chat messages, emoji reactions, and live cursors.

```dart
class ChatBroadcastService {
  RealtimeChannel? _channel;

  void Function(ChatMessage)? onMessage;
  void Function(String userId, String emoji)? onReaction;

  void connect(String roomId) {
    _channel = supabase.channel(
      'chat:$roomId',
      opts: const RealtimeChannelConfig(ack: false),
    )
      ..onBroadcast(
        event: 'message',
        callback: (payload) => onMessage?.call(ChatMessage.fromJson(payload)),
      )
      ..onBroadcast(
        event: 'reaction',
        callback: (payload) => onReaction?.call(
          payload['user_id'] as String,
          payload['emoji'] as String,
        ),
      )
      ..subscribe();
  }

  Future<void> sendMessage(ChatMessage msg) => _channel!.sendBroadcastMessage(
        event: 'message',
        payload: msg.toJson(),
      );

  Future<void> react(String userId, String emoji) =>
      _channel!.sendBroadcastMessage(
        event: 'reaction',
        payload: {'user_id': userId, 'emoji': emoji},
      );

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

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String,
        body: j['body'] as String,
        sentAt: DateTime.parse(j['sent_at'] as String),
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

## 4. Rate Limits and Throttling

```dart
/// Throttle broadcasts to avoid hitting plan limits.
class ThrottledChannel {
  final RealtimeChannel _channel;
  final Duration _interval;
  Timer? _timer;
  Map<String, dynamic>? _pending;

  ThrottledChannel(this._channel, {Duration interval = const Duration(milliseconds: 50)})
      : _interval = interval;

  void send(String event, Map<String, dynamic> payload) {
    _pending = {'event': event, 'payload': payload};
    _timer ??= Timer(_interval, _flush);
  }

  void _flush() {
    if (_pending != null) {
      _channel.sendBroadcastMessage(
        event: _pending!['event'] as String,
        payload: _pending!['payload'] as Map<String, dynamic>,
      );
      _pending = null;
    }
    _timer = null;
  }

  void dispose() => _timer?.cancel();
}

// 30fps cursor broadcast
final _cursorChannel = ThrottledChannel(
  channel,
  interval: const Duration(milliseconds: 33),
);

void onPointerMove(PointerMoveEvent event) {
  _cursorChannel.send('cursor', {'x': event.position.dx, 'y': event.position.dy});
}
```

## Plan Limits (as of 2030)

| Plan | Connections | Messages/sec | Presence members |
|------|-------------|-------------|-----------------|
| Free | 200 | 10 | 100/channel |
| Pro | 500 | 100 | 500/channel |
| Team | 10,000 | 500 | 10,000/channel |

## Summary

The three Realtime channel types cover distinct needs:

- **Postgres Changes** — database-driven notifications with RLS security
- **Presence** — synchronized online state across all clients
- **Broadcast** — low-latency peer events without a database round-trip

Combined with Flutter's reactive UI model, Supabase Realtime lets a solo developer ship collaborative features that would take a small backend team weeks to build from scratch. Next week we tackle indie dev growth loops.
