---
title: "Flutter Riverpod Deep Dive: Provider, StateNotifier, and AsyncNotifier"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Riverpod Deep Dive: Provider, StateNotifier, and AsyncNotifier

Pick the right Provider type and your state management code becomes almost trivial.

## Provider Selection Guide

```
What are you managing?
  ├── Read-only value / DI             → Provider
  ├── Mutable synchronous state        → StateNotifierProvider / NotifierProvider
  └── Async data (API / DB)            → FutureProvider / AsyncNotifierProvider
```

## Provider: Read-Only Values and Dependency Injection

```dart
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Derived value from another provider
final userNameProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.name ?? 'Guest';
});

// In a widget
final userName = ref.watch(userNameProvider);
```

## StateNotifierProvider: Mutable Synchronous State

```dart
// Immutable state class
class CartState {
  const CartState({required this.items, this.isLoading = false});
  final List<CartItem> items;
  final bool isLoading;

  CartState copyWith({List<CartItem>? items, bool? isLoading}) => CartState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
  );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState(items: []));

  void addItem(CartItem item) =>
    state = state.copyWith(items: [...state.items, item]);

  void removeItem(String id) =>
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
    );

  void clear() => state = const CartState(items: []);
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);

// In widget
final cart = ref.watch(cartProvider);
ref.read(cartProvider.notifier).addItem(item);
```

## AsyncNotifierProvider: Async State (Riverpod 2.x Recommended)

```dart
class TasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() => _fetchTasks();

  Future<List<Task>> _fetchTasks() async {
    final data = await ref.read(supabaseProvider)
      .from('tasks')
      .select()
      .order('created_at', ascending: false);
    return data.map(Task.fromJson).toList();
  }

  Future<void> addTask(String title) async {
    final previous = state;
    state = const AsyncLoading();
    try {
      await ref.read(supabaseProvider)
        .from('tasks')
        .insert({'title': title});
      state = AsyncData(await _fetchTasks());
    } catch (_) {
      state = previous; // rollback on error
      rethrow;
    }
  }
}

final tasksProvider = AsyncNotifierProvider<TasksNotifier, List<Task>>(
  TasksNotifier.new,
);

// In widget
Widget build(BuildContext context, WidgetRef ref) {
  return ref.watch(tasksProvider).when(
    data: (tasks) => TaskList(tasks: tasks),
    loading: () => const CircularProgressIndicator(),
    error: (e, _) => ErrorWidget(e.toString()),
  );
}
```

## family: Parameterized Providers

```dart
final taskDetailProvider = FutureProvider.family<Task, String>(
  (ref, taskId) async {
    final data = await ref.read(supabaseProvider)
      .from('tasks')
      .select()
      .eq('id', taskId)
      .single();
    return Task.fromJson(data);
  },
);

// Usage
final task = ref.watch(taskDetailProvider(taskId));
```

## Summary

```
Provider               → read-only, DI
StateNotifierProvider  → sync state (cart, filters, selections)
AsyncNotifierProvider  → async state (API/DB) ← Riverpod 2.x default
FutureProvider         → one-shot async (config loading etc.)
family                 → parameterized (per-ID data)
```

In Riverpod 2.x, `AsyncNotifier` is the standard for async. Keep `StateNotifier` for synchronous-only state.

