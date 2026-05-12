---
title: "Dart Macros — Compile-time Code Generation Without Build Runner"
tags: dart,flutter,webdev,indiedev
published: true
---

# Dart Macros — Compile-time Code Generation Without Build Runner

Dart 3.4 (Flutter 3.22) introduced Dart Macros as an experimental feature: compile-time code generation that works without `build_runner`. A single annotation can auto-generate `fromJson`/`toJson`, `copyWith`, or `Equatable`-style equality — all processed directly by the compiler.

## What Are Dart Macros? Key Differences from build_runner

Traditional `build_runner`-based code generation has two pain points:

1. **Slow build steps**: You must manually run `dart run build_runner build`, which can take seconds to minutes on large projects
2. **Generated file clutter**: The `.g.dart` files need to be committed (or `.gitignore`d), causing team disagreements

Dart Macros are processed by the compiler itself, eliminating the separate build step. IDE autocomplete works immediately, and there are no `.g.dart` files written to disk.

| | build_runner | Dart Macros |
|---|---|---|
| Build execution | Manual or watch mode | Not needed (compiler-integrated) |
| Generated files | `.g.dart` files on disk | No generated files |
| IDE completion | Available after build | Immediate |
| Maturity | Stable (Production ready) | Experimental (as of Dart 3.4) |

## Auto-generating fromJson/toJson with @JsonCodable

`@JsonCodable` is the first official Dart macro. Add it to a class and JSON serialization is generated automatically.

```dart
// pubspec.yaml additions:
// dependencies:
//   json: ^0.20.0   # macros-based JSON package
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

// The above automatically makes available:
// UserProfile.fromJson(Map<String, dynamic> json)
// Map<String, dynamic> toJson()

// Usage
final profile = UserProfile.fromJson({
  'id': 'uuid-123',
  'display_name': 'Kanta',
  'avatar_url': null,
  'created_at': '2026-04-29T12:00:00Z',
});
print(profile.toJson());
// {id: uuid-123, displayName: Kanta, ...}
```

Previously, achieving the same with `json_serializable` required `@JsonSerializable()`, running `build_runner`, and committing the `.g.dart` output. Macros eliminate all of that.

## Writing a Custom Macro with ClassDeclarationMacro

To create your own macro, implement the `ClassDeclarationsMacro` interface using the `macro` keyword.

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
    // Introspect the class fields at compile time
    final fields = await builder.fieldsOf(clazz);

    final params = fields.map((f) {
      final typeName = f.type.code.debugString;
      return '${typeName}? ${f.identifier.name}';
    }).join(', ');

    final assignments = fields.map((f) {
      final name = f.identifier.name;
      return '$name: $name ?? this.$name';
    }).join(', ');

    // Inject the copyWith method into the class
    builder.declareInClass(DeclarationCode.fromString('''
      ${clazz.identifier.name} copyWith({$params}) {
        return ${clazz.identifier.name}($assignments);
      }
    '''));
  }
}
```

```dart
// Using the custom macro
@CopyWith()
class Post {
  final String id;
  final String title;
  final String body;
  const Post({required this.id, required this.title, required this.body});
}

// copyWith is now available without any generated file
final updated = post.copyWith(title: 'New Title');
```

## Flutter Use Cases — Equatable Replacement

Value equality (needed for widget rebuild optimization and unit tests) is a natural target for macros.

```dart
// ValueEquality macro — replaces Equatable package
macro class ValueEquality implements ClassDeclarationsMacro {
  const ValueEquality();

  @override
  Future<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    final fields = await builder.fieldsOf(clazz);
    final fieldList = fields.map((f) => f.identifier.name).join(', ');

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

// Stack macros freely
@ValueEquality()
@CopyWith()
class FilterState {
  final String query;
  final List<String> tags;
  final bool showCompleted;
  const FilterState({
    required this.query,
    required this.tags,
    required this.showCompleted,
  });
}

// Both == and copyWith work without build_runner
final next = state.copyWith(query: 'flutter');
print(state == next); // false
```

## Current Limitations and Caveats

Dart Macros are experimental as of Dart 3.4. Be aware of these constraints before adopting them in production:

1. **Requires experiment flag**: Must enable `macros` in `pubspec.yaml` under `dart: experiments:`
2. **Limited pub.dev ecosystem**: Few packages use macros yet; the ecosystem is still maturing
3. **Harder to debug**: Macro errors can be more cryptic than build_runner errors
4. **Platform coverage not guaranteed**: Test on Web, iOS, and Android separately
5. **API is not stable**: The macro API may change in future Dart versions

```yaml
# pubspec.yaml: enabling the experiment
environment:
  sdk: '>=3.4.0 <4.0.0'

dart:
  experiments:
    - macros
```

**Recommended approach for production apps**: Use `@JsonCodable` for new data models if you're already on Dart 3.4+ and comfortable with experimental features. For `copyWith` and `Equatable`, stick with `freezed` + `build_runner` until macros stabilize — the `freezed` ecosystem is battle-tested and offers additional features like sealed classes.

## Summary

Dart Macros are the future replacement for `build_runner`, but today they remain experimental. `@JsonCodable` is worth trying on greenfield projects. Custom macros using `ClassDeclarationsMacro` are powerful for eliminating boilerplate, but the API will likely evolve before Dart 4.0 stabilizes them. Learn the concepts now, adopt carefully in production.
