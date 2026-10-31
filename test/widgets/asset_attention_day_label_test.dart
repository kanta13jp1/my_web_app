import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_spending_attention_calendar.dart';
import 'package:my_web_app/widgets/asset_attention_day_label.dart';

void main() {
  testWidgets('attention text exposes reasons and never claims actual drinking',
      (tester) async {
    final day = AssetSpendingAttentionCalendar.forDate(DateTime(2026, 10, 16));
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AssetAttentionDayLabel(day: day))),
    );
    expect(find.text('注意'), findsOneWidget);
    expect(find.byTooltip(day.description), findsOneWidget);
    expect(find.text('飲酒した'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
