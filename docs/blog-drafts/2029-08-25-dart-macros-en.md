---
title: "Dart Macros — Compile-time Code Generation Without build_runner"
tags: dart,flutter,webdev,indiedev
published: true
---

# Dart Macros — Compile-time Code Generation Without build_runner

Dart's macro system lets you generate and transform code at compile time — no `build_runner`, no `.g.dart` files. Here's what it means in practice.

## The Problem With build_runner

```dart
// Before macros: json_serializable workflow
// 1. Add dependencies to pubspec.yaml
// 2. Annotate with @JsonSerializable()
// 3. Run: dart run build_runner build (slow)
// 4. Commit the generated *.g.dart file
// 5. Remember to re-run when you change the class 😩

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
// With macros: just annotate and go
@JsonCodable()
class Task {
  final String id;
  final String title;
}
// fromJson and toJson exist immediately — no generated files
```

## How Macros Work

```
Compilation pipeline:
  1. Parse source → AST
  2. Detect @JsonCodable() annotation
  3. Macro reads the AST (field names, types)
  4. Macro emits new declarations inline
  5. Compiler sees the final expanded class

Benefits:
  - No *.g.dart files to commit or gitignore
  - Instant IDE autocomplete (no build step needed)
  - Faster builds (no codegen subprocess)
  - Easier debugging (everything is in one file)
```

## Writing a Simple Macro

```dart
import 'dart:async';
import 'package:macros/macros.dart';

macro class JsonCodable implements ClassDeclarationsMacro {
  const JsonCodable();

  @override
  Future<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    final fields = await builder.fieldsOf(clazz);

    builder.declareInClass(DeclarationCode.fromString(
      _buildFromJson(clazz.identifier, fields),
    ));
    builder.declareInClass(DeclarationCode.fromString(
      _buildToJson(fields),
    ));
  }

  String _buildFromJson(Identifier name, List<FieldDeclaration> fields) {
    final args = fields.map((f) {
      final n = f.identifier.name;
      return "$n: json['$n'] as ${f.type.code}";
    }).join(', ');
    return "factory ${name.name}.fromJson(Map<String, dynamic> json) => ${name.name}($args);";
  }

  String _buildToJson(List<FieldDeclaration> fields) {
    final entries = fields.map((f) {
      final n = f.identifier.name;
      return "'$n': $n";
    }).join(', ');
    return 'Map<String, dynamic> toJson() => {$entries};';
  }
}
```

## Using the Macro

```dart
@JsonCodable()
class Task {
  final String id;
  final String title;
  final DateTime createdAt;
  Task({required this.id, required this.title, required this.createdAt});
}

void main() {
  final task = Task.fromJson({
    'id': 'abc-123',
    'title': 'Write blog post',
    'createdAt': DateTime.now().toIso8601String(),
  });
  print(task.toJson()); // {id: abc-123, title: Write blog post, ...}
}
```

## Macro Types

```dart
// Declarations macro: add fields/methods to a class
class MyMacro implements ClassDeclarationsMacro { ... }

// Definitions macro: provide implementations for declared items
class MyMacro implements ClassDefinitionMacro { ... }

// Types macro: augment type annotations
class MyMacro implements ClassTypesMacro { ... }
```

## Current Status (as of 2029)

```
✅ Stable: @JsonCodable() (official flutter/packages)
✅ Stable: @DataClass() (copyWith, ==, hashCode)
🔶 Experimental: writing custom macros (API may change)
❌ Not supported: reading external files at macro-time
❌ Not supported: runtime execution (compile-time only)
```

## build_runner vs Macros

| Aspect | build_runner | Dart Macros |
|--------|-------------|-------------|
| Generated files | Required (.g.dart) | None |
| IDE autocomplete | After build | Instant |
| Build speed | Slow | Fast |
| Debugging | Hard (separate files) | Easy (inline) |
| Custom logic | `Builder` class | `macro class` |
| Stability | Stable | Partially experimental |

After switching to macros for JSON serialization, our CI build time dropped by 40 seconds — just from eliminating the code generation step.

---

Have you tried Dart macros in a real project? Share your experience below!
