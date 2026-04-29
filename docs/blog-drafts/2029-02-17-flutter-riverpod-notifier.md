---
title: "Flutter Riverpod 2.0 完全ガイド — Notifier・AsyncNotifier で状態管理を刷新する"
tags: flutter,dart,AI,個人開発
published: true
---

# Flutter Riverpod 2.0 完全ガイド — Notifier・AsyncNotifier で状態管理を刷新する

Riverpod 2.0 で登場した `Notifier` / `AsyncNotifier` は、従来の `StateNotifierProvider` を置き換える新しいアプローチです。コード生成 (`riverpod_generator`) と組み合わせることでボイラープレートを大幅に削減できます。

## Riverpod 2.0 の新 API 一覧

| 旧 API | 新 API | 用途 |
|--------|--------|------|
| `StateProvider` | `@riverpod` + Ref | 単純な値 |
| `StateNotifierProvider` | `@riverpod class XNotifier extends Notifier` | 同期的な状態 |
| `FutureProvider` | `@riverpod Future<X> x(Ref ref)` | 非同期データ取得 |
| `StateNotifierProvider` (非同期) | `@riverpod class XNotifier extends AsyncNotifier` | 非同期状態管理 |

## セットアップ

```yaml
# pubspec.yaml
dependencies:
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

dev_dependencies:
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.9
```

## Notifier — 同期的な状態管理

```dart
// lib/providers/counter_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'counter_provider.g.dart';

@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;  // 初期値

  void increment() => state++;
  void decrement() => state--;
  void reset() => state = 0;
}
```

```bash
# コード生成
flutter pub run build_runner build --delete-conflicting-outputs
```

```dart
// Widget で使用
class CounterWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Column(
      children: [
        Text('$count'),
        ElevatedButton(
          onPressed: ref.read(counterProvider.notifier).increment,
          child: const Text('+1'),
        ),
      ],
    );
  }
}
```

## AsyncNotifier — 非同期状態管理

Supabase からデータを取得しながら CRUD 操作を管理する例:

```dart
// lib/providers/notes_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/note.dart';
part 'notes_provider.g.dart';

@riverpod
class Notes extends _$Notes {
  @override
  Future<List<Note>> build() async {
    return _fetchNotes();
  }

  Future<List<Note>> _fetchNotes() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
      .from('notes')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);
    return data.map(Note.fromJson).toList();
  }

  Future<void> addNote(String content) async {
    // 楽観的更新: 先に UI を更新
    final previous = state.valueOrNull ?? [];
    final newNote = Note(id: 'temp', content: content, createdAt: DateTime.now());
    state = AsyncData([newNote, ...previous]);

    try {
      await supabase.from('notes').insert({
        'user_id': supabase.auth.currentUser!.id,
        'content': content,
      });
      // サーバーから最新データを再取得
      state = AsyncData(await _fetchNotes());
    } catch (e) {
      // 失敗したらロールバック
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> deleteNote(String id) async {
    final previous = state.valueOrNull ?? [];
    state = AsyncData(previous.where((n) => n.id != id).toList());

    try {
      await supabase.from('notes').delete().eq('id', id);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}
```

## AsyncValue の扱い

```dart
class NotesScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);

    return notesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('エラー: $error'),
            ElevatedButton(
              onPressed: () => ref.invalidate(notesProvider),
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
      data: (notes) => notes.isEmpty
        ? const Center(child: Text('メモがありません'))
        : ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return ListTile(
                title: Text(note.content),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => ref
                    .read(notesProvider.notifier)
                    .deleteNote(note.id),
                ),
              );
            },
          ),
    );
  }
}
```

## Provider 間の依存

```dart
// 認証状態に依存するプロバイダー
@riverpod
class UserProfile extends _$UserProfile {
  @override
  Future<Profile?> build() async {
    // authStateChanges を watch → ログアウト時は null
    final session = ref.watch(authStateProvider).value?.session;
    if (session == null) return null;

    final data = await supabase
      .from('profiles')
      .select()
      .eq('id', session.user.id)
      .single();
    return Profile.fromJson(data);
  }
}
```

## テスト

```dart
// test/providers/counter_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Counter increments correctly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(counterProvider), 0);
    container.read(counterProvider.notifier).increment();
    expect(container.read(counterProvider), 1);
  });
}
```

## まとめ

Riverpod 2.0 の `Notifier` / `AsyncNotifier` + コード生成で、型安全で保守しやすい状態管理が実現できます。楽観的更新パターンと組み合わせると、Supabase との連携がより快適になります。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
