---
title: "Dart 3 新機能完全ガイド — sealed class / パターンマッチング / Records"
tags: flutter,AI,個人開発,programming
published: true
---

# Dart 3 新機能完全ガイド — sealed class / パターンマッチング / Records

Dart 3 で書き方が大きく変わった。3つの主要機能を実例で習得する。

## Records: 複数の値を型安全に返す

```dart
// Before Dart 3: Map か専用クラスが必要だった
Map<String, dynamic> getUser() => {'name': 'Alice', 'age': 30};

// Dart 3: Record で型安全に
(String name, int age) getUser() => ('Alice', 30);

// 名前付きフィールド
({String name, int age}) getUserNamed() => (name: 'Alice', age: 30);

// 使い方
final user = getUser();
print(user.$1);  // 'Alice'
print(user.$2);  // 30

final named = getUserNamed();
print(named.name);  // 'Alice'

// 分割代入 (destructuring)
final (name, age) = getUser();
print('$name is $age years old');
```

## Patterns: 構造的なマッチング

```dart
// switch expression (値を返せる)
String describe(Object value) => switch (value) {
  int n when n < 0  => 'negative',
  int n when n == 0 => 'zero',
  int _             => 'positive',
  String s          => 'string: $s',
  _                 => 'unknown',
};

// List pattern
final [first, second, ...rest] = [1, 2, 3, 4, 5];
print(first);  // 1
print(rest);   // [3, 4, 5]

// Map pattern
final {'name': String name, 'age': int age} = {'name': 'Bob', 'age': 25};
print('$name: $age');

// Object pattern
class Point { final double x, y; const Point(this.x, this.y); }

String describePoint(Point p) => switch (p) {
  Point(x: 0, y: 0)        => 'origin',
  Point(x: var x, y: 0)    => 'x-axis at $x',
  Point(x: 0, y: var y)    => 'y-axis at $y',
  Point(x: var x, y: var y) => '($x, $y)',
};
```

## Sealed Classes: 網羅的なパターンマッチング

```dart
// sealed class = 同一ライブラリ内でのみ継承可
sealed class Shape {}
class Circle extends Shape { final double radius; Circle(this.radius); }
class Rectangle extends Shape { final double w, h; Rectangle(this.w, this.h); }
class Triangle extends Shape { final double base, height; Triangle(this.base, this.height); }

// コンパイラが全ケースを網羅チェック (else 不要)
double area(Shape shape) => switch (shape) {
  Circle(:final radius)        => 3.14 * radius * radius,
  Rectangle(:final w, :final h) => w * h,
  Triangle(:final base, :final height) => base * height / 2,
};
// Triangle を追加し忘れると → コンパイルエラー (網羅性チェック)
```

## 実践: API レスポンスの型安全なモデリング

```dart
sealed class ApiResult<T> {}
class Success<T> extends ApiResult<T> { final T data; Success(this.data); }
class Failure<T> extends ApiResult<T> { final String message; Failure(this.message); }
class Loading<T> extends ApiResult<T> {}

// UI でパターンマッチング
Widget buildWidget(ApiResult<User> result) => switch (result) {
  Loading()         => const CircularProgressIndicator(),
  Success(:final data) => UserCard(user: data),
  Failure(:final message) => ErrorText(message),
};
```

## まとめ

```
Records  → 複数戻り値を型安全に / (T1, T2) または ({name: T1, age: T2})
Patterns → switch expression で値を返す / List/Map/Object パターン
Sealed   → 継承を封印 + コンパイル時網羅チェック / API 状態モデルに最適
```

Dart 3 の 3 機能を組み合わせると、ランタイムエラーの大半をコンパイル時に検出できる。
