import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/business_execution.dart';

BusinessExecutionPlan plan({
  String id = 'plan',
  String start = '2026-10-29',
  String due = '2026-10-31',
}) =>
    BusinessExecutionPlan(
      id: id,
      issue: '相談に結びついていない',
      owner: '自分',
      outcome: '相談申込数',
      outcomeUnit: '件',
      outcomeTarget: 3,
      action: 'ヒアリング',
      actionUnit: '回',
      dailyTarget: 2,
      startDate: start,
      dueDate: due,
    );

void main() {
  test('zero is reported, missing is separate, latest KPI is not a sum', () {
    final recorded = plan()
        .withReport(
          '2026-10-29',
          BusinessDailyReport(actual: 0, outcomeActual: 1, note: '未実施'),
        )
        .withReport(
          '2026-10-30',
          BusinessDailyReport(actual: 2, outcomeActual: 3, note: '改善'),
        );
    expect(recorded.missingDates(DateTime(2026, 10, 30)), isEmpty);
    expect(recorded.missingDates(DateTime(2026, 11)), ['2026-10-31']);
    expect(recorded.totalActions, 2);
    expect(recorded.latestOutcome!.value.outcomeActual, 3);
    expect(plan().latestOutcome, isNull);
  });

  test('leap month, future start and year transition use civil dates', () {
    final leap = plan(start: '2028-02-28', due: '2028-02-29');
    expect(leap.expectedDates(DateTime(2028, 3)), [
      '2028-02-28',
      '2028-02-29',
    ]);
    expect(leap.expectedDates(DateTime(2028, 2, 27)), isEmpty);
    expect(
      plan(start: '2026-12-31', due: '2026-12-31')
          .expectedDates(DateTime(2027)),
      ['2026-12-31'],
    );
    expect(() => parseDay('2026-02-29'), throwsFormatException);
    expect(
      () => plan(start: '2026-10-31', due: '2026-11-01'),
      throwsFormatException,
    );
  });

  test('roundtrip keeps daily and monthly notes and replaces same day once',
      () {
    final original = plan()
        .withReport(
          '2026-10-29',
          BusinessDailyReport(actual: 0, note: '0を記録'),
        )
        .withReport(
          '2026-10-29',
          BusinessDailyReport(actual: 4, note: '訂正'),
        )
        .withReflection('次月は質問を変える');
    final restored = BusinessExecutionCodec.decode(
      BusinessExecutionCodec.encode([original]),
    ).single;
    expect(restored.reports.length, 1);
    expect(restored.totalActions, 4);
    expect(restored.reflection, '次月は質問を変える');
    expect(restored.reports['2026-10-29']!.note, '訂正');
  });

  test('rejects nonfinite numbers, out of range dates and excessive content',
      () {
    for (final number in [double.nan, double.infinity, -1.0, 1000000001.0]) {
      expect(
        () => BusinessDailyReport(actual: number, note: ''),
        throwsFormatException,
      );
    }
    expect(
      () => BusinessDailyReport(actual: 0, note: 'a' * 501),
      throwsFormatException,
    );
    expect(
      () => plan().withReport(
        '2026-10-28',
        BusinessDailyReport(actual: 1, note: ''),
      ),
      throwsFormatException,
    );
    expect(
      () => BusinessExecutionCodec.encode([plan(), plan()]),
      throwsFormatException,
    );
    expect(
      () => BusinessExecutionCodec.encode(
        List.generate(25, (index) => plan(id: '$index')),
      ),
      throwsFormatException,
    );
    expect(
      () => BusinessExecutionCodec.decode('{"version":2,"plans":[]}'),
      throwsFormatException,
    );
    expect(() => BusinessExecutionCodec.decode('{'), throwsFormatException);
  });
}
