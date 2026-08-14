import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';

/// 収入予定・定期収入の「入金先」候補口座を返す純関数を検証する。
/// 支払原資 (_paymentSourceAccountOptions) と違い、入金先は残高が 0 以下でも選べる
/// 必要がある (給料日前に残高が尽きた口座・当座マイナスの口座にも給料を入金するため)。
AssetLiabilityAccount _account({
  required String id,
  required AssetLiabilityAccountKind kind,
  required double balance,
}) {
  return AssetLiabilityAccount(
    id: id,
    name: id,
    kind: kind,
    balance: balance,
  );
}

void main() {
  group('incomeDestinationAccountOptions', () {
    test('現金・預金は残高が 0 以下でも入金先候補に含める', () {
      final options = incomeDestinationAccountOptions([
        _account(
          id: 'cash-zero',
          kind: AssetLiabilityAccountKind.cash,
          balance: 0,
        ),
        _account(
          id: 'deposit-negative',
          kind: AssetLiabilityAccountKind.deposit,
          balance: -12000,
        ),
        _account(
          id: 'deposit-positive',
          kind: AssetLiabilityAccountKind.deposit,
          balance: 50000,
        ),
      ]);

      final ids = options.map((a) => a.id).toList();
      // 残高 0 の現金・当座マイナスの預金も含まれる (支払原資フィルタとの決定的な差)。
      expect(ids, containsAll(<String>['cash-zero', 'deposit-negative']));
      expect(ids, contains('deposit-positive'));
    });

    test('与信枠 (クレカ/ショッピング枠/カードローン) は入金先にならない', () {
      final options = incomeDestinationAccountOptions([
        _account(
          id: 'card',
          kind: AssetLiabilityAccountKind.creditCard,
          balance: -30000,
        ),
        _account(
          id: 'shopping',
          kind: AssetLiabilityAccountKind.shoppingDebt,
          balance: -40000,
        ),
        _account(
          id: 'loan',
          kind: AssetLiabilityAccountKind.cardLoan,
          balance: -100000,
        ),
        _account(
          id: 'deposit',
          kind: AssetLiabilityAccountKind.deposit,
          balance: 1000,
        ),
      ]);

      expect(options.map((a) => a.id), <String>['deposit']);
    });

    test('残高の大きい順に並ぶ (マイナスは末尾)', () {
      final options = incomeDestinationAccountOptions([
        _account(
          id: 'mid',
          kind: AssetLiabilityAccountKind.deposit,
          balance: 10000,
        ),
        _account(
          id: 'high',
          kind: AssetLiabilityAccountKind.cash,
          balance: 80000,
        ),
        _account(
          id: 'low',
          kind: AssetLiabilityAccountKind.deposit,
          balance: -5000,
        ),
      ]);

      expect(
        options.map((a) => a.id).toList(),
        <String>['high', 'mid', 'low'],
      );
    });

    test('候補が無いときは空リストを返す', () {
      final options = incomeDestinationAccountOptions([
        _account(
          id: 'card',
          kind: AssetLiabilityAccountKind.creditCard,
          balance: -1000,
        ),
      ]);

      expect(options, isEmpty);
    });
  });
}
