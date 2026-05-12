---
title: "Supabase Realtime — リアルタイム購読・Presence・Broadcast"
tags: supabase,AI,個人開発,programming
published: true
---

# Supabase Realtime — リアルタイム購読・Presence・Broadcast

Supabase Realtime は WebSocket ベースのリアルタイム機能を3つの方式で提供する。

## Postgres Changes (DB変更購読)

```dart
// テーブルの INSERT/UPDATE/DELETE をリアルタイムで受信
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

// クリーンアップ
@override
void dispose() {
  supabase.removeChannel(channel);
  super.dispose();
}
```

## Presence (オンライン状態)

```dart
// ユーザーの在室状況をリアルタイム共有
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

## Broadcast (P2P メッセージ)

```dart
// DB を経由しない軽量なリアルタイム通信 (タイピング中通知など)
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

// 自分がタイピング中を通知
await typingChannel.sendBroadcastMessage(
  event: 'typing',
  payload: {'user_id': currentUserId},
);
```

## まとめ

```
Postgres Changes → DB 変更を即時反映 (チャット・通知・ダッシュボード)
Presence         → ユーザーの在室状況 (オンラインバッジ・共同編集)
Broadcast        → DB 非経由の軽量通信 (タイピング中・カーソル位置)
クリーンアップ   → dispose() で必ず removeChannel()
```

Realtime は「プッシュ通知より速く、ポーリングより安い」リアルタイム体験の最短実装。
