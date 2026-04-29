---
title: "Dart Isolates 実践 — バックグラウンド処理・Worker Pool・compute() の使い分け"
tags: flutter,dart,個人開発,AI
published: true
---

# Dart Isolates 実践 — バックグラウンド処理・Worker Pool・compute() の使い分け

Flutter アプリがフレームをスキップしたり UI がカクついたりする原因の多くは、メインスレッドでの重い同期処理です。Dart の **Isolate** はスレッドの代わりにメモリを共有しない独立した実行コンテキストで、CPU バウンドの処理を安全にオフロードできます。本記事では `compute()`・`Isolate.run()`・`Isolate.spawn()` の使い分けから Worker Pool パターンまで、実際のコードで解説します。

## Isolate の基本概念

Dart は **シングルスレッド** のイベントループモデルです。`async/await` は I/O の待機をノンブロッキングにしますが、CPU を使う計算 (JSON パース・画像処理・暗号化) はメインの Isolate をブロックします。

```
Dart のメモリモデル:
┌─────────────────────┐    ┌─────────────────────┐
│   Main Isolate       │    │   Worker Isolate     │
│  ┌───────────────┐   │    │  ┌───────────────┐   │
│  │ Event Loop    │   │◄──►│  │ Event Loop    │   │
│  │ (Flutter UI)  │   │    │  │ (Heavy task)  │   │
│  └───────────────┘   │    │  └───────────────┘   │
│  独自のヒープ         │    │  独自のヒープ         │
└─────────────────────┘    └─────────────────────┘
      ↑ メッセージパッシングのみ (共有メモリなし)
```

## compute() — Flutter の最もシンプルな選択肢

`compute()` は Flutter が提供するユーティリティで、1回限りの計算を Isolate にオフロードする最も簡単な方法です。

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';

// Isolate で実行される関数はトップレベルまたは static である必要がある
List<Product> _parseProducts(String jsonString) {
  final list = json.decode(jsonString) as List<dynamic>;
  return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
}

class ProductRepository {
  Future<List<Product>> fetchProducts() async {
    // ネットワークリクエスト (メイン Isolate でも OK — I/O はノンブロッキング)
    final response = await http.get(Uri.parse('https://api.example.com/products'));

    // JSON パース (CPU バウンド) を別 Isolate で実行
    return compute(_parseProducts, response.body);
  }
}

// 複数引数は Map や Record でラップする
Map<String, dynamic> _filterAndSort(Map<String, dynamic> args) {
  final items = (args['items'] as List).cast<Map<String, dynamic>>();
  final query = args['query'] as String;
  final sortBy = args['sortBy'] as String;

  final filtered = items
      .where((e) => e['name'].toString().toLowerCase().contains(query.toLowerCase()))
      .toList()
    ..sort((a, b) => a[sortBy].toString().compareTo(b[sortBy].toString()));

  return {'result': filtered};
}

// 呼び出し側
final result = await compute(_filterAndSort, {
  'items': rawItems,
  'query': 'flutter',
  'sortBy': 'name',
});
```

## Isolate.run() — Dart 3 の推奨方法

Dart 3.0 で追加された `Isolate.run()` は `compute()` より汎用的で、クロージャも使えます。

```dart
import 'dart:isolate';

// 1回限りの重い計算
Future<List<String>> processLargeDataset(List<String> input) async {
  return await Isolate.run(() {
    // このクロージャは別 Isolate で実行される
    // input は自動的にコピーされる (値渡し)
    return input
        .where((s) => s.isNotEmpty)
        .map((s) => s.trim().toLowerCase())
        .toSet()
        .toList()
      ..sort();
  });
}

// より複雑な例: 画像のピクセル処理
Future<Uint8List> applyGrayscaleFilter(Uint8List imageBytes) async {
  return await Isolate.run(() {
    final bytes = Uint8List.fromList(imageBytes);
    for (var i = 0; i < bytes.length; i += 4) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      // 輝度 (BT.601 係数)
      final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
      bytes[i] = bytes[i + 1] = bytes[i + 2] = gray;
    }
    return bytes;
  });
}

// エラーハンドリングも通常通り
Future<void> exampleWithErrorHandling() async {
  try {
    final result = await Isolate.run(() {
      throw Exception('計算エラー');
    });
  } on Exception catch (e) {
    print('Isolate からの例外: $e');
  }
}
```

## Isolate.spawn() — 双方向通信の完全制御

長期間動き続けて繰り返しメッセージをやり取りするケース (音声認識・ファイル監視など) では `Isolate.spawn()` で双方向ポートを確立します。

```dart
import 'dart:isolate';

// Isolate 側のエントリポイント (トップレベル関数必須)
void _workerMain(SendPort mainSendPort) {
  final workerReceivePort = ReceivePort();

  // メイン Isolate に自分の SendPort を送る
  mainSendPort.send(workerReceivePort.sendPort);

  // メッセージを受け取り続ける
  workerReceivePort.listen((message) {
    if (message is Map<String, dynamic>) {
      final input = message['data'] as String;
      final replyPort = message['replyPort'] as SendPort;

      // 重い処理
      final result = _heavyComputation(input);
      replyPort.send(result);
    } else if (message == 'shutdown') {
      workerReceivePort.close();
    }
  });
}

String _heavyComputation(String input) {
  // CPU バウンドの処理
  return input.split('').reversed.join() * 100;
}

class PersistentWorker {
  late final Isolate _isolate;
  late final SendPort _workerSendPort;
  final _responseCompleters = <int, Completer<String>>{};
  int _nextId = 0;

  Future<void> initialize() async {
    final mainReceivePort = ReceivePort();
    _isolate = await Isolate.spawn(_workerMain, mainReceivePort.sendPort);

    // Isolate から SendPort が送られてくるまで待つ
    _workerSendPort = await mainReceivePort.first as SendPort;
  }

  Future<String> process(String input) async {
    final id = _nextId++;
    final completer = Completer<String>();
    _responseCompleters[id] = completer;

    final replyPort = ReceivePort();
    replyPort.first.then((result) {
      _responseCompleters.remove(id)?.complete(result as String);
      replyPort.close();
    });

    _workerSendPort.send({
      'id': id,
      'data': input,
      'replyPort': replyPort.sendPort,
    });

    return completer.future;
  }

  void dispose() {
    _workerSendPort.send('shutdown');
    _isolate.kill();
  }
}

// 使い方
void main() async {
  final worker = PersistentWorker();
  await worker.initialize();

  final result = await worker.process('Hello Dart Isolates');
  print(result);

  worker.dispose();
}
```

## Worker Pool パターン

複数の Isolate を並列で動かし、タスクキューを使って効率的に分散処理します。

```dart
import 'dart:async';
import 'dart:isolate';

class IsolateWorkerPool {
  final int poolSize;
  final _workers = <_Worker>[];
  final _taskQueue = <_Task>[];
  bool _initialized = false;

  IsolateWorkerPool({this.poolSize = 4});

  Future<void> initialize() async {
    if (_initialized) return;
    for (var i = 0; i < poolSize; i++) {
      final worker = _Worker(id: i);
      await worker.start();
      _workers.add(worker);
    }
    _initialized = true;
  }

  Future<T> submit<T>(Future<T> Function() task) async {
    if (!_initialized) await initialize();

    // アイドル状態のワーカーを探す
    final idleWorker = _workers.firstWhere(
      (w) => !w.isBusy,
      orElse: () => throw StateError('No idle workers'),
    );

    return idleWorker.run(task) as Future<T>;
  }

  Future<List<T>> submitAll<T>(List<Future<T> Function()> tasks) async {
    if (!_initialized) await initialize();

    final results = <Future<T>>[];
    final queue = List.of(tasks);

    while (queue.isNotEmpty) {
      final idleWorkers = _workers.where((w) => !w.isBusy).toList();
      for (final worker in idleWorkers) {
        if (queue.isEmpty) break;
        final task = queue.removeAt(0);
        results.add(worker.run(task) as Future<T>);
      }
      if (queue.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    return Future.wait(results);
  }

  Future<void> dispose() async {
    for (final worker in _workers) {
      worker.stop();
    }
    _workers.clear();
    _initialized = false;
  }
}

class _Worker {
  final int id;
  bool isBusy = false;
  Isolate? _isolate;
  SendPort? _sendPort;

  _Worker({required this.id});

  Future<void> start() async {
    final port = ReceivePort();
    _isolate = await Isolate.spawn(_workerEntry, port.sendPort);
    _sendPort = await port.first as SendPort;
  }

  Future<dynamic> run(Function task) async {
    isBusy = true;
    try {
      return await Isolate.run(task);
    } finally {
      isBusy = false;
    }
  }

  void stop() {
    _isolate?.kill(priority: Isolate.immediate);
  }
}

void _workerEntry(SendPort port) {
  final recv = ReceivePort();
  port.send(recv.sendPort);
}

// 使い方: 大量の画像を並列処理
Future<void> processImages(List<String> imagePaths) async {
  final pool = IsolateWorkerPool(poolSize: 4);
  await pool.initialize();

  final tasks = imagePaths.map((path) => () async {
    final bytes = await File(path).readAsBytes();
    return await Isolate.run(() => _resizeImage(bytes, 800, 600));
  }).toList();

  final results = await pool.submitAll(tasks);
  print('処理完了: ${results.length} 件');
  await pool.dispose();
}

Uint8List _resizeImage(Uint8List bytes, int width, int height) {
  // 画像リサイズロジック (例示)
  return bytes;
}
```

## compute() vs Isolate.run() vs Isolate.spawn() の選び方

```
選択フローチャート:

タスクは1回限り?
  └─ Yes → 軽量 (< 5ms)?
      └─ Yes → async/await で十分 (Isolate 不要)
      └─ No → クロージャが必要?
          └─ Yes → Isolate.run() (Dart 3)
          └─ No → compute() (Flutter / Dart 2 互換)
  └─ No → 双方向通信が必要?
      └─ Yes → Isolate.spawn() + SendPort/ReceivePort
      └─ No → 並列タスク多数?
          └─ Yes → Worker Pool (IsolateWorkerPool)
          └─ No → Isolate.run() を繰り返し呼ぶ
```

## Isolate を使うべきでないケース

```dart
// ❌ 誤り: ネットワークリクエストは Isolate 不要
// async/await が既にノンブロッキング
Future<void> badExample() async {
  await Isolate.run(() async {
    // Isolate 内での http リクエストは特殊な設定が必要
    // かつパフォーマンス上のメリットがない
    final result = await http.get(Uri.parse('...'));
    return result.body;
  });
}

// ❌ 誤り: 小さな計算に Isolate を使う
// Isolate の起動コストは約 1-5ms。それより短い計算は損
Future<int> tooSmall() {
  return Isolate.run(() => 1 + 1); // オーバーヘッドの無駄
}

// ✅ 正しい使い方
// - JSON パース (> 50KB)
// - 画像・動画処理
// - 暗号化・ハッシュ計算
// - 大量データのソート・フィルタ
// - 機械学習の推論 (tflite等)
```

## まとめ

| API | 用途 | Dart バージョン |
|-----|------|----------------|
| `compute()` | 1回限りの計算・Flutter 互換 | Flutter 1.0+ |
| `Isolate.run()` | 1回限り・クロージャ対応 | Dart 3.0+ |
| `Isolate.spawn()` | 長期・双方向通信 | Dart 2.0+ |
| Worker Pool | 並列・大量タスク | 自前実装 |

Isolate の最大の落とし穴は「全ての非同期処理に使おうとすること」です。ネットワーク I/O は async/await で十分。**CPU を本当に使う処理だけ** を Isolate にオフロードするのが鉄則です。

---

あなたのアプリで Isolate を使った経験はありますか？特に Worker Pool や `Isolate.spawn()` でハマった箇所があればコメントで教えてください！
