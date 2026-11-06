import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_inputs.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

// Synthetic-only characterization of fixed baseline a67c93e; no user data.
// This records current classification; it does not endorse the result.
void main() {
  test('negative synthetic bank becomes liability, not forecast cash', () {
    final workbook = const AssetLiabilityPlanningService().buildWorkbook(
      latestSnapshot: const {'架空銀行A': 500, '架空銀行B': -1000},
      baseDate: DateTime(2026, 6, 15),
    );
    final positive = workbook.accounts.singleWhere((a) => a.name == '架空銀行A');
    final negative = workbook.accounts.singleWhere((a) => a.name == '架空銀行B');
    expect(positive.kind, AssetLiabilityAccountKind.deposit);
    expect(positive.balance, 500);
    expect(negative.kind, AssetLiabilityAccountKind.cardLoan);
    expect(negative.balance, -1000);
    expect(negative.isLiability, isTrue);
    expect(workbook.liabilityTotal, -1000);

    final inputs = AssetCashflowForecastInputs.fromAssetData(
      accounts: workbook.accounts,
      debtRows: workbook.debtMasterRows,
      recurringIncomeTemplates: const [],
      inflowRules: const [],
      oneTimeInflows: const [],
      subscriptions: const [],
    );
    expect(inputs.startingBalance, 500);
  });
}
