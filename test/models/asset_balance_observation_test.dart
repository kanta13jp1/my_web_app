import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_balance_observation.dart';

void main() {
  test('renders UTC and offset timestamps at the same Japan time', () {
    AssetBalanceObservation row(String timestamp) =>
        AssetBalanceObservation.fromRow({
          'id': 1,
          'title': '銀行',
          'amount': -170423,
          'created_at': timestamp,
        });
    expect(row('2026-10-10T17:18:00Z').timestampLabel,
        '2026-10-11 02:18 JST');
    expect(row('2026-10-11T02:18:00+09:00').timestampLabel,
        '2026-10-11 02:18 JST');
    expect(row('2026-10-09T08:39:00Z').timestampLabel,
        '2026-10-09 17:39 JST');
    expect(row('2026-10-10T17:18:00Z').amount, -170423);
  });

  test('keeps same-day and equal-value observations ordered by time then id', () {
    final rows = [
      for (final pair in [(1, '02:18'), (3, '17:44'), (2, '17:44')])
        AssetBalanceObservation(
          id: pair.$1,
          accountName: '銀行',
          amount: 81234,
          recordedAt: DateTime.parse('2026-10-11T${pair.$2}:00+09:00'),
        ),
    ]..sort(AssetBalanceObservation.newestFirst);
    expect(rows.map((row) => row.id), [3, 2, 1]);
    expect(rows.length, 3);
  });
}
