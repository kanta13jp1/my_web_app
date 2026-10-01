import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/slide_number_check.dart';
import 'package:my_web_app/widgets/slide_number_check_card.dart';

void main() {
  test('growth uses baseline and rejects missing or invalid evidence', () {
    expect(SlideNumberCheck.calculate('80', '100').growthPercent,
        closeTo(25, 1e-9));
    expect(SlideNumberCheck.calculate('100', '80').growthPercent,
        closeTo(-20, 1e-9));
    final rates = SlideNumberCheck.calculate('10', '15');
    expect(rates.growthPercent, closeTo(50, 1e-9));
    expect(rates.pointDifference, 5);
    for (final pair in [
      ['', '100'],
      ['0', '100'],
      ['-1', '100'],
      ['abc', '100'],
      ['NaN', '1'],
      ['1', 'Infinity'],
      ['1', '-1']
    ]) {
      expect(() => SlideNumberCheck.calculate(pair[0], pair[1]),
          throwsFormatException);
    }
  });

  testWidgets('invalid value clears result and can be corrected',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(child: SlideNumberCheckCard()))));
    await tester.tap(find.text('数字を確認する'));
    await tester.pump();
    expect(find.text('増加率: 25.00%'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('slide-number-before')), '0');
    await tester.pump();
    expect(find.byKey(const Key('slide-number-result')), findsNothing);
    await tester.tap(find.text('数字を確認する'));
    await tester.pump();
    expect(find.byKey(const Key('slide-number-error')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('slide-number-before')), '80');
    await tester.tap(find.text('数字を確認する'));
    await tester.pump();
    expect(find.text('増加率: 25.00%'), findsOneWidget);
    expect(find.byKey(const Key('slide-number-error')), findsNothing);
  });
}
