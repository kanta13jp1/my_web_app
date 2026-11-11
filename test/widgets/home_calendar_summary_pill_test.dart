import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_calendar_summary_pill.dart';

void main() {
  for (final selected in [false, true]) {
    testWidgets('summary pill renders and dispatches when selected=$selected',
        (tester) async {
      var taps = 0;
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SizedBox(
                  width: 320,
                  child: HomeCalendarSummaryPill(
                    label: '逸脱日数',
                    value: '2日',
                    color: Colors.orange,
                    isSelected: selected,
                    interactionKey: 'summary_test',
                    onTap: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('逸脱日数 2日'), findsOneWidget);
        final before = taps;
        await tester.tap(find.byKey(const Key('summary_test')));
        await tester.pump();
        expect(taps, before + 1);
        expect(find.text('逸脱日数 2日'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
