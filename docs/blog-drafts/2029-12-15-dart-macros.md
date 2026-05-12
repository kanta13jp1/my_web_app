---
title: "Dart Macros 入門 — コード生成を静的解析レベルで自動化する"
tags: flutter,dart,個人開発,AI
published: true
---

# Dart Macros 入門 — コード生成を静的解析レベルで自動化する

Dart 3.4 (Flutter 3.22) で実験的に導入された Dart Macros は、`build_runner` を使わずにコンパイル時コード生成を実現する新機能です。アノテーション1つで `fromJson` / `toJson`、`copyWith`、`Equatable` 相当のコードを自動生成できます。

## Dart Macros とは — 従来の build_runner との違い

従来の `build_runner` によるコード生成は2つの問題がありました:

1. **ビルドステップが遅い**: `dart run build_runner build` を手動実行する必要があり、大規模プロジェクトでは数十秒〜数分かかることも
2. **生成ファイルが git に混入しやすい**: `.g.dart` ファイルをコミットするかどうかでチームで議論になる

Dart Macros はコンパイラが直接処理するため、ビルドステップが不要になります。IDE上でも即座に補完が効き、生成コードを `.g.dart` として書き出しません。

| 比較 | build_runner | Dart Macros |
|---|---|---|
| ビルド実行 | 手動 or watch mode | 不要（コンパイラ統合） |
| 生成ファイル | `.g.dart` が生成される | 生成ファイルなし |
| IDE補完 | ビルド後に有効 | 即時有効 |
| 成熟度 | 安定（Production ready） | 実験的（Dart 3.4時点） |

## @JsonCodable マクロで fromJson/toJson 自動生成

最初の公式マクロが `@JsonCodable` です。クラスにアノテーションを付けるだけで JSON シリアライズ/デシリアライズが自動生成されます。

```dart
// pubspec.yaml に追加
// dependencies:
//   json (macros package)
// dart:
//   experiments:
//     - macros

import 'package:json/json.dart';

@JsonCodable()
class UserProfile {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;
}

// ↑ これだけで以下が自動生成される:
// UserProfile.fromJson(Map<String, dynamic> json) { ... }
// Map<String, dynamic> toJson() { ... }

// 使用例
final profile = UserProfile.fromJson({
  'id': 'uuid-123',
  'display_name': 'Kanta',
  'avatar_url': null,
  'created_at': '2026-04-29T12:00:00Z',
});
print(profile.toJson());
```

従来は `json_serializable` + `build_runner` で同じことをするために `@JsonSerializable()` アノテーション + `.g.dart` ファイルが必要でしたが、Macros ではそれが不要になります。

## カスタムマクロの作り方 (ClassDeclarationMacro)

独自のマクロを作るには `macro` キーワードと `ClassDeclarationMacro` インターフェースを実装します。

```dart
// lib/macros/copy_with.dart
import 'dart:async';
import 'package:macros/macros.dart';

macro class CopyWith implements ClassDeclarationsMacro {
  const CopyWith();

  @override
  Future<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    // クラスのフィールド一覧を取得
    final fields = await builder.fieldsOf(clazz);

    // copyWith メソッドのパラメータを生成
    final params = fields.map((f) {
      final typeName = f.type.code.debugString;
      return '${typeName}? ${f.identifier.name}';
    }).join(', ');

    // copyWith メソッドのボディを生成
    final assignments = fields.map((f) {
      final name = f.identifier.name;
      return '$name: $name ?? this.$name';
    }).join(', ');

    builder.declareInClass(DeclarationCode.fromString('''
      ${clazz.identifier.name} copyWith({$params}) {
        return ${clazz.identifier.name}($assignments);
      }
    '''));
  }
}
```

```dart
// 使用側
@CopyWith()
class Post {
  final String id;
  final String title;
  final String body;
  const Post({required this.id, required this.title, required this.body});
}

// copyWith が自動生成される
final updated = post.copyWith(title: '新しいタイトル');
```

## Flutter での活用例 — Equatable 代替

テスト時やウィジェットの `==` 比較に使う `Equatable` 相当の機能もマクロで実現できます。

```dart
// Equatable の代替マクロ
macro class ValueEquality implements ClassDeclarationsMacro {
  const ValueEquality();

  @override
  Future<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    final fields = await builder.fieldsOf(clazz);
    final fieldList = fields.map((f) => f.identifier.name).join(', ');

    // == と hashCode を自動生成
    builder.declareInClass(DeclarationCode.fromString('''
      @override
      bool operator ==(Object other) =>
          identical(this, other) ||
          other is ${clazz.identifier.name} &&
          runtimeType == other.runtimeType &&
          ${fields.map((f) => '${f.identifier.name} == other.${f.identifier.name}').join(' && ')};

      @override
      int get hashCode => Object.hash($fieldList);
    '''));
  }
}

// 使用例
@ValueEquality()
@CopyWith()
class FilterState {
  final String query;
  final List<String> tags;
  final bool showCompleted;
}
```

## 注意点と現在の制約

Dart Macros は Dart 3.4 時点ではまだ実験的機能です。以下の制約を把握しておく必要があります:

1. **`dart:experiments: [macros]` が必要**: `pubspec.yaml` で実験フラグを有効化しないと使えない
2. **pub.devのパッケージはまだ少ない**: エコシステムが成熟中のため、本番利用には慎重な判断が必要
3. **エラーメッセージが難解**: マクロのデバッグは従来のコード生成より複雑になるケースがある
4. **全てのターゲットで動作しない**: Web・iOS・Android での動作確認が必要
5. **安定APIではない**: Dart の次のバージョンで API が変わる可能性がある

```yaml
# pubspec.yaml での有効化
environment:
  sdk: '>=3.4.0 <4.0.0'

dart:
  experiments:
    - macros
```

## まとめ

Dart Macros は `build_runner` を置き換える将来の標準技術ですが、現時点ではまだ実験的段階です。`@JsonCodable` などの公式マクロは試す価値がありますが、本番プロダクトへの本格導入はエコシステムの成熟を待つのが賢明です。Dart 4.0 での正式サポートに向けて、今のうちに概念と仕組みを理解しておきましょう。
