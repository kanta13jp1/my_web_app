---
title: "Flutter × Dart 3 Complete Guide — Pattern Matching, Sealed Classes & Records"
tags: flutter,dart,ai,indiedev
published: true
---

# Flutter × Dart 3 Complete Guide — Pattern Matching, Sealed Classes & Records

Dart 3 introduced Pattern Matching, Sealed Classes, and Records — features that fundamentally change how you write Flutter apps. More expressive, safer code with less boilerplate.

## Dart 3 Key Features

1. **Patterns** — Destructure and match values
2. **Sealed Classes** — Exhaustive type checking
3. **Records** — Lightweight anonymous types
4. **Class Modifiers** (`final`, `interface`, `base`, `mixin`)

## Records — Lightweight Composite Types

Return multiple values without a dedicated class:

```dart
// Before: needed a Map or custom class
// Dart 3: Records
(String name, int age) getUser() => ('Kanta', 28);

final (name, age) = getUser();
print('$name ($age)');  // Kanta (28)

// Named fields
({String title, double price, bool inStock}) getProduct() =>
    (title: 'Premium Plan', price: 9.99, inStock: true);

print(getProduct().title);  // Premium Plan
```

### Records in Flutter Widgets

```dart
Future<(String? data, String? error)> fetchUser(String id) async {
  try {
    final data = await supabase.from('users').select().eq('id', id).single();
    return (data['name'] as String, null);
  } catch (e) {
    return (null, e.toString());
  }
}

FutureBuilder(
  future: fetchUser(userId),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();
    final (name, error) = snapshot.data!;
    if (error != null) return Text('Error: $error');
    return Text('Hello, $name!');
  },
)
```

## Pattern Matching — Evolved Switch

```dart
// Old style
String grade(int score) {
  if (score >= 90) return 'A';
  if (score >= 70) return 'B';
  if (score >= 50) return 'C';
  return 'F';
}

// Dart 3: switch expression
String grade(int score) => switch (score) {
  >= 90 => 'A',
  >= 70 => 'B',
  >= 50 => 'C',
  _     => 'F',
};
```

### Object Patterns

```dart
class Point {
  final double x, y;
  const Point(this.x, this.y);
}

String describe(Point p) => switch (p) {
  Point(x: 0, y: 0) => 'origin',
  Point(x: 0, y: var y) => 'on Y axis ($y)',
  Point(x: var x, y: 0) => 'on X axis ($x)',
  Point(x: var x, y: var y) when x == y => 'diagonal',
  _ => 'general point',
};
```

### Pattern Matching with AsyncValue

```dart
Widget buildContent(AsyncValue<List<Note>> value) => switch (value) {
  AsyncData(value: final notes) when notes.isEmpty => const EmptyState(),
  AsyncData(value: final notes) => NotesList(notes: notes),
  AsyncError(error: final e) => ErrorWidget(message: e.toString()),
  AsyncLoading() => const CircularProgressIndicator(),
};
```

## Sealed Classes — Exhaustive Type Checking

Perfect for state management, API responses, and error types:

```dart
sealed class AuthState {}

class Authenticated extends AuthState {
  final String userId;
  final String email;
  Authenticated({required this.userId, required this.email});
}

class Unauthenticated extends AuthState {}
class AuthLoading extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError({required this.message});
}
```

```dart
// No else needed — compiler enforces exhaustiveness
Widget buildAuth(AuthState state) => switch (state) {
  Authenticated(:final userId, :final email) => HomeScreen(userId: userId, email: email),
  Unauthenticated() => const LoginScreen(),
  AuthLoading() => const SplashScreen(),
  AuthError(:final message) => ErrorScreen(message: message),
};
```

### Sealed API Result Type

```dart
sealed class ApiResult<T> {}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  ApiSuccess(this.data);
}

class ApiFailure<T> extends ApiResult<T> {
  final String message;
  final int statusCode;
  ApiFailure({required this.message, required this.statusCode});
}

// Riverpod integration
@riverpod
Future<ApiResult<List<Note>>> notes(Ref ref) async {
  try {
    final data = await supabase.from('notes').select();
    return ApiSuccess(data.map(Note.fromJson).toList());
  } catch (e) {
    return ApiFailure(message: e.toString(), statusCode: 500);
  }
}
```

## if-case Statement

```dart
void handlePayload(dynamic payload) {
  if (payload case {'type': 'message', 'content': String content}) {
    showNotification(content);
  }
  if (payload case {'type': 'alert', 'level': int level} when level > 2) {
    showUrgentAlert(payload);
  }
}
```

## Summary

Dart 3's Pattern Matching, Sealed Classes, and Records together deliver:

- **Type-safe, exhaustive** state management
- **Dramatically less boilerplate**
- **Compile-time error detection** instead of runtime surprises

They pair perfectly with Flutter and Riverpod.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
