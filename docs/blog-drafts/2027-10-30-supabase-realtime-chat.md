---
title: "Supabase Realtime でチャットを実装する — Presence / Broadcast / DB変更"
tags: supabase,flutter,個人開発,AI
published: true
---

# Supabase Realtime でチャットを実装する — Presence / Broadcast / DB変更

WebSocket を1行も書かずにリアルタイムチャットを作る。Supabase Realtime の3チャンネルタイプを解説する。

## Supabase Realtime の3種類

```
1. Postgres Changes: DB の INSERT/UPDATE/DELETE をリアルタイム受信
2. Broadcast:        クライアント間で任意のメッセージを送受信
3. Presence:         オンラインユーザーの状態を同期
```

## 1. Postgres Changes でメッセージを受信

```dart
// メッセージが INSERT されたらリアルタイムで受信
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

// クリーンアップ
@override
void dispose() {
  supabase.removeChannel(subscription);
  super.dispose();
}
```

**SQL: messages テーブルと RLS**:

```sql
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: 自分のルームのメッセージのみ
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "room members can read messages"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM room_members
      WHERE room_id = messages.room_id
        AND user_id = auth.uid()
    )
  );

-- Realtime の有効化
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
```

## 2. Broadcast で即時メッセージ配信

DB を介さずにクライアント間で直接メッセージを送る（タイピングインジケーター等に最適）。

```dart
// チャンネル作成
final channel = supabase.channel('room:$roomId');

// タイピングインジケーター送信
channel.sendBroadcastMessage(
  event: 'typing',
  payload: {'user_id': userId, 'is_typing': true},
);

// 受信
channel.onBroadcast(
  event: 'typing',
  callback: (payload) {
    final isTyping = payload['is_typing'] as bool;
    final typingUserId = payload['user_id'] as String;
    setState(() => _typingUsers[typingUserId] = isTyping);
  },
).subscribe();
```

## 3. Presence でオンライン状態を同期

```dart
// オンライン状態を送信
final channel = supabase.channel('room:$roomId');

channel.onPresenceSync(callback: (_) {
  // 全ユーザーの状態を取得
  final presenceState = channel.presenceState();
  final onlineUsers = presenceState.entries
      .map((e) => e.value.first['user_id'] as String)
      .toList();
  setState(() => _onlineUsers = onlineUsers);
});

await channel.subscribe();

// 自分の状態を登録
await channel.track({'user_id': userId, 'status': 'online'});

// 退室時に削除
@override
void dispose() async {
  await channel.untrack();
  await supabase.removeChannel(channel);
  super.dispose();
}
```

## チャットUIの全体像

```dart
class ChatPage extends ConsumerStatefulWidget {
  final String roomId;
  const ChatPage({required this.roomId, super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final List<Message> _messages = [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _setupRealtime();
    _loadInitialMessages();
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
          callback: (payload) {
            setState(() => _messages.add(Message.fromJson(payload.newRecord)));
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    await supabase.from('messages').insert({
      'room_id': widget.roomId,
      'content': _controller.text.trim(),
    });
    _controller.clear();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (_, i) => MessageTile(message: _messages[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller)),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## まとめ

```
DB の変更をリアルタイム受信 → Postgres Changes
クライアント間の直接通信    → Broadcast (タイピング等)
オンライン状態の同期        → Presence
データ保護                  → RLS + supabase_realtime publication
```

Supabase Realtime はWebSocket の複雑さを完全に隠蔽する。チャットの本質的な実装（UI + DB 設計 + RLS）に集中できる。

