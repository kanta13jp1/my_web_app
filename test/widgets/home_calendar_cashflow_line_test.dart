import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_calendar_cashflow_line.dart';

void main() {
  testWidgets('cashflow labels preserve amount boundaries and explicit signs',
      (tester) async {
    const cases = <int, String>{
      0: '0',
      9999: '9,999',
      10000: '1.0万',
      10500: '1.1万',
      999999: '100.0万',
      1000000: '100万',
      -1234: '1,234',
    };
    for (final entry in cases.entries) {
      for (final income in [false, true]) {
        final label = income ? '収' : '支';
        final sign = income ? '+' : '-';
        await tester.pumpWidget(
          MaterialApp(
            home: HomeCalendarCashflowLine(
              textKey: const Key('cashflow_test'),
              label: label,
              amount: entry.key,
              color: Colors.green,
              sign: sign,
              isEmphasized: income,
            ),
          ),
        );
        final text = tester.widget<Text>(
          find.byKey(const Key('cashflow_test')),
        );
        expect(text.data, '$label $sign${entry.value}');
        expect(
          text.style!.color,
          income ? Colors.green : Colors.green.withValues(alpha: 0.74),
        );
      }
    }
  });

  testWidgets('cashflow fits a narrow day cell with large text',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(
            child: SizedBox(
              width: 45,
              child: HomeCalendarCashflowLine(
                textKey: Key('cashflow_test'),
                label: '支',
                amount: 999999,
                color: Colors.red,
                sign: '-',
                isEmphasized: true,
              ),
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.byKey(const Key('cashflow_test')));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}
