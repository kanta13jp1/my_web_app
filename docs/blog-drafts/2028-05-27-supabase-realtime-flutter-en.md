---
title: "Supabase Realtime × Flutter — Complete Guide to Real-Time Sync Patterns"
tags: supabase,flutter,ai,indiedev
published: true
---

# Supabase Realtime × Flutter — Complete Guide to Real-Time Sync Patterns

"Save and see it instantly" is table stakes for modern apps. Supabase Realtime makes it straightforward.

## Broadcast: Lightweight Instant Notifications

```dart
// Create a channel and send/receive Broadcasts
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

// Send your own cursor position
Future<void> sendCursor(Offset pos) async {
  await channel.sendBroadcast(
    event: 'cursor',
    payload: {'x': pos.dx, 'y': pos.dy},
  );
}
```

**Use cases**: cursor sharing, typing indicators, transient event notifications (nothing that needs DB persistence)

## Presence: Syncing Online Status

```dart
// Track who's online with Presence
final presenceChannel = supabase.channel('online-users');

presenceChannel
  .onPresenceSync(callback: (payload) {
    // Get everyone's current state
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
        // Announce your own presence
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

## Postgres Changes: Receive DB Mutations in Real Time

```dart
// Subscribe to changes on the tasks table
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

## Optimistic Update Pattern

```dart
// Update the UI first, then sync to DB (improves perceived performance)
Future<void> toggleTask(Task task) async {
  // 1. Optimistic update (instant)
  setState(() {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    _tasks[idx] = task.copyWith(completed: !task.completed);
  });

  try {
    // 2. Persist to DB
    await supabase
        .from('tasks')
        .update({'completed': !task.completed})
        .eq('id', task.id);
    // Realtime receives the change — UI is already in the correct state
  } catch (e) {
    // 3. Roll back on failure
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == task.id);
      _tasks[idx] = task;  // restore original
    });
  }
}
```

## Summary

```
Broadcast        → Transient events with no DB persistence (cursor, typing)
Presence         → Online status and session management
Postgres Changes → Subscribe to DB mutations (filter to your own data)
Optimistic UI    → Update state first to maximize perceived speed
```

Realtime channels carry a connection cost — only open the ones you need, and always release them in `dispose`.
