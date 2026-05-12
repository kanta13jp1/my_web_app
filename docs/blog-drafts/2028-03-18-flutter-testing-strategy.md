---
title: "Flutter テスト戦略 — Widget / Integration / Golden テストの使い分け"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter テスト戦略 — Widget / Integration / Golden テストの使い分け

テスト種別を正しく使い分けるだけで、CI が実用的な速度のまま信頼できるものになる。

## テスト選択基準

```
ロジック単体                → Unit test
UI コンポーネント           → Widget test
画面遷移 / DB 連携          → Integration test
デザイン回帰検知            → Golden test
```

## Unit Test: ビジネスロジックの基盤

```dart
// test/services/score_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/score_calculator.dart';

void main() {
  group('ScoreCalculator', () {
    test('returns 0 for empty list', () {
      expect(ScoreCalculator.total([]), equals(0));
    });

    test('sums positive values', () {
      expect(ScoreCalculator.total([10, 20, 30]), equals(60));
    });

    test('ignores negative values', () {
      expect(ScoreCalculator.total([10, -5, 20]), equals(30));
    });
  });
}
```

## Widget Test: UI コンポーネントの検証

```dart
// test/widgets/task_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/task_card.dart';

void main() {
  testWidgets('TaskCard shows title and completion button', (tester) async {
    bool completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(
            title: 'テストタスク',
            onComplete: () => completed = true,
          ),
        ),
      ),
    );

    expect(find.text('テストタスク'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_circle_outline));
    expect(completed, isTrue);
  });

  testWidgets('TaskCard shows completed state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(
            title: '完了タスク',
            isCompleted: true,
            onComplete: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
```

## Integration Test: 画面遷移と Supabase 連携

```dart
// integration_test/task_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ログイン → タスク作成 → 完了の一連フロー', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // ログイン
    await tester.enterText(find.byKey(const Key('email')), 'test@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'password123');
    await tester.tap(find.text('ログイン'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // タスク作成
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task_title')), '統合テスト用タスク');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('統合テスト用タスク'), findsOneWidget);
  });
}
```

## Golden Test: デザイン回帰の検知

```dart
// test/golden/task_card_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/task_card.dart';

void main() {
  testWidgets('TaskCard golden test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(
            child: TaskCard(
              title: 'Golden テスト',
              isCompleted: false,
            ),
          ),
        ),
      ),
    );

    // 初回実行: flutter test --update-goldens でスナップショット生成
    await expectLater(
      find.byType(TaskCard),
      matchesGoldenFile('goldens/task_card.png'),
    );
  });
}
```

## CI 設定 (GHA)

```yaml
# .github/workflows/ci.yml
- name: Flutter test (unit + widget)
  run: flutter test test/ --coverage

- name: Integration test (Chrome)
  run: |
    flutter drive \
      --driver=test_driver/integration_test.dart \
      --target=integration_test/task_flow_test.dart \
      -d chrome

- name: Upload coverage
  uses: codecov/codecov-action@v4
  with:
    file: coverage/lcov.info
```

## まとめ

```
Unit test       → ロジック単体・高速・大量に書く
Widget test     → UI コンポーネント・中速・重要 widget を網羅
Integration     → E2E シナリオ・低速・ゴールデンパス1〜3本
Golden test     → デザイン回帰・初回のみ --update-goldens
```

全部を同じ重さで書こうとすると CI が重くなる。
Unit が 70%・Widget が 25%・Integration が 5% の比率が現実的。
