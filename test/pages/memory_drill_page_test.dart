import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/memory_drill_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows answers and stores today completion', (
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

    final answerChip = find.byType(FilterChip).at(1);
    expect(tester.widget<FilterChip>(answerChip).selected, isFalse);

    await tester.tap(answerChip);
    await tester.pumpAndSettle();

    expect(tester.widget<FilterChip>(answerChip).selected, isTrue);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('memory_drill_completed_today_date'),
      '2026-03-22',
    );
    expect(
      prefs.getStringList('memory_drill_completed_today_pack_ids'),
      contains('countries_10'),
    );
  });
}
