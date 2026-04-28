---
title: "Flutter Testing Guide: Unit, Widget, and Integration — When to Use Each"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Testing Guide: Unit, Widget, and Integration — When to Use Each

Flutter gives you three test types. Knowing which to reach for—and when—is what makes testing feel useful rather than burdensome. Here's what I actually use in production.

## The Three Layers

```
Unit Test:        verify logic in isolation (milliseconds)
Widget Test:      verify UI behavior without a device (seconds)
Integration Test: verify full user flows on an emulator (minutes)
```

Build from the bottom up. Unit tests are your foundation. Integration tests are expensive — use them for critical paths only.

## Unit Tests: Protect Business Logic

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
    test('returns correct percentage', () {
      expect(ScoreCalculator.calculate(8, 10), equals(80.0));
    });

    test('returns 0 when total is 0', () {
      expect(ScoreCalculator.calculate(0, 0), equals(0.0));
    });
  });
}
```

```bash
flutter test test/utils/  # run unit tests only
```

## Widget Tests: Protect UI Behavior

```dart
// test/widgets/achievement_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/achievement_card.dart';

void main() {
  testWidgets('shows title and description', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AchievementCard(
          title: 'First Test',
          description: 'Wrote my first test',
        ),
      ),
    );

    expect(find.text('First Test'), findsOneWidget);
    expect(find.text('Wrote my first test'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AchievementCard(
          title: 'Test',
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(AchievementCard));
    expect(tapped, isTrue);
  });
}
```

## Riverpod: ProviderScope Overrides

```dart
// Override providers in widget tests
testWidgets('shows loading indicator while fetching', (tester) async {
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

  await tester.pump();  // don't settle — stay in loading state
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  await tester.pumpAndSettle();  // settle → data shown
  expect(find.byType(CircularProgressIndicator), findsNothing);
});
```

## Mocking Supabase

```dart
// test/helpers/mock_supabase.dart
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}

// In your test setUp:
setUp(() {
  final mockClient = MockSupabaseClient();
  final mockAuth = MockGoTrueClient();
  when(() => mockClient.auth).thenReturn(mockAuth);
  when(() => mockAuth.currentUser).thenReturn(null);  // unauthenticated
});
```

## Integration Tests: E2E Flow Verification

```dart
// integration_test/login_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login to home flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('email')), 'test@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'password');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });
}
```

```bash
flutter test integration_test/ --device-id emulator-5554
```

## CI Integration

```yaml
# .github/workflows/ci.yml
- name: Unit + Widget Tests
  run: flutter test --coverage

- name: Coverage check
  run: |
    lcov --summary coverage/lcov.info
    # fail if coverage drops below 70%
```

## Where to Start

```
Step 1: Write Unit Tests for critical business logic
Step 2: Write Widget Tests for UI you repeatedly test manually
Step 3: Write one Integration Test for your most important user flow
```

Start small, add tests as you go. Any tests are better than no tests.

## Summary

- **Unit**: highest ROI — fast, easy to write, catches logic regressions
- **Widget**: catches UI regressions — use Riverpod `overrides` to isolate dependencies
- **Integration**: catches flow regressions — expensive, limit to critical paths

Even as a solo developer, building a test habit is the foundation for shipping with confidence.
