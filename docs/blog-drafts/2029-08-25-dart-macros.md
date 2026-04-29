---
title: "Dart マクロ入門 — コード生成の新パラダイム (Dart 3.x)"
tags: flutter,dart,個人開発,AI
published: true
---

# Dart マクロ入門 — コード生成の新パラダイム (Dart 3.x)

Dart のマクロシステムは「コンパイル時にコードを生成・変換する」新機能です。`build_runner` + `json_serializable` の組み合わせを不要にし、より高速でシンプルな開発体験を実現します。

## なぜマクロが必要か

```dart
// 従来: json_serializable + build_runner
// 1. pubspec.yaml に依存追加
// 2. @JsonSerializable() アノテーション付与
// 3. dart run build_runner build 実行 (数十秒〜数分)
// 4. *.g.dart ファイルが生成される

@JsonSerializable()
class Task {
  final String id;
  final String title;
  Task({required this.id, required this.title});
  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
  Map<String, dynamic> toJson() => _$TaskToJson(this);
}
```

```dart
// マクロ時代: コンパイル時にインライン生成 (*.g.dart 不要)
@JsonCodable()  // マクロ
class Task {
  final String id;
  final String title;
}
// fromJson / toJson は自動的に "生えている"
```

## マクロの仕組み

```
コンパイルフェーズ:
  1. Dart ソースを解析 (AST)
  2. @JsonCodable() を検出
  3. マクロが AST を読んで新しいコードを生成
  4. 生成コードを同一ファイルに「拡張」として埋め込む
  5. 最終的な Dart ファイルとしてコンパイル

特徴:
  - *.g.dart ファイルが不要
  - IDE で生成コードを即座に確認・補完
  - build_runner 不要 → ビルド時間短縮
```

## 基本的なマクロの書き方

```dart
import 'dart:async';
import 'package:macros/macros.dart';

// マクロ宣言
macro class JsonCodable implements ClassDeclarationsMacro {
  const JsonCodable();

  @override
  Future<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    // クラスのフィールド一覧を取得
    final fields = await builder.fieldsOf(clazz);

    // fromJson ファクトリを生成
    final fromJsonCode = _buildFromJson(clazz.identifier, fields);
    builder.declareInClass(DeclarationCode.fromString(fromJsonCode));

    // toJson メソッドを生成
    final toJsonCode = _buildToJson(fields);
    builder.declareInClass(DeclarationCode.fromString(toJsonCode));
  }

  String _buildFromJson(Identifier className, List<FieldDeclaration> fields) {
    final args = fields.map((f) {
      final name = f.identifier.name;
      return "$name: json['$name'] as ${f.type.code}";
    }).join(', ');

    return '''
factory ${className.name}.fromJson(Map<String, dynamic> json) =>
    ${className.name}($args);
''';
  }

  String _buildToJson(List<FieldDeclaration> fields) {
    final entries = fields.map((f) {
      final name = f.identifier.name;
      return "'$name': $name";
    }).join(', ');

    return '''
Map<String, dynamic> toJson() => {$entries};
''';
  }
}
```

## 利用側のコード

```dart
import 'package:my_macros/my_macros.dart';

@JsonCodable()
class Task {
  final String id;
  final String title;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    required this.createdAt,
  });
}

// 生成後はそのまま使える
void main() {
  final task = Task.fromJson({
    'id': 'abc',
    'title': 'Buy milk',
    'createdAt': '2029-08-25T10:00:00Z',
  });
  print(task.toJson());
}
```

## マクロの種類

```dart
// 宣言マクロ: フィールド/メソッドを追加
class MyMacro implements ClassDeclarationsMacro { ... }

// 定義マクロ: 既存宣言の実装を提供
class MyMacro implements ClassDefinitionMacro { ... }

// 型マクロ: 型アノテーションを追加
class MyMacro implements ClassTypesMacro { ... }
```

## 現在の状況 (2029年時点)

```
✅ 安定版: @JsonCodable() (flutter/packages 公式)
✅ 安定版: @DataClass() (フィールドの copyWith / == / hashCode)
🔶 実験的: カスタムマクロの作成 (API 変更可能性あり)
❌ 未対応: マクロからの外部ファイル読み込み
❌ 未対応: ランタイム実行 (コンパイル時のみ)
```

## build_runner との比較

| 項目 | build_runner | Dart マクロ |
|------|-------------|------------|
| *.g.dart ファイル | 必要 | 不要 |
| IDE 補完 | △ (生成後) | ✅ (即時) |
| ビルド時間 | 遅い | 高速 |
| デバッグ | 難しい | 見やすい |
| カスタマイズ | `Builder` 実装 | `macro class` 実装 |
| 安定性 | 安定 | 一部実験的 |

マクロを導入してから、JSON 変換コードの生成待ち時間がゼロになり、開発体験が格段に改善しました。

---

Dart マクロを試してみた感想をコメントで教えてください！
