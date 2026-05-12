---
title: "Dart ジェネリクス 完全ガイド — 型境界・変性・実用パターン"
tags: dart,flutter,個人開発,AI
published: true
---

# Dart ジェネリクス 完全ガイド — 型境界・変性・実用パターン

Dart のジェネリクスは単なる「型パラメータを受け取る」以上の表現力を持ちます。型境界 (`extends`)・共変・反変・`covariant` キーワードを駆使することで、コンパイル時に多くのバグを防げます。

## 基本: 型パラメータと型推論

```dart
// 基本的なジェネリクス
class Box<T> {
  final T value;
  const Box(this.value);

  Box<R> map<R>(R Function(T) transform) => Box(transform(value));
}

// 型推論が働く
final intBox = Box(42);         // Box<int>
final strBox = Box('hello');    // Box<String>
final doubled = intBox.map((v) => v * 2); // Box<int>
final asStr = intBox.map((v) => '$v');    // Box<String>
```

## 型境界 (`extends`)

```dart
// 数値型のみ受け入れるジェネリクス
abstract class Numeric {}
class Calculable<T extends num> {
  final List<T> values;
  const Calculable(this.values);

  T get sum => values.reduce((a, b) => (a + b) as T);
  double get average => values.isEmpty ? 0 : sum / values.length;
  T get max => values.reduce((a, b) => a > b ? a : b);
}

// Comparable を実装した型のみ
class SortedList<T extends Comparable<T>> {
  final List<T> _items;

  SortedList(List<T> items)
      : _items = List.from(items)..sort();

  T get min => _items.first;
  T get max => _items.last;
  List<T> range(T from, T to) =>
      _items.where((e) => e.compareTo(from) >= 0 && e.compareTo(to) <= 0).toList();
}

// 使用例
final nums = SortedList([5, 2, 8, 1, 9]);
print(nums.min); // 1
print(nums.max); // 9
print(nums.range(2, 7)); // [2, 5]

final strs = SortedList(['banana', 'apple', 'cherry']);
print(strs.min); // apple
```

## 複数型パラメータ

```dart
// Either 型 (Result 型パターン)
sealed class Either<L, R> {
  const Either();

  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;

  T fold<T>(T Function(L) onLeft, T Function(R) onRight) {
    return switch (this) {
      Left(:final value) => onLeft(value),
      Right(:final value) => onRight(value),
    };
  }

  Either<L, R2> mapRight<R2>(R2 Function(R) transform) {
    return switch (this) {
      Left() => this as Either<L, R2>,
      Right(:final value) => Right(transform(value)),
    };
  }
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);
}

// 使用例: API 呼び出しの結果を表す
Future<Either<String, User>> fetchUser(String id) async {
  try {
    final data = await supabase.from('users').select().eq('id', id).single();
    return Right(User.fromJson(data));
  } catch (e) {
    return Left(e.toString());
  }
}

// 呼び出し側
final result = await fetchUser('123');
final message = result.fold(
  (error) => 'Error: $error',
  (user) => 'Welcome, ${user.name}!',
);
```

## `covariant` キーワード

```dart
// 動物の例
class Animal {
  void eat(Animal food) => print('$runtimeType eats $food');
}

class Cat extends Animal {
  // covariant: Cat は Cat だけを食べられる (型を絞る)
  @override
  void eat(covariant Cat food) => print('Cat eats cat food: ${food.runtimeType}');
}

// Repository の共変パターン
abstract class Repository<T> {
  Future<T?> findById(String id);
  Future<void> save(covariant T entity);
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

## 型消去と `runtimeType`

```dart
// Dart のジェネリクスは実行時に型情報を保持する (reified generics)
void checkType<T>() {
  print(T == int);    // true/false
  print(T == String); // true/false
}

// 実用: JSON デシリアライズのジェネリクス
class ApiClient {
  Future<T> get<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final response = await http.get(Uri.parse('$baseUrl$path'));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return fromJson(json);
  }

  Future<List<T>> getList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final response = await http.get(Uri.parse('$baseUrl$path'));
    final list = jsonDecode(response.body) as List;
    return list.cast<Map<String, dynamic>>().map(fromJson).toList();
  }
}

// 使用例
final client = ApiClient(baseUrl: 'https://api.example.com');
final user = await client.get('/users/123', User.fromJson);
final tasks = await client.getList('/tasks', Task.fromJson);
```

## 型安全な依存性注入

```dart
// ServiceLocator パターン
class ServiceLocator {
  final Map<Type, Object> _services = {};

  void register<T extends Object>(T service) {
    _services[T] = service;
  }

  T get<T extends Object>() {
    final service = _services[T];
    if (service == null) throw StateError('Service ${T} not registered');
    return service as T;
  }

  bool isRegistered<T extends Object>() => _services.containsKey(T);
}

// 使用例
final locator = ServiceLocator();
locator.register<TaskRepository>(TaskRepository(supabase));
locator.register<UserRepository>(UserRepository(supabase));
locator.register<ApiClient>(ApiClient(baseUrl: 'https://api.example.com'));

// 型安全に取得
final taskRepo = locator.get<TaskRepository>();
final userRepo = locator.get<UserRepository>();
```

## Flutter での実践: ジェネリクス Widget

```dart
// 汎用リストウィジェット
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

// 使用例
TypedListView<Task>(
  items: tasks,
  itemBuilder: (ctx, task, i) => TaskTile(task: task),
  emptyWidget: const Center(child: Text('タスクがありません')),
)

// 汎用 AsyncValue ウィジェット
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    super.key,
    required this.future,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
  });

  final Future<T> future;
  final Widget Function(T data) builder;
  final Widget? loadingWidget;
  final Widget Function(Object error)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ?? const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return errorBuilder?.call(snapshot.error!) ??
              Text('Error: ${snapshot.error}');
        }
        return builder(snapshot.data as T);
      },
    );
  }
}
```

## まとめ

| 機能 | 使いどころ |
|---|---|
| 型パラメータ `<T>` | コレクション・リポジトリ・ウィジェット |
| 型境界 `<T extends X>` | 数値計算・比較・特定契約の強制 |
| 複数型パラメータ `<L, R>` | Either/Result 型・変換パイプライン |
| `covariant` | サブクラスで引数型を絞りたいとき |
| Reified generics | 実行時型チェック・ファクトリパターン |

ジェネリクスを使いこなすと、「同じ処理を型違いで何度も書く」を排除し、型システムがバグを防ぐ堅牢なコードベースになります。

---

*自分株式会社では Dart + Flutter でタイプセーフなライフマネジメントアプリを開発中 → [@kanta13jp1](https://x.com/kanta13jp1)*
