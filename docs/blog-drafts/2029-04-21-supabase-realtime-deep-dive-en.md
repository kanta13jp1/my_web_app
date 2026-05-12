---
title: "Supabase Realtime Complete Guide — All Patterns for Real-Time Data Sync"
tags: supabase,flutter,ai,indiedev
published: true
---

# Supabase Realtime Complete Guide — All Patterns for Real-Time Data Sync

Supabase Realtime streams PostgreSQL changes to clients over WebSocket. Build chat, notifications, and collaboration features with minimal code.

## Three Realtime Features

1. **Postgres Changes**: Listen to INSERT / UPDATE / DELETE on any table
2. **Broadcast**: Send custom messages between clients
3. **Presence**: Share online status, cursor positions, and more

## Postgres Changes

```dart
final channel = supabase.channel('db-changes');

channel.onPostgresChanges(
  event: PostgresChangeEvent.all,
  schema: 'public',
  table: 'messages',
  callback: (payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        print('New: ${payload.newRecord['content']}');
      case PostgresChangeEvent.update:
        print('Updated: ${payload.newRecord['content']}');
      case PostgresChangeEvent.delete:
        print('Deleted: ${payload.oldRecord['id']}');
      default:
        break;
    }
  },
).subscribe();
```

### Filtered Subscription

```dart
channel.onPostgresChanges(
  event: PostgresChangeEvent.insert,
  schema: 'public',
  table: 'messages',
  filter: PostgresChangeFilter(
    type: PostgresChangeFilterType.eq,
    column: 'room_id',
    value: 'room-123',
  ),
  callback: (payload) {
    final message = Message.fromJson(payload.newRecord);
    setState(() => messages.add(message));
  },
).subscribe();
```

## Chat Implementation

```dart
class ChatPage extends ConsumerStatefulWidget {
  final String roomId;
  const ChatPage({required this.roomId, super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  late final RealtimeChannel _channel;
  final List<Message> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToChannel();
  }

  Future<void> _loadMessages() async {
    final data = await supabase
        .from('messages')
        .select()
        .eq('room_id', widget.roomId)
        .order('created_at');
    setState(() => _messages.addAll(data.map(Message.fromJson)));
  }

  void _subscribeToChannel() {
    _channel = supabase.channel('room-${widget.roomId}');
    _channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: widget.roomId,
        ),
        callback: (payload) {
          setState(() => _messages.add(Message.fromJson(payload.newRecord)));
        },
      )
      .subscribe();
  }

  @override
  void dispose() {
    supabase.removeChannel(_channel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: ListView.builder(
          reverse: true,
          itemCount: _messages.length,
          itemBuilder: (context, i) =>
              MessageBubble(message: _messages[_messages.length - 1 - i]),
        ),
      ),
      MessageInput(
        onSend: (content) => supabase.from('messages').insert({
          'room_id': widget.roomId,
          'user_id': supabase.auth.currentUser!.id,
          'content': content,
        }),
      ),
    ]);
  }
}
```

## Broadcast — Peer-to-Peer Messages

```dart
final channel = supabase.channel('cursor-positions');

void sendCursorPosition(double x, double y) {
  channel.sendBroadcastMessage(
    event: 'cursor_move',
    payload: {'x': x, 'y': y, 'user_id': currentUserId},
  );
}

channel.onBroadcast(
  event: 'cursor_move',
  callback: (payload) {
    updateCursorPosition(
      payload['user_id'] as String,
      payload['x'] as double,
      payload['y'] as double,
    );
  },
).subscribe();
```

## Presence — Online Status

```dart
final presenceChannel = supabase.channel('online-users');

presenceChannel
  .onPresenceSync(callback: (_) {
    final count = presenceChannel.presenceState().length;
    print('Online: $count users');
  })
  .onPresenceJoin(callback: (p) {
    print('Joined: ${p.newPresences.first['username']}');
  })
  .onPresenceLeave(callback: (p) {
    print('Left: ${p.leftPresences.first['username']}');
  })
  .subscribe(callback: (status, [_]) async {
    if (status == RealtimeSubscribeStatus.subscribed) {
      await presenceChannel.track({
        'user_id': supabase.auth.currentUser!.id,
        'username': currentUsername,
        'online_at': DateTime.now().toIso8601String(),
      });
    }
  });
```

## Summary

Supabase Realtime's three features:

- **Postgres Changes**: Push DB mutations to clients instantly
- **Broadcast**: Peer-to-peer messaging (cursors, drawing, gaming)
- **Presence**: Online status and active user tracking

Chat, collaboration, and notification systems in dozens of lines.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
