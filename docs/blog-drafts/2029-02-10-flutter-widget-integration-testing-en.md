---
title: "Flutter Testing Complete Guide — Widget & Integration Tests for Quality Assurance"
tags: flutter,dart,ai,indiedev
published: true
---

# Flutter Testing Complete Guide — Widget & Integration Tests for Quality Assurance

Quality matters even in indie development. This guide covers the three-layer testing approach — Unit, Widget, and Integration — to keep your Flutter app reliable.

## The Three Testing Layers

| Type | Speed | Confidence | Best For |
|------|-------|-----------|---------|
| **Unit** | ⚡ Fastest | Logic only | Business logic, calculations |
| **Widget** | 🚀 Fast | UI + Logic | Widget rendering, user interaction |
| **Integration** | 🐢 Slow | Near-real | Screen flows, APIs, full journeys |

## Setup

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mockito: ^5.4.4
  build_runner: ^2.4.9
```

## Unit Tests

```dart
// test/unit/score_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/score_calculator.dart';

void main() {
  group('ScoreCalculator', () {
    late ScoreCalculator calculator;
    setUp(() => calculator = ScoreCalculator());

    test('popularity bonus: rank 1 returns +0.05', () {
      expect(calculator.calculatePopularityBonus(rank: 1), closeTo(0.05, 0.001));
    });

    test('age bonus: 4 years old returns +0.02', () {
      expect(calculator.calculateAgeBonus(age: 4), closeTo(0.02, 0.001));
    });

    test('weight stability: within ±2kg returns +0.01', () {
      expect(
        calculator.calculateWeightBonus(previous: 460, current: 461),
        closeTo(0.01, 0.001),
      );
    });
  });
}
```

## Widget Tests

```dart
// test/widget/metric_card_test.dart
void main() {
  group('MetricCard', () {
    testWidgets('renders label and value correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricCard(
              label: 'MRR',
              value: '\$980',
              trend: '+\$120',
              trendColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.text('MRR'), findsOneWidget);
      expect(find.text('\$980'), findsOneWidget);
      expect(find.text('+\$120'), findsOneWidget);
    });

    testWidgets('does not render trend when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MetricCard(label: 'LTV', value: '\$320')),
        ),
      );
      expect(find.text('\$320'), findsOneWidget);
    });
  });
}
```

## Testing Riverpod Providers

```dart
// test/widget/home_page_test.dart
void main() {
  testWidgets('displays MRR from provider', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          metricsProvider.overrideWith((ref) async => Metrics(
            mrr: 980,
            churnRate: 2.1,
            ltv: 320,
            activeSubscriptions: 100,
          )),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('\$980'), findsOneWidget);
    expect(find.text('2.1%'), findsOneWidget);
  });
}
```

## Integration Tests

```dart
// integration_test/app_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login → Home flow', () {
    testWidgets('email login succeeds', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_page')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), 'password123');
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byKey(const Key('home_page')), findsOneWidget);
    });
  });
}
```

## GitHub Actions CI

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
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v4
        with:
          file: coverage/lcov.info
```

## Coverage Check

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Summary

The Unit → Widget → Integration testing pyramid gives you fast feedback at each layer. Riverpod's `overrideWith` makes mocking external dependencies clean. Automate with GitHub Actions so every PR gets tested without manual effort.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
