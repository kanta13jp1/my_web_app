---
title: "Flutter ウィジェットテスト完全ガイド — ゴールデンテスト・インタラクション・非同期テスト"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter ウィジェットテスト完全ガイド — ゴールデンテスト・インタラクション・非同期テスト

ユニットテストで関数を検証したら、次はウィジェットテストで UI の振る舞いを保証します。本番で壊れる前に CI で検出できる強力な手法を網羅します。

## 基本セットアップ

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
```

## 基本ウィジェットテスト

```dart
testWidgets('CounterWidget increments on tap', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: CounterWidget()));

  expect(find.text('0'), findsOneWidget);

  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();  // rebuild

  expect(find.text('1'), findsOneWidget);
});
```

## 非同期データのテスト

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

  // FutureProvider の初期状態 (loading)
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // 非同期完了まで待機
  await tester.pumpAndSettle();

  expect(find.text('Buy milk'), findsOneWidget);
  expect(find.text('Write tests'), findsOneWidget);
});
```

## フォームのインタラクションテスト

```dart
testWidgets('Login form validates and submits', (tester) async {
  final mockAuth = MockAuthService();
  when(() => mockAuth.signIn(any(), any())).thenAnswer((_) async => true);

  await tester.pumpWidget(MaterialApp(
    home: LoginPage(authService: mockAuth),
  ));

  // 空フォームで送信 → バリデーションエラー
  await tester.tap(find.byType(ElevatedButton));
  await tester.pump();
  expect(find.text('メールアドレスを入力してください'), findsOneWidget);

  // 正しい入力
  await tester.enterText(
    find.byKey(const Key('email_field')),
    'test@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('password_field')),
    'password123',
  );

  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();

  verify(() => mockAuth.signIn('test@example.com', 'password123')).called(1);
});
```

## ゴールデンテスト (スクリーンショット比較)

ピクセル単位で UI の崩れを検出します。

```dart
testWidgets('TaskCard matches golden', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: TaskCard(
          task: Task(id: '1', title: 'Buy milk', isDone: false),
        ),
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
# ゴールデンファイル生成 (初回 or 意図的更新)
flutter test --update-goldens

# 差分チェック (CI)
flutter test
```

## スクロール・ジェスチャーテスト

```dart
testWidgets('List scrolls to bottom', (tester) async {
  await tester.pumpWidget(MaterialApp(home: LongListPage()));
  await tester.pumpAndSettle();

  // スクロール
  await tester.drag(find.byType(ListView), const Offset(0, -500));
  await tester.pumpAndSettle();

  // 最下部のアイテムが表示されているか
  expect(find.text('Item 50'), findsOneWidget);
});

testWidgets('Swipe to delete task', (tester) async {
  await tester.pumpWidget(MaterialApp(home: TaskListPage()));
  await tester.pumpAndSettle();

  await tester.drag(find.text('Buy milk'), const Offset(-300, 0));
  await tester.pumpAndSettle();

  expect(find.text('Buy milk'), findsNothing);
});
```

## テストヘルパーで DRY に

```dart
// test/helpers/pump_app.dart
extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light,
          home: widget,
        ),
      ),
    );
  }
}

// テストで使う
testWidgets('uses helper', (tester) async {
  await tester.pumpApp(const TaskListPage());
  // ...
});
```

## CI での実行

```yaml
# .github/workflows/test.yml
- name: Run widget tests
  run: flutter test --coverage

- name: Check golden files
  run: flutter test test/golden/
```

ウィジェットテストを整備してから、本番リリース後のリグレッションがほぼゼロになりました。特にゴールデンテストはデザイン変更の意図しない影響を即検出できて強力です。

---

Flutter テストの中で一番使っているテスト種別は何ですか？ぜひコメントで教えてください！
