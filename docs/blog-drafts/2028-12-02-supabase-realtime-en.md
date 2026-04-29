---
title: "Supabase Realtime — Postgres Changes, Presence, and Broadcast"
tags: supabase,ai,indiedev,programming
published: true
---

# Supabase Realtime — Postgres Changes, Presence, and Broadcast

Supabase Realtime delivers WebSocket-based real-time features in three distinct modes.

## Postgres Changes (DB Change Subscription)

```dart
// Receive INSERT/UPDATE/DELETE from a table in real time
final channel = supabase.channel('public:messages');

channel
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'messages',
    callback: (payload) {
      final newRow = payload.newRecord;
      setState(() => _messages.add(Message.fromJson(newRow)));
    },
  )
  .subscribe();

// Cleanup
@override
void dispose() {
  supabase.removeChannel(channel);
  super.dispose();
}
```

## Presence (Online Status)

```dart
// Share user presence state in real time
final presenceChannel = supabase.channel('room:${roomId}');

presenceChannel
  .onPresenceSync((_) {
    final state = presenceChannel.presenceState();
    final onlineUsers = state.keys.toList();
    setState(() => _onlineUsers = onlineUsers);
  })
  .subscribe(
    (status, _) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await presenceChannel.track({'user_id': userId, 'online_at': DateTime.now().toIso8601String()});
      }
    },
  );
```

## Broadcast (P2P Messaging)

```dart
// Lightweight real-time communication without hitting the DB (typing indicators, cursors)
final typingChannel = supabase.channel('typing:${roomId}');

typingChannel
  .onBroadcast(
    event: 'typing',
    callback: (payload) {
      final typingUserId = payload['user_id'] as String;
      setState(() => _typingUsers.add(typingUserId));
    },
  )
  .subscribe();

// Notify others that the current user is typing
await typingChannel.sendBroadcastMessage(
  event: 'typing',
  payload: {'user_id': currentUserId},
);
```

## Summary

```
Postgres Changes → instant DB change propagation (chat, notifications, dashboards)
Presence         → user online state (online badges, collaborative editing)
Broadcast        → DB-bypass lightweight messaging (typing indicators, cursors)
Cleanup          → always call removeChannel() in dispose()
```

Realtime delivers faster than push notifications, cheaper than polling — it's the fastest path to a live-updating UX.
