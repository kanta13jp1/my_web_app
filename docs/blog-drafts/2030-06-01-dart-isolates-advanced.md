---
title: "Dart Isolate 完全ガイド — compute・SendPort・並列処理パターン"
tags: dart,flutter,個人開発,AI
published: true
---

# Dart Isolate 完全ガイド — compute・SendPort・並列処理パターン

Dart はメインスレッドがシングルスレッドのイベントループで動く言語です。重い処理をメインスレッドで実行すると UI がフリーズする。Isolate は Dart の並列処理の答えであり、スレッドとは異なる「メモリ共有なし」の設計が特徴です。

## なぜ Isolate が必要か

```dart
// これをメインスレッドで実行すると UI が 3 秒間止まる
List<int> heavySort(List<int> data) {
  data.sort(); // O(n log n) でも 10M件なら数秒かかる
  return data;
}
```

`async/await` は並列化ではなく非同期化。CPU バウンドな処理には Isolate が必要。

## compute(): 最もシンプルな Isolate

```dart
// Flutter の compute() — 関数を別 Isolate で実行
Future<List<int>> sortInBackground(List<int> data) {
  return compute(_sortData, data);
}

// トップレベル関数 or static メソッドのみ渡せる
List<int> _sortData(List<int> data) {
  data.sort();
  return data;
}

// 使用例
final sorted = await sortInBackground(bigList);
```

`compute()` は単発の重い処理向け。引数は1つのみ (複数なら Map か Record で包む)。

## Isolate.run(): Dart 2.19+ の改善版 compute

```dart
// Dart 2.19 以降: compute() より表現力が高い
Future<String> parseJsonInBackground(String jsonStr) async {
  return Isolate.run(() {
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    return decoded['title'] as String;
  });
}

// クロージャが使えるため外部変数をキャプチャ可能 (コピーされる)
Future<int> processWithConfig(List<int> data, Config config) async {
  return Isolate.run(() => _process(data, config));
}
```

`Isolate.run()` はクロージャをサポートするため、引数の制約がない。

## SendPort / ReceivePort: 双方向通信

```dart
// 長時間動き続ける Isolate との双方向チャネル
Future<void> startLongRunningIsolate() async {
  final receivePort = ReceivePort();

  await Isolate.spawn(_longRunningTask, receivePort.sendPort);

  // Isolate からのメッセージを受信
  receivePort.listen((message) {
    if (message is Map) {
      print('進捗: ${message['progress']}%');
    } else if (message == 'done') {
      receivePort.close();
    }
  });
}

void _longRunningTask(SendPort sendPort) {
  for (int i = 0; i <= 100; i += 10) {
    // 重い処理...
    _doHeavyWork();
    sendPort.send({'progress': i});
  }
  sendPort.send('done');
}
```

## 双方向通信パターン (Worker Isolate)

```dart
class IsolateWorker {
  late Isolate _isolate;
  late SendPort _sendPort;
  final _receivePort = ReceivePort();
  final _completers = <int, Completer<dynamic>>{};
  int _messageId = 0;

  Future<void> init() async {
    _isolate = await Isolate.spawn(_worker, _receivePort.sendPort);
    _receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
      } else if (message is Map) {
        final id = message['id'] as int;
        final result = message['result'];
        _completers[id]?.complete(result);
        _completers.remove(id);
      }
    });
    // Worker の SendPort が届くまで待機
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 10));
      return !_completers.containsKey(-1); // hack: 初期化完了チェック
    });
  }

  Future<T> send<T>(dynamic data) {
    final id = _messageId++;
    final completer = Completer<T>();
    _completers[id] = completer;
    _sendPort.send({'id': id, 'data': data});
    return completer.future;
  }

  void dispose() {
    _isolate.kill();
    _receivePort.close();
  }

  static void _worker(SendPort mainSendPort) {
    final workerPort = ReceivePort();
    mainSendPort.send(workerPort.sendPort);

    workerPort.listen((message) {
      if (message is Map) {
        final id = message['id'] as int;
        final data = message['data'];
        final result = _processData(data); // 重い処理
        mainSendPort.send({'id': id, 'result': result});
      }
    });
  }

  static dynamic _processData(dynamic data) {
    // 実際の重い処理をここで
    return data;
  }
}
```

## データ転送の最適化: TransferableTypedData

```dart
// 大きな Uint8List を Isolate に渡す場合
// デフォルト: コピー (遅い)
sendPort.send(largeUint8List); // コピーコスト O(n)

// TransferableTypedData: ゼロコピー転送
final transferable = TransferableTypedData.fromList([largeUint8List]);
sendPort.send(transferable); // O(1)

// 受信側で復元
final received = message as TransferableTypedData;
final data = received.materialize().asUint8List();
```

10MB 超の画像・音声データを扱う場合は `TransferableTypedData` 必須。

## 実用例: 画像処理 Isolate

```dart
// メインスレッドをブロックせずに画像をグレースケール化
Future<Uint8List> toGrayscale(Uint8List imageBytes) async {
  return Isolate.run(() {
    final image = img.decodeImage(imageBytes)!;
    final gray = img.grayscale(image);
    return Uint8List.fromList(img.encodePng(gray));
  });
}

// 使用例 (UI スレッドで呼んでもフリーズしない)
final grayBytes = await toGrayscale(originalBytes);
setState(() => _displayBytes = grayBytes);
```

## JSON デコード: いつ Isolate を使うか

```dart
// 目安: 1MB 未満 → メインスレッドで OK
// 1MB 超 → Isolate に移す

final json = response.body;
final data = json.length > 1024 * 1024
    ? await Isolate.run(() => jsonDecode(json))
    : jsonDecode(json);
```

過度な Isolate 使用は Spawn コスト (約 15ms) と通信コストが積み上がる。小さいデータに使わない。

## Flutter の BackgroundIsolateBinaryMessenger (Flutter 3.7+)

```dart
// Flutter 3.7 以降: Isolate から Platform Channel を呼べる
void _isolateTask(RootIsolateToken token) {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  // これ以降、Platform Channel が使える
  final channel = MethodChannel('com.example/native');
  channel.invokeMethod('doNativeWork');
}

// 起動時に Token を渡す
final token = RootIsolateToken.instance!;
await Isolate.spawn(_isolateTask, token);
```

## まとめ

| 用途 | 推奨API | 特徴 |
|------|---------|------|
| 単発の重い処理 | `Isolate.run()` | シンプル・クロージャ対応 |
| Flutter での単発処理 | `compute()` | Flutter 既製品 |
| 常駐 Worker | `Isolate.spawn` + `SendPort` | 双方向通信 |
| 大容量データ転送 | `TransferableTypedData` | ゼロコピー |

Dart の Isolate は「共有なき並列」を徹底することで、競合状態 (race condition) やデッドロックから解放してくれる。メモリ共有の複雑さなしに CPU バウンドな処理をオフロードできる点が最大の強みです。
