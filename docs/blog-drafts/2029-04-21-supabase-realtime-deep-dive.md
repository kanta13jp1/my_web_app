---
title: "Supabase Realtime 完全ガイド — リアルタイムデータ同期の全パターン"
tags: supabase,flutter,個人開発,AI
published: true
---

# Supabase Realtime 完全ガイド — リアルタイムデータ同期の全パターン

Supabase Realtime は PostgreSQL の変更をリアルタイムでクライアントに配信します。チャット・通知・コラボレーション機能を WebSocket ベースで簡単に実装できます。

## 3 つのリアルタイム機能

1. **Postgres Changes**: DB の INSERT/UPDATE/DELETE をリッスン
2. **Broadcast**: クライアント間でカスタムメッセージを送受信
3. **Presence**: オンライン状態・カーソル位置などを共有

## Postgres Changes

```dart
// テーブルの変更をリアルタイムで受信
final channel = supabase.channel('db-changes');

channel.onPostgresChanges(
  event: PostgresChangeEvent.all,  // insert/update/delete すべて
  schema: 'public',
  table: 'messages',
  callback: (payload) {
    final eventType = payload.eventType;
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    switch (eventType) {
      case PostgresChangeEvent.insert:
        print('新規メッセージ: ${newRecord['content']}');
      case PostgresChangeEvent.update:
        print('更新: ${oldRecord['id']} → ${newRecord['content']}');
      case PostgresChangeEvent.delete:
        print('削除: ${oldRecord['id']}');
      default:
        break;
    }
  },
).subscribe();
```

### フィルター付きリッスン

```dart
// 特定ユーザーのメッセージのみ受信
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

## チャット実装例

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
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final msg = _messages[_messages.length - 1 - i];
              return MessageBubble(message: msg);
            },
          ),
        ),
        MessageInput(
          onSend: (content) async {
            await supabase.from('messages').insert({
              'room_id': widget.roomId,
              'user_id': supabase.auth.currentUser!.id,
              'content': content,
            });
          },
        ),
      ],
    );
  }
}
```

## Broadcast — クライアント間メッセージ

```dart
// 送信
final channel = supabase.channel('cursor-positions');

// カーソル位置を全員にブロードキャスト
void sendCursorPosition(double x, double y) {
  channel.sendBroadcastMessage(
    event: 'cursor_move',
    payload: {'x': x, 'y': y, 'user_id': currentUserId},
  );
}

// 受信
channel.onBroadcast(
  event: 'cursor_move',
  callback: (payload) {
    final userId = payload['user_id'] as String;
    final x = payload['x'] as double;
    final y = payload['y'] as double;
    updateCursorPosition(userId, x, y);
  },
).subscribe();
```

## Presence — オンライン状態管理

```dart
// オンライン状態を共有
final presenceChannel = supabase.channel('online-users');

presenceChannel
  .onPresenceSync(callback: (payload) {
    // 全ユーザーのオンライン状態が更新された
    final onlineUsers = presenceChannel.presenceState();
    print('オンライン: ${onlineUsers.length}人');
  })
  .onPresenceJoin(callback: (payload) {
    print('参加: ${payload.newPresences.first['username']}');
  })
  .onPresenceLeave(callback: (payload) {
    print('退出: ${payload.leftPresences.first['username']}');
  })
  .subscribe(callback: (status, [error]) async {
    if (status == RealtimeSubscribeStatus.subscribed) {
      // 自分のステータスを送信
      await presenceChannel.track({
        'user_id': supabase.auth.currentUser!.id,
        'username': currentUsername,
        'online_at': DateTime.now().toIso8601String(),
      });
    }
  });
```

## まとめ

Supabase Realtime の 3 機能:

- **Postgres Changes**: DB変更をクライアントに即座に配信
- **Broadcast**: ピアツーピアのメッセージング (カーソル・描画)
- **Presence**: オンライン状態・アクティブユーザー追跡

チャット・コラボレーション・通知システムを数十行で実装できます。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
