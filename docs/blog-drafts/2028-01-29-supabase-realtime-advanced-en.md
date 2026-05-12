---
title: "Supabase Realtime Advanced: Presence, Broadcast, and Channel Management"
tags: supabase,flutter,indiedev,ai
published: true
---

# Supabase Realtime Advanced: Presence, Broadcast, and Channel Management

DB Changes is only one third of Supabase Realtime. Presence tracks who's online; Broadcast enables serverless real-time messaging between clients.

## The Three Realtime Features

```
DB Changes  → detect INSERT/UPDATE/DELETE on tables in real time
Broadcast   → send messages directly between clients (no DB required)
Presence    → share online user state in real time
```

## Broadcast: Serverless Real-Time Messaging

```dart
final channel = supabase.channel('room:$roomId');

// Receive
channel.onBroadcast(
  event: 'cursor-move',
  callback: (payload) {
    setState(() {
      _cursors[payload['userId']] = Offset(
        payload['x'].toDouble(),
        payload['y'].toDouble(),
      );
    });
  },
);

await channel.subscribe();

// Send (not persisted to DB — ephemeral, low latency)
Future<void> sendCursorPosition(Offset position) async {
  await channel.sendBroadcastMessage(
    event: 'cursor-move',
    payload: {
      'userId': supabase.auth.currentUser!.id,
      'x': position.dx,
      'y': position.dy,
    },
  );
}
```

**Best for**:

```
✅ Real-time cursor sharing
✅ Game state sync
✅ Collaborative whiteboard strokes
✅ Live poll intermediate results
```

## Presence: Online User Management

```dart
final channel = supabase.channel('online-users');

channel.onPresenceSync(callback: (_) {
  final onlineUsers = channel.presenceState().values
    .expand((p) => p)
    .map((p) => p.payload)
    .toList();
  setState(() => _onlineUsers = onlineUsers);
});

channel.onPresenceJoin(callback: (payload) {
  debugPrint('Joined: ${payload.newPresences.first.payload}');
});

channel.onPresenceLeave(callback: (payload) {
  debugPrint('Left: ${payload.leftPresences.first.payload}');
});

await channel.subscribe();

// Announce your own presence
await channel.track({
  'userId': supabase.auth.currentUser!.id,
  'userName': _currentUser.name,
  'avatarUrl': _currentUser.avatarUrl,
  'status': 'active',
  'lastSeen': DateTime.now().toIso8601String(),
});
```

**Display online avatars**:

```dart
Widget buildOnlineUsers() {
  return Row(
    children: [
      ..._onlineUsers.take(5).map((user) => CircleAvatar(
        backgroundImage: NetworkImage(user['avatarUrl']),
        radius: 16,
      )),
      if (_onlineUsers.length > 5)
        Text('+${_onlineUsers.length - 5}'),
    ],
  );
}
```

## Combining DB Changes + Broadcast

```dart
// Rule: important data → DB Changes (persisted, queryable later)
//       transient data → Broadcast (no DB, lowest latency)

final channel = supabase.channel('document:$docId')
  ..onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'documents',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'id',
      value: docId,
    ),
    callback: (payload) => _handleDocumentChange(payload),
  )
  ..onBroadcast(
    event: 'cursor',
    callback: (payload) => _updateCursor(payload),
  )
  ..onPresenceSync(callback: (_) => _updateOnlineUsers());

await channel.subscribe();
```

## Channel Lifecycle Management

```dart
class _RealtimePageState extends State<RealtimePage> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _setupChannel();
  }

  Future<void> _setupChannel() async {
    _channel = supabase.channel('room:${widget.roomId}');
    // ... register events ...
    await _channel!.subscribe();
  }

  @override
  void dispose() {
    supabase.removeChannel(_channel!); // always clean up
    super.dispose();
  }
}
```

## Summary

```
DB Changes → persist and detect changes (chat, comments, orders)
Broadcast  → ephemeral real-time comms (cursors, games, polls)
Presence   → who's online right now
Combine    → DB for durability + Broadcast for real-time feel
```

All three features work on a single channel. Pick the right tool for each data type — ephemeral vs. persistent.

