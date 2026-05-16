---
title: "Dart Concurrency Deep Dive — Isolates, Structured Concurrency, and Async Patterns"
tags: dart,flutter,programming,indiedev
published: true
---

Dart's concurrency model is unusual: single-threaded event loop by default, with explicit Isolates for true parallelism. No shared memory, no race conditions, no mutex locks. This guide covers everything from the simple `compute()` helper to long-lived Isolate workers, structured concurrency patterns, and Stream-based reactive flows.

## The Mental Model: Isolates vs Threads

| Concept | Dart Isolates | JavaScript Workers | Java Threads |
|---------|--------------|-------------------|--------------|
| Memory sharing | No — message passing only | No | Yes (with sync overhead) |
| Startup cost | ~1-5ms | ~1ms | ~0.1ms |
| Communication | SendPort/ReceivePort | postMessage | Shared memory |
| Good for | CPU-heavy tasks | Background compute | I/O + CPU mix |

Dart's lack of shared memory is a feature: it makes concurrent code dramatically safer by eliminating data races entirely.

## compute() — The 80% Solution

For one-off heavy operations, `compute()` handles Isolate lifecycle automatically:

```dart
// Top-level or static function only — closures capture state and can't cross Isolate boundaries
List<Product> _parseProductsSync(String json) {
  return (jsonDecode(json) as List)
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .toList();
}

// Offload to an Isolate automatically
Future<List<Product>> fetchAndParseProducts() async {
  final response = await http.get(Uri.parse('https://api.example.com/products'));
  return compute(_parseProductsSync, response.body);
}
```

**When to use**: JSON parsing > 5ms, image processing, cryptography, regex on large strings.
**When not to use**: I/O operations (network, disk) — those are async and don't block the main thread.

## Long-Lived Isolate Worker

For repeated heavy work, spawning a new Isolate per call is wasteful. Use a persistent worker:

```dart
class IsolateWorker {
  late final SendPort _toWorker;
  final _pending = <int, Completer<dynamic>>{};
  int _msgId = 0;

  Future<void> init() async {
    final inbox = ReceivePort();
    await Isolate.spawn(_entryPoint, inbox.sendPort);

    _toWorker = await inbox.first as SendPort;

    inbox.listen((msg) {
      final response = msg as Map<String, dynamic>;
      final id = response['id'] as int;
      final completer = _pending.remove(id);
      if (response.containsKey('error')) {
        completer?.completeError(response['error']!);
      } else {
        completer?.complete(response['result']);
      }
    });
  }

  Future<T> send<T>(String command, dynamic payload) {
    final id = _msgId++;
    final completer = Completer<T>();
    _pending[id] = completer;
    _toWorker.send({'id': id, 'command': command, 'payload': payload});
    return completer.future;
  }

  static void _entryPoint(SendPort replyTo) {
    final inbox = ReceivePort();
    replyTo.send(inbox.sendPort);

    inbox.listen((msg) {
      final request = msg as Map<String, dynamic>;
      final id = request['id'] as int;
      try {
        final result = _dispatch(request['command'] as String, request['payload']);
        replyTo.send({'id': id, 'result': result});
      } catch (e) {
        replyTo.send({'id': id, 'error': e.toString()});
      }
    });
  }

  static dynamic _dispatch(String command, dynamic payload) {
    return switch (command) {
      'reverse' => (payload as String).split('').reversed.join(),
      'sum' => (payload as List<int>).reduce((a, b) => a + b),
      _ => throw ArgumentError('Unknown command: $command'),
    };
  }
}
```

## Structured Concurrency

### Parallel Fetch with Future.wait

```dart
// All succeed or all fail fast
final (users, posts) = await (fetchUsers(), fetchPosts()).wait;

// Pre-Dart 3 equivalent
final results = await Future.wait([fetchUsers(), fetchPosts()]);

// Wait for all regardless of failures, collect errors
final settled = await Future.wait(
  [fetchA(), fetchB(), fetchC()],
  eagerError: false,
);
```

### Race Pattern (First to Finish Wins)

```dart
Future<String> fetchWithFallback(String url) {
  return Future.any([
    http.get(Uri.parse(url)).then((r) => r.body),
    Future.delayed(
      const Duration(seconds: 3),
      () => throw TimeoutException('Primary timeout'),
    ),
    http.get(Uri.parse('$url?fallback=true')).then((r) => r.body),
  ]);
}
```

### Cancellation Token Pattern

```dart
class CancellationToken {
  var _cancelled = false;
  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw CancelledException();
  }
}

class CancelledException implements Exception {}

Future<void> processPages(
  List<String> pages,
  CancellationToken token,
) async {
  for (final page in pages) {
    token.throwIfCancelled();
    await processPage(page);
  }
}

// UI usage: cancel previous operation when search changes
CancellationToken? _currentSearch;

void onSearchChanged(String query) {
  _currentSearch?.cancel();
  final token = _currentSearch = CancellationToken();

  searchDatabase(query, token).then(setState).catchError((e) {
    if (e is! CancelledException) rethrow;
  });
}
```

## Streams for Reactive Data Flows

### Broadcast Stream with Backpressure

```dart
class MarketDataService {
  final _controller = StreamController<Quote>.broadcast();
  
  // Buffer strategy: drop stale quotes
  Stream<Quote> get quotes => _controller.stream
      .where((q) => q.timestamp.isAfter(
          DateTime.now().subtract(const Duration(seconds: 5))));

  void _onNewQuote(Quote q) {
    if (_controller.hasListener) {
      _controller.add(q);
    }
  }
}
```

### async* Generator Streams

```dart
Stream<SearchResult> streamSearch(String query) async* {
  for (final source in [localDb, remoteApi, cacheService]) {
    yield* source.search(query).map((r) => r.copyWith(sourceLabel: source.label));
    await Future.delayed(Duration.zero); // Yield control between sources
  }
}
```

## Flutter Web Isolate Caveats

Flutter Web compiles Isolates to Web Workers. Constraints:
- Can only transfer `Transferable` types: `Uint8List`, `Int32List`, primitive values
- No direct `dart:io` access inside Isolates
- `compute()` works but has higher overhead in debug mode

```dart
// Safe cross-platform compute wrapper
Future<T> safeCompute<T, M>(ComputeCallback<M, T> fn, M message) {
  if (kDebugMode && kIsWeb) {
    // In web debug, run synchronously to avoid Worker overhead
    return Future.value(fn(message));
  }
  return compute(fn, message);
}
```

## Performance Rules of Thumb

| Operation | Threshold for Isolate | Preferred approach |
|----------|----------------------|-------------------|
| JSON parse | > 50KB | `compute()` |
| Image decode | Always | `compute()` |
| Regex on string | > 1MB | `compute()` |
| Network request | Never | `async/await` (non-blocking) |
| DB query | Never | `async/await` (non-blocking) |
| Encryption | Always | `compute()` or Isolate worker |

## Summary

Dart's concurrency model rewards understanding the right tool for each job: `compute()` for one-shot heavy work, persistent Isolate workers for repeated tasks, `Future.wait` for parallel coordination, cancellation tokens for interruptible operations, and Streams for reactive data flows. The absence of shared memory makes reasoning about correctness dramatically simpler — embrace it.

This concludes Phase 54 of the T-1 blog series. Next phase: Flutter Testing Deep Dive / Supabase pgvector / Indie Dev Community Building / Dart Macros.
