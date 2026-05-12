---
title: "Flutter テスト上級編 — Integration Test・Mocking・CI 自動化の実践パターン"
tags: flutter,dart,個人開発,AI
published: true
---

## はじめに

Flutter のユニットテストを書けるようになったら、次のステップは **E2E テスト・Mock 戦略・CI 自動化** の組み合わせだ。本稿では `integration_test` パッケージから始めて、mockito/mocktail による依存注入、GitHub Actions での自動化まで実践的なパターンを解説する。

---

## 1. integration_test パッケージで E2E テスト

`flutter_driver` は非推奨になった。現在の公式推奨は `integration_test` パッケージだ。

```yaml
# pubspec.yaml — 2030-01-19-flutter-testing-advanced
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter
```

テストファイルは `integration_test/` ディレクトリに置く。

```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ログインフローの E2E テスト', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // メールフィールドに入力
    await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
    await tester.enterText(find.byKey(const Key('password_field')), 'password123');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('ダッシュボード'), findsOneWidget);
  });
}
```

実行コマンド:

```bash
flutter test integration_test/app_test.dart -d chrome
```

---

## 2. mockito vs mocktail — 依存注入と Mock 作成

### mockito（コード生成方式）

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

  test('ログイン成功時にユーザーを返す', () async {
    when(mockClient.auth.signInWithPassword(
      email: anyNamed('email'),
      password: anyNamed('password'),
    )).thenAnswer((_) async => AuthResponse(/* ... */));

    final result = await authService.login('test@example.com', 'pass');
    expect(result.user, isNotNull);
  });
}
```

`build_runner` でモックを生成:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### mocktail（コード生成不要）

```dart
import 'package:mocktail/mocktail.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  test('mocktail でシンプルに Mock', () async {
    final mock = MockSupabaseClient();
    when(() => mock.from('users').select()).thenReturn(MockPostgrestFilterBuilder());
    // ...
  });
}
```

---

## 3. Supabase Mock Client パターン

Supabase は `SupabaseClient` をインターフェース越しに使うと Mock しやすい。

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

// テスト用 Fake 実装
class FakeSupabaseRepository implements ISupabaseRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    return [{'id': 1, 'title': 'テストタスク', 'done': false}];
  }
}
```

---

## 4. GitHub Actions での `flutter test --machine` 実行

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

`--machine` フラグで JSON 出力が得られるため、テスト結果を後続ステップで集計できる。

---

## 5. Golden Test の CI 自動更新パターン

Golden Test はスナップショットテストだ。UI が意図的に変わったときは `--update-goldens` フラグで更新する。

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

PR ブランチでは更新せず差分を検出、main マージ後に自動更新することで誤コミットを防げる。

---

## まとめ

| 手法 | 使いどころ |
|------|-----------|
| `integration_test` | E2E / ウィジェット結合テスト |
| mockito | 型安全な Mock（コード生成あり） |
| mocktail | 手軽な Mock（コード生成なし） |
| `--machine` + GHA | CI でのテスト結果集計 |
| Golden Test 自動更新 | UI 変更の意図的スナップショット管理 |

テスト戦略はピラミッド型（Unit → Widget → Integration）で積み上げるのが鉄則だ。まず Unit テストを充実させ、その上に Integration Test を薄く乗せると保守コストを最小化できる。
