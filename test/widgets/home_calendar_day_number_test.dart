import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_calendar_day_number.dart';

void main() {
  testWidgets('day number preserves month and highlight colors', (tester) async {
    final cases = [
      (false, true, false, false, const Color(0xFFB0B0B0)),
      (true, false, false, false, const Color(0xFFB0B0B0)),
      (true, false, false, true, const Color(0xFF666666)),
      (true, true, false, false, Colors.green),
      (true, true, true, false, const Color(0xDE000000)),
      (true, true, true, true, Colors.white.withValues(alpha: 0.7)),
    ];
    for (final item in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeCalendarDayNumber(
            day: 26,
            isCurrentMonth: item.$1,
            matchesFilter: item.$2,
            isUnset: item.$3,
            isDark: item.$4,
            accentColor: Colors.green,
          ),
        ),
      );
      expect(find.text('26'), findsOneWidget);
      expect(tester.widget<Text>(find.text('26')).style!.color, item.$5);
    }
  });

  testWidgets('day number updates within a narrow cell', (tester) async {
    for (final day in [9, 31]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Center(
              child: SizedBox(
                width: 45,
                child: HomeCalendarDayNumber(
                  day: day,
                  isCurrentMonth: true,
                  matchesFilter: true,
                  isUnset: false,
                  isDark: false,
                  accentColor: Colors.green,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('$day'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
