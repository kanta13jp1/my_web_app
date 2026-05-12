---
title: "Flutter State Management Comparison 2028 — Riverpod vs Bloc vs Provider"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter State Management Comparison 2028 — Riverpod vs Bloc vs Provider

A code-driven comparison of the three major state management libraries and when to choose each.

## Riverpod — The Indie Dev Default

```dart
// Simple async state
final userProvider = FutureProvider.autoDispose<User>((ref) async {
  return ref.watch(userRepositoryProvider).fetchUser();
});

// Derived state (recomputed automatically)
final displayNameProvider = Provider<String>((ref) {
  final user = ref.watch(userProvider).value;
  return user?.displayName ?? 'Anonymous';
});

// Widget side
class UserCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(userProvider).when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (user) => Text(user.name),
    );
  }
}
```

**When to choose**: indie dev / mid-size teams. Minimum boilerplate.

## Bloc — Built for Large Teams

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

// Widget side
BlocBuilder<CounterBloc, int>(
  builder: (context, count) => Text('$count'),
)
```

**When to choose**: large teams / complex business logic / test-heavy projects.

## Provider — Small Scale and Learning

```dart
// ChangeNotifier
class CounterModel extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
  void increment() { _count++; notifyListeners(); }
}

// Widget side
final counter = context.watch<CounterModel>();
Text('${counter.count}')
```

**When to choose**: small projects / learning Flutter.

## Selection Matrix

```
                  Riverpod  Bloc    Provider
Boilerplate        low      high    lowest
Testability        high     highest  medium
Learning curve     medium   high     low
Large-scale        high     highest  low
Indie dev          ◎        △        ○
```

## Summary

```
Indie dev / mid-size  → Riverpod (best balance)
Large team            → Bloc (explicit event-driven architecture)
Beginner / small      → Provider (simplest)
2028 trend            → Riverpod is the indie dev standard
```

State management choice comes down to team size × complexity. For indie dev: Riverpod, full stop.
