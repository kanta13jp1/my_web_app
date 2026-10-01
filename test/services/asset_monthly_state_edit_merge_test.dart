import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_monthly_state_edit_merge.dart';

void main() {
  test('an automatic save preserves remote paid amounts and Claude source', () {
    const stale = AssetLiabilityMonthlyState(
      paymentSourceAccountIds: {'custom_claude': 'acom_shopping'},
    );
    const remote = AssetLiabilityMonthlyState(
      paidAccountNames: {'rent', 'famipay', 'paypay'},
      actualPaymentAmounts: {'rent': 63000, 'famipay': 11000, 'paypay': 17080},
      paymentSourceAccountIds: {'custom_claude': 'famima'},
    );
    final merged = mergeAssetMonthlyStateEdits(
      monthKey: '2026-09',
      base: stale,
      edited: stale,
      remote: remote,
    );
    expect(merged.paidAccountNames, remote.paidAccountNames);
    expect(merged.actualPaymentAmounts, remote.actualPaymentAmounts);
    expect(merged.paymentSourceAccountIds['custom_claude'], 'famima');
  });

  test('an explicit uncheck removes only that account', () {
    final merged = mergeAssetMonthlyStateEdits(
      monthKey: '2026-09',
      base: const AssetLiabilityMonthlyState(paidAccountNames: {'rent'}),
      edited: const AssetLiabilityMonthlyState(),
      remote: const AssetLiabilityMonthlyState(
        paidAccountNames: {'rent', 'paypay'},
      ),
    );
    expect(merged.paidAccountNames, {'paypay'});
  });

  test('same-field amount conflict stops instead of overwriting', () {
    expect(
      () => mergeAssetMonthlyStateEdits(
        monthKey: '2026-09',
        base: const AssetLiabilityMonthlyState(
          paymentOverrides: {'claude': 3000},
        ),
        edited: const AssetLiabilityMonthlyState(
          paymentOverrides: {'claude': 3500},
        ),
        remote: const AssetLiabilityMonthlyState(
          paymentOverrides: {'claude': 3574},
        ),
      ),
      throwsStateError,
    );
  });

  test('receiving one salary does not remove another remote income plan', () {
    final salary = AssetLiabilityIncomePlan(
      id: 'salary',
      date: DateTime(2026, 9, 25),
      name: 'Salary',
      amount: 416709,
      destinationAccountId: null,
      destinationAccountName: null,
      received: false,
    );
    final received = AssetLiabilityIncomePlan(
      id: 'salary',
      date: DateTime(2026, 9, 25),
      name: 'Salary',
      amount: 416709,
      destinationAccountId: null,
      destinationAccountName: null,
      received: true,
    );
    final bonus = AssetLiabilityIncomePlan(
      id: 'bonus',
      date: DateTime(2026, 10, 1),
      name: 'Bonus',
      amount: 1000,
      destinationAccountId: null,
      destinationAccountName: null,
      received: false,
    );
    final merged = mergeAssetMonthlyStateEdits(
      monthKey: '2026-09',
      base: AssetLiabilityMonthlyState(incomePlans: [salary]),
      edited: AssetLiabilityMonthlyState(incomePlans: [received]),
      remote: AssetLiabilityMonthlyState(incomePlans: [salary, bonus]),
    );
    expect(merged.incomePlans.length, 2);
    expect(
      merged.incomePlans.firstWhere((p) => p.id == 'salary').received,
      isTrue,
    );
  });

  test('new-cycle saves contain no previous-cycle paid flags', () {
    final merged = mergeAssetMonthlyStateEdits(
      monthKey: '2026-10',
      base: const AssetLiabilityMonthlyState(),
      edited: const AssetLiabilityMonthlyState(),
      remote: const AssetLiabilityMonthlyState(),
    );
    expect(merged.paidAccountNames, isEmpty);
  });
}
