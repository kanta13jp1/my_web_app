---
title: "Publishing a Dart Package to pub.dev — pubspec, dartdoc, and Automated CI"
tags: dart,flutter,programming,indiedev
published: true
---

Publishing an open-source Dart package is one of the highest-leverage things an indie developer can do: it builds your reputation, drives traffic, and forces you to write cleaner code. This guide walks you through every step — package structure, pubspec setup, API docs, testing, and a fully automated GitHub Actions publish pipeline.

## 1. Package Structure

```text
my_package/
  lib/
    my_package.dart          # Main export barrel file
    src/
      feature_a.dart         # Implementation (not for direct import)
      feature_b.dart
  example/
    lib/
      main.dart              # Shown on pub.dev
  test/
    feature_a_test.dart
    feature_b_test.dart
  CHANGELOG.md               # Required — follows keep-a-changelog format
  LICENSE                    # Required — MIT or BSD-3 recommended
  README.md                  # pub.dev landing page
  pubspec.yaml               # Package metadata
```

## 2. pubspec.yaml

```yaml
name: my_flutter_utils
description: >-
  Flutter utilities for debounced search, infinite scroll,
  form validation, and common UI patterns.
version: 1.0.0
homepage: https://github.com/your-org/my_flutter_utils
repository: https://github.com/your-org/my_flutter_utils
issue_tracker: https://github.com/your-org/my_flutter_utils/issues

# Explicitly list supported platforms (affects pub.dev score)
platforms:
  android:
  ios:
  linux:
  macos:
  web:
  windows:

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.19.0'

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  pana: ^0.21.0
```

### Semantic Versioning Rules

```text
MAJOR.MINOR.PATCH  e.g. 2.1.3

MAJOR — breaking changes (removed/renamed public APIs)
MINOR — backward-compatible new features
PATCH — bug fixes and internal improvements

Pre-release suffixes:
  1.0.0-beta.1   beta
  1.0.0-rc.1     release candidate
  2.0.0-dev.1    dev snapshot

Version constraints for dependencies:
  ^1.2.3           = >=1.2.3 <2.0.0  (recommended — pin MAJOR)
  >=1.0.0 <3.0.0   = allow two major versions
```

## 3. Writing dartdoc Comments

pub.dev scores heavily weight API documentation coverage. Every public member needs a `///` doc comment with a code example.

```dart
/// A search service that delays execution until input settles.
///
/// When [search] is called repeatedly within [duration],
/// only the last call executes. Ideal for search-as-you-type UIs
/// where you don't want to fire an API request on every keystroke.
///
/// ```dart
/// final service = DebouncedSearchService(
///   duration: const Duration(milliseconds: 300),
///   onSearch: (query) async {
///     final results = await api.search(query);
///     setState(() => _results = results);
///   },
/// );
///
/// // Wire up to a TextField
/// TextField(
///   onChanged: service.search,
/// );
/// ```
///
/// Remember to call [dispose] to cancel any pending timer:
/// ```dart
/// @override
/// void dispose() {
///   service.dispose();
///   super.dispose();
/// }
/// ```
///
/// See also:
///   - [ThrottledSearchService] for leading-edge execution
///   - [CachedSearchService] for memoized results
class DebouncedSearchService {
  /// How long to wait after the last [search] call before executing.
  ///
  /// Defaults to 300 milliseconds.
  final Duration duration;

  /// Called with the final query string after [duration] elapses.
  ///
  /// Must return a [Future]. Exceptions are forwarded to [onError].
  final Future<void> Function(String query) onSearch;

  /// Optional error handler.
  ///
  /// If omitted, errors from [onSearch] are silently swallowed.
  final void Function(Object error, StackTrace stack)? onError;

  Timer? _timer;

  /// Creates a [DebouncedSearchService].
  ///
  /// Both [duration] and [onSearch] are required.
  DebouncedSearchService({
    this.duration = const Duration(milliseconds: 300),
    required this.onSearch,
    this.onError,
  });

  /// Schedules a search for [query].
  ///
  /// If called again within [duration], the previous call is cancelled.
  void search(String query) {
    _timer?.cancel();
    _timer = Timer(duration, () async {
      try {
        await onSearch(query);
      } catch (e, s) {
        onError?.call(e, s);
      }
    });
  }

  /// Cancels any pending search and frees resources.
  ///
  /// After calling [dispose], do not call [search] again.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
```

### Barrel File with Library-level Docs

```dart
// lib/my_flutter_utils.dart
/// Utility toolkit for Flutter apps.
///
/// ## Features
///
/// - **Search**: [DebouncedSearchService], [ThrottledSearchService]
/// - **Forms**: [EmailValidator], [PasswordStrengthMeter]
/// - **Scroll**: [InfiniteScrollController], [PaginatedListView]
///
/// ## Quick start
///
/// ```dart
/// import 'package:my_flutter_utils/my_flutter_utils.dart';
///
/// final search = DebouncedSearchService(
///   onSearch: (q) async { /* call your API */ },
/// );
/// ```
library my_flutter_utils;

export 'src/search/debounced_search_service.dart';
export 'src/search/throttled_search_service.dart';
export 'src/forms/email_validator.dart';
export 'src/forms/password_strength_meter.dart';
export 'src/scroll/infinite_scroll_controller.dart';
export 'src/scroll/paginated_list_view.dart';
```

## 4. Writing Tests

```dart
// test/debounced_search_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_utils/my_flutter_utils.dart';

void main() {
  group('DebouncedSearchService', () {
    late DebouncedSearchService sut;
    final calls = <String>[];

    setUp(() {
      calls.clear();
      sut = DebouncedSearchService(
        duration: const Duration(milliseconds: 100),
        onSearch: (q) async => calls.add(q),
      );
    });

    tearDown(sut.dispose);

    test('executes after delay', () async {
      sut.search('flutter');
      expect(calls, isEmpty);

      await Future.delayed(const Duration(milliseconds: 150));
      expect(calls, ['flutter']);
    });

    test('only executes the last call when debounced', () async {
      for (final q in ['f', 'fl', 'flu', 'flut', 'flutt', 'flutter']) {
        sut.search(q);
      }

      await Future.delayed(const Duration(milliseconds: 150));
      expect(calls, ['flutter']); // only the last one
    });

    test('resets timer on new call', () async {
      sut.search('first');
      await Future.delayed(const Duration(milliseconds: 60));
      sut.search('second'); // resets timer

      await Future.delayed(const Duration(milliseconds: 80));
      expect(calls, isEmpty); // neither has fired yet

      await Future.delayed(const Duration(milliseconds: 70));
      expect(calls, ['second']);
    });

    test('does not fire after dispose', () async {
      sut.search('query');
      sut.dispose();

      await Future.delayed(const Duration(milliseconds: 150));
      expect(calls, isEmpty);
    });

    test('routes errors to onError handler', () async {
      Object? caught;
      final errorSut = DebouncedSearchService(
        onSearch: (_) async => throw StateError('boom'),
        onError: (e, _) => caught = e,
      );

      errorSut.search('q');
      await Future.delayed(const Duration(milliseconds: 150));

      expect(caught, isA<StateError>());
      errorSut.dispose();
    });
  });
}
```

## 5. CHANGELOG.md Format

```markdown
## Unreleased

## 1.1.0 — 2030-08-15

### Added
- `DebouncedSearchService`: `onError` callback parameter
- `EmailValidator`: internationalized domain names (IDN) support

### Fixed
- `InfiniteScrollController`: memory leak on dispose

## 1.0.1 — 2030-07-20

### Changed
- `PaginatedListView`: improved loading indicator styling

## 1.0.0 — 2030-07-01

- Initial release
```

## 6. GitHub Actions — Automated Publishing

```yaml
# .github/workflows/pub-publish.yml
name: Publish to pub.dev

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+*'   # v1.0.0, v2.0.0-beta.1, etc.

permissions:
  id-token: write   # Required for pub.dev OIDC authentication

jobs:
  test:
    name: Test & Analyze
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - name: Install dependencies
        run: dart pub get

      - name: Check formatting
        run: dart format --output=none --set-exit-if-changed .

      - name: Analyze
        run: dart analyze --fatal-infos

      - name: Run tests with coverage
        run: dart test --coverage=coverage

      - name: Enforce ≥80% coverage
        run: |
          dart pub global activate coverage
          dart pub global run coverage:format_coverage \
            --lcov --in=coverage --out=coverage/lcov.info \
            --report-on=lib
          total=$(grep -c "^DA:" coverage/lcov.info)
          hit=$(grep -cP "^DA:\d+,[^0]" coverage/lcov.info)
          pct=$(( hit * 100 / total ))
          echo "Coverage: $pct% ($hit/$total lines)"
          [ "$pct" -ge 80 ] || (echo "Coverage below 80%" && exit 1)

  score-check:
    name: pub.dev Score Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      - run: dart pub get

      - name: Run pana
        run: |
          dart pub global activate pana
          dart pub global run pana --no-warning . | tee pana.txt
          score=$(grep -oP 'Points: \K\d+(?=/\d+)' pana.txt | head -1 || echo 0)
          echo "pub.dev score: $score / 140"
          [ "${score:-0}" -ge 120 ] || echo "::warning::Score below 120"

  publish:
    name: Publish
    needs: [test, score-check]
    runs-on: ubuntu-latest
    environment: pub-publish  # Require manual approval in GitHub Environments
    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - run: dart pub get

      - name: Dry run
        run: dart pub publish --dry-run

      - name: Publish
        run: dart pub publish --force
        # No secrets needed — OIDC auth via id-token permission above
```

### Tag and Release

```bash
# 1. Bump version in pubspec.yaml and update CHANGELOG.md
vim pubspec.yaml        # version: 1.1.0
vim CHANGELOG.md        # Add ## 1.1.0 section

# 2. Commit
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: release v1.1.0"

# 3. Tag — this triggers the GHA workflow
git tag v1.1.0
git push origin main --tags

# 4. Watch the workflow
gh run watch
```

## 7. pub.dev Score Checklist

| Check | Weight | Action |
|-------|--------|--------|
| `dart analyze` passes | High | Add `flutter_lints`, fix all warnings |
| API docs ≥20% public members | High | `///` on every public API |
| LICENSE file present | Required | MIT or BSD-3 |
| CHANGELOG.md present | Required | keep-a-changelog format |
| README.md (English) | High | Badges + quick start + screenshots |
| `example/` folder | High | Shown on pub.dev package page |
| All platforms declared | Medium | `platforms:` in pubspec.yaml |
| `--dry-run` passes | Required | Always check before tagging |

## Summary

A well-published Dart package needs:

1. **pubspec.yaml** — accurate platforms, SDK range, and description
2. **dartdoc** — every public API documented with runnable code samples
3. **Tests** — 80%+ coverage and edge cases covered
4. **CHANGELOG.md** — human-readable release notes
5. **CI** — pana score gate + OIDC automated publish on tag

Start small: publish one utility class you've already written. The process of making it package-worthy — good docs, tests, a clean API — will make you a better developer. Your pub.dev profile becomes part of your portfolio.
