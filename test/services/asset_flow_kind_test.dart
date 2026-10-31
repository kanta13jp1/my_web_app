import 'package:flutter_test/flutter_test.dart';

import 'package:my_web_app/services/asset_flow_kind.dart';

void main() {
  test('borrowed receipts do not inflate income or expense totals', () {
    const rows = [
      (type: 'borrowing', amount: 10000),
      (type: 'conquer', amount: 480),
      (type: 'expense', amount: 330),
      (type: 'transfer', amount: 20000),
    ];
    var income = 0;
    var expenses = 0;
    for (final row in rows) {
      final kind = AssetFlowKind.fromActionType(row.type);
      if (kind.countsAsIncome) income += row.amount;
      if (kind.countsAsExpense) expenses += row.amount;
    }
    expect(income, 480);
    expect(expenses, 330);
    final receipt = AssetFlowKind.fromActionType('borrowing');
    expect(receipt.label, '借入受取');
    expect(receipt.amountPrefix, '+');
  });

  test('legacy and unknown records are not presented as new expenses', () {
    for (final value in ['defend', 'invest', '', 'future_kind']) {
      final kind = AssetFlowKind.fromActionType(value);
      expect(kind, AssetFlowKind.other);
      expect(kind.countsAsIncome, isFalse);
      expect(kind.countsAsExpense, isFalse);
      expect(kind.amountPrefix, '');
    }
  });
}
