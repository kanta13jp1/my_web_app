---
title: "Dart Extension Types — ゼロコスト型安全ラッパーの使いかた"
tags: flutter,dart,個人開発,AI
published: true
---

# Dart Extension Types — ゼロコスト型安全ラッパーの使いかた

Dart 3.3 で導入された Extension Types は、既存の型をコンパイル時に別の型として扱う仕組みです。実行時オーバーヘッドがなく、誤った型の混用を防ぐ「ゼロコスト抽象化」です。

## 基本構文

```dart
// 従来: String を userId として使うと混同しやすい
String userId = 'abc-123';
String orgId  = 'org-456';
// 誰かが逆に渡しても型エラーにならない ❌

// Extension Types: コンパイル時に別型として扱う
extension type UserId(String value) implements String {}
extension type OrgId(String value) implements String {}

UserId userId = UserId('abc-123');
OrgId  orgId  = OrgId('org-456');

// 誤って渡すとコンパイルエラー ✅
void fetchUser(UserId id) { ... }
fetchUser(orgId); // ❌ コンパイルエラー: OrgId は UserId ではない
```

## `implements` の意味

```dart
// implements String → String のメソッドが全部使える
extension type UserId(String value) implements String {}

final userId = UserId('abc-123');
print(userId.length);           // ✅ String のプロパティ
print(userId.toUpperCase());    // ✅ String のメソッド
print(userId.startsWith('abc')); // ✅

// implements なし → 明示的なメソッドのみ
extension type StrictId(String _value) {
  String get value => _value;
  // toUpperCase などは呼べない
}
```

## メソッドの追加

```dart
extension type UserId(String value) implements String {
  // バリデーション
  bool get isValid => value.isNotEmpty && value.length <= 36;

  // ファクトリコンストラクタ
  factory UserId.generate() => UserId(
    DateTime.now().millisecondsSinceEpoch.toString(),
  );

  // 変換
  String toApiParam() => Uri.encodeComponent(value);
}

// 使用例
final id = UserId.generate();
if (id.isValid) {
  final url = '/api/users/${id.toApiParam()}';
}
```

## Flutter での活用: Color ラッパー

```dart
// 設計トークンをコンパイル時安全に管理
extension type AppColor(Color value) implements Color {
  static const AppColor primary   = AppColor(Color(0xFF6366F1));
  static const AppColor secondary = AppColor(Color(0xFFF97316));
  static const AppColor surface   = AppColor(Color(0xFF1E1B4B));

  // 透明度付きバリアント
  AppColor withAlpha50() => AppColor(value.withAlpha(128));
}

// 使用側: Color を直接渡すと警告/エラーにできる
Widget buildButton(AppColor color) => ElevatedButton(
  style: ElevatedButton.styleFrom(backgroundColor: color),
  child: const Text('Click'),
  onPressed: () {},
);

// ✅ 型安全
buildButton(AppColor.primary);

// ❌ 生の Color は渡せない (implements Color で実装しているが別型)
buildButton(Colors.blue); // コンパイルエラー
```

## Supabase 応用: 型安全な ID 管理

```dart
extension type TaskId(String value) implements String {
  factory TaskId.fromJson(dynamic json) => TaskId(json as String);
  Map<String, dynamic> toWhereClause() => {'id': 'eq.$value'};
}

extension type UserId(String value) implements String {
  factory UserId.fromJson(dynamic json) => UserId(json as String);
}

// Task モデル
class Task {
  final TaskId id;
  final UserId userId;
  final String title;

  Task({required this.id, required this.userId, required this.title});

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id:     TaskId.fromJson(json['id']),
    userId: UserId.fromJson(json['user_id']),
    title:  json['title'] as String,
  );
}

// Supabase クエリも型安全に
Future<Task?> fetchTask(TaskId id) async {
  final res = await supabase
    .from('tasks')
    .select()
    .eq('id', id.value)  // .value で String に変換
    .maybeSingle();
  return res != null ? Task.fromJson(res) : null;
}
```

## `implements` vs 非 `implements` の選び方

| 用途 | 推奨 |
|-----|------|
| 既存型を安全に使いたい | `implements` あり |
| 完全に隔離した新型が欲しい | `implements` なし |
| バリデーション付き文字列 | `implements String` |
| 単位系 (km, m, cm) | `implements` なし (混在防止) |

## typedef との違い

```dart
// typedef: 単なるエイリアス。型チェックは通る ❌
typedef UserId = String;
void fetchUser(UserId id) {}
fetchUser('org-456'); // ✅ コンパイル通る (= 意味なし)

// Extension Type: 別型として扱う ✅
extension type UserId(String value) implements String {}
void fetchUser(UserId id) {}
fetchUser('org-456'); // ❌ コンパイルエラー
```

Extension Types を導入してから、ID の取り違えによるバグがゼロになりました。

---

Extension Types の活用例があればコメントで教えてください！
