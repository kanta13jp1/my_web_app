---
title: "Build a Realtime Chat with Supabase: Presence, Broadcast, and DB Changes"
tags: supabase,flutter,indiedev,ai
published: true
---

# Build a Realtime Chat with Supabase: Presence, Broadcast, and DB Changes

Build production-quality realtime chat without writing a single WebSocket line. Three Supabase Realtime channel types explained.

## The Three Channel Types

```
1. Postgres Changes: receive INSERT/UPDATE/DELETE from the DB in real time
2. Broadcast:        send arbitrary messages directly between clients
3. Presence:         sync online user state across clients
```

## 1. Postgres Changes — Receive New Messages

```dart
final subscription = supabase
    .channel('messages:room_${roomId}')
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        final newMessage = Message.fromJson(payload.newRecord);
        setState(() => _messages.add(newMessage));
      },
    )
    .subscribe();

@override
void dispose() {
  supabase.removeChannel(subscription);
  super.dispose();
}
```

**Schema + RLS**:

```sql
CREATE TABLE messages (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id    UUID NOT NULL REFERENCES rooms(id),
  user_id    UUID NOT NULL REFERENCES auth.users(id),
  content    TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "room members can read messages"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM room_members
      WHERE room_id = messages.room_id AND user_id = auth.uid()
    )
  );

ALTER PUBLICATION supabase_realtime ADD TABLE messages;
```

## 2. Broadcast — Typing Indicators Without DB Writes

```dart
final channel = supabase.channel('room:$roomId');

// Send
channel.sendBroadcastMessage(
  event: 'typing',
  payload: {'user_id': userId, 'is_typing': true},
);

// Receive
channel.onBroadcast(
  event: 'typing',
  callback: (payload) {
    setState(() => _typingUsers[payload['user_id']] = payload['is_typing']);
  },
).subscribe();
```

## 3. Presence — Who's Online

```dart
final channel = supabase.channel('room:$roomId');

channel.onPresenceSync(callback: (_) {
  final onlineUsers = channel.presenceState().entries
      .map((e) => e.value.first['user_id'] as String)
      .toList();
  setState(() => _onlineUsers = onlineUsers);
});

await channel.subscribe();
await channel.track({'user_id': userId, 'status': 'online'});

@override
void dispose() async {
  await channel.untrack();
  await supabase.removeChannel(channel);
  super.dispose();
}
```

## Complete Chat Widget

```dart
class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final List<Message> _messages = [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _setupRealtime();
  }

  Future<void> _loadInitialMessages() async {
    final data = await supabase
        .from('messages')
        .select('*, profiles(username, avatar_url)')
        .eq('room_id', widget.roomId)
        .order('created_at')
        .limit(50);
    setState(() => _messages.addAll(data.map(Message.fromJson)));
  }

  void _setupRealtime() {
    _channel = supabase
        .channel('messages:${widget.roomId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId,
          ),
          callback: (p) => setState(() => _messages.add(Message.fromJson(p.newRecord))),
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await supabase.from('messages').insert({'room_id': widget.roomId, 'content': text});
    _controller.clear();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    super.dispose();
  }
}
```

## Summary

```
Real-time DB updates        → Postgres Changes
Direct client communication → Broadcast (typing indicators, reactions)
Online status               → Presence
Data protection             → RLS + supabase_realtime publication
```

Supabase Realtime abstracts WebSocket complexity entirely. Focus on what matters: UI, schema design, and RLS policies.

