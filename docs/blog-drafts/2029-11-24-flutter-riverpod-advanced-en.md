---
title: "Flutter Riverpod 2.0 Advanced — Notifier, AsyncNotifier, Family, and AutoDispose"
tags: flutter,dart,webdev,indiedev
published: true
---

# Flutter Riverpod 2.0 Advanced — Notifier, AsyncNotifier, Family, and AutoDispose

Riverpod 2.0 introduced `Notifier` and `AsyncNotifier` as the modern replacement for `StateNotifier`. This article covers advanced usage patterns for indie Flutter developers building production-grade apps with Supabase.

## Notifier vs AsyncNotifier

`Notifier<T>` handles synchronous state — use it when state transitions resolve immediately without async operations.

```dart
// Synchronous state management
@riverpod
class CounterNotifier extends _$CounterNotifier {
  @override
  int build() => 0;

  void increment() => state++;
  void reset() => state = 0;
}
```

`AsyncNotifier<T>` manages state that depends on asynchronous data sources — ideal for API calls or database access.

```dart
// Async state management with Supabase
@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  Future<UserProfile> build() async {
    final userId = ref.watch(currentUserIdProvider);
    return _fetchProfile(userId);
  }

  Future<void> updateDisplayName(String name) async {
    // Optimistic update: apply UI change immediately, then sync to API
    state = AsyncData(state.value!.copyWith(displayName: name));
    try {
      await supabase.from('profiles').update({'display_name': name})
          .eq('id', ref.read(currentUserIdProvider));
    } catch (e) {
      // On failure, re-fetch to roll back to server state
      state = await AsyncValue.guard(
        () => _fetchProfile(ref.read(currentUserIdProvider)),
      );
    }
  }

  Future<UserProfile> _fetchProfile(String userId) async {
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return UserProfile.fromJson(data);
  }
}
```

## Parameterized Providers with the family Modifier

The `family` modifier lets you create providers that accept external parameters — essential for ID-based data fetching patterns.

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

// Consuming the provider
@override
Widget build(BuildContext context, WidgetRef ref) {
  final postAsync = ref.watch(postDetailProvider('post-uuid-123'));
  return postAsync.when(
    data: (post) => PostCard(post: post),
    loading: () => const CircularProgressIndicator(),
    error: (e, _) => Text('Error: $e'),
  );
}
```

## Preventing Memory Leaks with autoDispose

With `autoDispose`, the provider is automatically destroyed when no widget is watching it. This is the default in Riverpod 2.0 with code generation, meaning you opt into keeping state alive rather than remembering to clean up.

```dart
@riverpod  // autoDispose is the default (keepAlive: false)
Future<List<Comment>> comments(CommentsRef ref, String postId) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);  // Cancel HTTP request on dispose
  return fetchComments(postId, cancelToken: cancelToken);
}

// Opt-in to persistent state when needed (e.g., auth, theme)
@Riverpod(keepAlive: true)
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}
```

## ref.watch vs ref.read vs ref.listen

| Method | When to use | Triggers rebuild |
|---|---|---|
| `ref.watch` | Reactively display values in UI | Yes |
| `ref.read` | Read once inside event handlers | No |
| `ref.listen` | Trigger side effects on state change | No (callback) |

```dart
// Using ref.listen to show a SnackBar on save
ref.listen<AsyncValue<void>>(savePostProvider, (previous, next) {
  next.whenOrNull(
    error: (e, _) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Save failed: $e'))),
    data: (_) => ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved successfully'))),
  );
});
```

## Realtime Data Management with Supabase + Riverpod

Supabase Realtime integrates cleanly with Riverpod's stream providers, enabling live UI updates without manual subscription management.

```dart
@riverpod
Stream<List<Message>> chatMessages(ChatMessagesRef ref, String roomId) {
  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at')
      .map((data) => data.map(Message.fromJson).toList());
  // Riverpod automatically cancels the stream subscription on dispose
}

// Displaying realtime messages in the UI
@override
Widget build(BuildContext context, WidgetRef ref) {
  final messagesAsync = ref.watch(chatMessagesProvider('room-123'));
  return messagesAsync.when(
    data: (messages) => ListView.builder(
      itemCount: messages.length,
      itemBuilder: (_, i) => MessageTile(message: messages[i]),
    ),
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(child: Text('Connection error: $e')),
  );
}
```

## Summary

- **Notifier**: Synchronous state (counters, form values, UI toggles)
- **AsyncNotifier**: Async state with API/DB operations, supports optimistic updates
- **family**: Parameterized providers for ID-based or argument-driven data
- **autoDispose**: Default in Riverpod 2.0 code-gen; use `keepAlive: true` only for truly global state
- Prefer **ref.watch** in build, **ref.read** in callbacks, **ref.listen** for side effects

Pair `riverpod_generator` with `build_runner` for annotation-based, type-safe providers. The generated `_$ClassName` base class eliminates boilerplate, making large Flutter codebases significantly easier to maintain.
