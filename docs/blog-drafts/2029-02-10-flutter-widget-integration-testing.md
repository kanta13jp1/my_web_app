---
title: "Flutter テスト完全ガイド — Widget テスト・Integration テストで品質を担保する"
tags: flutter,dart,AI,個人開発
published: true
---

# Flutter テスト完全ガイド — Widget テスト・Integration テストで品質を担保する

インディー開発でも品質維持は重要です。Unit テスト・Widget テスト・Integration テストの 3 層で Flutter アプリをテストする方法を解説します。

## テストの 3 層

| 種類 | 速度 | 信頼性 | 用途 |
|------|------|--------|------|
| **Unit** | ⚡ 最速 | ロジックのみ | ビジネスロジック・計算・変換 |
| **Widget** | 🚀 速い | UI + ロジック | Widget の表示・操作・状態 |
| **Integration** | 🐢 遅い | 本物に近い | 画面遷移・API・全体フロー |

## セットアップ

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mockito: ^5.4.4
  build_runner: ^2.4.9
  fake_supabase: ^0.1.0  # Supabase モック
```

## Unit テスト

```dart
// test/unit/horse_score_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/horse_score_calculator.dart';

void main() {
  group('HorseScoreCalculator', () {
    late HorseScoreCalculator calculator;

    setUp(() {
      calculator = HorseScoreCalculator();
    });

    test('popularscore bonus: 1番人気は +0.05', () {
      final score = calculator.calculatePopularityBonus(rank: 1);
      expect(score, closeTo(0.05, 0.001));
    });

    test('age optimal: 4歳は +0.02', () {
      final score = calculator.calculateAgeBonus(age: 4);
      expect(score, closeTo(0.02, 0.001));
    });

    test('weight stability: ±2kg以内は +0.01', () {
      final score = calculator.calculateWeightBonus(
        previousWeight: 460,
        currentWeight: 461,
      );
      expect(score, closeTo(0.01, 0.001));
    });
  });
}
```

## Widget テスト

```dart
// test/widget/metric_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/metric_card.dart';

void main() {
  group('MetricCard', () {
    testWidgets('ラベルと値が正しく表示される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricCard(
              label: 'MRR',
              value: '¥98,000',
              trend: '+¥12,000',
              trendColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.text('MRR'), findsOneWidget);
      expect(find.text('¥98,000'), findsOneWidget);
      expect(find.text('+¥12,000'), findsOneWidget);
    });

    testWidgets('trend が null のとき trend テキストは表示しない', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricCard(label: 'LTV', value: '¥32,000'),
          ),
        ),
      );

      expect(find.text('¥32,000'), findsOneWidget);
      // trend なし → trend widget は存在しない
    });
  });
}
```

## Riverpod Provider のテスト

```dart
// test/widget/home_page_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/pages/home_page.dart';
import 'package:my_app/providers/metrics_provider.dart';

void main() {
  testWidgets('メトリクス表示: MRR が正しく表示される', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          metricsProvider.overrideWith((ref) async => Metrics(
            mrr: 98000,
            churnRate: 2.1,
            ltv: 32000,
            activeSubscriptions: 100,
          )),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('¥98,000'), findsOneWidget);
    expect(find.text('2.1%'), findsOneWidget);
  });
}
```

## Integration テスト

```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ログイン → ホーム画面', () {
    testWidgets('メールログインが成功する', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // ログイン画面
      expect(find.byKey(const Key('login_page')), findsOneWidget);

      // メールアドレス入力
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'password123',
      );

      // ログインボタンタップ
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // ホーム画面に遷移
      expect(find.byKey(const Key('home_page')), findsOneWidget);
    });
  });
}
```

## GitHub Actions での自動実行

```yaml
# .github/workflows/flutter-test.yml
name: Flutter Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Run unit & widget tests
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: coverage/lcov.info
```

## カバレッジの確認

```bash
# テスト実行 + カバレッジ生成
flutter test --coverage

# HTML レポート生成 (lcov 必要)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## まとめ

Unit → Widget → Integration の 3 層テストで品質を段階的に担保します。Riverpod の `overrideWith` で外部依存をモックし、GitHub Actions で自動化することで、インディー開発でも CI/CD による品質管理が実現できます。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
