---
title: "Dart メタプログラミング完全ガイド — build_runner・コード生成・Dart 3 マクロ"
tags: Dart,Flutter,programming,個人開発
published: true
---

# Dart メタプログラミング完全ガイド — build_runner・コード生成・Dart 3 マクロ

「json_serializable って便利だけど、仕組みが謎…」「自分でもアノテーションを作れないか?」と感じたことはないだろうか。Dart のメタプログラミング (コード生成) は、JSON シリアライズ・ルーティング・DI (依存性注入) など、繰り返しの実装を自動化できる強力な仕組みだ。本記事では `build_runner` から始まり、カスタム `Builder` の作成、さらに Dart 3.x で実験的に導入された Macros API まで、実用レベルで解説する。

## Dart コード生成の全体像

```
Dart ソースコード (.dart)
       │
       │ @アノテーション を付ける
       ▼
build_runner (ビルドシステム)
       │
       │ Builder (コード生成ロジック) を実行
       ▼
生成ファイル (.g.dart / .freezed.dart など)
       │
       │ part 'xxx.g.dart' でインクルード
       ▼
最終的な Dart コード
```

`build_runner` は Dart のビルドシステムで、ソースコードを解析してファイルを生成する。`source_gen` はそのラッパーで、`Builder` クラスの実装を簡単にする。

## よく使うコード生成パッケージ

| パッケージ | 用途 | 生成ファイル |
|-----------|------|------------|
| `json_serializable` | JSON シリアライズ | `.g.dart` |
| `freezed` | イミュータブルクラス + Union | `.freezed.dart` + `.g.dart` |
| `riverpod_generator` | Riverpod Provider 自動生成 | `.g.dart` |
| `go_router_builder` | 型安全なルーティング | `.g.dart` |
| `injectable` | 依存性注入 | `.config.dart` |
| `isar_generator` | Isar DB スキーマ | `.g.dart` |

## Step 1: json_serializable で JSON を理解する

まず既存パッケージを使いこなして、コード生成の感覚をつかもう。

```yaml
# pubspec.yaml
dependencies:
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.8.0
```

```dart
// lib/models/user.dart
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';  // ← build_runner が生成するファイル

@JsonSerializable(
  fieldRename: FieldRename.snake,  // snake_case ↔ camelCase 自動変換
  includeIfNull: false,
  explicitToJson: true,
)
class User {
  const User({
    required this.id,
    required this.email,
    this.displayName,
    required this.createdAt,
  });

  final String id;
  final String email;

  @JsonKey(name: 'display_name')
  final String? displayName;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  String toString() => 'User(id: $id, email: $email)';
}
```

```bash
# 生成実行
dart run build_runner build --delete-conflicting-outputs

# ウォッチモード (開発中は常時起動)
dart run build_runner watch --delete-conflicting-outputs
```

生成された `user.g.dart` の中身:

```dart
// lib/models/user.g.dart (自動生成 — 手動編集禁止)
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$UserToJson(User instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'email': instance.email,
  };
  void writeNotNull(String key, dynamic value) {
    if (value != null) val[key] = value;
  }
  writeNotNull('display_name', instance.displayName);
  val['created_at'] = instance.createdAt.toIso8601String();
  return val;
}
```

## Step 2: カスタム Builder を作る

自分で `Builder` を実装して、独自のアノテーション + コード生成を作ってみよう。例として、`@Loggable` アノテーションを付けたクラスに自動でログメソッドを追加するジェネレーターを作る。

### パッケージ構成

```
packages/
  loggable_generator/          ← ジェネレーター (別パッケージ)
    pubspec.yaml
    lib/
      loggable_generator.dart
    build.yaml
  
lib/
  models/
    task.dart                  ← @Loggable を使う側
```

### アノテーション定義

```dart
// packages/loggable_generator/lib/src/loggable.dart
class Loggable {
  const Loggable({this.prefix = ''});
  final String prefix;
}

const loggable = Loggable();
```

### Builder の実装

```dart
// packages/loggable_generator/lib/src/loggable_generator.dart
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'loggable.dart';

class LoggableGenerator extends GeneratorForAnnotation<Loggable> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // クラス以外には適用不可
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@Loggable can only be applied to classes.',
        element: element,
      );
    }

    final className = element.name;
    final prefix = annotation.read('prefix').stringValue;
    final logPrefix = prefix.isEmpty ? className : prefix;

    // フィールド一覧からログ用文字列を生成
    final fields = element.fields
        .where((f) => !f.isStatic && !f.isSynthetic)
        .map((f) => '${f.name}: \$${f.name}')
        .join(', ');

    return '''
// ignore_for_file: type=lint

extension \$${className}Loggable on $className {
  /// 自動生成されたログメソッド
  String toLogString() => '[$logPrefix] $fields';

  void log() {
    // ignore: avoid_print
    print(toLogString());
  }
}
''';
  }
}

/// Builder ファクトリ関数
Builder loggableBuilder(BuilderOptions options) =>
    SharedPartBuilder([LoggableGenerator()], 'loggable');
```

### build.yaml の設定

```yaml
# packages/loggable_generator/build.yaml
builders:
  loggable:
    import: "package:loggable_generator/loggable_generator.dart"
    builder_factories: ["loggableBuilder"]
    build_extensions: {".dart": [".loggable.g.part"]}
    auto_apply: dependents
    build_to: source
    applies_builders: ["source_gen|combining_builder"]
```

### 使う側のコード

```dart
// lib/models/task.dart
import 'package:loggable_generator/loggable_generator.dart';
import 'package:json_annotation/json_annotation.dart';

part 'task.g.dart';

@loggable  // ← カスタムアノテーション
@JsonSerializable()
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.isDone,
    required this.createdAt,
  });

  final String id;
  final String title;
  final bool isDone;
  final DateTime createdAt;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
  Map<String, dynamic> toJson() => _$TaskToJson(this);
}

// 使用例:
// final task = Task(id: '1', title: 'ブログ記事を書く', isDone: false, createdAt: DateTime.now());
// task.log();
// => [Task] id: 1, title: ブログ記事を書く, isDone: false, createdAt: 2030-07-27 ...
```

## Step 3: go_router_builder で型安全なナビゲーション

自分株式会社では go_router_builder を使って、ルート名のタイポバグを完全に撲滅した。

```dart
// lib/routes/app_routes.dart
import 'package:go_router/go_router.dart';
import 'package:go_router_builder/go_router_builder.dart';

part 'app_routes.g.dart';  // 自動生成

@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const HomePage();
}

@TypedGoRoute<TaskDetailRoute>(path: '/tasks/:id')
class TaskDetailRoute extends GoRouteData {
  const TaskDetailRoute({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      TaskDetailPage(taskId: id);
}

// 使用例 (型安全 — タイポ不可能)
// HomeRoute().go(context);
// TaskDetailRoute(id: '123').push(context);
```

## Step 4: Dart 3 Macros (実験的機能)

Dart 3.x で実験的導入された Macros は、`build_runner` を不要にする次世代コード生成だ。コンパイル時にクラスを変換でき、`.g.dart` ファイルも生成しない。

```dart
// Dart Macros (experimental — dart 3.5+)
// pubspec.yaml に environment: sdk: '>=3.5.0' が必要

import 'package:macros/macros.dart';

/// JSON シリアライズを自動追加するマクロ
macro class JsonCodable implements ClassDeclarationsMacro {
  const JsonCodable();

  @override
  Future<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    final fields = await builder.fieldsOf(clazz);
    
    // fromJson ファクトリを生成
    final fromJsonCode = fields.map((f) {
      final name = f.identifier.name;
      return "$name: json['$name'] as ${f.type.code}";
    }).join(',\n      ');

    builder.declareInType(DeclarationCode.fromString('''
  factory ${clazz.identifier.name}.fromJson(Map<String, dynamic> json) =>
      ${clazz.identifier.name}(
        $fromJsonCode,
      );
'''));

    // toJson メソッドを生成
    final toJsonCode = fields.map((f) {
      final name = f.identifier.name;
      return "'$name': $name";
    }).join(',\n      ');

    builder.declareInType(DeclarationCode.fromString('''
  Map<String, dynamic> toJson() => {
    $toJsonCode,
  };
'''));
  }
}

// 使い方 (part ディレクティブ不要!)
@JsonCodable()
class User {
  const User({required this.id, required this.email});
  final String id;
  final String email;
  // fromJson / toJson は Macros が自動追加
}
```

> **注意**: Dart Macros は 2030 年時点でまだ実験的機能。本番利用は安定版リリース後を推奨。

## コード生成のベストプラクティス

| プラクティス | 理由 |
|------------|------|
| `.g.dart` を `.gitignore` に追加しない | CI で生成できるが、チーム開発では commit が安全 |
| `watch` は開発時のみ使う | バッテリー消費・CPU 負荷大 |
| `--delete-conflicting-outputs` を CI に付ける | 衝突エラーを防ぐ |
| `part` ディレクティブを必ず書く | 生成ファイルのスコープをファイルに閉じる |
| アノテーションクラスは別パッケージに分ける | 循環依存を防ぐ |

## まとめ

| 段階 | 技術 | 習得難易度 |
|------|------|-----------|
| 使う | `json_serializable`, `freezed` | ★☆☆ |
| 理解する | `source_gen`, `build_runner` 仕組み | ★★☆ |
| 作る | カスタム `Builder` + `build.yaml` | ★★★ |
| 先端 | Dart Macros (実験的) | ★★★ |

Dart のコード生成は「魔法」ではなく、理解すれば自分でも実装できる。まずは `json_serializable` を読み解いて、次に小さなカスタム Builder を作ってみることから始めよう。自分株式会社では `go_router_builder` と `riverpod_generator` の組み合わせで、ルーティングと状態管理の定型コードをほぼゼロにしている。

---

*本記事は自分株式会社 (Flutter Web + Supabase) の実装経験をもとに執筆しました。*
