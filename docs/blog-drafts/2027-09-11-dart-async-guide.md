---
title: "Dart 非同期処理入門 — Future / Stream / Isolate の使い分け"
tags: flutter,AI,個人開発,programming
published: true
---

# Dart 非同期処理入門 — Future / Stream / Isolate の使い分け

Dart の非同期処理は3層構造。「何をいつ使うか」を理解すれば、Flutter アプリの応答性が大幅に向上する。

## 非同期の必要性

```dart
// ❌ NG: 同期処理でUIがブロックされる
void fetchData() {
  final data = http.get('https://api.example.com/data');  // 2秒待つ
  // この2秒間、UIが固まる
}

// ✅ OK: 非同期処理でUIは継続
Future<void> fetchData() async {
  final data = await http.get('https://api.example.com/data');  // 非同期で待つ
  // UIは継続して応答する
}
```

## Future: 1回限りの非同期値

```dart
// Future の基本
Future<String> fetchUsername(String userId) async {
  final response = await supabase
      .from('profiles')
      .select('username')
      .eq('id', userId)
      .single();
  return response['username'] as String;
}

// 呼び出し側
final username = await fetchUsername('user-123');
print(username);  // 'kanta13jp1'
```

**エラーハンドリング**:

```dart
try {
  final username = await fetchUsername('user-123');
  print(username);
} on PostgrestException catch (e) {
  // Supabase のエラー
  debugPrint('DB error: ${e.message}');
} catch (e) {
  // その他のエラー
  debugPrint('Error: $e');
}
```

**Future.wait: 並列実行**:

```dart
// 逐次: 合計 2秒
final profile = await fetchProfile(userId);   // 1秒
final settings = await fetchSettings(userId); // 1秒

// 並列: 合計 1秒 (同時実行)
final results = await Future.wait([
  fetchProfile(userId),
  fetchSettings(userId),
]);
final profile = results[0] as Profile;
final settings = results[1] as Settings;
```

## Stream: 継続的な非同期値

```dart
// Supabase Realtime: メッセージをリアルタイム受信
Stream<List<Message>> watchMessages(String roomId) {
  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at');
}

// Widget で購読
class ChatPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Message>>(
      stream: watchMessages('room-1'),
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

**自前の Stream 作成**:

```dart
Stream<int> countDown(int from) async* {
  for (int i = from; i >= 0; i--) {
    yield i;
    await Future.delayed(const Duration(seconds: 1));
  }
}

// 使用
await for (final count in countDown(10)) {
  print(count);  // 10, 9, 8, ... 0
}
```

## Isolate: CPU集約処理を別スレッドで

```dart
// ❌ NG: メインスレッドで重い処理 → UIがカクつく
String parseHugeJson(String json) {
  // 500MB の JSON をパース → 3秒かかる
  return processJson(json);
}

// ✅ OK: Isolate で並列実行
Future<String> parseHugeJsonInBackground(String json) async {
  return Isolate.run(() => processJson(json));  // Flutter 3.7+
}
```

**Isolate.run は Flutter 3.7+**。それ以前は `compute()` を使う:

```dart
// Flutter 3.6以前
Future<String> parseHugeJson(String json) async {
  return compute(processJson, json);
}

String processJson(String json) {
  // バックグラウンドで実行される
  return jsonDecode(json).toString();
}
```

## 選び方まとめ

```
1回の非同期値が必要 → Future / async-await
連続した値が必要 → Stream / StreamBuilder
CPU集約処理 → Isolate.run / compute
並列実行 → Future.wait
```

**Riverpod との組み合わせ**:

```dart
// FutureProvider: Future を Riverpod で管理
@riverpod
Future<Profile> userProfile(UserProfileRef ref) async {
  return fetchProfile(ref.watch(authUserIdProvider));
}

// StreamProvider: Stream を Riverpod で管理
@riverpod
Stream<List<Message>> chatMessages(ChatMessagesRef ref, String roomId) {
  return watchMessages(roomId);
}
```

## まとめ

Dart の非同期処理は「どれくらい待つか」「何回値が来るか」「どれくらい重いか」で選ぶ。`await` から始めて、リアルタイム性が必要になったら `Stream` に、CPU が詰まったら `Isolate` に移行する。
