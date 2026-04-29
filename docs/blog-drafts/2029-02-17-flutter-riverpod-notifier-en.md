---
title: "Flutter Riverpod 2.0 Complete Guide — Notifier & AsyncNotifier for Modern State Management"
tags: flutter,dart,ai,indiedev
published: true
---

# Flutter Riverpod 2.0 Complete Guide — Notifier & AsyncNotifier for Modern State Management

Riverpod 2.0 introduced `Notifier` and `AsyncNotifier` as modern replacements for `StateNotifierProvider`. Combined with `riverpod_generator`, they drastically cut boilerplate.

## Riverpod 2.0 API Overview

| Old API | New API | Use Case |
|---------|---------|---------|
| `StateProvider` | `@riverpod` + Ref | Simple values |
| `StateNotifierProvider` | `@riverpod class X extends Notifier` | Sync state |
| `FutureProvider` | `@riverpod Future<X> x(Ref ref)` | Async data |
| `StateNotifierProvider` (async) | `@riverpod class X extends AsyncNotifier` | Async state |

## Setup

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

dev_dependencies:
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.9
```

## Notifier — Synchronous State

```dart
// lib/providers/counter_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'counter_provider.g.dart';

@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;

  void increment() => state++;
  void decrement() => state--;
  void reset() => state = 0;
}
```

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

```dart
class CounterWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Column(children: [
      Text('$count'),
      ElevatedButton(
        onPressed: ref.read(counterProvider.notifier).increment,
        child: const Text('+1'),
      ),
    ]);
  }
}
```

## AsyncNotifier — Async State with Optimistic Updates

```dart
// lib/providers/notes_provider.dart
@riverpod
class Notes extends _$Notes {
  @override
  Future<List<Note>> build() async => _fetchNotes();

  Future<List<Note>> _fetchNotes() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase.from('notes').select()
      .eq('user_id', userId).order('created_at', ascending: false);
    return data.map(Note.fromJson).toList();
  }

  Future<void> addNote(String content) async {
    final previous = state.valueOrNull ?? [];
    // Optimistic update
    state = AsyncData([Note(id: 'temp', content: content, createdAt: DateTime.now()), ...previous]);
    try {
      await supabase.from('notes').insert({
        'user_id': supabase.auth.currentUser!.id,
        'content': content,
      });
      state = AsyncData(await _fetchNotes());
    } catch (e) {
      state = AsyncData(previous); // Rollback
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

## Handling AsyncValue

```dart
class NotesScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(notesProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Error: $e'),
        ElevatedButton(
          onPressed: () => ref.invalidate(notesProvider),
          child: const Text('Retry'),
        ),
      ])),
      data: (notes) => notes.isEmpty
        ? const Center(child: Text('No notes yet'))
        : ListView.builder(
            itemCount: notes.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(notes[i].content),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => ref.read(notesProvider.notifier).deleteNote(notes[i].id),
              ),
            ),
          ),
    );
  }
}
```

## Provider Dependencies

```dart
@riverpod
class UserProfile extends _$UserProfile {
  @override
  Future<Profile?> build() async {
    final session = ref.watch(authStateProvider).value?.session;
    if (session == null) return null;
    final data = await supabase.from('profiles').select()
      .eq('id', session.user.id).single();
    return Profile.fromJson(data);
  }
}
```

## Testing

```dart
test('Counter increments correctly', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  expect(container.read(counterProvider), 0);
  container.read(counterProvider.notifier).increment();
  expect(container.read(counterProvider), 1);
});
```

## Summary

Riverpod 2.0's `Notifier` / `AsyncNotifier` + code generation gives you type-safe, low-boilerplate state management. The optimistic update pattern makes Supabase CRUD feel instant.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
