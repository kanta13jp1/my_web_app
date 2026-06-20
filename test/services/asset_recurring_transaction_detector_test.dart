import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_recurring_transaction_detector.dart';

void main() {
  final asOf = DateTime(2026, 6, 15); // 窓 = 2026年 1〜6月 (lookback 6)

  RecurringTransactionObservation obs(
    String label,
    int amount,
    int month, {
    int day = 15,
    int year = 2026,
    String sourceName = '',
  }) {
    return RecurringTransactionObservation(
      label: label,
      amount: amount,
      occurredAt: DateTime(year, month, day),
      sourceName: sourceName,
    );
  }

  group('AssetRecurringTransactionDetector.detect (monthly)', () {
    test('detects a stable monthly expense present every lookback month', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [for (var m = 1; m <= 6; m++) obs('電気代', 8000, m)],
        asOf: asOf,
      );

      expect(result.length, 1);
      final detected = result.single;
      expect(detected.label, '電気代');
      expect(detected.cadence, AssetRecurringFixedCostCadence.monthly);
      expect(detected.monthsObserved, 6);
      expect(detected.confidence, RecurringTransactionConfidence.high);
    });

    test('marks medium confidence when present in only some months', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('サブスク', 1500, 3),
          obs('サブスク', 1500, 4),
          obs('サブスク', 1500, 5),
          obs('サブスク', 1500, 6),
        ],
        asOf: asOf,
      );

      expect(result.single.cadence, AssetRecurringFixedCostCadence.monthly);
      expect(result.single.monthsObserved, 4);
      expect(result.single.confidence, RecurringTransactionConfidence.medium);
    });

    test('does not detect 3 consecutive months (ambiguous, not bimonthly)', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('新規', 5000, 4),
          obs('新規', 5000, 5),
          obs('新規', 5000, 6),
        ],
        asOf: asOf,
      );

      expect(result, isEmpty);
    });
  });

  group('AssetRecurringTransactionDetector.detect (bimonthly)', () {
    test('detects an even-month bimonthly expense (water bill pattern)', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('水道代', 6000, 2),
          obs('水道代', 6200, 4),
          obs('水道代', 5900, 6),
        ],
        asOf: asOf,
      );

      expect(result.length, 1);
      final detected = result.single;
      expect(
        detected.cadence,
        AssetRecurringFixedCostCadence.bimonthlyEvenMonth,
      );
      expect(detected.monthsObserved, 3);
      expect(detected.confidence, RecurringTransactionConfidence.high);
    });

    test('detects an odd-month bimonthly expense', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('隔月X', 4000, 1),
          obs('隔月X', 4000, 3),
          obs('隔月X', 4000, 5),
        ],
        asOf: asOf,
      );

      expect(
        result.single.cadence,
        AssetRecurringFixedCostCadence.bimonthlyOddMonth,
      );
    });

    test('does not treat an irregular 2-of-6 pattern as bimonthly', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [obs('不規則', 4000, 2), obs('不規則', 4000, 5)],
        asOf: asOf,
      );

      expect(result, isEmpty);
    });
  });

  group('AssetRecurringTransactionDetector.detect (filters)', () {
    test('ignores expenses with unstable amounts', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('コンビニ', 500, 3),
          obs('コンビニ', 3000, 4),
          obs('コンビニ', 12000, 5),
          obs('コンビニ', 800, 6),
        ],
        asOf: asOf,
      );

      expect(result, isEmpty);
    });

    test('applies the minimum typical amount floor', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [for (var m = 1; m <= 6; m++) obs('小額', 300, m)],
        asOf: asOf,
      );

      expect(result, isEmpty);
    });

    test('excludes observations outside the lookback window', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('家賃', 60000, 5),
          obs('家賃', 60000, 6),
          obs('家賃', 60000, 11, year: 2025),
          obs('家賃', 60000, 12, year: 2025),
        ],
        asOf: asOf,
      );

      expect(result, isEmpty); // 窓内は5月+6月の2ヶ月のみ
    });

    test('sorts detected transactions by typical amount descending', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          for (var m = 1; m <= 6; m++) obs('通信', 4000, m),
          for (var m = 1; m <= 6; m++) obs('家賃', 60000, m),
        ],
        asOf: asOf,
      );

      expect(result.map((d) => d.label).toList(), ['家賃', '通信']);
    });
  });

  group('AssetRecurringTransactionDetector.detect (source)', () {
    test('reports the most frequent source account name', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('電気代', 8000, 3, sourceName: '横浜銀行'),
          obs('電気代', 8000, 4, sourceName: '横浜銀行'),
          obs('電気代', 8000, 5, sourceName: '横浜銀行'),
          obs('電気代', 8000, 6, sourceName: 'みずほ'),
        ],
        asOf: asOf,
      );

      expect(result.single.suggestedSourceName, '横浜銀行');
    });

    test('leaves source null when no source name is present', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [for (var m = 1; m <= 6; m++) obs('電気代', 8000, m)],
        asOf: asOf,
      );

      expect(result.single.suggestedSourceName, isNull);
    });
  });

  group('AssetRecurringTransactionDetector.detect (income usage)', () {
    test('detects a stable monthly salary with its destination account', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          for (var m = 1; m <= 6; m++)
            obs('給料', 280000, m, day: 25, sourceName: '給与口座'),
        ],
        asOf: asOf,
      );

      expect(result.length, 1);
      final detected = result.single;
      expect(detected.label, '給料');
      expect(detected.cadence, AssetRecurringFixedCostCadence.monthly);
      expect(detected.typicalAmount, 280000);
      expect(detected.typicalPaymentDay, 25);
      expect(detected.confidence, RecurringTransactionConfidence.high);
      expect(detected.suggestedSourceName, '給与口座');
    });
  });

  group('AssetRecurringTransactionDetector.buildLabel', () {
    test('strips date and number fragments from the memo', () {
      expect(
        AssetRecurringTransactionDetector.buildLabel(
          source: '[横浜銀行]',
          memo: '電気代 2026年6月分',
        ),
        '電気代',
      );
      expect(
        AssetRecurringTransactionDetector.buildLabel(
          source: '[A]',
          memo: '水道代 06/15',
        ),
        '水道代',
      );
    });

    test('normalizes full-width digits before stripping', () {
      expect(
        AssetRecurringTransactionDetector.buildLabel(
          source: '[A]',
          memo: 'ガス代 ６月分',
        ),
        'ガス代',
      );
    });

    test('falls back to the bracket-stripped source when memo is empty', () {
      expect(
        AssetRecurringTransactionDetector.buildLabel(
          source: '[Anthropic]',
          memo: '',
        ),
        'Anthropic',
      );
    });

    test('keeps digits that are part of a word', () {
      expect(
        AssetRecurringTransactionDetector.buildLabel(
          source: '[A]',
          memo: '1Password',
        ),
        '1Password',
      );
    });
  });
}
