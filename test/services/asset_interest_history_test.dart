import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_interest_history.dart';

void main() {
  AssetInterestMonth record(
    String month,
    int amount, {
    bool complete = true,
    String name = 'A',
  }) =>
      AssetInterestMonth(
        month: month,
        amounts: {name: amount},
        complete: complete,
        evidence: '明細',
      );
  final now = DateTime(2026, 9, 12);
  test('compares only adjacent closed complete months with same scope', () {
    final aug = record('2026-08', 80);
    expect(aug.reductionFrom(record('2026-07', 100), now), 20);
    expect(aug.reductionFrom(record('2026-07', 50), now), -30);
    expect(aug.reductionFrom(record('2026-07', 80), now), 0);
    expect(aug.reductionFrom(record('2026-06', 100), now), isNull);
    expect(aug.reductionFrom(record('2026-07', 100, name: 'B'), now), isNull);
    expect(
      aug.reductionFrom(record('2026-07', 100, complete: false), now),
      isNull,
    );
    expect(
      record('2026-08', 80, complete: false)
          .reductionFrom(record('2026-07', 100), now),
      isNull,
    );
    expect(record('2026-09', 10).reductionFrom(aug, now), isNull);
    expect(aug.reductionFrom(null, now), isNull);
  });
  test('confirmed zero is distinct from missing and survives serialization',
      () {
    final zero = record('2026-08', 0);
    expect(zero.reductionFrom(record('2026-07', 100), now), 100);
    expect(AssetInterestMonth.fromJson(zero.toJson()).total, 0);
  });
  test('rejects invalid month, negative amount and missing evidence', () {
    expect(() => record('2026-13', 10), throwsFormatException);
    expect(() => record('2026-08', -1), throwsFormatException);
    expect(
      () => AssetInterestMonth(
        month: '2026-08',
        amounts: {},
        complete: true,
        evidence: 'x',
      ),
      throwsFormatException,
    );
  });
  test('parser rejects duplicate accounts, invalid and fractional amounts', () {
    expect(AssetInterestMonth.parseAmounts('A=0\nB=120'), {'A': 0, 'B': 120});
    for (final bad in ['A=1\nA=2', 'A=-1', 'A=NaN', 'A=1.5', 'A=']) {
      expect(() => AssetInterestMonth.parseAmounts(bad), throwsFormatException);
    }
  });
}
