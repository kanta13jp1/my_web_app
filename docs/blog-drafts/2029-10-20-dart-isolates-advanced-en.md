---
title: "Dart Isolates in Depth — Background Processing, Worker Pools, and compute()"
tags: flutter,dart,webdev,indiedev
published: true
---

# Dart Isolates in Depth — Background Processing, Worker Pools, and compute()

Flutter UI jank is almost always the same culprit: heavy synchronous work blocking the main isolate's event loop. Dart's answer is **Isolates** — independent execution contexts with separate heaps, communicating only through message passing. In this deep dive we'll cover `compute()`, `Isolate.run()` (Dart 3), `Isolate.spawn()` for persistent bidirectional workers, and a production-grade worker pool pattern.

## How Dart's Isolate Model Works

Unlike threads in Java or Go, Dart isolates share no memory. Each isolate has its own heap, and the only way to exchange data is by sending messages — values are copied (or transferred via `TransferableTypedData` for large buffers without copying).

```
Main Isolate                     Worker Isolate
┌──────────────────────┐        ┌──────────────────────┐
│  Flutter UI thread   │        │  Background thread   │
│  Event Loop          │◄──────►│  Event Loop          │
│  Own Heap            │ ports  │  Own Heap            │
│  - Widget tree       │        │  - Computation only  │
│  - Animations        │        │  - No Flutter SDK    │
└──────────────────────┘        └──────────────────────┘
         ▲
         │ async/await handles I/O — no isolate needed
         │ isolate needed only for CPU-bound work
```

Key rules:
- Top-level functions or `static` methods can be used as isolate entry points
- Closures work with `Isolate.run()` (Dart 3) but not `Isolate.spawn()`
- Objects sent through ports are deep-copied by default

## compute() — The Flutter Convenience Wrapper

`compute()` spawns a fresh isolate, runs your function, returns the result, and disposes of the isolate. It's the right choice for one-off CPU tasks in Flutter apps that need Dart 2 compatibility.

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';

// Must be a top-level or static function
List<Product> _parseProducts(String json) {
  final decoded = jsonDecode(json) as List<dynamic>;
  return decoded
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .toList();
}

class ProductRepository {
  final _http = http.Client();

  Future<List<Product>> fetchAll() async {
    // Network I/O is non-blocking — no isolate needed
    final response = await _http.get(Uri.parse('https://api.example.com/products'));

    // JSON parsing of a large payload is CPU-bound — offload it
    return compute(_parseProducts, response.body);
  }
}

// Multiple arguments: wrap in a record or Map
(List<Item>, List<Item>) _partitionItems((List<Item>, bool Function(Item)) args) {
  final (items, predicate) = args;
  final matched = items.where(predicate).toList();
  final rest = items.where((e) => !predicate(e)).toList();
  return (matched, rest);
}

final (active, archived) = await compute(
  _partitionItems,
  (allItems, (Item item) => item.isActive),
);
```

## Isolate.run() — The Dart 3 Way

`Isolate.run()` accepts a closure (not just top-level functions), making the call site much cleaner. It has the same "spawn → run → dispose" lifecycle as `compute()`.

```dart
import 'dart:isolate';

// Closures work fine — captured variables are deep-copied
Future<List<String>> deduplicateAndSort(List<String> input) {
  return Isolate.run(() {
    return input
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim().toLowerCase())
        .toSet()
        .toList()
      ..sort();
  });
}

// Image processing — flip pixels to grayscale
Future<Uint8List> toGrayscale(Uint8List pixels) {
  return Isolate.run(() {
    final out = Uint8List.fromList(pixels);
    for (var i = 0; i < out.length - 3; i += 4) {
      // BT.601 luma coefficients
      final luma = (0.299 * out[i] + 0.587 * out[i + 1] + 0.114 * out[i + 2])
          .round()
          .clamp(0, 255);
      out[i] = out[i + 1] = out[i + 2] = luma;
    }
    return out;
  });
}

// Encryption — bcrypt-style work factor
Future<String> hashPassword(String password) {
  return Isolate.run(() {
    // Uses dart:crypto or a pure-Dart bcrypt implementation
    final salt = generateSalt(12);
    return bcrypt(password, salt);
  });
}

// Error handling is identical to regular async code
Future<void> withErrorHandling() async {
  try {
    await Isolate.run(() => throw FormatException('bad input'));
  } on FormatException catch (e) {
    debugPrint('Caught from isolate: $e');
  }
}
```

## Isolate.spawn() — Persistent Bidirectional Workers

When you need a long-running worker that processes many messages (e.g., a real-time transcription service, a file watcher, or a stream processor), use `Isolate.spawn()` to keep the isolate alive.

```dart
import 'dart:isolate';

// Entry point — must be a top-level function
void _workerEntryPoint(SendPort callerSendPort) {
  final workerReceivePort = ReceivePort();

  // Handshake: send our port to the caller
  callerSendPort.send(workerReceivePort.sendPort);

  workerReceivePort.listen((dynamic message) {
    if (message == 'shutdown') {
      workerReceivePort.close();
      return;
    }

    if (message is _WorkRequest) {
      final result = _processWork(message.payload);
      message.replyPort.send(_WorkResponse(id: message.id, result: result));
    }
  });
}

String _processWork(String payload) {
  // Simulate CPU-intensive work
  var result = payload;
  for (var i = 0; i < 10000; i++) {
    result = result.hashCode.toRadixString(16);
  }
  return result;
}

// Message types — plain data classes, no Flutter dependencies
class _WorkRequest {
  final int id;
  final String payload;
  final SendPort replyPort;
  const _WorkRequest(this.id, this.payload, this.replyPort);
}

class _WorkResponse {
  final int id;
  final String result;
  const _WorkResponse({required this.id, required this.result});
}

// High-level wrapper used from Flutter
class PersistentHashWorker {
  Isolate? _isolate;
  SendPort? _toWorker;
  final _pending = <int, Completer<String>>{};
  int _idCounter = 0;
  ReceivePort? _fromWorker;

  Future<void> start() async {
    final setupPort = ReceivePort();
    _isolate = await Isolate.spawn(_workerEntryPoint, setupPort.sendPort);
    _toWorker = await setupPort.first as SendPort;

    // Set up a permanent reply listener
    _fromWorker = ReceivePort();
    _fromWorker!.listen((dynamic msg) {
      if (msg is _WorkResponse) {
        _pending.remove(msg.id)?.complete(msg.result);
      }
    });
  }

  Future<String> hash(String input) {
    if (_toWorker == null) throw StateError('Worker not started');
    final id = _idCounter++;
    final completer = Completer<String>();
    _pending[id] = completer;

    final replyPort = ReceivePort();
    replyPort.first.then((dynamic msg) {
      if (msg is _WorkResponse) {
        _pending.remove(msg.id)?.complete(msg.result);
      }
      replyPort.close();
    });

    _toWorker!.send(_WorkRequest(id, input, replyPort.sendPort));
    return completer.future;
  }

  void stop() {
    _toWorker?.send('shutdown');
    _fromWorker?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _toWorker = null;
  }
}
```

## Worker Pool Pattern

When you have many tasks to process in parallel, a pool of isolates gives you throughput without the per-task startup overhead.

```dart
import 'dart:async';
import 'dart:isolate';

typedef IsolateTask<T> = FutureOr<T> Function();

class IsolatePool {
  final int size;
  final _idle = <_PoolWorker>[];
  final _busy = <_PoolWorker>[];
  final _queue = Queue<_QueuedTask>();

  IsolatePool({this.size = 4});

  Future<void> start() async {
    for (var i = 0; i < size; i++) {
      final w = _PoolWorker(id: i, onComplete: _onWorkerFree);
      await w.start();
      _idle.add(w);
    }
  }

  Future<T> run<T>(IsolateTask<T> task) {
    final queued = _QueuedTask<T>(task);
    _dispatch(queued);
    return queued.completer.future;
  }

  void _dispatch(_QueuedTask task) {
    if (_idle.isEmpty) {
      _queue.add(task);
      return;
    }
    final worker = _idle.removeAt(0);
    _busy.add(worker);
    worker.execute(task);
  }

  void _onWorkerFree(_PoolWorker worker) {
    _busy.remove(worker);
    _idle.add(worker);
    if (_queue.isNotEmpty) {
      _dispatch(_queue.removeFirst());
    }
  }

  Future<void> stop() async {
    for (final w in [..._idle, ..._busy]) {
      w.stop();
    }
    _idle.clear();
    _busy.clear();
  }
}

class _PoolWorker {
  final int id;
  final void Function(_PoolWorker) onComplete;

  _PoolWorker({required this.id, required this.onComplete});

  Future<void> start() async {} // Simplified — real impl uses Isolate.spawn

  Future<void> execute(_QueuedTask task) async {
    try {
      final result = await Isolate.run(task.fn);
      task.completer.complete(result);
    } catch (e, st) {
      task.completer.completeError(e, st);
    } finally {
      onComplete(this);
    }
  }

  void stop() {}
}

class _QueuedTask<T> {
  final IsolateTask<T> fn;
  final completer = Completer<T>();
  _QueuedTask(this.fn);
}

// Usage: parallel image processing pipeline
Future<void> processImageBatch(List<Uint8List> images) async {
  final pool = IsolatePool(size: 4);
  await pool.start();

  final results = await Future.wait(
    images.map((img) => pool.run(() => toGrayscale(img))),
  );

  debugPrint('Processed ${results.length} images');
  await pool.stop();
}
```

## TransferableTypedData — Zero-Copy Large Buffers

Sending large `Uint8List` values through ports copies the bytes by default. Use `TransferableTypedData` to transfer ownership without copying:

```dart
Future<Uint8List> processLargeBuffer(Uint8List input) async {
  // Transfer without copying — input is no longer usable after this
  final transferable = TransferableTypedData.fromList([input]);

  return await Isolate.run(() {
    // Materialise on the other side
    final bytes = transferable.materialize().asUint8List();
    // Process bytes...
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = 255 - bytes[i]; // invert red channel
    }
    return bytes;
  });
}
```

## When NOT to Use Isolates

```dart
// ❌ Network I/O — async/await already handles this non-blocking
// Adding an isolate here only adds overhead and complexity
Future<String> badNetworkIsolate() {
  return Isolate.run(() async {
    final r = await http.get(Uri.parse('https://api.example.com/data'));
    return r.body; // No benefit — and http may behave differently in isolates
  });
}

// ❌ Tiny computations — isolate startup costs ~1–5ms
Future<int> wastedIsolate() => Isolate.run(() => 42 * 2);

// ❌ Shared mutable state — isolates can't share objects
// Use a SendPort/ReceivePort message protocol instead

// ✅ Good isolate candidates:
// • JSON parsing of payloads > 100 KB
// • Image / video frame processing
// • Cryptographic operations (bcrypt, argon2, AES)
// • Sorting / filtering datasets > 10,000 items
// • TFLite / ONNX inference
// • Markdown / syntax highlighting rendering
// • Compression / decompression (gzip, zstd)
```

## Choosing the Right API

| API | Use When | Dart Version | Closure Support |
|-----|----------|--------------|----------------|
| `compute()` | One-off task, Flutter target, Dart 2 compat | Flutter 1.0+ | No (top-level only) |
| `Isolate.run()` | One-off task, Dart 3 | Dart 3.0+ | Yes |
| `Isolate.spawn()` | Long-lived worker, stream of messages | Dart 2.0+ | No (top-level only) |
| Worker Pool | Many parallel tasks, controlled concurrency | Custom | Via `Isolate.run()` |

```
Decision tree:
Is the task CPU-bound and takes > ~5ms?
  └─ No  → Use plain async/await
  └─ Yes → Is it one-off?
      └─ Yes → Dart 3 available? → Isolate.run() else compute()
      └─ No  → Need bidirectional stream? → Isolate.spawn()
                Need concurrency control?  → Worker Pool
```

## Summary

Dart isolates solve a narrow but critical problem: keeping 60 fps Flutter animations smooth while doing real work in the background. The right mental model is:

- **I/O-bound** (network, file, database): `async/await` is sufficient
- **CPU-bound, one-off**: `Isolate.run()` (Dart 3) or `compute()` (Flutter)
- **CPU-bound, persistent stream**: `Isolate.spawn()` with ports
- **CPU-bound, many parallel tasks**: Worker pool built on `Isolate.run()`

The biggest mistake is reaching for isolates too eagerly. Profile first with Flutter DevTools' CPU profiler, find the actual bottleneck, then apply the minimum isolate complexity needed to fix it.

---

Have you hit a performance wall in your Flutter app that isolates solved — or made worse? I'm especially curious about experiences with the Worker Pool pattern in production. Share your story in the comments!
