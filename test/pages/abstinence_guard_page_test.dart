import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/abstinence_guard_page.dart';
import 'package:my_web_app/services/abstinence_guard_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AbstinenceGuardPage shows tracked harmful habits',
      (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await AbstinenceGuardStore.setEnabled(
      itemId: 'alcohol',
      isEnabled: true,
      prefs: prefs,
      now: DateTime(2026, 2, 26),
    );
    await AbstinenceGuardStore.incrementSlip(
      itemId: 'alcohol',
      prefs: prefs,
      now: DateTime(2026, 2, 26),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AbstinenceGuardPage(
          nowProvider: _fixedNow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('禁欲ガード'), findsOneWidget);
    expect(find.text('今日やらないことを固定する'), findsOneWidget);
    expect(find.text('逸脱あり'), findsOneWidget);
    expect(find.text('酒'), findsOneWidget);
    expect(find.textContaining('逸脱 +1 (1)'), findsOneWidget);
  });

  testWidgets('AbstinenceGuardPage can move between previous and next day',
      (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await AbstinenceGuardStore.setEnabled(
      itemId: 'alcohol',
      isEnabled: true,
      prefs: prefs,
      now: DateTime(2026, 2, 25),
    );
    await AbstinenceGuardStore.setEnabled(
      itemId: 'smoking',
      isEnabled: true,
      prefs: prefs,
      now: DateTime(2026, 2, 26),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AbstinenceGuardPage(
          nowProvider: _fixedNow,
          initialDate: DateTime(2026, 2, 25),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('対象日: 2026/02/25'), findsOneWidget);
    expect(find.text('無傷'), findsOneWidget);
    expect(find.text('酒'), findsOneWidget);

    await tester.tap(find.byTooltip('翌日'));
    await tester.pumpAndSettle();

    expect(find.text('対象日: 2026/02/26'), findsOneWidget);
    expect(find.text('無傷'), findsOneWidget);
    expect(find.text('煙草'), findsOneWidget);
  });

  testWidgets('AbstinenceGuardPage can jump to arbitrary day with date picker',
      (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await AbstinenceGuardStore.setEnabled(
      itemId: 'alcohol',
      isEnabled: true,
      prefs: prefs,
      now: DateTime(2026, 2, 24),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AbstinenceGuardPage(
          nowProvider: _fixedNow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('日付を選択'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('対象日: 2026/02/24'), findsOneWidget);
    expect(find.text('無傷'), findsOneWidget);
    expect(find.text('酒'), findsOneWidget);
  });

  testWidgets('AbstinenceGuardPage shows unset status when no guard is configured',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AbstinenceGuardPage(
          nowProvider: _fixedNow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('未設定'), findsOneWidget);
    expect(find.text('その日の禁止対象が固定されていません。'), findsOneWidget);
  });
}

DateTime _fixedNow() => DateTime(2026, 2, 26, 9, 0);
