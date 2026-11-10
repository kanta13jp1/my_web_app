import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_calendar_month_header.dart';

void main() {
  Widget app(String label, VoidCallback previous, VoidCallback next) {
    return MaterialApp(
      home: Scaffold(
        body: HomeCalendarMonthHeader(
          currentMonthLabel: label,
          onPreviousMonth: previous,
          onNextMonth: next,
        ),
      ),
    );
  }

  testWidgets('shows the supplied label and accessible month controls',
      (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(app('2026年11月', () {}, () {}));
    expect(find.text('継続カレンダー 2026年11月'), findsOneWidget);
    // Tooltip text is a semantics tooltip, not a semantics label.
    final previous = tester.getSemantics(find.byTooltip('前月'));
    final next = tester.getSemantics(find.byTooltip('翌月'));
    expect(previous.getSemanticsData().tooltip, '前月');
    expect(next.getSemanticsData().tooltip, '翌月');
  });

  testWidgets('dispatches each month callback once without owning selection',
      (tester) async {
    var previous = 0;
    var next = 0;
    await tester.pumpWidget(app('2026年12月', () => previous++, () => next++));
    await tester.tap(find.byTooltip('前月'));
    await tester.pump();
    expect(previous, 1);
    expect(next, 0);
    await tester.tap(find.byTooltip('翌月'));
    await tester.pump();
    expect(previous, 1);
    expect(next, 1);
    expect(find.text('継続カレンダー 2026年12月'), findsOneWidget);
    await tester.pumpWidget(app('2027年1月', () {}, () {}));
    expect(find.text('継続カレンダー 2027年1月'), findsOneWidget);
    expect(find.text('継続カレンダー 2026年12月'), findsNothing);
  });

  testWidgets('wraps at a narrow width with large text in both themes',
      (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SizedBox(
                width: 320,
                child: HomeCalendarMonthHeader(
                  currentMonthLabel: '2026年11月',
                  onPreviousMonth: () {},
                  onNextMonth: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('前月'), findsOneWidget);
      expect(find.byTooltip('翌月'), findsOneWidget);
    }
  });
}
