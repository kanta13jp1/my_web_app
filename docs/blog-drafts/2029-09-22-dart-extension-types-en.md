---
title: "Dart Extension Types — Zero-cost Type-safe Wrappers"
tags: dart,flutter,webdev,indiedev
published: true
---

# Dart Extension Types — Zero-cost Type-safe Wrappers

Introduced in Dart 3.3, Extension Types let you treat an existing type as a distinct type at compile time — with zero runtime overhead. They're the "newtype" pattern Dart developers have wanted for years.

## Basic Syntax

```dart
// Before: String IDs are easy to confuse
String userId = 'abc-123';
String orgId  = 'org-456';
// Passing orgId where userId is expected compiles fine ❌

// After: distinct types at compile time
extension type UserId(String value) implements String {}
extension type OrgId(String value) implements String {}

UserId userId = UserId('abc-123');
OrgId  orgId  = OrgId('org-456');

void fetchUser(UserId id) { ... }
fetchUser(orgId); // ❌ Compile error: OrgId is not UserId
```

## `implements` vs. No `implements`

```dart
// With implements String: all String methods are available
extension type UserId(String value) implements String {}

final id = UserId('abc-123');
id.length;           // ✅
id.toUpperCase();    // ✅
id.startsWith('a'); // ✅

// Without implements: only explicitly declared members
extension type StrictId(String _v) {
  String get value => _v;
  // .length, .toUpperCase() → compile error
}
```

## Adding Methods

```dart
extension type UserId(String value) implements String {
  bool get isValid => value.isNotEmpty && value.length <= 36;

  factory UserId.generate() =>
      UserId(DateTime.now().millisecondsSinceEpoch.toString());

  String toApiParam() => Uri.encodeComponent(value);
}

final id = UserId.generate();
if (id.isValid) {
  final url = '/api/users/${id.toApiParam()}';
}
```

## Design Tokens: Type-safe Colors

```dart
extension type AppColor(Color value) implements Color {
  static const AppColor primary   = AppColor(Color(0xFF6366F1));
  static const AppColor secondary = AppColor(Color(0xFFF97316));
  static const AppColor surface   = AppColor(Color(0xFF1E1B4B));

  AppColor withAlpha50() => AppColor(value.withAlpha(128));
}

Widget buildButton(AppColor color) => ElevatedButton(
  style: ElevatedButton.styleFrom(backgroundColor: color),
  onPressed: () {},
  child: const Text('Click'),
);

buildButton(AppColor.primary); // ✅
buildButton(Colors.blue);      // ❌ Compile error
```

## Supabase: Type-safe ID Management

```dart
extension type TaskId(String value) implements String {
  factory TaskId.fromJson(dynamic json) => TaskId(json as String);
}
extension type UserId(String value) implements String {
  factory UserId.fromJson(dynamic json) => UserId(json as String);
}

class Task {
  final TaskId id;
  final UserId userId;
  final String title;

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id:     TaskId.fromJson(json['id']),
    userId: UserId.fromJson(json['user_id']),
    title:  json['title'] as String,
  );
}

// Impossible to accidentally pass a UserId where TaskId is expected
Future<Task?> fetchTask(TaskId id) async {
  final res = await supabase
      .from('tasks')
      .select()
      .eq('id', id.value)
      .maybeSingle();
  return res != null ? Task.fromJson(res) : null;
}
```

## Extension Types vs. typedef

```dart
// typedef: just an alias — no type safety
typedef UserId = String;
void fetchUser(UserId id) {}
fetchUser('org-456'); // compiles ✅ (useless)

// Extension Type: actually distinct
extension type UserId(String value) implements String {}
void fetchUser(UserId id) {}
fetchUser('org-456'); // ❌ Compile error
```

## When to Use `implements`

| Use case | Recommendation |
|----------|---------------|
| Safe wrapper for existing type | `implements` ✅ |
| Completely isolated new type | No `implements` |
| Validated string (email, URL) | `implements String` |
| Units (km, m, cm — prevent mixing) | No `implements` |

Since adopting Extension Types for all ID fields, we've had zero "wrong ID type" bugs in production.

---

How are you using Extension Types in your codebase? Let me know below!
