---
title: "Flutter Isolates & Compute Complete Guide — Keep Your UI Smooth with Background Processing"
tags: flutter,dart,ai,indiedev
published: true
---

# Flutter Isolates & Compute Complete Guide — Keep Your UI Smooth with Background Processing

Flutter runs on a single thread (Dart VM). Heavy work on the main thread drops frames and freezes your UI. Isolates and `compute` let you run expensive operations in the background while keeping 60fps.

## Dart's Concurrency Model

Dart uses Isolate-based concurrency:

- **Main Isolate**: UI rendering + user input
- **Spawned Isolates**: Heavy computation, JSON parsing, image processing
- **Communication**: Message passing via `SendPort` / `ReceivePort`
- **No shared memory**: Each Isolate has its own heap

## compute() — The Simplest Option

```dart
// Parse large JSON in the background
Future<List<Product>> parseProducts(String jsonString) async {
  return compute(_parseProductsIsolate, jsonString);
}

// Must be top-level or static
List<Product> _parseProductsIsolate(String jsonString) {
  final List<dynamic> data = jsonDecode(jsonString);
  return data.map((json) => Product.fromJson(json)).toList();
}

// Usage
Future<List<Product>> _loadProducts() async {
  final response = await http.get(Uri.parse('https://api.example.com/products'));
  return compute(_parseProductsIsolate, response.body);
}
```

## Isolate.run() — Flutter 2.15+ Clean API

```dart
// Apply image filter in background
Future<Uint8List> applyFilter(Uint8List imageBytes) async {
  return Isolate.run(() => _applyGrayscaleFilter(imageBytes));
}

Uint8List _applyGrayscaleFilter(Uint8List bytes) {
  final img = decodeImage(bytes)!;
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      final pixel = img.getPixel(x, y);
      final gray = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114).toInt();
      img.setPixel(x, y, ColorRgb8(gray, gray, gray));
    }
  }
  return Uint8List.fromList(encodeJpg(img));
}
```

## Long-Running Isolate (SendPort / ReceivePort)

```dart
class DataProcessor {
  late Isolate _isolate;
  late SendPort _sendPort;
  final _receivePort = ReceivePort();

  Future<void> start() async {
    _isolate = await Isolate.spawn(_processorIsolate, _receivePort.sendPort);
    _sendPort = await _receivePort.first as SendPort;
  }

  Future<ProcessedData> process(RawData data) async {
    final responsePort = ReceivePort();
    _sendPort.send([data, responsePort.sendPort]);
    return await responsePort.first as ProcessedData;
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
    _receivePort.close();
  }
}

void _processorIsolate(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    final data = message[0] as RawData;
    final replyPort = message[1] as SendPort;
    replyPort.send(_heavyProcessing(data));
  });
}
```

## Riverpod + Isolate

```dart
@riverpod
Future<AnalysisResult> analyzeData(Ref ref, String rawData) async {
  return Isolate.run(() => _performAnalysis(rawData));
}

class AnalysisPage extends ConsumerWidget {
  final String data;
  const AnalysisPage(this.data);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(analyzeDataProvider(data));

    return switch (result) {
      AsyncData(:final value) => ResultDisplay(value),
      AsyncError(:final error) => ErrorWidget(message: error.toString()),
      AsyncLoading() => const CircularProgressIndicator(),
    };
  }
}
```

## Benchmark: compute vs Synchronous

```dart
Future<void> benchmarkCompute() async {
  const iterations = 1000;
  final testData = List.generate(iterations, (i) => {'id': i, 'value': 'test$i'});
  final jsonString = jsonEncode(testData);

  // Synchronous — blocks main thread
  final syncStart = DateTime.now();
  jsonDecode(jsonString);
  final syncDuration = DateTime.now().difference(syncStart);

  // compute — runs in background
  final asyncStart = DateTime.now();
  await compute(jsonDecode, jsonString);
  final asyncDuration = DateTime.now().difference(asyncStart);

  print('Sync: ${syncDuration.inMilliseconds}ms');
  print('Async: ${asyncDuration.inMilliseconds}ms');
}
```

## Which API to Use

| Scenario | Recommended |
| --- | --- |
| One-shot heavy task | `compute()` or `Isolate.run()` |
| Repeated per-call tasks | `Isolate.run()` |
| Continuous stream processing | `SendPort` / `ReceivePort` |
| Short async operations | `async` / `await` is enough |

**Rule of thumb**: Under 16ms → async/await. Over 16ms → consider an Isolate.

## Summary

Flutter Isolates and `compute` give you:

- **Zero UI jank** from heavy background operations
- **Consistent 60fps** for a smooth user experience
- `compute()` for simple one-shot tasks
- `Isolate.run()` for the cleanest modern API
- `SendPort`/`ReceivePort` for long-running or streaming workloads

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
