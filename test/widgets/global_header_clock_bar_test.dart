import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/global_header_clock_bar.dart';

void main() {
  testWidgets('GlobalHeaderClockShell shows clock and wrapped child', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlobalHeaderClockShell(
          child: Scaffold(
            body: Center(child: Text('dummy page')),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('global_header_clock_bar')), findsOneWidget);
    expect(find.byKey(const Key('global_header_clock_text')), findsOneWidget);
    expect(find.text('dummy page'), findsOneWidget);
  });
}
