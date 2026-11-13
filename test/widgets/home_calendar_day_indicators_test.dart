import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_calendar_day_indicators.dart';

void main() {
  testWidgets('indicator colors and spacing', (tester) async {
    const colors = [
      Color(0xFFFFC107),
      Color(0xFF4CAF50),
      Color(0xFFE53935),
      Color(0xFFFF6B35),
      Color(0xFF009688),
    ];
    for (final emphasized in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 20,
              child: HomeCalendarDayIndicators(
                colors: colors,
                isEmphasized: emphasized,
              ),
            ),
          ),
        ),
      );
      final dots = find.descendant(
        of: find.byType(HomeCalendarDayIndicators),
        matching: find.byType(Container),
      );
      expect(dots, findsNWidgets(colors.length));
      final first = tester.getTopLeft(dots.at(0));
      expect(tester.getTopLeft(dots.at(1)) - first, const Offset(10, 0));
      expect(tester.getTopLeft(dots.at(2)) - first, const Offset(0, 10));
      for (var i = 0; i < colors.length; i++) {
        final dot = tester.widget<Container>(dots.at(i));
        final decoration = dot.decoration! as BoxDecoration;
        expect(
          decoration.color,
          emphasized ? colors[i] : colors[i].withValues(alpha: 0.22),
        );
        expect(decoration.shape, BoxShape.circle);
        expect(tester.getSize(dots.at(i)), const Size(7, 7));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('immutable empty input', (tester) async {
    final colors = <Color>[];
    final widget = HomeCalendarDayIndicators(
      colors: colors,
      isEmphasized: true,
    );
    colors.add(Colors.teal);
    await tester.pumpWidget(MaterialApp(home: widget));
    final dots = find.descendant(
      of: find.byType(HomeCalendarDayIndicators),
      matching: find.byType(Container),
    );
    expect(dots, findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeCalendarDayIndicators(
          colors: colors,
          isEmphasized: true,
        ),
      ),
    );
    expect(dots, findsOneWidget);
  });
}
