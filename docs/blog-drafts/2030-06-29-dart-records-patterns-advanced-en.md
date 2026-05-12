---
title: "Dart Records & Patterns Deep Dive — Destructuring, Sealed Classes & Exhaustive Matching"
published: true
tags: dart, flutter, programming, design-pattern
canonical_url: null
---

# Dart Records & Patterns Deep Dive — Destructuring, Sealed Classes & Exhaustive Matching

Dart 3.0 shipped Records, Patterns, and Sealed Classes together. Used well, they eliminate entire categories of runtime errors and make state management dramatically more expressive.

## Records — typed tuples without the boilerplate

```dart
// Before: untyped Map
Map<String, dynamic> getUserInfo() => {'name': 'Alice', 'age': 30};

// Dart 3: typed Record
(String name, int age) getUserInfo() => ('Alice', 30);

void main() {
  final (name, age) = getUserInfo();
  print('$name is $age years old');
}
```

### Named fields

```dart
({String name, int age, String email}) getUser() => (
  name: 'Alice',
  age: 30,
  email: 'alice@example.com',
);

final user = getUser();
print(user.name); // Alice
```

### Parsing Edge Function responses with Records

```dart
({bool ok, String? error, Map<String, dynamic>? data}) parseEfResponse(
    http.Response response) {
  if (response.statusCode == 200) {
    return (ok: true, error: null, data: jsonDecode(response.body));
  }
  return (ok: false, error: response.body, data: null);
}

Future<void> fetchDashboard() async {
  final result = parseEfResponse(await http.get(Uri.parse('...')));
  if (!result.ok) {
    print('Error: ${result.error}');
    return;
  }
  processData(result.data!);
}
```

## Patterns — destructuring as a first-class feature

### List patterns

```dart
switch ([1, 2, 3, 4, 5]) {
  case [var first, var second, ...]:
    print('First: $first, Second: $second');
  case []:
    print('Empty');
}
```

### Map patterns

```dart
void processConfig(Map<String, dynamic> config) {
  switch (config) {
    case {'type': 'ai_chat', 'model': String model, 'temperature': double temp}:
      initAiChat(model: model, temperature: temp);
    case {'type': 'competitor_check', 'urls': List urls}:
      checkCompetitors(urls.cast<String>());
    default:
      throw ArgumentError('Unknown config type');
  }
}
```

### Object patterns

```dart
sealed class Shape {}
class Circle extends Shape { final double radius; Circle(this.radius); }
class Rectangle extends Shape {
  final double width, height;
  Rectangle(this.width, this.height);
}

double area(Shape shape) => switch (shape) {
  Circle(:final radius) => math.pi * radius * radius,
  Rectangle(:final width, :final height) => width * height,
};
```

## Sealed Classes — compiler-enforced exhaustiveness

```dart
sealed class AgentState {}

class AgentIdle extends AgentState {}
class AgentThinking extends AgentState {
  final String task;
  AgentThinking(this.task);
}
class AgentCompleted extends AgentState {
  final String result;
  final Duration elapsed;
  AgentCompleted(this.result, this.elapsed);
}
class AgentFailed extends AgentState {
  final String error;
  final int retryCount;
  AgentFailed(this.error, this.retryCount);
}

// Compiler guarantees all cases are covered
String describeState(AgentState state) => switch (state) {
  AgentIdle() => 'Idle',
  AgentThinking(:final task) => 'Processing: $task',
  AgentCompleted(:final result, :final elapsed) =>
    'Done in ${elapsed.inSeconds}s: $result',
  AgentFailed(:final error, :final retryCount) =>
    'Failed (attempt $retryCount): $error',
};
```

### Driving Flutter UI from sealed state

```dart
Widget buildAgentWidget(AgentState state) => switch (state) {
  AgentIdle() => const Icon(Icons.smart_toy_outlined),
  AgentThinking(:final task) => Column(children: [
    const CircularProgressIndicator(),
    Text(task),
  ]),
  AgentCompleted(:final result) =>
    Text(result, style: const TextStyle(color: Colors.green)),
  AgentFailed(:final error, :final retryCount) => Column(children: [
    const Icon(Icons.error, color: Colors.red),
    Text(error),
    if (retryCount < 3)
      TextButton(onPressed: retry, child: const Text('Retry')),
  ]),
};
```

## Guard clauses with `when`

```dart
List<String> categorize(List<int> numbers) => [
  for (final n in numbers)
    switch (n) {
      int x when x < 0 => 'negative',
      0 => 'zero',
      int x when x.isEven => 'positive even',
      _ => 'positive odd',
    }
];
```

## Pattern: a type-safe Result type

```dart
sealed class Result<T> {}

class Ok<T> extends Result<T> {
  final T value;
  Ok(this.value);
}

class Err<T> extends Result<T> {
  final String message;
  final StackTrace? stackTrace;
  Err(this.message, [this.stackTrace]);
}

Result<List<Map<String, dynamic>>> parseJson(String body) {
  try {
    final data = jsonDecode(body) as List;
    return Ok(data.cast<Map<String, dynamic>>());
  } catch (e, st) {
    return Err('JSON parse failed: $e', st);
  }
}

Future<void> loadAiProviders() async {
  switch (parseJson(await fetchProviders())) {
    case Ok(:final value):
      setState(() => providers = value);
    case Err(:final message, :final stackTrace):
      logger.error(message, stackTrace);
      showSnackBar('Failed to load');
  }
}
```

## Quick reference

| Feature | Best for |
|---|---|
| Records | Multiple return values, lightweight DTOs, destructuring |
| List/Map/Object Patterns | Data-shape branching and transformation |
| Sealed Classes | State machines, error types, algebraic data types |
| Guard clauses (`when`) | Conditional patterns |
| `if-case` | Single destructure + type narrowing |

Dart 3 patterns eliminate most `instanceof` checks, casts, and null guards — and the compiler tells you immediately when you miss a case.
