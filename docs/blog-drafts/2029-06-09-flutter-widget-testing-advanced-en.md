---
title: "Flutter Widget Testing Guide — Golden Tests, Interactions, and Async"
tags: flutter,dart,webdev,indiedev
published: true
---

# Flutter Widget Testing Guide — Golden Tests, Interactions, and Async

Unit tests verify logic. Widget tests verify UI behavior. Here's a complete guide to writing robust widget tests that catch regressions before they hit production.

## Basic Widget Test

```dart
testWidgets('CounterWidget increments on tap', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: CounterWidget()));

  expect(find.text('0'), findsOneWidget);

  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();

  expect(find.text('1'), findsOneWidget);
});
```

## Async Data Loading

```dart
testWidgets('TaskList loads and displays tasks', (tester) async {
  final mockRepo = MockTaskRepository();
  when(() => mockRepo.getAll()).thenAnswer((_) async => [
    Task(id: '1', title: 'Buy milk', isDone: false),
    Task(id: '2', title: 'Write tests', isDone: true),
  ]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [taskRepoProvider.overrideWithValue(mockRepo)],
      child: const MaterialApp(home: TaskListPage()),
    ),
  );

  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  await tester.pumpAndSettle();

  expect(find.text('Buy milk'), findsOneWidget);
  expect(find.text('Write tests'), findsOneWidget);
});
```

## Form Interaction Testing

```dart
testWidgets('Login form validates and submits', (tester) async {
  final mockAuth = MockAuthService();
  when(() => mockAuth.signIn(any(), any())).thenAnswer((_) async => true);

  await tester.pumpWidget(MaterialApp(home: LoginPage(authService: mockAuth)));

  // Empty submit → validation errors
  await tester.tap(find.byType(ElevatedButton));
  await tester.pump();
  expect(find.text('Email is required'), findsOneWidget);

  // Fill and submit
  await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
  await tester.enterText(find.byKey(const Key('password_field')), 'password123');

  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();

  verify(() => mockAuth.signIn('test@example.com', 'password123')).called(1);
});
```

## Golden Tests (Screenshot Diffing)

Pixel-perfect regression detection — catches visual changes CI would otherwise miss.

```dart
testWidgets('TaskCard matches golden', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: TaskCard(task: Task(id: '1', title: 'Buy milk', isDone: false)),
      ),
    ),
  );

  await expectLater(
    find.byType(TaskCard),
    matchesGoldenFile('goldens/task_card.png'),
  );
});
```

```bash
# Generate golden files (first run or intentional update)
flutter test --update-goldens

# Diff check in CI
flutter test
```

## Gesture Tests

```dart
testWidgets('Swipe to delete', (tester) async {
  await tester.pumpWidget(MaterialApp(home: TaskListPage()));
  await tester.pumpAndSettle();

  await tester.drag(find.text('Buy milk'), const Offset(-300, 0));
  await tester.pumpAndSettle();

  expect(find.text('Buy milk'), findsNothing);
});
```

## Reusable Test Helper

```dart
// test/helpers/pump_app.dart
extension PumpApp on WidgetTester {
  Future<void> pumpApp(Widget widget, {List<Override> overrides = const []}) {
    return pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(theme: AppTheme.light, home: widget),
      ),
    );
  }
}

// Usage
await tester.pumpApp(const TaskListPage());
```

## CI Integration

```yaml
- name: Flutter tests + coverage
  run: flutter test --coverage

- name: Golden file check
  run: flutter test test/golden/
```

Since adding golden tests, production UI regressions have dropped to near zero. The pixel diff catches what code review misses.

---

What's your go-to Flutter testing strategy? Drop a comment below.
