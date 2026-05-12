---
title: "Flutter Isolate & Compute 完全ガイド — バックグラウンド処理でUI を滑らかに保つ"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter Isolate & Compute 完全ガイド — バックグラウンド処理でUI を滑らかに保つ

Flutter は単一スレッド (Dart VM) で動作するため、重い処理をメインスレッドで実行するとUIがカクつきます。Isolate と compute を使えば、バックグラウンドスレッドで重い処理を実行し、60fps を維持できます。

## Dart の並行モデル

Dart は Isolate ベースの並行処理:

- **メイン Isolate**: UIレンダリング + ユーザー操作
- **追加 Isolate**: 重い計算 / JSON解析 / 画像処理 など
- **Isolate 間通信**: `SendPort` / `ReceivePort` でメッセージパッシング
- **メモリ共有なし**: 各 Isolate は独立したメモリ空間

## compute() — 最もシンプルなバックグラウンド処理

```dart
// 重いJSON解析をバックグラウンドで実行
Future<List<Product>> parseProducts(String jsonString) async {
  return compute(_parseProductsIsolate, jsonString);
}

// Isolate 内で実行される関数 (top-level or static)
List<Product> _parseProductsIsolate(String jsonString) {
  final List<dynamic> data = jsonDecode(jsonString);
  return data.map((json) => Product.fromJson(json)).toList();
}

// 使用例
class ProductListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Product>>(
      future: _loadProducts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, i) => ProductTile(snapshot.data![i]),
        );
      },
    );
  }

  Future<List<Product>> _loadProducts() async {
    final response = await http.get(Uri.parse('https://api.example.com/products'));
    return compute(_parseProductsIsolate, response.body);
  }
}
```

## Isolate.run() — Flutter 2.15+ の新 API

```dart
// 画像フィルタリングをバックグラウンドで実行
Future<Uint8List> applyFilter(Uint8List imageBytes) async {
  return Isolate.run(() {
    // この関数はバックグラウンド Isolate で実行される
    return _applyGrayscaleFilter(imageBytes);
  });
}

Uint8List _applyGrayscaleFilter(Uint8List bytes) {
  // 重いピクセル操作
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

## 長時間実行 Isolate (SendPort / ReceivePort)

```dart
// 継続的にデータを処理する Isolate
class DataProcessor {
  late Isolate _isolate;
  late SendPort _sendPort;
  final _receivePort = ReceivePort();

  Future<void> start() async {
    _isolate = await Isolate.spawn(
      _processorIsolate,
      _receivePort.sendPort,
    );

    // Isolate から最初のメッセージで SendPort を受け取る
    _sendPort = await _receivePort.first as SendPort;
  }

  // データを Isolate に送信してレスポンスを待つ
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

// Isolate 内で動く関数
void _processorIsolate(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    final data = message[0] as RawData;
    final replyPort = message[1] as SendPort;

    // 重い処理
    final result = _heavyProcessing(data);
    replyPort.send(result);
  });
}
```

## Riverpod + Isolate で非同期データ管理

```dart
@riverpod
Future<AnalysisResult> analyzeData(Ref ref, String rawData) async {
  // バックグラウンドで解析
  return Isolate.run(() => _performAnalysis(rawData));
}

// UI側
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

## パフォーマンス計測

```dart
// compute vs 同期処理の比較
Future<void> benchmarkCompute() async {
  const iterations = 1000;
  final testData = List.generate(iterations, (i) => {'id': i, 'value': 'test$i'});
  final jsonString = jsonEncode(testData);

  // 同期処理
  final syncStart = DateTime.now();
  jsonDecode(jsonString); // メインスレッドをブロック
  final syncDuration = DateTime.now().difference(syncStart);

  // compute で非同期処理
  final asyncStart = DateTime.now();
  await compute(jsonDecode, jsonString); // バックグラウンドで実行
  final asyncDuration = DateTime.now().difference(asyncStart);

  print('Sync: ${syncDuration.inMilliseconds}ms');
  print('Async: ${asyncDuration.inMilliseconds}ms');
}
```

## どのAPIを使うか

| シナリオ | 推奨API |
| --- | --- |
| 1回限りの重い処理 | `compute()` or `Isolate.run()` |
| 複数回処理 (都度起動) | `Isolate.run()` |
| 継続的なストリーム処理 | `SendPort` / `ReceivePort` |
| 小さな非同期処理 | `async` / `await` で十分 |

**目安**: 実行時間 16ms 以下 → async/await のみ。16ms 超 → Isolate 検討。

## まとめ

Flutter の Isolate / compute で:

- **UIフリーズなし**で重い処理を実行
- **60fps 維持**でスムーズなユーザー体験
- **compute()**: シンプルな1回限りの処理に最適
- **Isolate.run()**: Flutter 2.15+ 向けシンプルAPI
- **SendPort/ReceivePort**: 長時間・継続処理に

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
