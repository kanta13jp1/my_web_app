---
title: "Flutter 状態管理比較 2028 — Riverpod・Bloc・Provider を選ぶ基準"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter 状態管理比較 2028 — Riverpod・Bloc・Provider を選ぶ基準

3 大状態管理ライブラリの特徴と選定基準をコードで比較する。

## Riverpod — 個人開発のデファクト

```dart
// シンプルな非同期状態
final userProvider = FutureProvider.autoDispose<User>((ref) async {
  return ref.watch(userRepositoryProvider).fetchUser();
});

// 派生状態 (自動で再計算)
final displayNameProvider = Provider<String>((ref) {
  final user = ref.watch(userProvider).value;
  return user?.displayName ?? '匿名';
});

// ウィジェット側
class UserCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(userProvider).when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('エラー: $e'),
      data: (user) => Text(user.name),
    );
  }
}
```

**選ぶ基準**: 個人開発・中規模チーム。ボイラープレートが最小。

## Bloc — 大規模チーム向け

```dart
// Event
sealed class CounterEvent {}
class Increment extends CounterEvent {}
class Decrement extends CounterEvent {}

// Bloc
class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((event, emit) => emit(state + 1));
    on<Decrement>((event, emit) => emit(state - 1));
  }
}

// ウィジェット側
BlocBuilder<CounterBloc, int>(
  builder: (context, count) => Text('$count'),
)
```

**選ぶ基準**: 大規模・複雑なビジネスロジック・テスト重視。

## Provider — 小規模・学習用

```dart
// ChangeNotifier
class CounterModel extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
  void increment() { _count++; notifyListeners(); }
}

// ウィジェット側
final counter = context.watch<CounterModel>();
Text('${counter.count}')
```

**選ぶ基準**: 小規模・Flutter 入門時。

## 選定マトリクス

```
                  Riverpod  Bloc    Provider
ボイラープレート    少       多      最少
テストのしやすさ    高       最高    中
学習コスト          中       高      低
大規模対応          高       最高    低
個人開発            ◎        △       ○
```

## まとめ

```
個人開発 / 中規模   → Riverpod (バランス最良)
大規模チーム       → Bloc (明示的なイベント駆動)
入門 / 小規模      → Provider (シンプル)
2028 トレンド      → Riverpod が個人開発の標準
```

状態管理の選択は「チーム規模×複雑さ」で決まる。個人開発なら Riverpod 一択。
