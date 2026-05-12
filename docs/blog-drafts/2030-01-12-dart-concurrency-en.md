---
title: "Dart Concurrency Complete Guide — Isolates, compute, Streams, and Mutex Patterns"
tags: dart,flutter,webdev,indiedev
published: true
---

# Dart Concurrency Complete Guide — Isolates, compute, Streams, and Mutex Patterns

Most Flutter UI jank ultimately comes from blocking the main thread with heavy computation. Dart's concurrency model is powerful but often misunderstood. This guide covers every tool in the toolkit — from the ergonomic `compute()` shortcut to zero-copy buffer transfers and `synchronized` mutexes.

## Dart's Single-Threaded Model and the Event Loop

Dart runs on a **single thread** by default. Asynchronous code (`async`/`await`) doesn't create parallelism — it just yields control to the event loop while waiting for I/O, then resumes. Two pieces of Dart code never truly run simultaneously on the main thread.

The critical distinction:
- **Async (async/await)**: Cooperative concurrency — efficient for I/O-bound work, but still single-threaded.
- **Isolates**: True parallelism on a separate OS thread — required for CPU-bound work.

Anything that burns CPU — JSON decoding, image transformation, encryption, ML inference — must move to an Isolate or it will cause dropped frames.

## compute() — The Simplest Way to Use an Isolate

Flutter's `compute()` function runs a top-level or static function in a background Isolate, waits for the result, and returns it to the calling thread. It's the right choice for one-shot CPU work.

```dart
// Must be a top-level or static function — closures don't work
List<Product> _parseProducts(String jsonStr) {
  final list = jsonDecode(jsonStr) as List;
  return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
}

class ProductRepository {
  Future<List<Product>> fetchProducts() async {
    final response = await http.get(Uri.parse('https://api.example.com/products'));
    // Main thread stays free while this decodes in the background
    return compute(_parseProducts, response.body);
  }
}
```

**Constraint**: Only serializable types can cross Isolate boundaries — primitives, `List`, `Map`, `Uint8List`. You cannot pass a closure, `BuildContext`, or any class with native handles.

## Isolate.spawn() for Long-Lived Bidirectional Workers

When you need to send multiple messages to a persistent background worker (e.g., a compression pipeline or a WebSocket relay), use `Isolate.spawn()` directly with `SendPort` and `ReceivePort`.

```dart
class HeavyProcessor {
  late Isolate _isolate;
  late SendPort _sendPort;
  late ReceivePort _receivePort;

  Future<void> start() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_worker, _receivePort.sendPort);

    // First message from the Isolate is its own SendPort
    _sendPort = await _receivePort.first as SendPort;
  }

  Future<String> process(String input) async {
    final resultPort = ReceivePort();
    _sendPort.send([input, resultPort.sendPort]);
    return await resultPort.first as String;
  }

  void stop() {
    _isolate.kill(priority: Isolate.immediate);
    _receivePort.close();
  }

  static void _worker(SendPort mainSendPort) {
    final workerReceivePort = ReceivePort();
    mainSendPort.send(workerReceivePort.sendPort);

    workerReceivePort.listen((message) {
      final args = message as List;
      final input = args[0] as String;
      final replyPort = args[1] as SendPort;
      replyPort.send(_heavyCompute(input));
    });
  }

  static String _heavyCompute(String input) {
    // Replace with actual CPU-heavy work: compression, parsing, inference, etc.
    return input.split('').reversed.join();
  }
}
```

## Zero-Copy Transfers with TransferableTypedData

When sending large `Uint8List` buffers (decoded image pixels, audio frames) between Isolates, a normal `send()` call copies the entire buffer — doubling memory usage. `TransferableTypedData` transfers *ownership* with no copy.

```dart
// Sender side (main thread)
final pixels = image.buffer.asUint8List();
final transferable = TransferableTypedData.fromList([pixels]);
sendPort.send(transferable);
// pixels is now neutered — accessing it throws. The Isolate owns it.

// Receiver side (Isolate)
receivePort.listen((message) {
  final data = (message as TransferableTypedData).materialize().asUint8List();
  // Process data here
});
```

This pattern is essential for real-time image pipelines where copying 4MB per frame would tank performance.

## Async Stream Transformations — map, where, asyncMap

`Stream` is Dart's native abstraction for sequences of values over time. Chain transformers to build reactive pipelines:

```dart
final Stream<String> rawEvents = _eventController.stream;

final pipeline = rawEvents
  .where((e) => e.isNotEmpty)              // Filter empty events
  .map((e) => e.trim())                    // Synchronous transform
  .asyncMap((e) => _classifyEvent(e))      // Async transform (e.g., API call)
  .distinct();                             // Deduplicate consecutive equal values

// asyncMap preserves order and waits for each Future before pulling the next value
Future<ClassifiedEvent> _classifyEvent(String raw) async {
  final label = await aiClient.classify(raw);
  return ClassifiedEvent(raw: raw, label: label);
}
```

`asyncMap` is sequential — the next upstream event isn't consumed until the current `Future` resolves. This naturally rate-limits API calls. For true parallel async processing, use `transform` with a custom `StreamTransformer`.

## Mutex Patterns with the synchronized Package

Within a single Isolate, `async` code can still race — multiple concurrent `await` calls can interleave unexpectedly. The `synchronized` package provides a `Lock` to serialize access to shared resources.

```dart
import 'package:synchronized/synchronized.dart';

class NetworkCache {
  final _lock = Lock();
  final Map<String, dynamic> _store = {};

  /// Guarantees only one in-flight request per key, even with concurrent callers
  Future<dynamic> getOrFetch(String key) async {
    return _lock.synchronized(() async {
      if (_store.containsKey(key)) return _store[key];

      final result = await _fetchFromNetwork(key);
      _store[key] = result;
      return result;
    });
  }
}
```

Without the `Lock`, two simultaneous callers for the same key could both miss the cache, both fire network requests, and both write results — the classic "thundering herd" problem.

## Flutter Practical Examples — Image Resizing and JSON Decoding

```dart
// Pattern 1: Resize an image in a background Isolate
Future<Uint8List> resizeImageInBackground(Uint8List original) {
  return compute(_resizeImage, original);
}

Uint8List _resizeImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes)!;
  final resized = img.copyResize(decoded, width: 400);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
}

// Pattern 2: Parse a large API response without blocking the UI
Future<DashboardData> loadDashboard() async {
  final res = await supabase.functions.invoke('get-home-dashboard');
  // JSON decoding of a 200KB payload can take ~30ms on old devices
  return compute(_parseDashboard, jsonEncode(res.data));
}

DashboardData _parseDashboard(String jsonStr) {
  return DashboardData.fromJson(
    jsonDecode(jsonStr) as Map<String, dynamic>,
  );
}
```

## Quick Reference

| Use case | Best tool |
|----------|-----------|
| One-shot CPU work | `compute()` |
| Long-lived background worker | `Isolate.spawn()` |
| Large buffer transfer (no copy) | `TransferableTypedData` |
| Reactive data pipelines | `Stream` + `asyncMap` |
| Serializing concurrent async code | `synchronized` (`Lock`) |

The golden rule: keep the main thread free for building and painting widgets. Offload everything else. Start with `compute()` — it handles 80% of real-world Flutter concurrency needs with minimal boilerplate.
