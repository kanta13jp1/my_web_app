---
title: "Flutter Golden Tests — Catch UI Regressions with Snapshot Testing"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Golden Tests — Catch UI Regressions with Snapshot Testing

Golden tests save a "expected UI image" and automatically compare it against future renders. They catch design regressions in CI before they ship.

## Basic Golden Test

```dart
testWidgets('PricingCard goldentest', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PricingCard(
          plan: PricingPlan(name: 'Pro', price: 2980, highlight: true),
        ),
      ),
    ),
  );

  await expectLater(
    find.byType(PricingCard),
    matchesGoldenFile('goldens/pricing_card_pro.png'),
  );
});
```

First run with `flutter test --update-goldens` generates the PNG. Subsequent runs fail on any visual diff.

## Managing Golden Files

```bash
# First run / after intentional design changes: update goldens
flutter test --update-goldens test/widget/pricing_card_test.dart

# CI: diff check without updating
flutter test test/widget/pricing_card_test.dart
```

## Theme + Dark Mode Variants

```dart
Future<void> pumpWithTheme(
  WidgetTester tester,
  Widget widget, {
  ThemeMode mode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      home: Scaffold(body: widget),
    ),
  );
  await tester.pumpAndSettle();
}

testWidgets('PricingCard dark mode golden', (tester) async {
  await pumpWithTheme(
    tester,
    PricingCard(plan: PricingPlan(name: 'Pro', price: 2980, highlight: true)),
    mode: ThemeMode.dark,
  );
  await expectLater(
    find.byType(PricingCard),
    matchesGoldenFile('goldens/pricing_card_pro_dark.png'),
  );
});
```

## CI with GitHub Actions

```yaml
- name: Run golden tests
  run: flutter test test/widget/ --reporter github
  env:
    FLUTTER_TEST_GOLDEN: "true"

- name: Upload golden diff on failure
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: golden-failures
    path: test/failures/
```

## Summary

```
Initial run    → flutter test --update-goldens generates snapshots
CI             → diff detection → save diff images to test/failures/
Dark mode      → separate golden file per ThemeMode variant
Workflow       → only run --update-goldens on intentional design changes
```

Golden tests are the simplest way to automate the UI quality checks you're currently doing by eye. Start with one core component and expand from there.
