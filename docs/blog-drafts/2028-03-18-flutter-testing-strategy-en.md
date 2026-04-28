---
title: "Flutter Testing Strategy: Widget, Integration, and Golden Tests"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Testing Strategy: Widget, Integration, and Golden Tests

Picking the right test type keeps CI fast without sacrificing confidence.

## Test Selection Guide

```
Business logic alone      → Unit test
UI component              → Widget test
Screen navigation / DB    → Integration test
Design regression         → Golden test
```

## Unit Tests: The Foundation

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

## Widget Tests: UI Component Verification

```dart
// test/widgets/task_card_test.dart
testWidgets('TaskCard shows title and completion button', (tester) async {
  bool completed = false;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TaskCard(
          title: 'Test task',
          onComplete: () => completed = true,
        ),
      ),
    ),
  );

  expect(find.text('Test task'), findsOneWidget);
  expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

  await tester.tap(find.byIcon(Icons.check_circle_outline));
  expect(completed, isTrue);
});

testWidgets('TaskCard shows completed state', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TaskCard(
          title: 'Done task',
          isCompleted: true,
          onComplete: () {},
        ),
      ),
    ),
  );

  expect(find.byIcon(Icons.check_circle), findsOneWidget);
});
```

## Integration Tests: Full Flow with Supabase

```dart
// integration_test/task_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Login → create task → complete flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('email')), 'test@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'password123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task_title')), 'Integration test task');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Integration test task'), findsOneWidget);
  });
}
```

## Golden Tests: Design Regression Detection

```dart
// test/golden/task_card_golden_test.dart
testWidgets('TaskCard golden test', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: Center(
          child: TaskCard(title: 'Golden test', isCompleted: false),
        ),
      ),
    ),
  );

  // First run: flutter test --update-goldens to create snapshot
  await expectLater(
    find.byType(TaskCard),
    matchesGoldenFile('goldens/task_card.png'),
  );
});
```

## CI Configuration (GHA)

```yaml
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

## Summary

```
Unit          → logic only · fast · write many
Widget        → UI components · medium speed · cover key widgets
Integration   → E2E golden path · slow · 1–3 scenarios max
Golden        → design regression · regenerate with --update-goldens
```

Aim for 70% unit / 25% widget / 5% integration. Writing everything at the
same depth makes CI unbearably slow — pick your battles.
