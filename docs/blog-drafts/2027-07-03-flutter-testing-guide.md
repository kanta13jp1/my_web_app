---
title: "Flutter テスト完全ガイド — Unit / Widget / Integration の使い分け"
tags: flutter,AI,個人開発,buildinpublic
published: true
---

# Flutter テスト完全ガイド — Unit / Widget / Integration の使い分け

Flutter には3種類のテストがある。「どれをいつ使うか」が分かれば、テストが怖くなくなる。個人開発で実際に使っているパターンを公開する。

## テスト3層の役割

```
Unit Test:        ロジック単体を高速検証 (ミリ秒)
Widget Test:      UI コンポーネントを検証 (秒)
Integration Test: アプリ全体をエミュレータで検証 (分)
```

ピラミッドの下から充実させる。Unit が土台。Integration はコストが高い。

## Unit Test: ビジネスロジックを守る

```yaml
# pubspec.yaml
dev_dependencies:
  test: ^1.24.0
```

```dart
// lib/utils/score_calculator.dart
class ScoreCalculator {
  static double calculate(int correct, int total) {
    if (total == 0) return 0;
    return correct / total * 100;
  }
}

// test/utils/score_calculator_test.dart
import 'package:test/test.dart';
import 'package:my_app/utils/score_calculator.dart';

void main() {
  group('ScoreCalculator', () {
    test('正しい割合を返す', () {
      expect(ScoreCalculator.calculate(8, 10), equals(80.0));
    });

    test('total が 0 の場合は 0 を返す', () {
      expect(ScoreCalculator.calculate(0, 0), equals(0.0));
    });
  });
}
```

```bash
flutter test test/utils/  # Unit のみ実行
```

## Widget Test: UI の振る舞いを守る

```dart
// test/widgets/achievement_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/achievement_card.dart';

void main() {
  testWidgets('タイトルと説明が表示される', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AchievementCard(
          title: 'テスト実装完了',
          description: '初めてのテストを書いた',
        ),
      ),
    );

    expect(find.text('テスト実装完了'), findsOneWidget);
    expect(find.text('初めてのテストを書いた'), findsOneWidget);
  });

  testWidgets('タップでコールバックが呼ばれる', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AchievementCard(
          title: 'テスト',
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(AchievementCard));
    expect(tapped, isTrue);
  });
}
```

## Riverpod のテスト: ProviderScope overrides

```dart
// Riverpod を使っている場合の Widget Test
testWidgets('データ取得中は Loading を表示', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        achievementsProvider.overrideWith(
          (_) async {
            await Future.delayed(const Duration(seconds: 1));
            return [];
          },
        ),
      ],
      child: const MaterialApp(home: AchievementsPage()),
    ),
  );

  // pump だけ (settle しない → Loading 状態)
  await tester.pump();
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // settle → データ表示
  await tester.pumpAndSettle();
  expect(find.byType(CircularProgressIndicator), findsNothing);
});
```

## Supabase のモック

```dart
// test/helpers/mock_supabase.dart
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}

// テストで使う
setUp(() {
  final mockClient = MockSupabaseClient();
  final mockAuth = MockGoTrueClient();
  when(() => mockClient.auth).thenReturn(mockAuth);
  when(() => mockAuth.currentUser).thenReturn(null);  // 未ログイン
});
```

## Integration Test: E2E フロー検証

```dart
// integration_test/login_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ログインからホームまで', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // ログイン画面
    await tester.enterText(find.byKey(const Key('email')), 'test@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'password');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    // ホーム画面に遷移
    expect(find.text('ホーム'), findsOneWidget);
  });
}
```

```bash
flutter test integration_test/ --device-id emulator-5554
```

## CI での自動実行

```yaml
# .github/workflows/ci.yml
- name: Unit + Widget Tests
  run: flutter test --coverage

- name: Coverage check
  run: |
    lcov --summary coverage/lcov.info
    # カバレッジ 70% 未満なら fail
```

## どこから始めるか

```
Step 1: 重要なビジネスロジックに Unit Test を書く
Step 2: 繰り返し手動テストしている Widget に Widget Test を書く
Step 3: 重要なユーザーフローに Integration Test を 1 本書く
```

Unit から始めて、少しずつ積み上げる。完璧を目指さない。テストがないよりある方が常に良い。

## まとめ

- **Unit**: ロジック変更を安全に。一番コスパが高い
- **Widget**: UI の退行バグを防ぐ。Riverpod overrides で依存を切る
- **Integration**: ユーザーフロー全体を守る。コストが高いので主要フローのみ

個人開発でも「壊れないコード」を作る習慣がスケールの土台になる。
