---
title: "Flutter Riverpod テスト戦略 — Provider のモック・統合テスト・CI"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter Riverpod テスト戦略 — Provider のモック・統合テスト・CI

Riverpod を使うアプリの正しいテスト方法を解説する。

## ProviderContainer でユニットテスト

```dart
// テスト対象: ユーザー一覧を取得する Provider
final usersProvider = FutureProvider<List<User>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getUsers();
});

// テスト
void main() {
  test('usersProvider がユーザー一覧を返す', () async {
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    addTearDown(container.dispose);

    final users = await container.read(usersProvider.future);
    expect(users, hasLength(3));
  });
}

class FakeUserRepository implements UserRepository {
  @override
  Future<List<User>> getUsers() async => [
    User(id: '1', name: 'Alice'),
    User(id: '2', name: 'Bob'),
    User(id: '3', name: 'Charlie'),
  ];
}
```

## Widget テスト: ProviderScope でオーバーライド

```dart
testWidgets('UserListPage がユーザーを表示する', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
      child: const MaterialApp(home: UserListPage()),
    ),
  );

  // FutureProvider のローディング解消を待つ
  await tester.pumpAndSettle();

  expect(find.text('Alice'), findsOneWidget);
  expect(find.text('Bob'), findsOneWidget);
});
```

## AsyncNotifier のテスト

```dart
final counterProvider = AsyncNotifierProvider<CounterNotifier, int>(
  CounterNotifier.new,
);

class CounterNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async => 0;

  Future<void> increment() async {
    state = const AsyncLoading();
    state = AsyncData((state.value ?? 0) + 1);
  }
}

// テスト
test('CounterNotifier が increment する', () async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  await container.read(counterProvider.future); // build() を完了させる
  await container.read(counterProvider.notifier).increment();

  expect(container.read(counterProvider).value, equals(1));
});
```

## CI 統合: GitHub Actions

```yaml
# .github/workflows/flutter-test.yml
- name: Flutter Test
  run: flutter test --coverage

- name: Upload coverage
  uses: codecov/codecov-action@v3
  with:
    file: coverage/lcov.info
```

## まとめ

```
ユニットテスト → ProviderContainer + override
Widget テスト  → ProviderScope + override
CI            → flutter test --coverage + Codecov
鉄則          → 本物の実装を FakeXxx で差し替える (mockito 不要)
```

Provider のオーバーライド機構を使えば mockito なしで完結するテストが書ける。
