---
title: "Flutter × Dart 3 完全ガイド — Pattern Matching・Sealed Classes・Records で書き方が変わる"
tags: flutter,dart,AI,個人開発
published: true
---

# Flutter × Dart 3 完全ガイド — Pattern Matching・Sealed Classes・Records で書き方が変わる

Dart 3 で導入された Pattern Matching・Sealed Classes・Records は、Flutter 開発の書き方を大きく変えます。より表現力豊かで安全なコードが書けるようになる新機能を解説します。

## Dart 3 の主要な新機能

1. **Patterns** — 値の分解・マッチング
2. **Sealed Classes** — 網羅的な型チェック
3. **Records** — 軽量な匿名型
4. **Class Modifiers** (`final`, `interface`, `base`, `mixin`)

## Records — 匿名の複合型

複数の値をまとめて返したいときに便利:

```dart
// 従来: Map か専用クラスが必要だった
// Dart 3: Record で簡潔に
(String name, int age) getUser() => ('田中', 28);

// 分解して使う
final (name, age) = getUser();
print('$name ($age歳)');  // 田中 (28歳)

// 名前付きフィールド
({String title, double price, bool inStock}) getProduct() =>
    (title: 'プレミアムプラン', price: 980.0, inStock: true);

final product = getProduct();
print(product.title);  // プレミアムプラン
print(product.price);  // 980.0
```

### Flutter Widget での活用

```dart
// 非同期処理の結果を Record で返す
Future<(String? data, String? error)> fetchUser(String id) async {
  try {
    final data = await supabase.from('users').select().eq('id', id).single();
    return (data['name'] as String, null);
  } catch (e) {
    return (null, e.toString());
  }
}

// 使用例
FutureBuilder(
  future: fetchUser(userId),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();
    final (name, error) = snapshot.data!;
    if (error != null) return Text('エラー: $error');
    return Text('こんにちは、$name さん');
  },
)
```

## Pattern Matching — switch 式の進化

```dart
// 旧来の switch 文
String describeScore(int score) {
  if (score >= 90) return '優秀';
  if (score >= 70) return '良好';
  if (score >= 50) return '合格';
  return '不合格';
}

// Dart 3: switch 式 + パターン
String describeScore(int score) => switch (score) {
  >= 90 => '優秀',
  >= 70 => '良好',
  >= 50 => '合格',
  _     => '不合格',
};
```

### オブジェクトパターン

```dart
class Point {
  final double x, y;
  const Point(this.x, this.y);
}

String describePoint(Point p) => switch (p) {
  Point(x: 0, y: 0) => '原点',
  Point(x: 0, y: var y) => 'Y軸上 ($y)',
  Point(x: var x, y: 0) => 'X軸上 ($x)',
  Point(x: var x, y: var y) when x == y => '対角線上',
  _ => '一般点',
};
```

### Flutter Widget でのパターン

```dart
// AsyncValue を switch で網羅的に処理
Widget buildContent(AsyncValue<List<Note>> value) => switch (value) {
  AsyncData(value: final notes) when notes.isEmpty =>
      const EmptyState(),
  AsyncData(value: final notes) =>
      NotesList(notes: notes),
  AsyncError(error: final e) =>
      ErrorWidget(message: e.toString()),
  AsyncLoading() =>
      const CircularProgressIndicator(),
};
```

## Sealed Classes — 網羅的な型チェック

状態管理・API レスポンス・エラー型に最適:

```dart
// 認証状態を Sealed Class で表現
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
// switch で網羅的に処理 (else 不要!)
Widget buildAuth(AuthState state) => switch (state) {
  Authenticated(:final userId, :final email) =>
      HomeScreen(userId: userId, email: email),
  Unauthenticated() =>
      const LoginScreen(),
  AuthLoading() =>
      const SplashScreen(),
  AuthError(:final message) =>
      ErrorScreen(message: message),
  // コンパイラが全ケースをカバーしているか確認する
};
```

### API レスポンスへの応用

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

class ApiLoading<T> extends ApiResult<T> {}

// Riverpod と組み合わせ
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

## if-case 文

```dart
// 特定のパターンにだけ反応する
void handleNotification(dynamic payload) {
  if (payload case {'type': 'message', 'content': String content}) {
    showNotification(content);
  }
  if (payload case {'type': 'alert', 'level': int level} when level > 2) {
    showUrgentAlert(payload);
  }
}
```

## まとめ

Dart 3 の Pattern Matching・Sealed Classes・Records を組み合わせることで:

- 型安全で網羅的な状態管理
- ボイラープレートの大幅削減
- コンパイル時のエラー検出強化

Flutter × Riverpod との相性も抜群です。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
