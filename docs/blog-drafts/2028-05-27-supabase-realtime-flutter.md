---
title: "Supabase Realtime × Flutter — リアルタイム同期パターン完全ガイド"
tags: supabase,flutter,AI,個人開発
published: true
---

# Supabase Realtime × Flutter — リアルタイム同期パターン完全ガイド

「保存したらすぐ反映」は現代アプリの基本。Supabase Realtime で実現する。

## Broadcast: 軽量な即時通知

```dart
// チャンネルを作成して Broadcast を送受信
final channel = supabase.channel('room-1');

channel
  .onBroadcast(
    event: 'cursor',
    callback: (payload) {
      final x = payload['x'] as double;
      final y = payload['y'] as double;
      setState(() => _remoteCursor = Offset(x, y));
    },
  )
  .subscribe();

// 自分のカーソル位置を送信
Future<void> sendCursor(Offset pos) async {
  await channel.sendBroadcast(
    event: 'cursor',
    payload: {'x': pos.dx, 'y': pos.dy},
  );
}
```

**用途**: カーソル共有・タイピングインジケーター・一時的なイベント通知 (DBに保存不要なもの)

## Presence: オンライン状態の同期

```dart
// Presence でユーザーのオンライン状態を管理
final presenceChannel = supabase.channel('online-users');

presenceChannel
  .onPresenceSync(callback: (payload) {
    // 全員の現在状態を取得
    final state = presenceChannel.presenceState();
    setState(() {
      _onlineUsers = state.values
          .expand((list) => list)
          .map((p) => p.payload['user'] as String)
          .toList();
    });
  })
  .subscribe(
    (status, [_]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // 自分の状態を送信
        await presenceChannel.track({'user': _userId, 'status': 'active'});
      }
    },
  );

@override
void dispose() {
  presenceChannel.untrack();
  supabase.removeChannel(presenceChannel);
  super.dispose();
}
```

## Postgres Changes: DBの変更をリアルタイムで受信

```dart
// tasks テーブルの変更を購読
supabase
  .channel('tasks-changes')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'tasks',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: _userId,
    ),
    callback: (payload) {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          final task = Task.fromJson(payload.newRecord);
          setState(() => _tasks.add(task));
        case PostgresChangeEvent.update:
          final updated = Task.fromJson(payload.newRecord);
          setState(() {
            final idx = _tasks.indexWhere((t) => t.id == updated.id);
            if (idx >= 0) _tasks[idx] = updated;
          });
        case PostgresChangeEvent.delete:
          final id = payload.oldRecord['id'] as String;
          setState(() => _tasks.removeWhere((t) => t.id == id));
        default:
          break;
      }
    },
  )
  .subscribe();
```

## Optimistic Update パターン

```dart
// UIを先に更新してから DB に反映 (体感速度向上)
Future<void> toggleTask(Task task) async {
  // 1. 楽観的更新 (即時)
  setState(() {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    _tasks[idx] = task.copyWith(completed: !task.completed);
  });

  try {
    // 2. DB に反映
    await supabase
        .from('tasks')
        .update({'completed': !task.completed})
        .eq('id', task.id);
    // Realtime が変更を受信 → UIは既に正しい状態
  } catch (e) {
    // 3. 失敗時にロールバック
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == task.id);
      _tasks[idx] = task;  // 元に戻す
    });
  }
}
```

## まとめ

```
Broadcast        → DB不要の一時イベント (カーソル/タイピング)
Presence         → オンライン状態・セッション管理
Postgres Changes → DB変更の購読 (filter で自分のデータのみ)
Optimistic UI    → 楽観的更新で体感速度を最大化
```

Realtime は接続維持コストがあるため、必要なチャンネルだけ開き、dispose で必ず解放する。
