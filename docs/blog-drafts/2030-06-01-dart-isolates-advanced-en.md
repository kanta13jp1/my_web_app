---
title: "Dart Isolates Deep Dive — compute, SendPort, and Parallel Processing Patterns"
tags: dart,flutter,webdev,indiedev
published: true
---

# Dart Isolates Deep Dive — compute, SendPort, and Parallel Processing Patterns

Dart's main thread runs on a single-threaded event loop. CPU-heavy work blocks that loop, freezing your UI. Isolates are Dart's answer to parallelism — and their "no shared memory" design eliminates entire classes of bugs that plague threaded systems.

## Why Isolates?

```dart
// This blocks the UI thread for seconds on large datasets
List<int> heavySort(List<int> data) {
  data.sort();
  return data;
}
```

`async/await` is *concurrency* (cooperative scheduling), not *parallelism* (true simultaneous execution). CPU-bound work requires Isolates.

## compute(): Simplest Entry Point

```dart
Future<List<int>> sortInBackground(List<int> data) {
  return compute(_sortData, data); // runs in a new Isolate
}

// Must be a top-level or static function
List<int> _sortData(List<int> data) {
  data.sort();
  return data;
}

final sorted = await sortInBackground(bigList); // UI stays responsive
```

`compute()` accepts exactly one argument. Wrap multiple values in a `Record` or `Map`.

## Isolate.run(): Modern compute() (Dart 2.19+)

```dart
// Closures work — captures are copied to the new Isolate
Future<String> parseTitle(String jsonStr) async {
  return Isolate.run(() {
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    return decoded['title'] as String;
  });
}

Future<int> processWithConfig(List<int> data, Config config) async {
  return Isolate.run(() => _process(data, config));
}
```

Prefer `Isolate.run()` over `compute()` for new code. It's more expressive and handles closures.

## SendPort / ReceivePort: Bidirectional Channels

```dart
// Long-running Isolate with progress reporting
Future<void> startWorker() async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_longRunningTask, receivePort.sendPort);

  receivePort.listen((message) {
    if (message is Map) {
      print('Progress: ${message['progress']}%');
    } else if (message == 'done') {
      receivePort.close();
    }
  });
}

void _longRunningTask(SendPort sendPort) {
  for (int i = 0; i <= 100; i += 10) {
    _doHeavyWork();
    sendPort.send({'progress': i});
  }
  sendPort.send('done');
}
```

## Persistent Worker Isolate Pattern

```dart
class IsolateWorker {
  late SendPort _toIsolate;
  final _fromIsolate = ReceivePort();
  final _pending = <int, Completer<dynamic>>{};
  int _nextId = 0;
  late Isolate _isolate;

  Future<void> init() async {
    final ready = Completer<void>();
    _fromIsolate.listen((msg) {
      if (msg is SendPort) {
        _toIsolate = msg;
        ready.complete();
      } else if (msg is ({int id, dynamic result})) {
        _pending[msg.id]?.complete(msg.result);
        _pending.remove(msg.id);
      }
    });
    _isolate = await Isolate.spawn(_worker, _fromIsolate.sendPort);
    await ready.future;
  }

  Future<T> call<T>(dynamic data) {
    final id = _nextId++;
    final c = Completer<T>();
    _pending[id] = c;
    _toIsolate.send((id: id, data: data));
    return c.future;
  }

  void dispose() {
    _isolate.kill();
    _fromIsolate.close();
  }

  static void _worker(SendPort main) {
    final port = ReceivePort();
    main.send(port.sendPort);
    port.listen((msg) {
      if (msg is ({int id, dynamic data})) {
        final result = _process(msg.data);
        main.send((id: msg.id, result: result));
      }
    });
  }

  static dynamic _process(dynamic data) => data; // replace with real work
}
```

## Zero-Copy Transfers: TransferableTypedData

```dart
// Default: copy (slow for large buffers)
sendPort.send(largeUint8List);      // O(n) copy cost

// TransferableTypedData: zero-copy transfer
final transferable = TransferableTypedData.fromList([largeUint8List]);
sendPort.send(transferable);         // O(1)

// Receiving side
final received = message as TransferableTypedData;
final data = received.materialize().asUint8List();
```

Use `TransferableTypedData` for image/audio buffers above ~1 MB. The performance difference is dramatic.

## Real Example: Background Image Processing

```dart
import 'package:image/image.dart' as img;

Future<Uint8List> toGrayscale(Uint8List imageBytes) async {
  return Isolate.run(() {
    final image = img.decodeImage(imageBytes)!;
    return Uint8List.fromList(img.encodePng(img.grayscale(image)));
  });
}

// Called from UI — no jank
final grayBytes = await toGrayscale(originalBytes);
setState(() => _displayBytes = grayBytes);
```

## When NOT to Use Isolates

```dart
// Spawn cost ~15ms + serialization cost — not worth it for small data
final decoded = json.length > 1024 * 1024     // only above ~1MB
    ? await Isolate.run(() => jsonDecode(json))
    : jsonDecode(json);                          // fast enough on main thread
```

Over-using Isolates adds latency. Profile before parallelizing.

## Flutter 3.7+: Platform Channels from Isolates

```dart
// Before 3.7: calling Platform Channels from an Isolate crashed
// After 3.7: pass a RootIsolateToken
void _isolateTask((RootIsolateToken, SendPort) args) {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.$1);
  // Platform Channels work now
  MethodChannel('com.example/native').invokeMethod('doNativeWork');
}

final token = RootIsolateToken.instance!;
await Isolate.spawn(_isolateTask, (token, sendPort));
```

## Summary

| Use Case | Recommended API | Notes |
|----------|----------------|-------|
| One-shot heavy work | `Isolate.run()` | Simplest, closure support |
| Flutter one-shot | `compute()` | Convenience wrapper |
| Persistent worker | `Isolate.spawn` + `SendPort` | Bidirectional channel |
| Large buffer transfer | `TransferableTypedData` | Zero-copy |

Dart Isolates enforce "share nothing" parallelism. You give up easy shared state and gain freedom from race conditions and deadlocks. For CPU-bound work in Flutter apps, that's an excellent trade.
