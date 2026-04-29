---
title: "Dart Async Deep Dive — Mastering Future, Stream, and Isolates"
tags: flutter,dart,webdev,indiedev
published: true
---

# Dart Async Deep Dive — Mastering Future, Stream, and Isolates

`async/await` is the surface. Underneath is a three-layer system: Future, Stream, and Isolate. Here's a complete breakdown of when and how to use each.

## Future — Single Async Value

```dart
Future<String> fetchUser(String id) async {
  final response = await http.get(Uri.parse('/users/$id'));
  return response.body;
}

// Error handling
Future<User> safeGetUser(String id) async {
  try {
    return await userRepo.get(id);
  } on NotFoundException {
    throw UserNotFoundError(id);
  } catch (e, stack) {
    log.error('Unexpected', error: e, stackTrace: stack);
    rethrow;
  }
}

// ❌ Sequential (3 seconds total)
final user = await getUser();
final prefs = await getPrefs();

// ✅ Parallel (2 seconds max)
final [user, prefs] = await Future.wait([getUser(), getPrefs()]);

// Timeout
final data = await fetchData().timeout(
  const Duration(seconds: 10),
  onTimeout: () => throw TimeoutException('Timed out'),
);
```

## Stream — Multiple Async Values

```dart
// Generator
Stream<int> countDown(int from) async* {
  for (int i = from; i >= 0; i--) {
    yield i;
    await Future.delayed(const Duration(seconds: 1));
  }
}

await for (final n in countDown(10)) { print(n); }

// StreamController (manual)
final ctrl = StreamController<String>();
ctrl.add('hello');
ctrl.add('world');
ctrl.close();

ctrl.stream.listen(print, onError: print, onDone: () => print('done'));
```

### StreamBuilder in Flutter

```dart
StreamBuilder<List<Message>>(
  stream: supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('created_at'),
  builder: (context, snapshot) {
    if (snapshot.hasError) return ErrorView(error: snapshot.error!);
    if (!snapshot.hasData) return const CircularProgressIndicator();
    return MessageList(messages: snapshot.data!);
  },
)
```

### Stream Transformations

```dart
final processed = rawStream
    .where((v) => v > 0)
    .map((v) => v * 2)
    .distinct()
    .debounceTime(const Duration(milliseconds: 300))  // rxdart
    .take(10);
```

## Isolate — True Parallelism

Dart is single-threaded by default. Isolates run on separate threads — use them for CPU-heavy work that would block the UI.

```dart
// compute() — high-level, simplest API
final result = await compute(parseJsonInBackground, largeJsonString);

String parseJsonInBackground(String json) {
  // Runs in a separate isolate — UI stays smooth
  return expensiveParse(json);
}
```

```dart
// Isolate.run() — Dart 2.19+
final result = await Isolate.run(() => expensiveCalculation(data));
```

```dart
// Bidirectional communication (advanced)
Future<void> spawnWorker() async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_worker, receivePort.sendPort);

  final sendPort = await receivePort.first as SendPort;
  final reply = ReceivePort();
  sendPort.send([data, reply.sendPort]);
  final result = await reply.first;
}

void _worker(SendPort main) {
  final port = ReceivePort();
  main.send(port.sendPort);
  port.listen((msg) {
    final [data, SendPort replyTo] = msg as List;
    replyTo.send(process(data));
  });
}
```

## Decision Guide

| Task | Use |
|---|---|
| API calls, DB queries | `Future` + `async/await` |
| Real-time data, WebSocket | `Stream` + `StreamBuilder` |
| JSON parse >1MB | `compute()` / `Isolate.run()` |
| Image processing, audio | `Isolate` (bidirectional) |

## Common Pitfalls

- **Sequential awaits when parallel is possible** → `Future.wait()`
- **Spawning Isolates for small tasks** → overhead > gain; profile first
- **Not cancelling streams** → memory leaks; always cancel subscriptions in `dispose()`
- **Missing error handling on Streams** → silent failures; always pass `onError`

---

What's the trickiest async pattern you've dealt with in Flutter/Dart? Drop a comment — I'm particularly curious about real-world Isolate use cases.
