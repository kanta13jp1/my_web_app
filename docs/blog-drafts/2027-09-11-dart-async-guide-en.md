---
title: "Dart Async Guide: Future, Stream, and Isolate — When to Use Each"
tags: flutter,ai,indiedev,programming
published: true
---

# Dart Async Guide: Future, Stream, and Isolate — When to Use Each

Dart's async model has three layers. Understanding which to reach for — and when — is what keeps Flutter apps responsive.

## Why Async Matters

```dart
// ❌ BAD: synchronous call blocks the UI
void fetchData() {
  final data = http.get('https://api.example.com/data');  // 2s wait
  // UI freezes for 2 seconds
}

// ✅ GOOD: async keeps the UI responsive
Future<void> fetchData() async {
  final data = await http.get('https://api.example.com/data');
  // UI continues responding while waiting
}
```

## Future: One-Time Async Value

```dart
Future<String> fetchUsername(String userId) async {
  final response = await supabase
      .from('profiles')
      .select('username')
      .eq('id', userId)
      .single();
  return response['username'] as String;
}

final username = await fetchUsername('user-123');
```

**Error handling**:

```dart
try {
  final username = await fetchUsername('user-123');
} on PostgrestException catch (e) {
  debugPrint('DB error: ${e.message}');
} catch (e) {
  debugPrint('Error: $e');
}
```

**Parallel execution with Future.wait**:

```dart
// Sequential: 2 seconds total
final profile = await fetchProfile(userId);   // 1s
final settings = await fetchSettings(userId); // 1s

// Parallel: 1 second total
final results = await Future.wait([
  fetchProfile(userId),
  fetchSettings(userId),
]);
final profile = results[0] as Profile;
final settings = results[1] as Settings;
```

## Stream: Continuous Async Values

```dart
// Supabase Realtime: receive messages as they arrive
Stream<List<Message>> watchMessages(String roomId) {
  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at');
}

// Use in a widget
StreamBuilder<List<Message>>(
  stream: watchMessages('room-1'),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();
    final messages = snapshot.data!;
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (_, i) => MessageTile(message: messages[i]),
    );
  },
)
```

**Building your own Stream**:

```dart
Stream<int> countDown(int from) async* {
  for (int i = from; i >= 0; i--) {
    yield i;
    await Future.delayed(const Duration(seconds: 1));
  }
}

await for (final count in countDown(10)) {
  print(count);  // 10, 9, 8, ... 0
}
```

## Isolate: CPU-Heavy Work on a Separate Thread

```dart
// ❌ BAD: heavy work on main thread → jank
String parseHugeJson(String json) {
  return processJson(json);  // 3 seconds — UI freezes
}

// ✅ GOOD: offload to an Isolate (Flutter 3.7+)
Future<String> parseHugeJsonInBackground(String json) async {
  return Isolate.run(() => processJson(json));
}
```

**For Flutter < 3.7, use `compute()`**:

```dart
Future<String> parseHugeJson(String json) async {
  return compute(processJson, json);
}

String processJson(String json) {
  // runs in a background isolate
  return jsonDecode(json).toString();
}
```

## Decision Guide

```
One-time async value      → Future / async-await
Continuous stream of values → Stream / StreamBuilder
CPU-intensive processing  → Isolate.run / compute
Multiple concurrent tasks → Future.wait
```

**Combining with Riverpod**:

```dart
@riverpod
Future<Profile> userProfile(UserProfileRef ref) async {
  return fetchProfile(ref.watch(authUserIdProvider));
}

@riverpod
Stream<List<Message>> chatMessages(ChatMessagesRef ref, String roomId) {
  return watchMessages(roomId);
}
```

## Summary

Choose based on three questions: how long to wait, how many values, how CPU-heavy. Start with `await`. Add `Stream` when you need real-time updates. Add `Isolate` when the CPU is the bottleneck.
