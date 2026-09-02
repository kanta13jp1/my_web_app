import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_inputs.dart';
import 'package:my_web_app/services/asset_expected_inflow_store.dart';

AssetLiabilityAccount _account(
  String name,
  AssetLiabilityAccountKind kind,
  double balance,
) {
  return AssetLiabilityAccount(
    id: name,
    name: name,
    kind: kind,
    balance: balance,
  );
}

void main() {
  group('AssetCashflowForecastInputs.subscriptionRecurringEntry', () {
    test('maps a valid subscription to a recurring entry', () {
      final entry = AssetCashflowForecastInputs.subscriptionRecurringEntry(
        <String, dynamic>{
          'service_name': 'Netflix',
          'price': 1500,
          'due_date': '2026-06-10',
        },
      );

      expect(entry, isNotNull);
      expect(entry!.dayOfMonth, 10);
      expect(entry.amount, 1500);
      expect(entry.label, 'Netflix');
    });

    test('returns null for a non-positive or missing price', () {
      expect(
        AssetCashflowForecastInputs.subscriptionRecurringEntry(
          <String, dynamic>{'price': 0},
        ),
        isNull,
      );
      expect(
        AssetCashflowForecastInputs.subscriptionRecurringEntry(
          <String, dynamic>{'foo': 'bar'},
        ),
        isNull,
      );
    });

    test('falls back to day 1 and 固定費 label when fields are missing', () {
      final entry = AssetCashflowForecastInputs.subscriptionRecurringEntry(
        <String, dynamic>{'price': 980},
      );

      expect(entry!.dayOfMonth, 1);
      expect(entry.label, '固定費');
    });
  });

  group('AssetCashflowForecastInputs.fromAssetData', () {
    test(
        'Issue #5191: deduplicates duplicate salary in recurringIncomeTemplates and inflowRules on the same day',
        () {
      final inputs = AssetCashflowForecastInputs.fromAssetData(
        accounts: const [],
        debtRows: const [],
        recurringIncomeTemplates: const [
          AssetLiabilityRecurringIncomeTemplate(
            id: 't_salary',
            dayOfMonth: 25,
            name: '給料',
            amount: 421277,
            destinationAccountId: null,
            destinationAccountName: null,
          ),
        ],
        inflowRules: const [
          AssetExpectedInflowRule(
            id: 'r_salary',
            dayOfMonth: 25,
            amount: 415547,
            label: '給与振込',
          ),
          AssetExpectedInflowRule(
            id: 'r_side',
            dayOfMonth: 15,
            amount: 50000,
            label: '副業',
          ),
        ],
        oneTimeInflows: const [],
        subscriptions: const [],
      );

      expect(inputs.recurringIncome, hasLength(2));
      final salaryEntry =
          inputs.recurringIncome.firstWhere((e) => e.dayOfMonth == 25);
      expect(salaryEntry.label, '給料');
      expect(salaryEntry.amount, 421277);

      final sideEntry =
          inputs.recurringIncome.firstWhere((e) => e.dayOfMonth == 15);
      expect(sideEntry.label, '副業');
      expect(sideEntry.amount, 50000);
    });

    test('sums only positive cash/deposit balances into startingBalance', () {
      final inputs = AssetCashflowForecastInputs.fromAssetData(
        accounts: [
          _account('財布', AssetLiabilityAccountKind.cash, 11000),
          _account('普通預金', AssetLiabilityAccountKind.deposit, 50000),
          _account('当座マイナス', AssetLiabilityAccountKind.deposit, -3000),
          _account('証券', AssetLiabilityAccountKind.securities, 99999),
        ],
        debtRows: const [],
        recurringIncomeTemplates: const [],
        inflowRules: const [],
        oneTimeInflows: const [],
        subscriptions: const [],
      );

      expect(inputs.startingBalance, 61000);
      expect(inputs.hasData, isFalse);
    });

    test('derives recurring income from templates and inflow rules', () {
      final inputs = AssetCashflowForecastInputs.fromAssetData(
        accounts: const [],
        debtRows: const [],
        recurringIncomeTemplates: const [
          AssetLiabilityRecurringIncomeTemplate(
            id: 't1',
            dayOfMonth: 25,
            name: '給料',
            amount: 300000,
            destinationAccountId: null,
            destinationAccountName: null,
          ),
          AssetLiabilityRecurringIncomeTemplate(
            id: 't0',
            dayOfMonth: 0,
            name: 'invalid-day',
            amount: 1,
            destinationAccountId: null,
            destinationAccountName: null,
          ),
        ],
        inflowRules: const [
          AssetExpectedInflowRule(
            id: 'r1',
            dayOfMonth: 10,
            amount: 20000,
            label: '副業',
          ),
        ],
        oneTimeInflows: const [],
        subscriptions: const [],
      );

      expect(inputs.recurringIncome, hasLength(2));
      expect(
        inputs.recurringIncome.map((e) => e.label),
        containsAll(<String>['給料', '副業']),
      );
      expect(inputs.hasData, isTrue);
    });

    test('subscriptions → recurring outflow; one-time inflows → dated income',
        () {
      final inputs = AssetCashflowForecastInputs.fromAssetData(
        accounts: const [],
        debtRows: const [],
        recurringIncomeTemplates: const [],
        inflowRules: const [],
        oneTimeInflows: [
          AssetExpectedInflow(
            id: 'i1',
            date: DateTime(2026, 7, 5),
            amount: 50000,
            label: '臨時',
          ),
          AssetExpectedInflow(
            id: 'i0',
            date: DateTime(2026, 7, 6),
            amount: 0,
            label: 'zero',
          ),
        ],
        subscriptions: [
          <String, dynamic>{
            'service_name': 'Spotify',
            'price': 980,
            'due_date': '2026-06-15',
          },
          <String, dynamic>{'service_name': 'bad', 'price': 0},
        ],
      );

      expect(inputs.recurringOutflow, hasLength(1));
      expect(inputs.recurringOutflow.single.label, 'Spotify');
      expect(inputs.recurringOutflow.single.dayOfMonth, 15);
      expect(inputs.oneTimeIncome, hasLength(1));
      expect(inputs.oneTimeIncome.single.amount, 50000);
    });
  });
}
