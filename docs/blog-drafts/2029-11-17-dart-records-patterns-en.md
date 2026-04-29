---
title: "Dart 3 Records and Patterns — Destructuring, Exhaustive Switches, and More"
tags: dart,flutter,webdev,indiedev
published: true
---

# Dart 3 Records and Patterns — Destructuring, Exhaustive Switches, and More

Dart 3 shipped three related language features simultaneously: Records, Patterns, and sealed classes. Together they eliminate entire categories of boilerplate — multiple return values, verbose type checks, and non-exhaustive switch chains — without adding runtime overhead. This guide covers every feature with real Flutter code.

---

## Records

A Record is an anonymous, fixed-size, immutable aggregate type. Unlike `Map`, it is fully typed.

### Positional Records

```dart
// Type: (double, double)
final point = (3.0, 4.0);
print(point.$1); // 3.0
print(point.$2); // 4.0

double distance((double, double) a, (double, double) b) {
  final dx = a.$1 - b.$1;
  final dy = a.$2 - b.$2;
  return sqrt(dx * dx + dy * dy);
}
```

### Named Records

```dart
// Type: ({String id, String email, bool isAdmin})
final user = (id: 'u_001', email: 'alice@example.com', isAdmin: false);
print(user.id);      // u_001
print(user.isAdmin); // false
```

### Type Aliases

```dart
typedef Coordinate = ({double lat, double lng});
typedef ApiResult<T> = ({bool ok, T? data, String? error});

Coordinate tokyo = (lat: 35.6895, lng: 139.6917);

ApiResult<String> fetchName() =>
    (ok: true, data: 'Alice', error: null);
```

### Multiple Return Values (The Killer Feature)

Before Dart 3, returning multiple values required a class, a `List`, or a `Map` — all with trade-offs.

```dart
// Dart 3: clean, typed, zero boilerplate
({bool valid, String? error}) validateEmail(String input) {
  if (!input.contains('@')) return (valid: false, error: 'Missing @');
  if (input.length < 5)     return (valid: false, error: 'Too short');
  return (valid: true, error: null);
}

// Caller
final (:valid, :error) = validateEmail('alice@example.com');
if (!valid) showError(error!);
```

---

## Patterns — Destructuring

Patterns appear in variable declarations, `for` loops, `switch` expressions, `switch` statements, and `if-case` statements.

### Variable Patterns

```dart
// Positional destructuring
final (x, y) = (10.0, 20.0);
print('$x, $y'); // 10.0, 20.0

// Named destructuring (shorthand when variable names match field names)
final (:String id, :String email) = (id: 'u_1', email: 'a@b.com');
print(id);    // u_1
print(email); // a@b.com
```

### Destructuring in for Loops

```dart
final users = [
  (id: '1', name: 'Alice', role: 'admin'),
  (id: '2', name: 'Bob',   role: 'member'),
];

for (final (:id, :name, :role) in users) {
  print('$id: $name ($role)');
}
```

### List Patterns

```dart
String summarize(List<int> values) => switch (values) {
  []                           => 'empty',
  [final v]                    => 'single: $v',
  [final a, final b]           => 'pair: $a, $b',
  [final first, ..., final last] => 'many; first=$first last=$last',
};

print(summarize([]));           // empty
print(summarize([7]));          // single: 7
print(summarize([1, 2]));       // pair: 1, 2
print(summarize([1, 2, 3, 4])); // many; first=1 last=4
```

### Map Patterns

```dart
String extractRegion(Map<String, dynamic> json) => switch (json) {
  {'country': 'JP', 'city': String city}  => 'Japan / $city',
  {'country': String c, 'city': String city} => '$c / $city',
  {'city': String city}                   => '? / $city',
  _                                       => 'Unknown',
};
```

---

## Sealed Classes and Exhaustive Switches

`sealed` restricts all direct subclasses to the same library, which lets the compiler verify that `switch` covers every case.

```dart
sealed class Shape {}

class Circle    extends Shape { final double radius; Circle(this.radius); }
class Rect      extends Shape { final double w, h;  Rect(this.w, this.h); }
class Triangle  extends Shape { final double base, height; Triangle(this.base, this.height); }

// Compiler guarantees all cases are covered — add a new subclass and it becomes a compile error
double area(Shape shape) => switch (shape) {
  Circle(:final radius)             => pi * radius * radius,
  Rect(:final w, :final h)          => w * h,
  Triangle(:final base, :final height) => 0.5 * base * height,
};
```

---

## Object Patterns

Object patterns match on type and simultaneously destructure fields.

```dart
class HttpResponse {
  final int status;
  final Map<String, dynamic> body;
  const HttpResponse(this.status, this.body);
}

String interpret(HttpResponse r) => switch (r) {
  HttpResponse(status: 200, body: {'items': List items}) =>
    'Got ${items.length} items',
  HttpResponse(status: 201, body: {'id': String id}) =>
    'Created: $id',
  HttpResponse(status: >= 400 && < 500, :final status) =>
    'Client error $status',
  HttpResponse(status: >= 500, :final status) =>
    'Server error $status',
  _ => 'Unexpected',
};
```

---

## Guards (when Clauses)

A `when` clause adds a boolean condition on top of a pattern match.

```dart
sealed class Tx {}
class Credit extends Tx { final double amount; Credit(this.amount); }
class Debit  extends Tx { final double amount; Debit(this.amount);  }

String classify(Tx t) => switch (t) {
  Credit(:final amount) when amount >= 10000 => 'Large credit',
  Credit(:final amount) when amount > 0      => 'Regular credit',
  Credit()                                   => 'Zero credit',
  Debit(:final amount)  when amount >= 5000  => 'Large debit ⚠️',
  Debit(:final amount)  when amount > 0      => 'Regular debit',
  Debit()                                    => 'Zero debit',
};
```

---

## if-case Statements

For single-pattern checks without a full `switch`.

```dart
void handleMessage(Object msg) {
  if (msg case {'type': 'chat', 'text': String text, 'from': String from}) {
    print('[$from]: $text');
  } else if (msg case {'type': 'join', 'user': String user}) {
    print('$user joined the room');
  }
}
```

---

## Real Flutter Use Cases

### Typed Result Type

```dart
sealed class Result<T> {
  const Result();
}
class Ok<T>  extends Result<T> { final T value;    const Ok(this.value); }
class Err<T> extends Result<T> {
  final String message;
  final int? code;
  const Err(this.message, {this.code});
}

Widget buildFromResult(Result<List<String>> result) => switch (result) {
  Ok(value: []) =>
    const Center(child: Text('No items yet')),
  Ok(:final value) =>
    ListView.builder(
      itemCount: value.length,
      itemBuilder: (_, i) => ListTile(title: Text(value[i])),
    ),
  Err(code: 401) =>
    const Center(child: Text('Please log in')),
  Err(code: 404) =>
    const Center(child: Text('Not found')),
  Err(:final message) =>
    Center(child: Text('Error: $message')),
};
```

### Auth State Machine

```dart
sealed class AuthState {}
class Unauthenticated extends AuthState { const Unauthenticated(); }
class Authenticating  extends AuthState { const Authenticating();  }
class Authenticated   extends AuthState {
  final String uid;
  final String displayName;
  const Authenticated({required this.uid, required this.displayName});
}
class AuthFailed extends AuthState {
  final String reason;
  const AuthFailed(this.reason);
}

Widget routeFor(AuthState state) => switch (state) {
  Unauthenticated()           => const LoginPage(),
  Authenticating()            => const SplashPage(),
  Authenticated(:final displayName)  => HomePage(name: displayName),
  AuthFailed(:final reason)   => ErrorPage(message: reason),
};
```

### Combining Records and switch for Multi-Dimensional State

```dart
// (network, auth) — two independent axes
Widget buildScreen((bool online, AuthState auth) state) => switch (state) {
  (false, _)                               => const OfflineBanner(),
  (true, Unauthenticated())                => const LoginPage(),
  (true, Authenticating())                 => const SplashPage(),
  (true, Authenticated(:final displayName)) => HomePage(name: displayName),
  (true, AuthFailed(:final reason))        => ErrorPage(message: reason),
};
```

---

## Refactoring if-chains to switch Expressions

```dart
// Before — imperative, easy to miss a case
Color statusColor(String status) {
  if (status == 'active')    return Colors.green;
  if (status == 'pending')   return Colors.orange;
  if (status == 'suspended') return Colors.red;
  if (status == 'deleted')   return Colors.grey;
  return Colors.transparent;
}

// After — exhaustive, compact, readable
Color statusColor(String status) => switch (status) {
  'active'    => Colors.green,
  'pending'   => Colors.orange,
  'suspended' => Colors.red,
  'deleted'   => Colors.grey,
  _           => Colors.transparent,
};
```

---

## Quick Reference

| Feature | Syntax | Use case |
|---------|--------|----------|
| Positional record | `(a, b)` | Multiple return values |
| Named record | `(x: a, y: b)` | Typed lightweight DTO |
| Variable pattern | `final (x, y) = point` | Destructuring |
| Object pattern | `MyClass(:field)` | Type + field match |
| List pattern | `[first, ...rest]` | Structural list checks |
| Map pattern | `{'key': value}` | JSON/map destructuring |
| Sealed + switch | `switch (s) { SubA() => ... }` | Exhaustive dispatch |
| Guard | `case Foo() when condition` | Conditional pattern |
| if-case | `if (x case Pattern)` | Single-branch pattern |

Dart 3's Records and Patterns make it possible to write code that is simultaneously more concise and more correct. The exhaustive switch check alone eliminates an entire class of bugs that previously only showed up at runtime.

---

Which pattern feature has changed how you write Flutter code most? Share your example in the comments!
