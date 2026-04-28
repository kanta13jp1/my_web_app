---
title: "Supabase Realtime + Flutter: Live UI Without Polling"
tags: supabase,flutter,postgresql,indiedev
published: true
---

# Supabase Realtime + Flutter: Live UI Without Polling

Supabase Realtime pushes database changes via WebSocket. No polling, no repeated API calls, sub-100ms updates. Here's how this project uses it.

## Polling vs Realtime

```
Polling (every 5 seconds):
  Flutter → GET /api/data → Supabase → response → display
  Problem: 5-second delay, constant API consumption

Realtime (WebSocket):
  Flutter ←── WebSocket ──← Supabase (pushes changes immediately)
  Result: sub-100ms updates, zero client-side requests
```

## Basic Setup: Listen to Table Changes

```dart
// lib/services/realtime_service.dart
class RealtimeService {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  void subscribeToNotes({required void Function(List<Map<String, dynamic>>) onUpdate}) {
    _channel = _supabase
      .channel('public:notes')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,  // INSERT / UPDATE / DELETE
        schema: 'public',
        table: 'notes',
        callback: (payload) {
          onUpdate(payload.newRecord.isEmpty ? [] : [payload.newRecord]);
        },
      )
      .subscribe();
  }

  void unsubscribe() {
    _channel?.unsubscribe();
  }
}
```

## Integration with Flutter Widget

```dart
class _NotesRealtimePageState extends State<NotesRealtimePage> {
  final _service = RealtimeService();
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _service.subscribeToNotes(
      onUpdate: (records) {
        if (mounted) {
          setState(() {
            for (final record in records) {
              final index = _notes.indexWhere((n) => n['id'] == record['id']);
              if (index >= 0) {
                _notes[index] = record;  // update existing
              } else {
                _notes.insert(0, record);  // prepend new
              }
            }
          });
        }
      },
    );
  }

  Future<void> _loadInitialData() async {
    final data = await Supabase.instance.client
      .from('notes')
      .select()
      .order('created_at', ascending: false)
      .limit(50);
    setState(() => _notes = List<Map<String, dynamic>>.from(data));
  }

  @override
  void dispose() {
    _service.unsubscribe();
    super.dispose();
  }
}
```

Load initial data in `initState`, subscribe to Realtime, unsubscribe in `dispose`.

## RLS + Realtime

RLS policies apply to Realtime automatically:

```sql
-- This policy means Realtime also delivers only the user's own rows
CREATE POLICY "users_select_own" ON notes
  FOR SELECT USING (auth.uid() = user_id);
```

Use an authenticated client (with the user's JWT) and Realtime respects RLS automatically. No extra work.

## Broadcast: Client-to-Client Messaging

Send arbitrary messages between clients without writing to the database:

```dart
// Sender
await _supabase
  .channel('room:${roomId}')
  .sendBroadcastMessage(
    event: 'cursor_move',
    payload: {'x': 0.5, 'y': 0.3, 'userId': userId},
  );

// Receiver
_supabase
  .channel('room:${roomId}')
  .onBroadcast(
    event: 'cursor_move',
    callback: (payload) {
      setState(() => _cursors[payload['userId']] = Offset(
        payload['x'] as double,
        payload['y'] as double,
      ));
    },
  )
  .subscribe();
```

## Presence: Online User Tracking

```dart
final channel = _supabase.channel('online_users');

channel
  .onPresenceSync(callback: (_) {
    final state = channel.presenceState();
    setState(() => _onlineCount = state.length);
  })
  .subscribe((_,__) async {
    await channel.track({
      'user_id': userId,
      'online_at': DateTime.now().toIso8601String(),
    });
  });
```

`track()` shares presence info. `presenceState()` returns everyone currently online.

## Production Notes

**1. Channel name scope.**  
`public:notes` receives changes from all users. Either rely on RLS to filter, or use scoped channel names like `user:${userId}:notes`.

**2. Connection management.**  
The WebSocket connection is shared app-wide. Don't subscribe to the same channel multiple times. Always unsubscribe in `dispose`.

**3. Enable Realtime per table.**  
Tables need Realtime enabled in the Supabase dashboard, or via migration:

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE notes;
```

## Summary

Supabase Realtime + Flutter in practice:
1. `onPostgresChanges` — listen to table changes
2. RLS applies to Realtime — no separate auth logic
3. `Broadcast` — client-to-client events without DB writes
4. `Presence` — who's online right now
5. Always unsubscribe in `dispose`

Drop polling. Realtime makes both the code and the UX simpler.
