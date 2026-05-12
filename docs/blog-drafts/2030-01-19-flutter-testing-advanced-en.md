---
title: "Flutter Testing Advanced — Integration Tests, Mocking, and CI Automation"
tags: flutter,dart,webdev,indiedev
published: true
---

## Introduction

Once you've mastered unit testing in Flutter, the next step is combining **E2E tests, mocking strategies, and CI automation**. This article walks through practical patterns using `integration_test`, mockito/mocktail, and GitHub Actions — everything you need to build a production-grade test suite.

---

## 1. E2E Testing with the `integration_test` Package

`flutter_driver` is deprecated. The current official recommendation is the `integration_test` package.

```yaml
# pubspec.yaml — 2030-01-19-flutter-testing-advanced-en
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter
```

Place test files in the `integration_test/` directory:

```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E login flow test', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Enter credentials
    await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
    await tester.enterText(find.byKey(const Key('password_field')), 'password123');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Dashboard'), findsOneWidget);
  });
}
```

Run it with:

```bash
flutter test integration_test/app_test.dart -d chrome
```

---

## 2. mockito vs mocktail — Dependency Injection and Mock Creation

### mockito (code generation approach)

```dart
// test/auth_service_test.dart
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'auth_service_test.mocks.dart';

@GenerateMocks([SupabaseClient])
void main() {
  late MockSupabaseClient mockClient;
  late AuthService authService;

  setUp(() {
    mockClient = MockSupabaseClient();
    authService = AuthService(client: mockClient);
  });

  test('returns user on successful login', () async {
    when(mockClient.auth.signInWithPassword(
      email: anyNamed('email'),
      password: anyNamed('password'),
    )).thenAnswer((_) async => AuthResponse(/* ... */));

    final result = await authService.login('test@example.com', 'pass');
    expect(result.user, isNotNull);
  });
}
```

Generate mocks with `build_runner`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### mocktail (no code generation required)

```dart
import 'package:mocktail/mocktail.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  test('simple mock with mocktail', () async {
    final mock = MockSupabaseClient();
    when(() => mock.from('users').select()).thenReturn(MockPostgrestFilterBuilder());
    // ...
  });
}
```

mocktail shines for quick tests where the overhead of code generation isn't worth it.

---

## 3. Supabase Mock Client Pattern

Design your repositories behind an interface to make Supabase easy to mock:

```dart
abstract class ISupabaseRepository {
  Future<List<Map<String, dynamic>>> fetchTasks();
}

class SupabaseRepository implements ISupabaseRepository {
  final SupabaseClient _client;
  SupabaseRepository(this._client);

  @override
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    final response = await _client.from('tasks').select();
    return List<Map<String, dynamic>>.from(response);
  }
}

// Fake implementation for tests — no network calls
class FakeSupabaseRepository implements ISupabaseRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    return [{'id': 1, 'title': 'Test Task', 'done': false}];
  }
}
```

Inject `FakeSupabaseRepository` in your widget tests to keep them fast and deterministic.

---

## 4. Running `flutter test --machine` in GitHub Actions

```yaml
# .github/workflows/flutter-test.yml
name: Flutter Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Run unit & widget tests
        run: flutter test --machine | tee test-results.json

      - name: Run integration tests (Chrome)
        run: |
          flutter test integration_test/ -d chrome \
            --machine | tee integration-results.json
```

The `--machine` flag emits JSON output — ideal for aggregating results or feeding into test reporting tools.

---

## 5. Automatically Updating Golden Tests in CI

Golden tests capture UI snapshots. When the UI intentionally changes, update them using `--update-goldens`:

```yaml
      - name: Update goldens on main branch
        if: github.ref == 'refs/heads/main'
        run: flutter test --update-goldens test/golden/

      - name: Commit updated goldens
        if: github.ref == 'refs/heads/main'
        uses: stefanzweifel/git-auto-commit-action@v5
        with:
          commit_message: 'chore: update golden test snapshots'
          file_pattern: 'test/golden/*.png'
```

On PR branches, goldens are not updated — the CI simply reports diffs. After merging to main, they are updated automatically. This prevents accidental snapshot drift while still catching unintended visual regressions.

---

## Summary

| Technique | Best for |
|-----------|----------|
| `integration_test` | E2E / widget integration tests |
| mockito | Type-safe mocks with code generation |
| mocktail | Quick mocks without code generation |
| `--machine` + GHA | Aggregating CI test results |
| Golden test auto-update | Managing intentional UI snapshot changes |

Think of your test suite as a pyramid: Unit tests at the base (fast and numerous), widget tests in the middle, and a thin layer of integration tests at the top. This structure minimizes maintenance cost while maximizing confidence in your Flutter app.
