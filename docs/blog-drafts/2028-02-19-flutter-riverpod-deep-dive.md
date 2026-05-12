---
title: "Flutter Riverpod 深化 — Provider / StateNotifier / AsyncNotifier"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter Riverpod 深化 — Provider / StateNotifier / AsyncNotifier

Riverpod の3つの Provider を正しく使い分けるだけで、状態管理のコードが劇的にシンプルになる。

## Riverpod の Provider 選択基準

```
何を管理するか?
  ├── 単純な値 (設定/定数)       → Provider
  ├── 変更可能な同期状態         → StateNotifierProvider / NotifierProvider
  └── 非同期データ (API/DB)      → FutureProvider / AsyncNotifierProvider
```

## Provider: 読み取り専用の値

```dart
// 単純な依存性注入
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// 計算値 (他 Provider から派生)
final userNameProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.name ?? 'ゲスト';
});

// Widget から使用
final userName = ref.watch(userNameProvider);
```

## StateNotifierProvider: 同期状態の管理

```dart
// 状態クラス (immutable)
class CartState {
  const CartState({required this.items, this.isLoading = false});
  final List<CartItem> items;
  final bool isLoading;

  CartState copyWith({List<CartItem>? items, bool? isLoading}) =>
    CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
}

// Notifier
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState(items: []));

  void addItem(CartItem item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  void removeItem(String itemId) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != itemId).toList(),
    );
  }

  void clear() => state = const CartState(items: []);
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);

// Widget から使用
final cart = ref.watch(cartProvider);
ref.read(cartProvider.notifier).addItem(item);
```

## AsyncNotifierProvider: 非同期状態の管理 (Riverpod 2.x 推奨)

```dart
// AsyncNotifier (Riverpod 2.x)
class TasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() async {
    // 初期データ取得
    return _fetchTasks();
  }

  Future<List<Task>> _fetchTasks() async {
    final supabase = ref.read(supabaseProvider);
    final data = await supabase
      .from('tasks')
      .select()
      .order('created_at', ascending: false);
    return data.map(Task.fromJson).toList();
  }

  Future<void> addTask(String title) async {
    // 楽観的更新
    final previous = state;
    state = const AsyncLoading();
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('tasks').insert({'title': title});
      state = AsyncData(await _fetchTasks());
    } catch (e, st) {
      state = previous;  // ロールバック
      rethrow;
    }
  }
}

final tasksProvider = AsyncNotifierProvider<TasksNotifier, List<Task>>(
  TasksNotifier.new,
);

// Widget から使用
Widget build(BuildContext context, WidgetRef ref) {
  final tasksAsync = ref.watch(tasksProvider);
  return tasksAsync.when(
    data: (tasks) => TaskList(tasks: tasks),
    loading: () => const CircularProgressIndicator(),
    error: (e, _) => ErrorWidget(e.toString()),
  );
}
```

## family: パラメータ付き Provider

```dart
// IDごとに異なるデータを取得
final taskDetailProvider = FutureProvider.family<Task, String>(
  (ref, taskId) async {
    final supabase = ref.read(supabaseProvider);
    final data = await supabase
      .from('tasks')
      .select()
      .eq('id', taskId)
      .single();
    return Task.fromJson(data);
  },
);

// 使用
final task = ref.watch(taskDetailProvider(taskId));
```

## まとめ

```
Provider               → 読み取り専用・依存性注入
StateNotifierProvider  → 同期状態 (カート・フィルター・選択状態)
AsyncNotifierProvider  → 非同期状態 (API/DB データ) ← Riverpod 2.x 推奨
FutureProvider         → 単発の非同期取得 (設定読み込み等)
family                 → パラメータ付き (ID ごとのデータ)
```

Riverpod 2.x では `AsyncNotifier` が非同期の標準。`StateNotifier` は同期専用に使い分ける。

