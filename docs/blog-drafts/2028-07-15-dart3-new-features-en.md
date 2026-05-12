---
title: "Dart 3 New Features — Sealed Classes, Pattern Matching, and Records"
tags: flutter,ai,indiedev,programming
published: true
---

# Dart 3 New Features — Sealed Classes, Pattern Matching, and Records

Dart 3 changed how we write Dart. Master the three flagship features with real examples.

## Records: Return Multiple Values Type-Safely

```dart
// Before Dart 3: needed a Map or a dedicated class
Map<String, dynamic> getUser() => {'name': 'Alice', 'age': 30};

// Dart 3: Records are type-safe
(String name, int age) getUser() => ('Alice', 30);

// Named fields
({String name, int age}) getUserNamed() => (name: 'Alice', age: 30);

// Usage
final user = getUser();
print(user.$1);  // 'Alice'
print(user.$2);  // 30

final named = getUserNamed();
print(named.name);  // 'Alice'

// Destructuring
final (name, age) = getUser();
print('$name is $age years old');
```

## Patterns: Structural Matching

```dart
// switch expression (returns a value)
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
  Point(x: 0, y: 0)         => 'origin',
  Point(x: var x, y: 0)     => 'x-axis at $x',
  Point(x: 0, y: var y)     => 'y-axis at $y',
  Point(x: var x, y: var y) => '($x, $y)',
};
```

## Sealed Classes: Exhaustive Pattern Matching

```dart
// sealed class = subclassable only within the same library
sealed class Shape {}
class Circle    extends Shape { final double radius;        Circle(this.radius); }
class Rectangle extends Shape { final double w, h;          Rectangle(this.w, this.h); }
class Triangle  extends Shape { final double base, height;  Triangle(this.base, this.height); }

// The compiler verifies exhaustiveness — no else needed
double area(Shape shape) => switch (shape) {
  Circle(:final radius)              => 3.14 * radius * radius,
  Rectangle(:final w, :final h)     => w * h,
  Triangle(:final base, :final height) => base * height / 2,
};
// Forget Triangle → compile error (exhaustiveness check)
```

## In Practice: Type-Safe API Response Modeling

```dart
sealed class ApiResult<T> {}
class Success<T> extends ApiResult<T> { final T data;    Success(this.data); }
class Failure<T> extends ApiResult<T> { final String message; Failure(this.message); }
class Loading<T> extends ApiResult<T> {}

// Pattern-match in the UI
Widget buildWidget(ApiResult<User> result) => switch (result) {
  Loading()              => const CircularProgressIndicator(),
  Success(:final data)   => UserCard(user: data),
  Failure(:final message) => ErrorText(message),
};
```

## Summary

```
Records  → type-safe multiple return values: (T1, T2) or ({name: T1, age: T2})
Patterns → switch expression returns a value / List, Map, Object patterns
Sealed   → restrict inheritance + compile-time exhaustiveness / ideal for API state
```

Combining all three Dart 3 features catches the majority of runtime errors at compile time.
