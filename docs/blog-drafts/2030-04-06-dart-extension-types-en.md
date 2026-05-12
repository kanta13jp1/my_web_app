---
title: "Dart Extension Types — Zero-Cost Wrappers and Type-Safe Domain Modeling"
tags: dart,flutter,webdev,indiedev
published: true
---

# Dart Extension Types — Zero-Cost Wrappers and Type-Safe Domain Modeling

Introduced in Dart 3.3, Extension Types let you wrap an existing type with **zero runtime overhead** while gaining domain-specific type safety. More powerful than `typedef`, cheaper than `class`.

## What Are Extension Types?

An Extension Type is identical to its wrapped type at runtime, but treated as a distinct type by the static type checker.

```dart
// ❌ Type-unsafe: wrong argument order compiles fine
void transferMoney(int from, int to, int amount) { ... }
transferMoney(userId, accountId, 1000); // silently wrong

// ✅ Extension Types prevent this at compile time
extension type UserId(int value) {}
extension type AccountId(int value) {}
extension type Money(int cents) {}

void transferMoney(UserId from, AccountId to, Money amount) { ... }
transferMoney(UserId(123), AccountId(456), Money(1000)); // only correct order compiles
```

Zero runtime overhead — `UserId(123)` has the same memory representation as the `int` `123`.

## Basic Syntax

```dart
extension type Celsius(double value) {
  Fahrenheit toFahrenheit() => Fahrenheit(value * 9/5 + 32);
  
  Celsius operator +(Celsius other) => Celsius(value + other.value);
  
  bool get isFreezing => value <= 0;
}

extension type Fahrenheit(double value) {
  Celsius toCelsius() => Celsius((value - 32) * 5/9);
}

void main() {
  const temp = Celsius(100.0);
  print(temp.toFahrenheit().value); // 212.0
  print(temp.isFreezing); // false
  
  // ❌ Compile error: Celsius and Fahrenheit are incompatible types
  // Celsius c = Fahrenheit(32.0);
}
```

## `implements` to Expose the Underlying Type's API

By default, Extension Types don't expose the wrapped type's methods.

```dart
extension type SafeString(String value) implements String {
  // implements String → all String methods are accessible
  
  bool get isValidEmail => RegExp(r'^[\w-\.]+@[\w-]+\.[a-z]{2,}$')
      .hasMatch(value);
}

void main() {
  const email = SafeString('user@example.com');
  print(email.length);        // ✅ String.length available
  print(email.toUpperCase()); // ✅ String.toUpperCase() available
  print(email.isValidEmail);  // ✅ custom method
}
```

## Domain Modeling in Practice

### Separating ID Types

```dart
extension type UserId(String value) {
  factory UserId.generate() => UserId(DateTime.now().millisecondsSinceEpoch.toString());
  
  @override
  String toString() => 'User:$value';
}

extension type PostId(String value) {
  @override
  String toString() => 'Post:$value';
}

// Type-safe Supabase queries
class UserRepository {
  Future<Map<String, dynamic>?> findById(UserId id) async {
    // Passing a PostId is caught at compile time
    final response = await supabase
        .from('users')
        .select()
        .eq('id', id.value)
        .maybeSingle();
    return response;
  }
}
```

### Type-Safe Money Representation

```dart
extension type Cents(int value) {
  Cents withTax([double rate = 0.10]) => Cents((value * (1 + rate)).round());
  
  String get formatted {
    final dollars = value ~/ 100;
    final cents = value % 100;
    return '\$${dollars.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}.${cents.toString().padLeft(2, '0')}';
  }
  
  Cents operator +(Cents other) => Cents(value + other.value);
  Cents operator *(int factor) => Cents(value * factor);
  bool operator <(Cents other) => value < other.value;
  bool operator >(Cents other) => value > other.value;
}

void main() {
  const price = Cents(1000); // $10.00
  print(price.withTax().formatted); // $11.00
  
  const cart = [Cents(300), Cents(500), Cents(200)];
  final total = cart.reduce((a, b) => a + b);
  print(total.formatted); // $10.00
}
```

### Validated String Types

```dart
extension type ValidEmail(String value) {
  static ValidEmail? tryParse(String input) {
    final regex = RegExp(r'^[\w-\.]+@[\w-]+\.[a-z]{2,}$');
    return regex.hasMatch(input) ? ValidEmail(input) : null;
  }
  
  String get domain => value.split('@').last;
  String get localPart => value.split('@').first;
}

extension type Slug(String value) {
  static Slug fromTitle(String title) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    return Slug(slug);
  }
}
```

## Application in Flutter Widgets

```dart
extension type AppColor(Color value) {
  static const primary = AppColor(Color(0xFF6200EE));
  static const secondary = AppColor(Color(0xFF03DAC5));
  static const error = AppColor(Color(0xFFB00020));
  
  AppColor withOpacity(double opacity) =>
      AppColor(value.withOpacity(opacity));
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor = AppColor.primary,
  });

  final String label;
  final VoidCallback onPressed;
  final AppColor backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor.value,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
```

## Combining with Sealed Classes

```dart
sealed class ApiResponse<T> {
  const ApiResponse();
}

extension type ApiData<T>(T data) implements ApiResponse<T> {}
extension type ApiError(String message) implements ApiResponse<Never> {}
extension type ApiLoading(double? progress) implements ApiResponse<Never> {}

Widget buildFromResponse<T>(ApiResponse<T> response, Widget Function(T) builder) {
  return switch (response) {
    ApiData(:final data) => builder(data),
    ApiError(:final message) => ErrorWidget(message),
    ApiLoading(:final progress) => LinearProgressIndicator(value: progress),
  };
}
```

## Extension Types vs typedef

```dart
// typedef: just an alias — treated as the same type
typedef UserId = String;
typedef PostId = String;

void example(UserId id) {}
PostId postId = 'post-123';
example(postId); // ✅ compiles (both are String)

// Extension Type: genuinely distinct types
extension type ExtUserId(String value) {}
extension type ExtPostId(String value) {}

void goodExample(ExtUserId id) {}
ExtPostId extPostId = ExtPostId('post-123');
// goodExample(extPostId); // ❌ compile error
```

## When to Use Extension Types

| Use Case | Extension Type |
|---|---|
| Separating ID types | ✅ `UserId`, `PostId`, `OrderId` |
| Unit-bearing numbers | ✅ `Celsius`, `Cents`, `Meters` |
| Validated strings | ✅ `ValidEmail`, `Slug`, `PhoneNumber` |
| Design tokens | ✅ `AppColor`, `SpacingToken` |
| Zero runtime cost required | ✅ no overhead |

Extension Types are a surgical cure for the **Primitive Obsession** antipattern — using raw `String` and `int` for everything. Let the type system express your domain model.

---

*Building a life-management app that replaces 21 competing SaaS tools with Flutter + Supabase. Follow the journey → [@kanta13jp1](https://x.com/kanta13jp1)*
