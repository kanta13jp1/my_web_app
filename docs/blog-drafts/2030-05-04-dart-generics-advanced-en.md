---
title: "Dart Generics Deep Dive — Bounds, Variance, and Production Patterns"
tags: dart,flutter,webdev,indiedev
published: true
---

# Dart Generics Deep Dive — Bounds, Variance, and Production Patterns

Dart generics go far beyond "a class that takes a type parameter." Type bounds, covariance, reified generics, and multi-parameter types unlock compile-time correctness that runtime checks can't match. This post walks through patterns from real production code.

## Basics: Type Parameters and Inference

```dart
class Box<T> {
  final T value;
  const Box(this.value);

  Box<R> map<R>(R Function(T) transform) => Box(transform(value));
}

// Inference works as expected
final intBox = Box(42);            // Box<int>
final strBox = Box('hello');       // Box<String>
final doubled = intBox.map((v) => v * 2);  // Box<int>
final asStr  = intBox.map((v) => '$v');    // Box<String>
```

## Type Bounds (`extends`)

```dart
// Accept only numeric types
class Calculable<T extends num> {
  final List<T> values;
  const Calculable(this.values);

  T get sum => values.reduce((a, b) => (a + b) as T);
  double get average => values.isEmpty ? 0 : sum / values.length;
  T get max => values.reduce((a, b) => a > b ? a : b);
}

// Accept only Comparable types
class SortedList<T extends Comparable<T>> {
  final List<T> _items;

  SortedList(List<T> items) : _items = List.from(items)..sort();

  T get min => _items.first;
  T get max => _items.last;

  List<T> range(T from, T to) =>
      _items.where((e) => e.compareTo(from) >= 0 && e.compareTo(to) <= 0).toList();
}

final nums = SortedList([5, 2, 8, 1, 9]);
print(nums.min);         // 1
print(nums.range(2, 7)); // [2, 5]

final strs = SortedList(['banana', 'apple', 'cherry']);
print(strs.min); // apple
```

## Multiple Type Parameters

```dart
// Either / Result type
sealed class Either<L, R> {
  const Either();

  bool get isLeft  => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;

  T fold<T>(T Function(L) onLeft, T Function(R) onRight) {
    return switch (this) {
      Left(:final value)  => onLeft(value),
      Right(:final value) => onRight(value),
    };
  }

  Either<L, R2> mapRight<R2>(R2 Function(R) transform) {
    return switch (this) {
      Left()              => this as Either<L, R2>,
      Right(:final value) => Right(transform(value)),
    };
  }
}

class Left<L, R>  extends Either<L, R> { final L value; const Left(this.value);  }
class Right<L, R> extends Either<L, R> { final R value; const Right(this.value); }

// API call result
Future<Either<String, User>> fetchUser(String id) async {
  try {
    final data = await supabase.from('users').select().eq('id', id).single();
    return Right(User.fromJson(data));
  } catch (e) {
    return Left(e.toString());
  }
}

final result = await fetchUser('123');
final message = result.fold(
  (error) => 'Error: $error',
  (user)  => 'Welcome, ${user.name}!',
);
```

## The `covariant` Keyword

```dart
// Narrowing parameter types in subclasses
abstract class Repository<T> {
  Future<T?> findById(String id);
  Future<void> save(covariant T entity); // concrete subclasses accept only T, not its supertypes
  Future<List<T>> findAll();
}

class TaskRepository extends Repository<Task> {
  @override
  Future<Task?> findById(String id) async {
    final data = await supabase.from('tasks').select().eq('id', id).maybeSingle();
    return data == null ? null : Task.fromJson(data);
  }

  @override
  Future<void> save(Task entity) async {
    await supabase.from('tasks').upsert(entity.toJson());
  }

  @override
  Future<List<Task>> findAll() async {
    final data = await supabase.from('tasks').select();
    return data.map(Task.fromJson).toList();
  }
}
```

## Type Erasure? No — Dart Has Reified Generics

Unlike Java, Dart retains type information at runtime:

```dart
void checkType<T>() {
  print(T == int);    // true or false — works at runtime
  print(T == String);
}

// Practical: generic JSON deserialisation
class ApiClient {
  Future<T> get<T>(String path, T Function(Map<String, dynamic>) fromJson) async {
    final response = await http.get(Uri.parse('$baseUrl$path'));
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<T>> getList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final response = await http.get(Uri.parse('$baseUrl$path'));
    return (jsonDecode(response.body) as List)
        .cast<Map<String, dynamic>>()
        .map(fromJson)
        .toList();
  }
}

final client = ApiClient(baseUrl: 'https://api.example.com');
final user  = await client.get('/users/123', User.fromJson);
final tasks = await client.getList('/tasks', Task.fromJson);
```

## Type-Safe Service Locator

```dart
class ServiceLocator {
  final Map<Type, Object> _services = {};

  void register<T extends Object>(T service) => _services[T] = service;

  T get<T extends Object>() {
    final service = _services[T];
    if (service == null) throw StateError('$T not registered');
    return service as T;
  }
}

final locator = ServiceLocator()
  ..register<TaskRepository>(TaskRepository(supabase))
  ..register<UserRepository>(UserRepository(supabase));

final taskRepo = locator.get<TaskRepository>(); // fully type-safe
```

## Generic Widgets in Flutter

```dart
class TypedListView<T> extends StatelessWidget {
  const TypedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.emptyWidget = const SizedBox.shrink(),
  });

  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final Widget emptyWidget;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return emptyWidget;
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) => itemBuilder(ctx, items[i], i),
    );
  }
}

// Usage
TypedListView<Task>(
  items: tasks,
  itemBuilder: (ctx, task, i) => TaskTile(task: task),
  emptyWidget: const Center(child: Text('No tasks')),
)
```

## When to Use What

| Feature | Use When |
|---|---|
| `<T>` | Collections, repositories, widgets |
| `<T extends X>` | Numeric ops, Comparable, interface contracts |
| `<L, R>` (multi-param) | Either/Result types, transformation pipelines |
| `covariant` | Narrowing param types in subclasses |
| Reified generics | Runtime type dispatch, factory patterns |

Master Dart generics and you eliminate the "same logic repeated for every type" problem while letting the type system catch whole categories of bugs at compile time.

---

*Building a type-safe life-management app with Dart + Flutter. Follow the journey → [@kanta13jp1](https://x.com/kanta13jp1)*
