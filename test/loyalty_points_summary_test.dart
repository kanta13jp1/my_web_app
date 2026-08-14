import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/loyalty_points_summary.dart';

void main() {
  group('LoyaltyPointsSummary.fromResponse', () {
    test('parses balance and nested metadata history from EF response', () {
      final summary = LoyaltyPointsSummary.fromResponse({
        'success': true,
        'balance': 1250,
        'history': [
          {
            'id': 'a',
            'metadata': {
              'amount': 500,
              'reason': '初回登録ボーナス',
              'earned_at': '2026-07-10T09:00:00Z',
              'user_id': 'u1',
            },
            'created_at': '2026-07-10T09:00:00Z',
          },
          {
            'id': 'b',
            'metadata': {
              'amount': -200,
              'reason': 'クーポン交換',
              'redeemed_at': '2026-07-11T12:00:00Z',
              'user_id': 'u1',
            },
            'created_at': '2026-07-11T12:00:00Z',
          },
        ],
      });

      expect(summary.balance, 1250);
      expect(summary.entries.length, 2);

      final earn = summary.entries[0];
      expect(earn.amount, 500);
      expect(earn.reason, '初回登録ボーナス');
      expect(earn.isEarn, isTrue);

      final redeem = summary.entries[1];
      expect(redeem.amount, -200);
      expect(redeem.reason, 'クーポン交換');
      expect(redeem.isEarn, isFalse);
    });

    test('does NOT fabricate +0 pt rows (regression: old code read wrong keys)',
        () {
      // 旧実装は item['points'] / item['type'] / item['description'] を読み、
      // 存在しないため全行「ポイント N / +0 pt」を描画していた。
      final summary = LoyaltyPointsSummary.fromResponse({
        'balance': 500,
        'history': [
          {
            'metadata': {'amount': 500, 'reason': 'キャンペーン付与'},
            'created_at': '2026-07-12T00:00:00Z',
          },
        ],
      });
      final entry = summary.entries.single;
      expect(entry.amount, 500, reason: 'metadata.amount を読むべき');
      expect(entry.amount, isNot(0), reason: '捏造の 0 を出してはならない');
      expect(entry.reason, 'キャンペーン付与');
    });

    test('derives balance from entries when EF omits balance (bare list)', () {
      final summary = LoyaltyPointsSummary.fromResponse([
        {
          'metadata': {'amount': 300, 'reason': 'A'},
          'created_at': '2026-07-01T00:00:00Z',
        },
        {
          'metadata': {'amount': -100, 'reason': 'B'},
          'created_at': '2026-07-02T00:00:00Z',
        },
      ]);
      expect(summary.balance, 200);
      expect(summary.entries.length, 2);
    });

    test('treats explicit balance:0 as valid (not derived)', () {
      final summary = LoyaltyPointsSummary.fromResponse({
        'balance': 0,
        'history': <dynamic>[],
      });
      expect(summary.balance, 0);
      expect(summary.isEmpty, isTrue);
    });

    test('handles null / malformed responses gracefully', () {
      expect(LoyaltyPointsSummary.fromResponse(null).isEmpty, isTrue);
      expect(LoyaltyPointsSummary.fromResponse(null).balance, 0);
      expect(LoyaltyPointsSummary.fromResponse('oops').isEmpty, isTrue);
    });

    test('parses numeric strings and falls back to legacy flat keys', () {
      final summary = LoyaltyPointsSummary.fromResponse({
        'balance': '750',
        'history': [
          // legacy flat shape without nested metadata
          {'points': '750', 'description': '旧形式', 'created_at': ''},
        ],
      });
      expect(summary.balance, 750);
      expect(summary.entries.single.amount, 750);
      expect(summary.entries.single.reason, '旧形式');
    });

    test('uses fallback reason when missing', () {
      final summary = LoyaltyPointsSummary.fromResponse({
        'balance': 10,
        'history': [
          {
            'metadata': {'amount': 10},
            'created_at': '2026-07-12T00:00:00Z',
          },
        ],
      });
      expect(summary.entries.single.reason, 'ポイント履歴');
    });
  });

  group('formatLoyaltyPoints', () {
    test('adds thousands separators for integers', () {
      expect(formatLoyaltyPoints(1250), '1,250');
      expect(formatLoyaltyPoints(1000000), '1,000,000');
      expect(formatLoyaltyPoints(0), '0');
      expect(formatLoyaltyPoints(999), '999');
    });

    test('renders negatives and decimals', () {
      expect(formatLoyaltyPoints(-1200), '-1,200');
      expect(formatLoyaltyPoints(12.5), '12.50');
    });
  });

  group('formatLoyaltyTimestamp', () {
    test('formats ISO timestamp to yyyy/MM/dd HH:mm', () {
      // Use a value with explicit offset and assert on the shape only, since
      // toLocal() depends on the host timezone.
      final formatted = formatLoyaltyTimestamp('2026-07-12T03:45:00Z');
      expect(
        RegExp(r'^\d{4}/\d{2}/\d{2} \d{2}:\d{2}$').hasMatch(formatted),
        isTrue,
        reason: 'got: $formatted',
      );
    });

    test('returns empty string for empty input', () {
      expect(formatLoyaltyTimestamp(''), '');
    });

    test('returns raw string when unparseable', () {
      expect(formatLoyaltyTimestamp('not-a-date'), 'not-a-date');
    });
  });
}
