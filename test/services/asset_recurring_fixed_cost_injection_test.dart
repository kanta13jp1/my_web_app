import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  const planning = AssetLiabilityPlanningService();

  AssetLiabilityDebtRow? debtRowByName(
    AssetLiabilityWorkbook workbook,
    String name,
  ) {
    for (final row in workbook.debtMasterRows) {
      if (row.name == name) {
        return row;
      }
    }
    return null;
  }

  group('buildWorkbook recurringFixedCosts injection', () {
    test('monthly fixed cost stays scheduled without inflating current debt',
        () {
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'みずほ銀行': 100000},
        baseDate: DateTime(2026, 6, 15),
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'fc_denki',
            name: '電気代',
            amount: 8000,
            paymentDay: 27,
          ),
        ],
      );

      final row = debtRowByName(workbook, '電気代');
      expect(row, isNotNull);
      expect(row!.kind, AssetLiabilityAccountKind.utility);
      expect(row.scheduledPaymentAmount, 8000);
      expect(row.paymentDay, 27);
      expect(row.isDirectCashflowTarget, isTrue);
      expect(row.fullPaymentEstimate, isTrue);
      // 金額を入力済み = 推定ではない → 請求確認待ちにならない。
      expect(row.paymentAmountEstimated, isFalse);
      expect(workbook.liabilityTotal, 0);
      expect(workbook.currentDebtRows, isEmpty);
      expect(
        workbook.hasBillingConfirmationPendingRows,
        isFalse,
      );
    });

    test('empty list leaves the workbook unchanged', () {
      const snapshot = <String, double>{'みずほ銀行': 100000, '楽天カード': -30000};
      final baseline = planning.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 6, 15),
      );
      final withEmpty = planning.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 6, 15),
        recurringFixedCosts: const <AssetRecurringFixedCost>[],
      );
      expect(withEmpty.liabilityTotal, baseline.liabilityTotal);
      expect(
        withEmpty.debtMasterRows.length,
        baseline.debtMasterRows.length,
      );
    });

    test('bimonthly cost only appears in matching months', () {
      const cost = AssetRecurringFixedCost(
        id: 'fc_chonaikai',
        name: '町内会費',
        amount: 1000,
        paymentDay: 10,
        cadence: AssetRecurringFixedCostCadence.bimonthlyEvenMonth,
      );
      final june = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'みずほ銀行': 100000},
        baseDate: DateTime(2026, 6, 15),
        recurringFixedCosts: const <AssetRecurringFixedCost>[cost],
      );
      final july = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'みずほ銀行': 100000},
        baseDate: DateTime(2026, 7, 15),
        recurringFixedCosts: const <AssetRecurringFixedCost>[cost],
      );

      expect(debtRowByName(june, '町内会費'), isNotNull);
      expect(debtRowByName(july, '町内会費'), isNull);
    });

    test('does not double-count when a same-named liability already exists',
        () {
      final workbook = planning.buildWorkbook(
        // ユーザーが既に「電気代」を負債として手動計上している。
        latestSnapshot: const <String, double>{
          'みずほ銀行': 100000,
          '電気代': -5000,
        },
        baseDate: DateTime(2026, 6, 15),
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'fc_denki',
            name: '電気代',
            amount: 8000,
            paymentDay: 27,
          ),
        ],
      );

      final denki =
          workbook.debtMasterRows.where((row) => row.name == '電気代').toList();
      expect(denki.length, 1);
      // 既存の手動計上 (-5000) が優先され、固定費 (8000) は二重計上されない。
      expect(workbook.liabilityTotal, -5000);
    });

    test('source account id flows to the debt row', () {
      final workbook = planning.buildWorkbook(
        latestSnapshot: const <String, double>{'みずほ銀行': 100000},
        baseDate: DateTime(2026, 6, 15),
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'fc_denki',
            name: '電気代',
            amount: 8000,
            paymentDay: 27,
            sourceAccountId: 'smbc_otsuka_branch',
          ),
        ],
      );

      final row = debtRowByName(workbook, '電気代');
      expect(row, isNotNull);
      expect(row!.paymentSourceAccountId, 'smbc_otsuka_branch');
    });
  });
}
