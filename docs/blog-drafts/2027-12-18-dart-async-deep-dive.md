---
title: "Dart 非同期プログラミング完全ガイド — Future / Stream / Isolate"
tags: flutter,AI,個人開発,programming
published: true
---

# Dart 非同期プログラミング完全ガイド — Future / Stream / Isolate

Flutter アプリの「固まる」「カクつく」は非同期処理の誤解が原因のことが多い。3つの概念を整理する。

## なぜ非同期が重要か

```
UI スレッド (メインスレッド) でブロッキング処理をすると:
  → フレームが16ms以内に描画できない
  → ジャンク (カクつき) 発生
  → ANR / UIフリーズ

解決策:
  Future  → 一度だけ完了する非同期操作 (API 呼び出し・DB クエリ)
  Stream  → 継続的にデータを流す (Supabase Realtime・センサー)
  Isolate → CPU 集約処理をバックグラウンドスレッドで実行
```

## Future: 一度だけの非同期操作

```dart
// 基本形
Future<String> fetchUserName(String userId) async {
  final response = await supabase
    .from('users')
    .select('name')
    .eq('id', userId)
    .single();
  return response['name'] as String;
}

// エラーハンドリング
Future<String?> fetchUserNameSafe(String userId) async {
  try {
    return await fetchUserName(userId);
  } on PostgrestException catch (e) {
    debugPrint('DB error: ${e.message}');
    return null;
  }
}

// 並列実行 (直列より高速)
final results = await Future.wait([
  fetchUserName(userId),
  fetchUserPlan(userId),
  fetchUserStats(userId),
]);
```

**よくある間違い**:

```dart
// ❌ これは Future を返すだけで await していない
void loadData() {
  fetchUserName(userId); // ← 戻り値を無視
}

// ✅ async/await で待機
Future<void> loadData() async {
  final name = await fetchUserName(userId);
  setState(() => _name = name);
}
```

## Stream: 継続的なデータフロー

```dart
// Supabase Realtime で Stream を受け取る
class ChatPage extends StatefulWidget { ... }
class _ChatPageState extends State<ChatPage> {
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('room_id', widget.roomId)
      .order('created_at');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final messages = snapshot.data!;
        return ListView.builder(
          itemCount: messages.length,
          itemBuilder: (_, i) => MessageTile(message: messages[i]),
        );
      },
    );
  }
}
```

**StreamController でカスタム Stream を作る**:

```dart
class KpiService {
  final _controller = StreamController<KpiData>.broadcast();
  Stream<KpiData> get stream => _controller.stream;

  void update(KpiData data) => _controller.add(data);
  void dispose() => _controller.close();
}
```

## Isolate: CPU 集約処理をオフロード

```dart
// compute() で簡単にオフロード (Flutter の Isolate ラッパー)
Future<List<ProcessedItem>> processLargeDataset(
  List<RawItem> rawItems,
) async {
  return compute(_processItems, rawItems);
}

// トップレベル関数として定義 (Isolate に渡せる制約)
List<ProcessedItem> _processItems(List<RawItem> items) {
  return items.map((item) {
    // CPU 集約処理 (JSON パース・画像変換・暗号化など)
    return ProcessedItem(
      id: item.id,
      hash: sha256.convert(utf8.encode(item.data)).toString(),
    );
  }).toList();
}
```

**Isolate.spawn で長期バックグラウンド処理**:

```dart
// SendPort/ReceivePort でメッセージパッシング
Future<void> startBackgroundWorker() async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_workerEntryPoint, receivePort.sendPort);
  
  await for (final message in receivePort) {
    if (message is WorkerResult) {
      _handleResult(message);
    }
  }
}

void _workerEntryPoint(SendPort sendPort) {
  // バックグラウンドで継続実行
  while (true) {
    // 処理...
    sendPort.send(WorkerResult(data: 'result'));
  }
}
```

## 3つの使い分けまとめ

```
Future  → API / DB / ファイル I/O (一度だけ完了するもの)
Stream  → Realtime / WebSocket / センサー (継続して届くもの)
Isolate → 重い計算 / 大量データ変換 / 暗号化 (CPU を使い切るもの)
```

## まとめ

```
ルール:
  1. UI スレッドをブロックしない → async/await を使う
  2. 並列できるものは Future.wait でまとめる
  3. Realtime データは Stream + StreamBuilder
  4. CPU 集約処理は compute() で Isolate にオフロード
  5. エラーは try/catch で必ずハンドリング
```

Flutter の「重い」「遅い」の多くは Isolate で解決できる。まず compute() から試す。

