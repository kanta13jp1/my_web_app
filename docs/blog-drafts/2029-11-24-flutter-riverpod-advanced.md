---
title: "Flutter Riverpod 2.0 上級編 — Notifier・AsyncNotifier・Family・AutoDispose の使い分け"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter Riverpod 2.0 上級編 — Notifier・AsyncNotifier・Family・AutoDispose の使い分け

Riverpod 2.0 で導入された `Notifier` / `AsyncNotifier` は、従来の `StateNotifier` を置き換える新しい標準APIです。この記事では上級者向けに、各クラスの使い分けと実践的なパターンを解説します。

## Notifier vs AsyncNotifier の違い

`Notifier<T>` は同期的な状態管理に使います。状態の更新が即座に確定できる場合に適しています。

```dart
// 同期的な状態管理
@riverpod
class CounterNotifier extends _$CounterNotifier {
  @override
  int build() => 0;

  void increment() => state++;
  void reset() => state = 0;
}
```

`AsyncNotifier<T>` は非同期データを伴う状態管理に使います。API 呼び出しやデータベースアクセスをともなう場合はこちらを選びます。

```dart
// 非同期状態管理（Supabase との連携例）
@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  Future<UserProfile> build() async {
    final userId = ref.watch(currentUserIdProvider);
    return _fetchProfile(userId);
  }

  Future<void> updateDisplayName(String name) async {
    // 楽観的更新: 先にUIを更新してからAPIを叩く
    state = AsyncData(state.value!.copyWith(displayName: name));
    try {
      await supabase.from('profiles').update({'display_name': name})
          .eq('id', ref.read(currentUserIdProvider));
    } catch (e) {
      // 失敗時は再取得してロールバック
      state = await AsyncValue.guard(() => _fetchProfile(ref.read(currentUserIdProvider)));
    }
  }

  Future<UserProfile> _fetchProfile(String userId) async {
    final data = await supabase.from('profiles').select().eq('id', userId).single();
    return UserProfile.fromJson(data);
  }
}
```

## family 修飾子でパラメータ付き Provider

`family` を使うと、パラメータを受け取る Provider を定義できます。記事IDで投稿を取得するような場合に最適です。

```dart
@riverpod
Future<Post> postDetail(PostDetailRef ref, String postId) async {
  final data = await supabase
      .from('posts')
      .select('*, author:profiles(*)')
      .eq('id', postId)
      .single();
  return Post.fromJson(data);
}

// 使用側
@override
Widget build(BuildContext context, WidgetRef ref) {
  final postAsync = ref.watch(postDetailProvider('post-uuid-123'));
  return postAsync.when(
    data: (post) => PostCard(post: post),
    loading: () => const CircularProgressIndicator(),
    error: (e, _) => Text('エラー: $e'),
  );
}
```

## autoDispose でメモリリーク防止

`autoDispose` を付けると、Provider を監視するウィジェットがツリーから取り除かれたタイミングで自動的に状態が破棄されます。一覧画面から詳細画面へ遷移する際に生成された一時的なデータをクリーンアップするのに有効です。

```dart
@riverpod  // autoDispose がデフォルトで有効 (keepAlive: false)
Future<List<Comment>> comments(CommentsRef ref, String postId) async {
  // このProviderはウィジェットが破棄されると自動でキャンセル
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  return fetchComments(postId, cancelToken: cancelToken);
}

// keepAlive が必要な場合
@Riverpod(keepAlive: true)
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}
```

## ref.watch / ref.read / ref.listen の使い分け

| メソッド | 用途 | 再ビルド |
|---|---|---|
| `ref.watch` | UIに値を反映したい場合 | あり |
| `ref.read` | イベント処理内で一度だけ値を読む場合 | なし |
| `ref.listen` | 変化に副作用を持たせたい場合 | なし (コールバック) |

```dart
// ref.listen でSnackBarを表示する例
ref.listen<AsyncValue<void>>(savePostProvider, (previous, next) {
  next.whenOrNull(
    error: (e, _) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('保存失敗: $e'))),
    data: (_) => ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('保存しました'))),
  );
});
```

## Supabase + Riverpod でリアルタイムデータ管理

Supabase Realtime と Riverpod を組み合わせると、DBの変更をリアルタイムでUIに反映できます。

```dart
@riverpod
Stream<List<Message>> chatMessages(ChatMessagesRef ref, String roomId) {
  final stream = supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at')
      .map((data) => data.map(Message.fromJson).toList());

  // Stream Provider は自動でサブスクリプションを管理
  return stream;
}

// UIでリアルタイムメッセージを表示
@override
Widget build(BuildContext context, WidgetRef ref) {
  final messagesAsync = ref.watch(chatMessagesProvider('room-123'));
  return messagesAsync.when(
    data: (messages) => ListView.builder(
      itemCount: messages.length,
      itemBuilder: (_, i) => MessageTile(message: messages[i]),
    ),
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(child: Text('接続エラー: $e')),
  );
}
```

## まとめ

- **Notifier**: 同期的な状態管理（カウンター、フォームの入力値など）
- **AsyncNotifier**: 非同期データを含む状態管理（API・DB連携）
- **family**: パラメータ付き Provider（IDベースのデータ取得）
- **autoDispose**: メモリ管理（一時的な状態、ページ単位のデータ）
- **ref.watch** を基本とし、イベントハンドラ内では **ref.read**、副作用には **ref.listen** を使う

Riverpod 2.0 のコード生成（`riverpod_generator`）を活用すれば、アノテーションベースで型安全な Provider を自動生成できるため、大規模なFlutterアプリでも管理しやすい設計を維持できます。
