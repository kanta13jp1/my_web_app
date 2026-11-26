import 'package:flutter_test/flutter_test.dart';
import '../utils/hyrum_order_jitter_helper.dart';

Map<String, int> _aggregateCategoryTotals(
  List<Map<String, Object>> rows,
) {
  final totals = <String, int>{};
  for (final row in rows) {
    final category = row['category']! as String;
    final amount = row['amount']! as int;
    totals[category] = (totals[category] ?? 0) + amount;
  }
  final sortedKeys = totals.keys.toList()..sort();
  return <String, int>{
    for (final key in sortedKeys) key: totals[key]!,
  };
}

void main() {
  group('Hyrum order invariance', () {
    test('permuteWithSeed is reproducible and varies order across seeds', () {
      const items = <int>[1, 2, 3, 4, 5, 6];
      final first = permuteWithSeed<int>(items, seed: 11);
      final repeated = permuteWithSeed<int>(items, seed: 11);
      final other = permuteWithSeed<int>(items, seed: 83);

      expect(first, repeated);
      expect(first.length, items.length);
      expect(first.toSet(), items.toSet());
      expect(other, isNot(equals(first)));
    });

    test('unordered Supabase mock rows aggregate identically across seeds', () {
      final baseRows = <Map<String, Object>>[
        <String, Object>{'id': '1', 'category': 'food', 'amount': 1200},
        <String, Object>{'id': '2', 'category': 'books', 'amount': 2400},
        <String, Object>{'id': '3', 'category': 'food', 'amount': 800},
        <String, Object>{'id': '4', 'category': 'transit', 'amount': 540},
        <String, Object>{'id': '5', 'category': 'books', 'amount': 600},
      ];

      final expected = _aggregateCategoryTotals(baseRows);

      for (final seed in hyrumDefaultSeeds) {
        final permuted = permuteWithSeed<Map<String, Object>>(
          baseRows,
          seed: seed,
        );
        expect(
          _aggregateCategoryTotals(permuted),
          expected,
          reason: 'Aggregation diverged for seed=$seed',
        );
      }
    });
  });
}
