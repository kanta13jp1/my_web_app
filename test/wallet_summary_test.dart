import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/wallet_summary.dart';

void main() {
  group('WalletSummary.fromResponse', () {
    test('parses balance and nested metadata transactions from EF response',
        () {
      final summary = WalletSummary.fromResponse({
        'success': true,
        'balance': 1500,
        'currency': 'JPY',
        'transactions': [
          {
            'id': 'a',
            'metadata': {
              'amount': 2000,
              'type': 'deposit',
              'method': 'card',
              'currency': 'JPY',
              'user_id': 'u1',
            },
            'created_at': '2026-07-10T09:00:00Z',
          },
          {
            'id': 'b',
            'metadata': {
              'amount': -500,
              'type': 'payment',
              'to': 'alice',
              'currency': 'JPY',
              'user_id': 'u1',
            },
            'created_at': '2026-07-11T12:00:00Z',
          },
        ],
      });

      expect(summary.balance, 1500);
      expect(summary.transactions.length, 2);

      final deposit = summary.transactions[0];
      expect(deposit.amount, 2000);
      expect(deposit.type, 'deposit');
      expect(deposit.note, 'card');
      expect(deposit.isCredit, isTrue);
      expect(deposit.label, '入金・card');

      final payment = summary.transactions[1];
      expect(payment.amount, -500);
      expect(payment.type, 'payment');
      expect(payment.note, 'alice');
      expect(payment.isCredit, isFalse);
      expect(payment.label, '支払い・alice');
    });

    test(
        'does NOT fabricate ¥0 / debit rows (regression: old code read '
        'flat tx[amount]/tx[type]/tx[description])', () {
      // 旧実装は tx['amount'] / tx['type'] / tx['description'] を読み、
      // 存在しないため全行「取引 N / ¥0 / 支出(赤)」を描画していた。
      final summary = WalletSummary.fromResponse({
        'balance': 2000,
        'transactions': [
          {
            'metadata': {'amount': 2000, 'type': 'deposit', 'method': 'bank'},
            'created_at': '2026-07-12T00:00:00Z',
          },
        ],
      });
      final tx = summary.transactions.single;
      expect(tx.amount, 2000, reason: 'metadata.amount を読むべき');
      expect(tx.amount, isNot(0), reason: '捏造の 0 を出してはならない');
      expect(tx.isCredit, isTrue, reason: '入金は緑・下矢印であるべき');
      expect(tx.label, contains('入金'));
    });

    test('derives balance from transactions when EF omits balance (bare list)',
        () {
      final summary = WalletSummary.fromResponse([
        {
          'metadata': {'amount': 3000, 'type': 'deposit'},
          'created_at': '2026-07-01T00:00:00Z',
        },
        {
          'metadata': {'amount': -1000, 'type': 'payment'},
          'created_at': '2026-07-02T00:00:00Z',
        },
      ]);
      expect(summary.balance, 2000);
      expect(summary.transactions.length, 2);
    });

    test('treats explicit balance:0 as valid (not derived)', () {
      final summary = WalletSummary.fromResponse({
        'balance': 0,
        'transactions': <dynamic>[],
      });
      expect(summary.balance, 0);
      expect(summary.isEmpty, isTrue);
    });

    test('handles null / malformed responses gracefully', () {
      expect(WalletSummary.fromResponse(null).isEmpty, isTrue);
      expect(WalletSummary.fromResponse(null).balance, 0);
      expect(WalletSummary.fromResponse('oops').isEmpty, isTrue);
    });

    test('parses numeric strings and falls back to legacy flat keys', () {
      final summary = WalletSummary.fromResponse({
        'balance': '750',
        'transactions': [
          // legacy flat shape without nested metadata
          {'amount': '750', 'type': 'deposit', 'created_at': ''},
        ],
      });
      expect(summary.balance, 750);
      expect(summary.transactions.single.amount, 750);
      expect(summary.transactions.single.type, 'deposit');
    });

    test('label falls back to sign when type is missing/unknown', () {
      final credit = WalletTransaction.fromMap({
        'metadata': {'amount': 500},
        'created_at': '',
      });
      expect(credit.label, '入金');

      final debit = WalletTransaction.fromMap({
        'metadata': {'amount': -500},
        'created_at': '',
      });
      expect(debit.label, '支払い');
    });

    test('reads nested reason and uses type to classify zero amounts', () {
      final payment = WalletTransaction.fromMap({
        'metadata': {
          'amount': 0,
          'type': 'payment',
          'reason': '返金調整',
        },
      });
      final deposit = WalletTransaction.fromMap({
        'metadata': {'amount': 0, 'type': 'deposit'},
      });

      expect(payment.note, '返金調整');
      expect(payment.label, '支払い・返金調整');
      expect(payment.isCredit, isFalse);
      expect(deposit.isCredit, isTrue);
    });
  });

  group('formatWalletYen', () {
    test('adds thousands separators for integers', () {
      expect(formatWalletYen(1500), '1,500');
      expect(formatWalletYen(1000000), '1,000,000');
      expect(formatWalletYen(0), '0');
      expect(formatWalletYen(999), '999');
    });

    test('renders negatives and decimals', () {
      expect(formatWalletYen(-1200), '-1,200');
      expect(formatWalletYen(12.5), '12.50');
    });
  });

  group('formatWalletTimestamp', () {
    test('formats ISO timestamp to yyyy/MM/dd HH:mm', () {
      // toLocal() depends on host timezone, so assert on the shape only.
      final formatted = formatWalletTimestamp('2026-07-12T03:45:00Z');
      expect(
        RegExp(r'^\d{4}/\d{2}/\d{2} \d{2}:\d{2}$').hasMatch(formatted),
        isTrue,
        reason: 'got: $formatted',
      );
    });

    test('returns empty string for empty input', () {
      expect(formatWalletTimestamp(''), '');
    });

    test('returns raw string when unparseable', () {
      expect(formatWalletTimestamp('not-a-date'), 'not-a-date');
    });
  });
}
