---
title: "Dart 並行処理完全ガイド — Isolate・compute・Stream・Mutex の実践パターン"
tags: flutter,dart,個人開発,AI
published: true
---

# Dart 並行処理完全ガイド — Isolate・compute・Stream・Mutex の実践パターン

Flutter アプリの UI がカクつく原因の多くは、**メインスレッドをブロックする重い処理**です。Dart の並行処理モデルを正しく理解して使いこなせば、滑らかな 60fps を維持しながら大量のデータ処理が可能になります。

## Dart のシングルスレッドモデルとイベントループ

Dart は基本的に**シングルスレッド**で動作します。ただし非同期処理（`async`/`await`）を使うことで、I/O 待ちの間に他の処理を進める**イベントループ**ベースの並行性が実現できます。

重要な区別:
- **非同期 (async/await)**: 待ち時間を有効活用するが、同時に 2 つの Dart コードは実行しない
- **並行 (Isolate)**: 別スレッドで本当に同時実行する。UI スレッドをブロックしない

CPU バウンドな処理（JSON デコード、画像変換、暗号化など）は必ず Isolate に逃がす必要があります。

## compute() — 最もシンプルな Isolate の使い方

Flutter が提供する `compute()` 関数は、最上位関数または静的関数を別 Isolate で実行するショートカットです。

```dart
// トップレベル関数として定義（クロージャは渡せない点に注意）
List<Product> _parseProducts(String jsonStr) {
  final list = jsonDecode(jsonStr) as List;
  return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
}

class ProductRepository {
  Future<List<Product>> fetchProducts() async {
    final response = await http.get(Uri.parse('https://api.example.com/products'));
    // メインスレッドをブロックせずに JSON デコード
    return compute(_parseProducts, response.body);
  }
}
```

`compute()` の制約: 引数として渡せるのは `SendPort` でシリアライズ可能な型のみ（プリミティブ、List, Map, Uint8List など）。クロージャや `BuildContext` は渡せません。

## Isolate.spawn() で双方向通信

長期間動作する Isolate や、複数回メッセージを交換する場合は `Isolate.spawn()` と `SendPort`/`ReceivePort` を直接使います。

```dart
class HeavyProcessor {
  late Isolate _isolate;
  late SendPort _sendPort;
  late ReceivePort _receivePort;

  Future<void> start() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_worker, _receivePort.sendPort);

    // 最初のメッセージは Isolate の SendPort を受け取る
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

  // Isolate 内で動く関数（トップレベル or static）
  static void _worker(SendPort mainSendPort) {
    final workerReceivePort = ReceivePort();
    mainSendPort.send(workerReceivePort.sendPort);

    workerReceivePort.listen((message) {
      final args = message as List;
      final input = args[0] as String;
      final replyPort = args[1] as SendPort;

      // 重い処理をここで実行
      final result = _heavyCompute(input);
      replyPort.send(result);
    });
  }

  static String _heavyCompute(String input) {
    // 例: 圧縮・暗号化・機械学習推論 etc.
    return input.toUpperCase(); // 実際は重い処理
  }
}
```

## TransferableTypedData でゼロコピー転送

画像のピクセルバッファなど大きな `Uint8List` を Isolate 間で送受信する場合、通常はコピーが発生してメモリを 2 倍消費します。`TransferableTypedData` を使うとコピーなしで所有権を移譲できます。

```dart
// 送信側（メインスレッド）
final pixels = image.buffer.asUint8List();
final transferable = TransferableTypedData.fromList([pixels]);
sendPort.send(transferable);
// この時点で pixels は無効化される（所有権が移った）

// 受信側（Isolate）
receivePort.listen((message) {
  final data = (message as TransferableTypedData).materialize().asUint8List();
  // data を処理...
});
```

## Stream の非同期変換 — map / where / asyncMap

`Stream` は時系列データの処理に最適です。変換チェーンを組み合わせてリアクティブなパイプラインを構築できます。

```dart
final Stream<String> rawEvents = _controller.stream;

final processedStream = rawEvents
  .where((event) => event.isNotEmpty)             // 空のイベントを除外
  .map((event) => event.trim())                   // 同期変換
  .asyncMap((event) => _classify(event))          // 非同期変換（API 呼び出しなど）
  .distinct();                                     // 重複を除去

// 非同期変換の例
Future<ClassifiedEvent> _classify(String raw) async {
  final label = await aiApi.classify(raw);
  return ClassifiedEvent(raw: raw, label: label);
}
```

`asyncMap` はアップストリームが次の値を発行しても前の Future が完了するまで待機します。順序が保証されるため、API レート制限がある場合に便利です。

## Mutex の実装 — synchronized パッケージ

Isolate ではなく同一スレッド内で共有リソースへの競合アクセスを制御したい場合は `synchronized` パッケージを使います。

```dart
import 'package:synchronized/synchronized.dart';

class CacheManager {
  final _lock = Lock();
  final Map<String, String> _cache = {};

  Future<String> getOrFetch(String key) async {
    // 同じ key に対する並行 fetch が複数起きても安全
    return _lock.synchronized(() async {
      if (_cache.containsKey(key)) return _cache[key]!;

      final value = await _fetchFromNetwork(key);
      _cache[key] = value;
      return value;
    });
  }
}
```

## Flutter での実践例 — 画像処理と JSON デコード

```dart
// 実践パターン: 大きな画像を Isolate でリサイズ
Future<Uint8List> resizeImageInBackground(Uint8List original) async {
  return compute(_resizeImage, original);
}

Uint8List _resizeImage(Uint8List bytes) {
  final codec = img.decodeImage(bytes)!;
  final resized = img.copyResize(codec, width: 300);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}

// 実践パターン: API レスポンスの大きな JSON を Isolate でパース
Future<DashboardData> loadDashboard() async {
  final res = await supabase.functions.invoke('get-home-dashboard');
  return compute(_parseDashboard, jsonEncode(res.data));
}

DashboardData _parseDashboard(String jsonStr) {
  return DashboardData.fromJson(jsonDecode(jsonStr));
}
```

## まとめ

| 用途 | 推奨手段 |
|------|---------|
| 1 回限りの CPU バウンド処理 | `compute()` |
| 長期間動く専用ワーカー | `Isolate.spawn()` |
| 大きなバッファのゼロコピー転送 | `TransferableTypedData` |
| 時系列データの変換パイプライン | `Stream` + `asyncMap` |
| 同一スレッド内の排他制御 | `synchronized` パッケージ |

Dart の並行処理は「重い処理をメインスレッドから切り離す」ことが第一歩。まず `compute()` で始めて、双方向通信が必要になったら `Isolate.spawn()` に進化させましょう。
