---
title: "Dart Extension Types 完全ガイド — 型安全なラッパーとゼロコストドメインモデリング"
tags: dart,flutter,個人開発,AI
published: true
---

# Dart Extension Types 完全ガイド — 型安全なラッパーとゼロコストドメインモデリング

Dart 3.3 で導入された Extension Types は、既存の型を「ゼロコスト」でラップし、ドメイン固有の型安全性を実現します。`typedef` より強力で、`class` よりコストが低い新しいツールです。

## Extension Types とは

Extension Types は実行時にはラップされた型と同一ですが、静的型チェックでは別の型として扱われます。

```dart
// ❌ 型安全でない従来のコード
void transferMoney(int from, int to, int amount) { ... }
transferMoney(userId, accountId, 1000); // 引数の順番を間違えてもコンパイル通る

// ✅ Extension Types で型安全に
extension type UserId(int value) {}
extension type AccountId(int value) {}
extension type Money(int cents) {}

void transferMoney(UserId from, AccountId to, Money amount) { ... }
transferMoney(UserId(123), AccountId(456), Money(1000)); // 正しい順番のみコンパイル通る
```

実行時オーバーヘッドはゼロです。`UserId(123)` は `int` の `123` と同じメモリ表現です。

## 基本構文

```dart
// 基本的な Extension Type 定義
extension type Celsius(double value) {
  // 追加メソッド
  Fahrenheit toFahrenheit() => Fahrenheit(value * 9/5 + 32);
  
  // 演算子オーバーロード
  Celsius operator +(Celsius other) => Celsius(value + other.value);
  
  // getter
  bool get isFreezing => value <= 0;
}

extension type Fahrenheit(double value) {
  Celsius toCelsius() => Celsius((value - 32) * 5/9);
}

// 使用例
void main() {
  const temp = Celsius(100.0);
  print(temp.toFahrenheit().value); // 212.0
  print(temp.isFreezing); // false
  
  // ❌ コンパイルエラー: Celsius と Fahrenheit は互換性なし
  // Celsius c = Fahrenheit(32.0);
}
```

## `implements` で元の型のメソッドを公開

デフォルトでは、Extension Type は元の型のメソッドを公開しません。

```dart
extension type SafeString(String value) implements String {
  // implements String → String のすべてのメソッドが使用可能
  
  // 追加バリデーション
  bool get isValidEmail => RegExp(r'^[\w-\.]+@[\w-]+\.[a-z]{2,}$')
      .hasMatch(value);
}

void main() {
  const email = SafeString('user@example.com');
  print(email.length);       // ✅ String.length が使用可能
  print(email.toUpperCase()); // ✅ String.toUpperCase() が使用可能
  print(email.isValidEmail); // ✅ 追加メソッド
}
```

## ドメインモデリングの実践

### ID 型の分離

```dart
// ユーザードメインの型定義
extension type UserId(String value) {
  factory UserId.generate() => UserId(DateTime.now().millisecondsSinceEpoch.toString());
  
  @override
  String toString() => 'User:$value';
}

extension type PostId(String value) {
  @override
  String toString() => 'Post:$value';
}

// Supabase クエリで型安全に
class UserRepository {
  Future<Map<String, dynamic>?> findById(UserId id) async {
    // PostId を誤って渡すことがコンパイル時に防止される
    final response = await supabase
        .from('users')
        .select()
        .eq('id', id.value)
        .maybeSingle();
    return response;
  }
}
```

### 金額・通貨の型安全な表現

```dart
extension type Yen(int value) {
  // 消費税込み金額
  Yen withTax([double rate = 0.10]) =>
      Yen((value * (1 + rate)).round());
  
  String get formatted => '¥${value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  )}';
  
  Yen operator +(Yen other) => Yen(value + other.value);
  Yen operator *(int factor) => Yen(value * factor);
  
  bool operator <(Yen other) => value < other.value;
  bool operator >(Yen other) => value > other.value;
}

void main() {
  const price = Yen(10000);
  print(price.withTax().formatted); // ¥11,000
  
  const cart = [Yen(3000), Yen(5000), Yen(2000)];
  final total = cart.reduce((a, b) => a + b);
  print(total.formatted); // ¥10,000
}
```

### 検証済み文字列型

```dart
extension type ValidEmail(String value) {
  // 作成時にバリデーション
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

## Flutter Widget での活用

```dart
// 色の型安全な定義
extension type AppColor(Color value) {
  static const primary = AppColor(Color(0xFF6200EE));
  static const secondary = AppColor(Color(0xFF03DAC5));
  static const error = AppColor(Color(0xFFB00020));
  
  AppColor withOpacity(double opacity) =>
      AppColor(value.withOpacity(opacity));
}

// Widget で型安全に使用
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
        backgroundColor: backgroundColor.value, // Color に変換
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
```

## Sealed Class との組み合わせ

```dart
// API レスポンス型
sealed class ApiResponse<T> {
  const ApiResponse();
}

extension type ApiData<T>(T data) implements ApiResponse<T> {}
extension type ApiError(String message) implements ApiResponse<Never> {}
extension type ApiLoading(double? progress) implements ApiResponse<Never> {}

// 使用例
Widget buildFromResponse<T>(ApiResponse<T> response, Widget Function(T) builder) {
  return switch (response) {
    ApiData(:final data) => builder(data),
    ApiError(:final message) => ErrorWidget(message),
    ApiLoading(:final progress) => LinearProgressIndicator(value: progress),
  };
}
```

## typedef との違い

```dart
// typedef: 型エイリアス (型チェックは同じ型として扱われる)
typedef UserId = String;
typedef PostId = String;

void badExample(UserId id) {}
PostId postId = 'post-123';
badExample(postId); // ✅ コンパイル通る (同じ String 型)

// Extension Type: 独立した型として扱われる
extension type ExtUserId(String value) {}
extension type ExtPostId(String value) {}

void goodExample(ExtUserId id) {}
ExtPostId extPostId = ExtPostId('post-123');
// goodExample(extPostId); // ❌ コンパイルエラー
```

## まとめ

Extension Types の使いどころです。

| ユースケース | Extension Type が適切 |
|---|---|
| ID 型の分離 | ✅ `UserId`, `PostId`, `OrderId` |
| 単位付き数値 | ✅ `Celsius`, `Yen`, `Meters` |
| 検証済み文字列 | ✅ `ValidEmail`, `Slug`, `PhoneNumber` |
| デザイントークン | ✅ `AppColor`, `SpacingToken` |
| 実行時コストが問題 | ✅ ゼロオーバーヘッド |

Extension Types は「Primitive Obsession」アンチパターン (生の `String` や `int` を何にでも使う) を解消する強力なツールです。型システムをドメインモデルの表現手段として活用しましょう。

---

*自分株式会社では Flutter + Supabase で日本の21競合SaaSを1つに統合するライフマネジメントアプリを開発しています。開発の舞台裏を発信中 → [@kanta13jp1](https://x.com/kanta13jp1)*
