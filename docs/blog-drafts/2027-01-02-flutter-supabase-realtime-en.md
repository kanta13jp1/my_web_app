---
title: "Flutter Web + Supabase Realtime: From Channel Subscriptions to Optimistic Updates"
tags: supabase,ai,postgresql,indiedev
published: true
---

# Flutter Web + Supabase Realtime: From Channel Subscriptions to Optimistic Updates

Supabase Realtime is easy to start with and easy to get wrong in production. Here are the patterns that worked in my Flutter Web project, covering channel management, optimistic updates, and the gotchas that burned me.

## Basic: Channel Subscription

```dart
// lib/services/realtime_service.dart
class RealtimeService {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  void subscribeMemos(String userId, void Function(List<Memo>) onUpdate) {
    _channel = _supabase
      .channel('memos:$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'memos',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          onUpdate(_buildMemoList(payload));
        },
      )
      .subscribe();
  }

  void dispose() {
    _channel?.unsubscribe();
    _supabase.removeAllChannels();
  }
}
```

**Critical**: forgetting `dispose()` leaks the WebSocket connection. Always call it in your `StatefulWidget`'s `dispose()` method.

## Optimistic Updates

Don't wait for the realtime event — update the UI immediately and roll back on failure:

```dart
Future<void> toggleReaction(String memoId, String reactionType) async {
  // 1. Optimistic update (immediate)
  setState(() {
    _reactions[memoId] = [...?_reactions[memoId], reactionType];
  });

  try {
    // 2. Server call
    await _supabase.functions.invoke('core-hub', body: {
      'action': 'memo.react.toggle',
      'params': {'memo_id': memoId, 'reaction_type': reactionType},
    });
    // 3. Realtime delivers confirmed value → setState again with real data
  } catch (e) {
    // 4. Rollback on failure
    setState(() {
      _reactions[memoId]?.remove(reactionType);
    });
  }
}
```

## Monitoring Connection State

```dart
_channel = _supabase.channel('memos:$userId')
  ..onPostgresChanges(/* ... */)
  ..onSubscribe((status, error) {
    if (status == RealtimeSubscribeStatus.subscribed) {
      debugPrint('realtime: connected');
    } else if (status == RealtimeSubscribeStatus.timedOut) {
      // Flutter Web tabs going to background disconnect frequently
      _reconnect();
    }
  })
  ..subscribe();
```

Flutter Web WebSocket connections drop when the tab goes to the background. Detect timeouts via `onSubscribe` and reconnect proactively.

## Row Level Security Integration

```sql
-- RLS policy on memos table
CREATE POLICY "users can see own memos"
ON memos FOR SELECT
USING (auth.uid() = user_id);
```

RLS policies apply to Realtime subscriptions automatically. Other users' memos never reach the channel.

## Performance: Debouncing High-Frequency Updates

```dart
Timer? _debounce;

void onTyping(String text) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () async {
    await _supabase.from('typing_status').upsert({
      'user_id': userId,
      'is_typing': text.isNotEmpty,
    });
  });
}
```

300ms debounce throttles DB writes for typing indicators. Without this, each keystroke hits the database.

## Common Pitfalls

| Problem | Cause | Fix |
|---|---|---|
| Channel subscribed multiple times | `subscribe()` called repeatedly | Call `dispose()` before re-subscribing |
| RLS blocks realtime events | anon key + wrong policy | Check auth state + verify policy |
| Flutter Web disconnects | Tab goes inactive | Reconnect in timeout callback |
| `memo_reactions` 404 | Stale EF still referenced | Verify migration to core-hub is complete |

## Summary

Flutter + Supabase Realtime reliability comes down to connection lifecycle management. Tie subscribe/unsubscribe to `StatefulWidget` lifecycle, use optimistic updates for snappy UX, secure with RLS — those three principles cover the vast majority of production issues.
