---
title: "Dart Records & Patterns 完全ガイド — 構造分解・Sealed Class・パターンマッチングの実践"
emoji: "🎯"
type: "tech"
topics: ["dart", "flutter", "programming", "design-pattern"]
published: true
---

# Dart Records & Patterns 完全ガイド — 構造分解・Sealed Class・パターンマッチングの実践

Dart 3.0 で導入された Records、Patterns、Sealed Class は、型安全な状態管理とデータ変換を劇的に簡潔にします。Flutter プロジェクトでの実践パターンを網羅します。

## Records — 軽量な複合型

```dart
// 従来: Map や List を返す → 型安全でない
Map<String, dynamic> getUserInfo() => {'name': 'Alice', 'age': 30};

// Dart 3.0: Records → 型安全
(String name, int age) getUserInfo() => ('Alice', 30);

void main() {
  final (name, age) = getUserInfo();
  print('$name is $age years old'); // Alice is 30 years old
}
```

### 名前付きフィールド

```dart
({String name, int age, String email}) getUser() => (
  name: 'Alice',
  age: 30,
  email: 'alice@example.com',
);

void main() {
  final user = getUser();
  print(user.name); // Alice
  print(user.age);  // 30
}
```

### 複数戻り値で Edge Function レスポンスを処理

```dart
// Supabase EF の結果を型安全に受け取る
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

## Patterns — 構造分解の新構文

### List Patterns

```dart
final numbers = [1, 2, 3, 4, 5];

switch (numbers) {
  case [var first, var second, ...]:
    print('First: $first, Second: $second'); // First: 1, Second: 2
  case []:
    print('Empty');
}
```

### Map Patterns

```dart
void processConfig(Map<String, dynamic> config) {
  switch (config) {
    case {'type': 'ai_chat', 'model': String model, 'temperature': double temp}:
      initAiChat(model: model, temperature: temp);
    case {'type': 'competitor_check', 'urls': List urls}:
      checkCompetitors(urls.cast<String>());
    default:
      throw ArgumentError('Unknown config type: ${config['type']}');
  }
}
```

### Object Patterns

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

## Sealed Classes — 網羅的なパターンマッチング

Sealed Class は同一ライブラリ内でのみ継承可能で、`switch` で全ケースを漏れなく処理できます。

```dart
// 自分株式会社の AI エージェント状態管理
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

// コンパイラが全ケース網羅を保証
String describeState(AgentState state) => switch (state) {
  AgentIdle() => '待機中',
  AgentThinking(:final task) => '$task を処理中...',
  AgentCompleted(:final result, :final elapsed) =>
    '完了 (${elapsed.inSeconds}s): $result',
  AgentFailed(:final error, :final retryCount) =>
    '失敗 (試行 $retryCount 回): $error',
};
```

### Flutter UI での活用

```dart
Widget buildAgentWidget(AgentState state) => switch (state) {
  AgentIdle() => const Icon(Icons.smart_toy_outlined),
  AgentThinking(:final task) => Column(children: [
    const CircularProgressIndicator(),
    Text(task),
  ]),
  AgentCompleted(:final result) => Text(result, style: const TextStyle(color: Colors.green)),
  AgentFailed(:final error, :final retryCount) => Column(children: [
    Icon(Icons.error, color: Colors.red),
    Text(error),
    if (retryCount < 3)
      TextButton(onPressed: () => retry(), child: const Text('再試行')),
  ]),
};
```

## if-case と for-in patterns

```dart
// if-case: 単一条件の分解
final dynamic json = {'type': 'user', 'id': 42};
if (json case {'type': 'user', 'id': int id}) {
  print('User ID: $id'); // User ID: 42
}

// for-in patterns: コレクション変換
final pairs = [('Alice', 30), ('Bob', 25), ('Charlie', 35)];
for (final (name, age) in pairs) {
  print('$name: $age');
}
```

## Guard clauses (when)

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

print(categorize([-2, 0, 3, 4, 7]));
// [negative, zero, positive odd, positive even, positive odd]
```

## 実務パターン: Result 型

`sealed class` + `Records` でエラーハンドリングを型安全にします。

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

// 使用例
Result<List<Map<String, dynamic>>> parseJson(String body) {
  try {
    final data = jsonDecode(body) as List;
    return Ok(data.cast<Map<String, dynamic>>());
  } catch (e, st) {
    return Err('JSON parse failed: $e', st);
  }
}

Future<void> loadAiProviders() async {
  final result = parseJson(await fetchProviders());
  switch (result) {
    case Ok(:final value):
      setState(() => providers = value);
    case Err(:final message, :final stackTrace):
      logger.error(message, stackTrace);
      showSnackBar('読み込みに失敗しました');
  }
}
```

## まとめ

| 機能 | 主なユースケース |
|---|---|
| Records | 複数戻り値・軽量DTO・分解代入 |
| List/Map/Object Patterns | データ構造の分岐・変換 |
| Sealed Class | 状態管理・エラー型・ADT |
| Guard clauses (when) | 条件付きパターン |
| if-case | 単一分解・型チェック |

Dart 3.0 のパターン機能を使うと、`instanceof`チェック・キャスト・null チェックが劇的に減り、コンパイラが網羅性を保証してくれます。
