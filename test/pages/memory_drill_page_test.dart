import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/memory_drill_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows answers and completes today drill', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryDrillPage(
          nowProvider: () => DateTime(2026, 3, 22, 8),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('暗記ドリル'), findsOneWidget);
    expect(find.text('世界の国 10個'), findsOneWidget);

    await tester.tap(find.text('答え'));
    await tester.pumpAndSettle();

    expect(find.text('日本'), findsOneWidget);

    await tester.tap(find.text('今日の暗記を完了'));
    await tester.pumpAndSettle();

    expect(find.text('今日完了'), findsOneWidget);
  });
}
