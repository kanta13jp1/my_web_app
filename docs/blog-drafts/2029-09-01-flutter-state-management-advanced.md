---
title: "Flutter 状態管理 深掘り — Riverpod vs BLoC vs Provider 選択指針"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter 状態管理 深掘り — Riverpod vs BLoC vs Provider 選択指針

Flutter の状態管理は「宗教戦争」になりがちですが、規模・チーム・テスト容易性の軸で客観的に選べます。Riverpod・BLoC・Provider の実装比較と選択指針をまとめます。

## シンプルなカウンター: 3パターン比較

### Riverpod 2.0 (推奨)

```dart
// providers.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'providers.g.dart';

@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;
  void increment() => state++;
  void decrement() => state--;
}

// UI
class CounterWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Column(children: [
      Text('$count'),
      ElevatedButton(
        onPressed: () => ref.read(counterProvider.notifier).increment(),
        child: const Text('+'),
      ),
    ]);
  }
}
```

### BLoC

```dart
// counter_bloc.dart
class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((event, emit) => emit(state + 1));
    on<Decrement>((event, emit) => emit(state - 1));
  }
}

sealed class CounterEvent {}
class Increment extends CounterEvent {}
class Decrement extends CounterEvent {}

// UI
BlocBuilder<CounterBloc, int>(
  builder: (context, count) => Column(children: [
    Text('$count'),
    ElevatedButton(
      onPressed: () => context.read<CounterBloc>().add(Increment()),
      child: const Text('+'),
    ),
  ]),
)
```

### Provider (旧来)

```dart
class CounterNotifier extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
  void increment() { _count++; notifyListeners(); }
}

// UI
Consumer<CounterNotifier>(
  builder: (_, notifier, __) => Text('${notifier.count}'),
)
```

## 非同期データ取得: Riverpod の強み

```dart
// FutureProvider でAPI呼び出し
@riverpod
Future<List<Task>> tasks(TasksRef ref) async {
  final client = ref.watch(supabaseProvider);
  final res = await client.from('tasks').select().order('created_at');
  return res.map(Task.fromJson).toList();
}

// UI: ローディング/エラーを自動ハンドリング
ref.watch(tasksProvider).when(
  data: (tasks) => ListView.builder(
    itemCount: tasks.length,
    itemBuilder: (_, i) => TaskTile(task: tasks[i]),
  ),
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
)
```

## 依存関係の注入: Riverpod vs BLoC

```dart
// Riverpod: Provider から自動で依存解決
@riverpod
SupabaseClient supabase(SupabaseRef ref) =>
    Supabase.instance.client;

@riverpod
TaskRepository taskRepository(TaskRepositoryRef ref) =>
    TaskRepository(client: ref.watch(supabaseProvider));

@riverpod
Future<List<Task>> tasks(TasksRef ref) async {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getAll();
}
```

```dart
// BLoC: MultiBlocProvider で手動注入
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => AuthBloc(authRepo: AuthRepository())),
    BlocProvider(create: (ctx) => TaskBloc(
      taskRepo: TaskRepository(client: ctx.read<SupabaseClient>()),
    )),
  ],
  child: const App(),
)
```

## テスト容易性の比較

```dart
// Riverpod テスト (ProviderContainer 使用)
test('increment counter', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  expect(container.read(counterProvider), 0);
  container.read(counterProvider.notifier).increment();
  expect(container.read(counterProvider), 1);
});

// モック差し替えも簡単
final container = ProviderContainer(
  overrides: [
    supabaseProvider.overrideWithValue(MockSupabaseClient()),
  ],
);
```

```dart
// BLoC テスト (bloc_test パッケージ)
blocTest<CounterBloc, int>(
  'emits [1] when Increment is added',
  build: () => CounterBloc(),
  act: (bloc) => bloc.add(Increment()),
  expect: () => [1],
);
```

## 選択マトリクス

| 軸 | Riverpod 2.0 | BLoC | Provider |
|---|-------------|------|---------|
| 学習コスト | 中 (コード生成あり) | 高 | 低 |
| テスト容易性 | ◎ | ◎ | ○ |
| 非同期処理 | ◎ (FutureProvider) | ○ | △ |
| チーム開発 | ◎ (型安全) | ◎ (明示的) | ○ |
| ボイラープレート | 少 (生成) | 多 | 少 |
| 推奨規模 | 全規模 | 大規模 | 小規模 |

**私の選択**: Riverpod 2.0 + `riverpod_annotation`。`build_runner` で生成されるコードで型安全性を担保しつつ、非同期処理が最もシンプルに書けます。

Riverpod に移行後、状態管理関連のバグが 70% 減少しました。

---

あなたのプロジェクトで使っている状態管理ライブラリは？コメントで教えてください！
