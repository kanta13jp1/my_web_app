---
title: "Supabase Realtime Deep Dive — Postgres Changes, Broadcast, and Presence"
tags: supabase,webdev,indiedev,flutter
published: true
---

# Supabase Realtime Deep Dive — Postgres Changes, Broadcast, and Presence

Supabase Realtime gives you WebSocket-based push for three distinct use cases. Picking the wrong subsystem wastes messages and adds complexity, so this guide covers all three with Flutter code you can drop straight into production.

---

## The Three Subsystems at a Glance

| Feature | Best for | Persisted? | Scale concern |
|---------|----------|-----------|---------------|
| Postgres Changes | DB row events | Yes — in PostgreSQL | Messages/month |
| Broadcast | Ephemeral signals | No — fire-and-forget | Messages/month |
| Presence | Online state sync | No — auto-clean on disconnect | Presence events |

---

## Project Setup

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.5.0
```

```dart
// main.dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;
```

---

## Postgres Changes

Supabase streams WAL (Write-Ahead Log) events from PostgreSQL to connected clients. You must enable the `supabase_realtime` publication for each table.

```sql
-- Enable realtime for your table (run once in the SQL editor)
alter publication supabase_realtime add table tasks;
```

### Subscribing to INSERT / UPDATE / DELETE

```dart
class TaskFeed extends StatefulWidget {
  const TaskFeed({super.key});

  @override
  State<TaskFeed> createState() => _TaskFeedState();
}

class _TaskFeedState extends State<TaskFeed> {
  final _tasks = <Map<String, dynamic>>[];
  late final RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
    _subscribe();
  }

  Future<void> _loadSnapshot() async {
    final rows = await supabase
        .from('tasks')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    if (!mounted) return;
    setState(() => _tasks.addAll(List<Map<String, dynamic>>.from(rows)));
  }

  void _subscribe() {
    _channel = supabase
        .channel('public:tasks')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tasks',
          callback: (p) {
            if (!mounted) return;
            setState(() => _tasks.insert(0, p.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tasks',
          callback: (p) {
            if (!mounted) return;
            setState(() {
              final i = _tasks.indexWhere((t) => t['id'] == p.newRecord['id']);
              if (i >= 0) _tasks[i] = p.newRecord;
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'tasks',
          callback: (p) {
            if (!mounted) return;
            setState(() => _tasks.removeWhere(
                (t) => t['id'] == p.oldRecord['id']));
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
  Widget build(BuildContext context) => ListView.separated(
        itemCount: _tasks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => ListTile(
          title: Text(_tasks[i]['title'] as String),
          trailing: Text(_tasks[i]['status'] as String),
        ),
      );
}
```

### Row-Level Filtering

```dart
_channel = supabase
    .channel('my_tasks')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tasks',
      // Only receive rows where user_id matches the current user
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: supabase.auth.currentUser!.id,
      ),
      callback: (p) => debugPrint(p.toString()),
    )
    .subscribe();
```

Supported filter types: `eq`, `neq`, `lt`, `lte`, `gt`, `gte`, `in`.

---

## Broadcast — Ephemeral Events

Broadcast is ideal for cursor tracking, typing indicators, live votes, or any signal that doesn't need to be stored.

```dart
class WhiteboardPage extends StatefulWidget {
  final String boardId;
  final String userId;

  const WhiteboardPage({
    super.key,
    required this.boardId,
    required this.userId,
  });

  @override
  State<WhiteboardPage> createState() => _WhiteboardPageState();
}

class _WhiteboardPageState extends State<WhiteboardPage> {
  late final RealtimeChannel _channel;
  final Map<String, Offset> _remoteCursors = {};

  @override
  void initState() {
    super.initState();
    _channel = supabase
        .channel('board_${widget.boardId}')
        .onBroadcast(
          event: 'cursor',
          callback: (payload) {
            if (!mounted) return;
            final uid = payload['uid'] as String?;
            if (uid == null || uid == widget.userId) return;
            setState(() {
              _remoteCursors[uid] = Offset(
                (payload['x'] as num).toDouble(),
                (payload['y'] as num).toDouble(),
              );
            });
          },
        )
        .subscribe();
  }

  Future<void> _sendCursor(Offset pos) async {
    await _channel.sendBroadcastMessage(
      event: 'cursor',
      payload: {
        'uid': widget.userId,
        'x': pos.dx,
        'y': pos.dy,
      },
    );
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (e) => _sendCursor(e.localPosition),
      child: Stack(
        children: [
          const ColoredBox(color: Color(0xFFF5F5F5), child: SizedBox.expand()),
          for (final e in _remoteCursors.entries)
            Positioned(
              left: e.value.dx,
              top: e.value.dy,
              child: _RemoteCursor(label: e.key),
            ),
        ],
      ),
    );
  }
}

class _RemoteCursor extends StatelessWidget {
  final String label;
  const _RemoteCursor({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mouse, size: 14, color: Colors.blue),
        Container(
          margin: const EdgeInsets.only(left: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 9)),
        ),
      ],
    );
  }
}
```

---

## Presence — Who Is Online Right Now

Presence maintains a CRDT-based shared state across all connected clients. When a client disconnects, its presence entry is automatically removed.

```dart
class RoomPage extends StatefulWidget {
  final String roomId;
  final String userId;
  final String userName;

  const RoomPage({
    super.key,
    required this.roomId,
    required this.userId,
    required this.userName,
  });

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late final RealtimeChannel _channel;
  Map<String, dynamic> _presenceState = {};

  @override
  void initState() {
    super.initState();
    _channel = supabase.channel('room_${widget.roomId}');

    _channel
        .onPresenceSync(callback: (_) {
          if (!mounted) return;
          setState(() => _presenceState = _channel.presenceState());
        })
        .onPresenceJoin(callback: (payload) {
          for (final p in payload.newPresences) {
            debugPrint('Joined: ${p.payload['name']}');
          }
        })
        .onPresenceLeave(callback: (payload) {
          for (final p in payload.leftPresences) {
            debugPrint('Left: ${p.payload['name']}');
          }
        })
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Announce yourself to the room
            await _channel.track({
              'user_id': widget.userId,
              'name': widget.userName,
              'joined_at': DateTime.now().toIso8601String(),
            });
          }
        });
  }

  List<String> get _onlineNames {
    return _presenceState.values
        .expand((list) => list as List)
        .map((p) => (p as Map)['name'] as String? ?? '?')
        .toList();
  }

  @override
  void dispose() {
    _channel.untrack();
    _channel.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Online now: ${_onlineNames.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Wrap(
          spacing: 8,
          children: _onlineNames
              .map((n) => Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Text(
                        n[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    label: Text(n),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
```

---

## Combining All Three on One Channel

A single channel can carry all three event types, which reduces the number of WebSocket handshakes.

```dart
_channel = supabase
    .channel('chat_$roomId')
    // DB messages
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (p) => _onNewMessage(p.newRecord),
    )
    // Typing indicator (ephemeral)
    .onBroadcast(
      event: 'typing',
      callback: (p) => _onTyping(p['user_id'] as String),
    )
    // Who is in the room
    .onPresenceSync(callback: (_) {
      setState(() => _members = _channel.presenceState());
    })
    .subscribe((status, [_]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _channel.track({'user_id': currentUserId, 'name': displayName});
      }
    });
```

---

## Cleanup Checklist

```dart
@override
void dispose() {
  // 1. Stop tracking presence
  await _channel.untrack();
  // 2. Unsubscribe from the channel
  _channel.unsubscribe();
  // 3. Or nuke everything at once (useful in app shutdown):
  // supabase.removeAllChannels();
  super.dispose();
}
```

Never skip `unsubscribe`. Leaked subscriptions hold open WebSocket connections and count against your message quota.

---

## Choosing the Right Tool

| Use case | Feature |
|---------|---------|
| Chat messages, task updates, notifications | Postgres Changes |
| Cursor positions, drawing strokes, live votes | Broadcast |
| Online user list, room participants | Presence |
| Full collaboration app | Combine all three |

---

Which Supabase Realtime feature have you found most useful for your indie project — and what problems did you run into? Share in the comments!
