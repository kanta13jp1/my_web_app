---
title: "Flutter Riverpod Testing Strategy — Mocking Providers, Integration Tests, and CI"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Riverpod Testing Strategy — Mocking Providers, Integration Tests, and CI

The right way to test Riverpod-powered apps.

## Unit Tests with ProviderContainer

```dart
// Subject under test: a Provider that fetches users
final usersProvider = FutureProvider<List<User>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getUsers();
});

// Test
void main() {
  test('usersProvider returns a list of users', () async {
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

## Widget Tests: Override with ProviderScope

```dart
testWidgets('UserListPage displays users', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
      child: const MaterialApp(home: UserListPage()),
    ),
  );

  // Wait for the FutureProvider to resolve
  await tester.pumpAndSettle();

  expect(find.text('Alice'), findsOneWidget);
  expect(find.text('Bob'), findsOneWidget);
});
```

## Testing AsyncNotifier

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

// Test
test('CounterNotifier increments', () async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  await container.read(counterProvider.future); // complete build()
  await container.read(counterProvider.notifier).increment();

  expect(container.read(counterProvider).value, equals(1));
});
```

## CI Integration: GitHub Actions

```yaml
# .github/workflows/flutter-test.yml
- name: Flutter Test
  run: flutter test --coverage

- name: Upload coverage
  uses: codecov/codecov-action@v3
  with:
    file: coverage/lcov.info
```

## Summary

```
Unit tests   → ProviderContainer + override
Widget tests → ProviderScope + override
CI           → flutter test --coverage + Codecov
Key rule     → replace real implementations with FakeXxx (no mockito needed)
```

Riverpod's override mechanism lets you write self-contained tests without mockito.
