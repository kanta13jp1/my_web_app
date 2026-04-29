---
title: "Dart 非同期プログラミング深掘り — Future・Stream・Isolate を完全理解する"
tags: flutter,dart,個人開発,AI
published: true
---

# Dart 非同期プログラミング深掘り — Future・Stream・Isolate を完全理解する

Dart の非同期機能は表面的には `async/await` だけに見えますが、その下には Future・Stream・Isolate の 3 層構造があります。本記事で完全に理解します。

## Future — 単一の非同期値

```dart
// 基本
Future<String> fetchUser(String id) async {
  final response = await http.get(Uri.parse('/users/$id'));
  return response.body;
}

// エラーハンドリング
Future<User> safeGetUser(String id) async {
  try {
    return await userRepo.get(id);
  } on NotFoundException {
    throw UserNotFoundError(id);
  } catch (e, stack) {
    log.error('Unexpected error', error: e, stackTrace: stack);
    rethrow;
  }
}

// 並列実行 — await を連続させると直列になるので注意
// ❌ 直列 (2秒 + 1秒 = 3秒)
final user = await getUser();
final prefs = await getPrefs();

// ✅ 並列 (max(2秒, 1秒) = 2秒)
final results = await Future.wait([getUser(), getPrefs()]);
final user = results[0] as User;
final prefs = results[1] as Prefs;

// タイムアウト付き
final data = await fetchData().timeout(
  const Duration(seconds: 10),
  onTimeout: () => throw TimeoutException('Request timed out'),
);
```

## Future チェーン

```dart
// then / catchError (古いスタイル)
fetchUser(id)
  .then((user) => fetchPosts(user.id))
  .then((posts) => displayPosts(posts))
  .catchError((e) => showError(e));

// async/await (推奨)
final user = await fetchUser(id);
final posts = await fetchPosts(user.id);
displayPosts(posts);
```

## Stream — 複数値の非同期シーケンス

```dart
// Stream 作成
Stream<int> countDown(int from) async* {
  for (int i = from; i >= 0; i--) {
    yield i;
    await Future.delayed(const Duration(seconds: 1));
  }
}

// 消費
await for (final count in countDown(10)) {
  print(count);
}

// StreamController — 手動制御
final controller = StreamController<String>();

// データ追加
controller.add('hello');
controller.add('world');
controller.close();

// 購読
controller.stream.listen(
  (data) => print(data),
  onError: (e) => print('error: $e'),
  onDone: () => print('closed'),
);
```

### StreamBuilder (Flutter UI)

```dart
StreamBuilder<List<Message>>(
  stream: supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('created_at'),
  builder: (context, snapshot) {
    if (snapshot.hasError) return ErrorView(error: snapshot.error!);
    if (!snapshot.hasData) return const CircularProgressIndicator();
    return MessageList(messages: snapshot.data!);
  },
)
```

### Stream 変換

```dart
final stream = someStream
    .where((value) => value > 0)          // フィルター
    .map((value) => value * 2)            // 変換
    .distinct()                           // 重複除去
    .debounceTime(const Duration(ms: 300)) // デバウンス (rxdart)
    .take(10);                            // 最初の10件のみ
```

## Isolate — 真の並列処理

Dart はシングルスレッドですが、Isolate で別スレッドを起動できます。UI をブロックする重い処理に使います。

```dart
// compute() — シンプルな並列処理 (Flutter の高レベル API)
final result = await compute(parseJsonInBackground, largeJsonString);

String parseJsonInBackground(String json) {
  // この関数は別 Isolate で実行 → UI ブロックなし
  return expensive_parse(json);
}
```

```dart
// Isolate.run() — Dart 2.19+
final result = await Isolate.run(() {
  return expensiveCalculation(data);
});
```

```dart
// 双方向通信 (高度な使い方)
Future<void> runWithIsolate() async {
  final receivePort = ReceivePort();

  final isolate = await Isolate.spawn(
    _workerIsolate,
    receivePort.sendPort,
  );

  final sendPort = await receivePort.first as SendPort;

  final response = ReceivePort();
  sendPort.send(['process', largeData, response.sendPort]);
  final result = await response.first;

  isolate.kill();
}

void _workerIsolate(SendPort mainPort) {
  final port = ReceivePort();
  mainPort.send(port.sendPort);

  port.listen((message) {
    final [action, data, SendPort replyTo] = message as List;
    if (action == 'process') {
      replyTo.send(processData(data));
    }
  });
}
```

## いつ何を使うか

| 処理 | 推奨 |
|---|---|
| API 呼び出し・DB クエリ | `Future` + `async/await` |
| リアルタイムデータ・WebSocket | `Stream` + `StreamBuilder` |
| 重い JSON パース (>1MB) | `compute()` / `Isolate.run()` |
| 画像処理・音声解析 | `Isolate` (双方向通信) |
| UI アニメーション | メインスレッドで `Timer` |

非同期を正しく理解すると、「なぜ UI がカクつくのか」がすぐわかるようになります。Isolate を使いすぎるとオーバーヘッドが増えるので、まず `compute()` で測定してから最適化しましょう。

---

Dart の非同期で詰まった経験はありますか？よくある落とし穴をコメントで教えてください！
