import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_recurring_transaction_detector.dart';

void main() {
  final asOf = DateTime(2026, 6, 15);

  RecurringTransactionObservation obs(
    String label,
    int amount,
    int year,
    int month,
    int day,
  ) {
    return RecurringTransactionObservation(
      label: label,
      amount: amount,
      occurredAt: DateTime(year, month, day),
    );
  }

  group('AssetRecurringTransactionDetector.detect', () {
    test('detects a stable monthly expense across recent months', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('電気代', 8000, 2026, 6, 15),
          obs('電気代', 8200, 2026, 5, 15),
          obs('電気代', 7800, 2026, 4, 14),
          obs('電気代', 8100, 2026, 3, 15),
        ],
        asOf: asOf,
      );

      expect(result.length, 1);
      final detected = result.single;
      expect(detected.label, '電気代');
      expect(detected.monthsObserved, 4);
      expect(detected.typicalPaymentDay, 15);
      expect(detected.typicalAmount, 8050); // median of 7800/8000/8100/8200
      expect(detected.confidence, RecurringTransactionConfidence.high);
    });

    test('ignores expenses seen in fewer than the minimum months', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('スポット', 5000, 2026, 6, 1),
          obs('スポット', 5000, 2026, 5, 1),
        ],
        asOf: asOf,
      );

      expect(result, isEmpty);
    });

    test('ignores expenses with unstable amounts (variable spend)', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('コンビニ', 500, 2026, 6, 3),
          obs('コンビニ', 3000, 2026, 5, 9),
          obs('コンビニ', 12000, 2026, 4, 20),
        ],
        asOf: asOf,
      );

      expect(result, isEmpty);
    });

    test('marks medium confidence when absent in some lookback months', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('サブスク', 1500, 2026, 6, 10),
          obs('サブスク', 1500, 2026, 5, 10),
          obs('サブスク', 1500, 2026, 4, 10),
          // 3月は無し → 直近4ヶ月中3ヶ月。
        ],
        asOf: asOf,
      );

      expect(result.single.monthsObserved, 3);
      expect(result.single.confidence, RecurringTransactionConfidence.medium);
    });

    test('excludes observations outside the lookback window', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('家賃', 60000, 2026, 6, 27),
          obs('家賃', 60000, 2026, 5, 27),
          obs('家賃', 60000, 2026, 1, 27), // 窓外 (3月〜6月)
          obs('家賃', 60000, 2025, 12, 27),
        ],
        asOf: asOf,
      );

      expect(result, isEmpty); // 窓内は6月+5月の2ヶ月のみ
    });

    test('applies the minimum typical amount floor', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('小額', 300, 2026, 6, 5),
          obs('小額', 300, 2026, 5, 5),
          obs('小額', 300, 2026, 4, 5),
        ],
        asOf: asOf,
      );

      expect(result, isEmpty);
    });

    test('sorts detected transactions by typical amount descending', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('通信', 4000, 2026, 6, 21),
          obs('通信', 4000, 2026, 5, 21),
          obs('通信', 4000, 2026, 4, 21),
          obs('家賃', 60000, 2026, 6, 27),
          obs('家賃', 60000, 2026, 5, 27),
          obs('家賃', 60000, 2026, 4, 27),
        ],
        asOf: asOf,
      );

      expect(result.map((d) => d.label).toList(), ['家賃', '通信']);
    });

    test('skips observations with an empty label', () {
      final result = AssetRecurringTransactionDetector.detect(
        observations: [
          obs('', 8000, 2026, 6, 15),
          obs('', 8000, 2026, 5, 15),
          obs('', 8000, 2026, 4, 15),
        ],
        asOf: asOf,
      );

      expect(result, isEmpty);
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
