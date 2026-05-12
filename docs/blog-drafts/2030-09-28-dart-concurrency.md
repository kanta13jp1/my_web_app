---
title: "Dart 並行処理完全ガイド — Isolates・structured concurrency・async パターン"
tags: Dart,Flutter,programming,webdev
published: true
---

Dart の並行処理は独自の設計思想を持ちます。スレッドではなく Isolate、`await` ではなく `compute` で重い処理を分離する方法、そして structured concurrency を活用して安全な非同期コードを書く方法を解説します。

## Dart 並行処理の基本設計

Dart は **シングルスレッド + イベントループ** がデフォルト。メモリを共有しない独立した実行コンテキスト「Isolate」で並行処理を実現します。

| 概念 | Dart | JavaScript | Java/Kotlin |
|------|------|-----------|------------|
| 並行単位 | Isolate | Worker | Thread |
| メモリ共有 | なし (メッセージ) | なし | あり (同期必要) |
| 状態共有 | Isolate.exit/send | postMessage | synchronized |

## compute() — 最もシンプルな並行処理

```dart
// 重いJSON解析をメインスレッドから分離
Future<List<Product>> parseProductsJson(String jsonString) {
  return compute(_parseProducts, jsonString);
}

// Isolate内で実行される関数 (トップレベルまたはstaticのみ)
List<Product> _parseProducts(String jsonString) {
  final data = jsonDecode(jsonString) as List;
  return data.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
}

// 使用例
final products = await parseProductsJson(response.body);
```

`compute()` は内部で Isolate を生成・破棄するためオーバーヘッドがありますが、1回限りの重い処理には最適です。

## Isolate.spawn — 長期実行 Isolate

```dart
class BackgroundProcessor {
  late SendPort _sendPort;
  late Isolate _isolate;

  Future<void> start() async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_worker, receivePort.sendPort);
    _sendPort = await receivePort.first as SendPort;
  }

  Future<String> process(String data) {
    final responsePort = ReceivePort();
    _sendPort.send([data, responsePort.sendPort]);
    return (responsePort.first as Future<dynamic>).then((v) => v as String);
  }

  void stop() {
    _isolate.kill(priority: Isolate.immediate);
  }

  // Isolate 内で実行されるエントリーポイント
  static void _worker(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      final [String data, SendPort replyPort] = message as List;
      final result = _heavyProcessing(data);
      replyPort.send(result);
    });
  }

  static String _heavyProcessing(String data) {
    // CPU集中型の処理
    return data.split('').reversed.join();
  }
}
```

## Structured Concurrency — Future.wait と CancellationToken

### 並列実行と失敗ハンドリング

```dart
// 全部成功を待つ
final [users, posts, comments] = await Future.wait([
  fetchUsers(),
  fetchPosts(),
  fetchComments(),
]);

// エラーがあっても全部待つ
final results = await Future.wait(
  [fetchA(), fetchB(), fetchC()],
  eagerError: false,  // 1つ失敗しても他を継続
);

// タイムアウト付き
final data = await fetchData().timeout(
  const Duration(seconds: 10),
  onTimeout: () => throw TimeoutException('Request timed out'),
);
```

### CancellationToken パターン (Dart 3+)

```dart
class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

Future<List<SearchResult>> searchWithCancel(
  String query,
  CancellationToken token,
) async {
  final results = <SearchResult>[];
  
  for (final source in _dataSources) {
    if (token.isCancelled) break;
    final partial = await source.search(query);
    results.addAll(partial);
  }
  
  return results;
}

// 使用側でキャンセル
final token = CancellationToken();
final searchFuture = searchWithCancel(query, token);

// 新しい検索開始時に前の検索をキャンセル
onQueryChanged: (newQuery) {
  token.cancel();
  // 新しいトークンで再実行
}
```

## Stream — リアクティブな非同期処理

```dart
// StreamController でカスタムストリーム
class LivePriceService {
  final _controller = StreamController<double>.broadcast();
  Timer? _timer;

  Stream<double> get priceStream => _controller.stream;

  void start(String symbol) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final price = await _fetchPrice(symbol);
      if (!_controller.isClosed) _controller.add(price);
    });
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

// Flutter ウィジェットでの使用
StreamBuilder<double>(
  stream: _priceService.priceStream,
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();
    return Text('¥${snapshot.data!.toStringAsFixed(2)}');
  },
)
```

## async* / yield — 非同期ジェネレータ

```dart
Stream<int> countdown(int from) async* {
  for (int i = from; i >= 0; i--) {
    yield i;
    await Future.delayed(const Duration(seconds: 1));
  }
}

// 使用
await for (final count in countdown(10)) {
  print('$count...');
}
```

## Flutter Web での注意点

Flutter Web は Isolate をサポートしていますが、ブラウザ環境では Web Workers にマッピングされます。`compute()` は Flutter Web でも動作しますが、デバッグビルドではパフォーマンスが異なります。

```dart
// Web では kIsWeb チェックが有用
if (kIsWeb) {
  // Web Workers の制約: Uint8List など限られた型のみ送受信可
  final result = await compute(_processData, data);
} else {
  // Native: 任意のオブジェクト送受信可
  final isolate = await Isolate.spawn(...);
}
```

## まとめ

Dart の並行処理は「Isolate = 安全なメモリ分離」「Stream = リアクティブなデータフロー」「async/await = 読みやすい非同期コード」の3本柱です。重い処理は `compute()`、長期実行は `Isolate.spawn`、リアルタイム更新は `Stream` という使い分けを覚えておきましょう。
