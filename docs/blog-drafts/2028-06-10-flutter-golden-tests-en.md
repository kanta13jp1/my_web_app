---
title: "Flutter Golden Tests — Prevent UI Regressions with Screenshot Diffs"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Golden Tests — Prevent UI Regressions with Screenshot Diffs

Catch "the design broke" in code. Golden tests are screenshot diff tests.

## Basic Golden Test

```dart
// test/golden/task_card_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/task_card.dart';

void main() {
  testWidgets('TaskCard golden test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TaskCard(
            task: Task(
              id: '1',
              title: 'Write shopping list',
              completed: false,
              priority: Priority.high,
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(TaskCard),
      matchesGoldenFile('goldens/task_card.png'),
    );
  });
}
```

```bash
# First run: generate the golden file
flutter test --update-goldens test/golden/

# Subsequent runs: check for diffs (run in CI)
flutter test test/golden/
```

## Dark Mode Coverage

```dart
testWidgets('TaskCard dark mode golden', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: TaskCard(task: _sampleTask),
      ),
    ),
  );

  await expectLater(
    find.byType(TaskCard),
    matchesGoldenFile('goldens/task_card_dark.png'),
  );
});
```

## Stabilizing Font Rendering

```dart
// Register fonts in tests to suppress CI/local rendering differences
setUpAll(() async {
  await loadAppFonts();
});

// Use tolerance to allow minor pixel-level variance (0.0–1.0)
await expectLater(
  find.byType(TaskCard),
  matchesGoldenFile(
    'goldens/task_card.png',
    // skip: !Platform.isMacOS,  // skip on non-matching OS if needed
  ),
);
```

## Surfacing Golden Diffs in CI

```yaml
# .github/workflows/golden-test.yml
- name: Run Golden Tests
  run: flutter test test/golden/ --reporter compact

- name: Upload golden diffs on failure
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: golden-failures
    path: test/golden/failures/
    # diff images appear as PR artifacts for easy review
```

## Summary

```
Generate  → flutter test --update-goldens (first run or intentional change)
Verify    → flutter test test/golden/ (every CI run)
Dark mode → maintain separate golden files per theme
CI diffs  → upload failures/ as artifacts → review in PR
```

Widget tests cover behavior; golden tests cover appearance. Use both to achieve zero regressions.
