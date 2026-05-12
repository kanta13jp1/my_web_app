---
title: "Supabase Realtime 高度活用 — Presence / Broadcast / チャンネル管理"
tags: supabase,flutter,個人開発,AI
published: true
---

# Supabase Realtime 高度活用 — Presence / Broadcast / チャンネル管理

DB Changes だけが Realtime ではない。Presence でオンラインユーザー管理、Broadcast でサーバーレスなリアルタイム通信を実現する。

## Realtime の3つの機能

```
DB Changes  → テーブルの INSERT/UPDATE/DELETE をリアルタイム検知
Broadcast   → クライアント間で直接メッセージを送受信 (DB 不要)
Presence    → オンラインユーザーの状態をリアルタイム共有
```

## Broadcast: サーバーレスなリアルタイム通信

```dart
// チャンネルに参加して Broadcast を送受信
final channel = supabase.channel('room:${roomId}');

// 受信
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

// 送信 (DB に保存されない = 揮発性)
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

**用途**:

```
✅ リアルタイムカーソル位置共有
✅ ゲームの状態同期
✅ ホワイトボードの描画
✅ ライブ投票 (中間結果表示)
```

## Presence: オンラインユーザー管理

```dart
final channel = supabase.channel('online-users');

// Presence の変化を監視
channel.onPresenceSync(callback: (_) {
  final presenceState = channel.presenceState();
  final onlineUsers = presenceState.values
    .expand((presences) => presences)
    .map((p) => p.payload)
    .toList();
  setState(() => _onlineUsers = onlineUsers);
});

channel.onPresenceJoin(callback: (payload) {
  debugPrint('User joined: ${payload.newPresences.first.payload}');
});

channel.onPresenceLeave(callback: (payload) {
  debugPrint('User left: ${payload.leftPresences.first.payload}');
});

await channel.subscribe();

// 自分の状態を送信
await channel.track({
  'userId': supabase.auth.currentUser!.id,
  'userName': _currentUser.name,
  'avatarUrl': _currentUser.avatarUrl,
  'status': 'active',
  'lastSeen': DateTime.now().toIso8601String(),
});
```

**オンラインユーザー一覧表示**:

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

## DB Changes + Broadcast の組み合わせ

```dart
// 重要なデータ = DB Changes (永続化 + 後から参照可能)
// 一時的なデータ = Broadcast (DB 不要・低レイテンシ)

final channel = supabase.channel('document:${docId}')
  // DB の変更を監視
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
  // 他ユーザーのカーソル位置 (Broadcast)
  ..onBroadcast(
    event: 'cursor',
    callback: (payload) => _updateCursor(payload),
  )
  // オンラインユーザー (Presence)
  ..onPresenceSync(callback: (_) => _updateOnlineUsers());

await channel.subscribe();
```

## チャンネルのライフサイクル管理

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
    // ... イベント登録 ...
    await _channel!.subscribe();
  }

  @override
  void dispose() {
    // チャンネルを必ず解除
    supabase.removeChannel(_channel!);
    super.dispose();
  }
}
```

## まとめ

```
DB Changes → 永続データの変更検知 (チャット/コメント/注文)
Broadcast  → 揮発性のリアルタイム通信 (カーソル/ゲーム/投票)
Presence   → オンラインユーザー管理 (誰が今見ているか)
組み合わせ  → 重要データは DB + リアルタイム体験は Broadcast
```

Supabase Realtime は3機能を1つのチャンネルで組み合わせられる。用途に応じて使い分けるのがポイント。

