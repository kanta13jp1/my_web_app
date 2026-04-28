---
title: "Flutter Testing Strategy: Unit, Widget, Integration, and Golden Tests"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Testing Strategy: Unit, Widget, Integration, and Golden Tests

"No time to write tests" vs "losing time to bugs" — which costs more? A practical guide to all four Flutter test types.

## The Testing Pyramid

```
       /Golden\        ← few (UI snapshots)
      /Integration\    ← moderate (full screen flows)
     /  Widget    \    ← more (widget-level)
    /    Unit      \   ← most (business logic)
```

## Unit Tests: Guarantee Logic Correctness

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/kpi_calculator.dart';

void main() {
  group('KpiCalculator', () {
    test('calculates DAU/MAU ratio correctly', () {
      final calc = KpiCalculator();
      expect(calc.dauMauRatio(dau: 100, mau: 500), equals(0.20));
    });

    test('returns 0 when MAU is 0', () {
      expect(KpiCalculator().dauMauRatio(dau: 0, mau: 0), equals(0.0));
    });

    test('MRR growth rate: 10000 → 12000 = 20%', () {
      expect(
        KpiCalculator().mrrGrowthRate(previous: 10000, current: 12000),
        equals(0.20),
      );
    });
  });
}
```

## Widget Tests: Test UI Components in Isolation

```dart
testWidgets('KpiCard shows title and value', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: KpiCard(title: 'MAU', value: '1,234', trend: 0.15),
    ),
  );

  expect(find.text('MAU'),   findsOneWidget);
  expect(find.text('1,234'), findsOneWidget);
  expect(find.text('+15%'),  findsOneWidget);
});

testWidgets('negative trend renders in red', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: KpiCard(title: 'Churn', value: '5%', trend: -0.03),
    ),
  );

  final text = tester.widget<Text>(find.text('-3%'));
  expect(text.style?.color, equals(Colors.red));
});
```

**Mocking Riverpod providers**:

```dart
testWidgets('shows username from provider', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(
          (ref) => Future.value(Profile(id: '1', username: 'test_user')),
        ),
      ],
      child: const MaterialApp(home: ProfilePage()),
    ),
  );

  await tester.pump();
  expect(find.text('test_user'), findsOneWidget);
});
```

## Integration Tests: Test Full Screen Flows

```dart
// integration_test/login_flow_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('magic link login flow', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('email_field')),
      'test@example.com',
    );

    await tester.tap(find.byKey(const Key('send_magic_link_button')));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
  });
}
```

**Run in CI**:

```yaml
- name: Integration tests (Chrome)
  run: |
    flutter test integration_test/ \
      -d chrome \
      --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
      --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
```

## Golden Tests: Protect Visual Appearance

```dart
testGoldens('KpiDashboard layout is stable', (tester) async {
  await tester.pumpWidgetBuilder(
    const KpiDashboard(),
    surfaceSize: const Size(375, 812),  // iPhone 12
  );

  await screenMatchesGolden(tester, 'kpi_dashboard');
  // First run: generates goldens/kpi_dashboard.png
  // Subsequent runs: pixel-diff against saved PNG → fails on changes
});
```

**Update goldens after intentional design changes**:

```bash
flutter test --update-goldens test/golden/
```

## Decision Guide

```
Business logic (math, validation, transforms) → Unit
Widget display + interaction                  → Widget
Screen navigation, forms, API calls           → Integration
Prevent visual regressions                    → Golden
```

**Recommended split for indie devs**:

```
Unit:        60% (logic breaks most often)
Widget:      25% (core components only)
Integration: 10% (happy path only)
Golden:       5% (landing page + key screens)
```

Tests are an investment: writing time now vs. debugging time later. Start with Unit, add Widget for regressions, Integration for critical flows. Golden is optional but saves hours when you redesign.

