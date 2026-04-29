---
title: "Dart 3 Records & Patterns 実践 — 構造的分解と exhaustive switch の活用"
tags: flutter,dart,個人開発,AI
published: true
---

# Dart 3 Records & Patterns 実践 — 構造的分解と exhaustive switch の活用

Dart 3.0 で導入された Records と Patterns は、関数型プログラミングのエッセンスを Dart に持ち込む大型機能です。冗長な `if-else` チェーンや型キャストが一掃され、コードが格段に読みやすくなります。本記事では実際の Flutter プロジェクトで使えるパターンを中心に解説します。

---

## Records — 軽量な複合型

### 基本構文

```dart
// 位置レコード (positional record)
final point = (10.0, 20.0);
print(point.$1); // 10.0
print(point.$2); // 20.0

// 名前付きレコード (named record)
final user = (id: 'u_001', name: '田中', age: 28);
print(user.id);   // u_001
print(user.name); // 田中

// 混在も可
final mixed = ('active', count: 42);
print(mixed.$1);    // active
print(mixed.count); // 42
```

### 型注釈

```dart
// 型エイリアスで読みやすくする
typedef Point2D = (double x, double y);
typedef UserSummary = ({String id, String name, int age});

Point2D origin = (0.0, 0.0);
UserSummary admin = (id: 'admin', name: 'Admin', age: 30);
```

### 関数の複数返り値

Records の最大のユースケースは複数値の返却です。`Map` や独自クラスを定義する必要がなくなります。

```dart
// Before Dart 3
class ParseResult {
  final bool success;
  final int? value;
  final String? error;
  ParseResult({required this.success, this.value, this.error});
}

// After Dart 3 — Records で簡潔に
(bool success, int? value, String? error) parseInput(String input) {
  final n = int.tryParse(input);
  if (n == null) return (false, null, '数値ではありません: $input');
  if (n < 0) return (false, null, '負の値は無効です');
  return (true, n, null);
}

// 呼び出し側
final (success, value, error) = parseInput('42');
if (success) print('OK: $value');
else print('NG: $error');
```

---

## Record の分解 (Destructuring)

### 変数パターン

```dart
final (double lat, double lng) = (35.6895, 139.6917);
print('$lat, $lng'); // 35.6895, 139.6917

// 名前付き
final (:String id, :String name) = (id: 'u_001', name: '田中');
print('$id: $name'); // u_001: 田中
```

### for ループでの分解

```dart
final locations = [
  (name: '東京', lat: 35.68, lng: 139.69),
  (name: '大阪', lat: 34.69, lng: 135.50),
  (name: '福岡', lat: 33.59, lng: 130.40),
];

for (final (:name, :lat, :lng) in locations) {
  print('$name: $lat, $lng');
}
```

---

## Pattern Matching — switch 式と文

### switch 式 (exhaustive)

```dart
sealed class Shape {}
class Circle extends Shape { final double radius; Circle(this.radius); }
class Rectangle extends Shape { final double w, h; Rectangle(this.w, this.h); }
class Triangle extends Shape { final double base, height; Triangle(this.base, this.height); }

double area(Shape shape) => switch (shape) {
  Circle(:final radius)          => pi * radius * radius,
  Rectangle(:final w, :final h)  => w * h,
  Triangle(:final base, :final height) => base * height / 2,
};
```

`sealed` クラスを使うと、コンパイラがすべてのサブクラスを列挙していることを検証します。ケースを追加し忘れるとコンパイルエラーになります。

### Object パターン

```dart
class ApiResponse {
  final int statusCode;
  final Map<String, dynamic> body;
  const ApiResponse(this.statusCode, this.body);
}

String describeResponse(ApiResponse res) => switch (res) {
  ApiResponse(statusCode: 200, body: {'data': final data}) =>
    'Success: $data',
  ApiResponse(statusCode: 201) =>
    'Created',
  ApiResponse(statusCode: >= 400 && < 500, :final statusCode) =>
    'Client error $statusCode',
  ApiResponse(statusCode: >= 500, :final statusCode) =>
    'Server error $statusCode',
  _ => 'Unknown',
};
```

---

## List / Map パターン

### リストパターン

```dart
String describeList(List<int> nums) => switch (nums) {
  []          => 'empty',
  [final x]   => 'single: $x',
  [final x, final y] => 'pair: $x, $y',
  [final first, ..., final last] => 'many, first=$first last=$last',
};
```

### マップパターン

```dart
String extractCity(Map<String, dynamic> json) => switch (json) {
  {'city': String city, 'country': 'JP'} => '日本の都市: $city',
  {'city': String city}                  => '海外の都市: $city',
  _                                      => '不明',
};
```

---

## Guards — when 節

`when` でパターンに追加条件を付けられます。

```dart
sealed class Transaction {}
class Income  extends Transaction { final double amount; Income(this.amount);  }
class Expense extends Transaction { final double amount; Expense(this.amount); }

String classify(Transaction t) => switch (t) {
  Income(:final amount) when amount >= 100000 => '大口入金',
  Income(:final amount) when amount > 0       => '通常入金',
  Income()                                    => '入金 (金額不明)',
  Expense(:final amount) when amount >= 50000 => '大口出費 ⚠️',
  Expense(:final amount) when amount > 0      => '通常出費',
  Expense()                                   => '出費 (金額不明)',
};
```

---

## if-case 文

`if` 文でも単一パターンを使えます。

```dart
void handleEvent(Object event) {
  if (event case {'type': 'tap', 'x': double x, 'y': double y}) {
    debugPrint('Tapped at ($x, $y)');
  } else if (event case {'type': 'scroll', 'delta': double delta}) {
    debugPrint('Scrolled by $delta');
  }
}
```

---

## Flutter での実践例

### API レスポンスの処理

```dart
sealed class Result<T> {
  const Result();
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final String message;
  final int? statusCode;
  const Err(this.message, {this.statusCode});
}

// Riverpod AsyncValue 的なパターン
Widget buildContent(Result<List<String>> result) => switch (result) {
  Ok(value: final items) when items.isEmpty =>
    const Center(child: Text('データがありません')),
  Ok(:final value) =>
    ListView.builder(
      itemCount: value.length,
      itemBuilder: (_, i) => ListTile(title: Text(value[i])),
    ),
  Err(statusCode: 401) =>
    const Center(child: Text('認証が必要です')),
  Err(statusCode: 404) =>
    const Center(child: Text('リソースが見つかりません')),
  Err(:final message) =>
    Center(child: Text('エラー: $message')),
};
```

### 状態管理 — sealed + switch

```dart
sealed class AuthState {}
class Unauthenticated extends AuthState {}
class Loading extends AuthState {}
class Authenticated extends AuthState {
  final String userId;
  final String displayName;
  Authenticated({required this.userId, required this.displayName});
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

Widget buildAuthScreen(AuthState state) => switch (state) {
  Unauthenticated()     => const LoginPage(),
  Loading()             => const Scaffold(
      body: Center(child: CircularProgressIndicator())),
  Authenticated(:final displayName) => HomePage(name: displayName),
  AuthError(:final message)         => ErrorPage(message: message),
};
```

### Records で複数の状態をまとめて switch

```dart
// 接続状態 × 認証状態の組み合わせ
Widget buildScreen((bool isConnected, AuthState auth) state) =>
    switch (state) {
      (false, _)                        => const OfflineScreen(),
      (true, Unauthenticated())          => const LoginPage(),
      (true, Loading())                  =>
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      (true, Authenticated(:final displayName)) => HomePage(name: displayName),
      (true, AuthError(:final message))  => ErrorPage(message: message),
    };
```

---

## if-chain から switch 式へのリファクタリング

```dart
// Before — 読みにくい if-else チェーン
String getStatusLabel(String status) {
  if (status == 'pending') return '保留中';
  if (status == 'active') return 'アクティブ';
  if (status == 'suspended') return '停止中';
  if (status == 'deleted') return '削除済み';
  return '不明';
}

// After — switch 式で網羅的 & 読みやすい
String getStatusLabel(String status) => switch (status) {
  'pending'   => '保留中',
  'active'    => 'アクティブ',
  'suspended' => '停止中',
  'deleted'   => '削除済み',
  _           => '不明',
};
```

---

## まとめ

| 機能 | ユースケース |
|------|-------------|
| Records | 複数返り値、軽量 DTO |
| 変数パターン | 分解代入 |
| Object パターン | 型 + フィールドの同時チェック |
| sealed + switch | 網羅的な型ディスパッチ |
| when 節 | 条件付きパターン |
| if-case | 単一パターンの条件分岐 |
| List / Map パターン | 構造的なデータ検証 |

Records と Patterns を使いこなすと、型安全かつ読みやすいコードが自然と書けるようになります。Flutter の状態管理や API レスポンス処理は特に恩恵が大きいです。

---

Dart 3 の Records / Patterns で最も便利だと感じた場面はどこでしたか？コメントで教えてください！
