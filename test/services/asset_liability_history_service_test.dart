import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_history_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  group('AssetLiabilityHistoryService', () {
    const historyService = AssetLiabilityHistoryService();
    const planningService = AssetLiabilityPlanningService();

    test('builds monthly snapshot with paid, unpaid, and overdue totals', () {
      final workbook = planningService.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'モビット': -100000,
          'auPayカード': -10000,
        },
        baseDate: DateTime(2026, 5, 20),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 10000,
          'aupay_card': 5000,
        },
        paidAccountNames: const <String>{
          'aupay_card',
        },
      );

      final snapshot = historyService.buildSnapshot(
        monthKey: '2026-05',
        workbook: workbook,
        savedAt: DateTime(2026, 5, 20, 9),
      );

      expect(snapshot.monthKey, '2026-05');
      expect(snapshot.monthlyScheduledPaymentTotal, 15000);
      expect(snapshot.monthlyPaidPaymentTotal, 5000);
      expect(snapshot.monthlyUnpaidPaymentTotal, 10000);
      expect(snapshot.overduePaymentCount, 1);
    });

    test('calculates month-over-month deltas', () {
      final comparisons = historyService.compareSnapshots(
        <AssetLiabilityMonthlySnapshot>[
          AssetLiabilityMonthlySnapshot(
            monthKey: '2026-05',
            savedAt: DateTime(2026, 5, 31),
            positiveAssetTotal: 100000,
            liabilityTotal: -7000000,
            netWorth: -6900000,
            cashLikeTotal: 50000,
            monthlyScheduledPaymentTotal: 120000,
            monthlyPaidPaymentTotal: 80000,
            monthlyUnpaidPaymentTotal: 40000,
            overduePaymentCount: 1,
          ),
          AssetLiabilityMonthlySnapshot(
            monthKey: '2026-06',
            savedAt: DateTime(2026, 6, 30),
            positiveAssetTotal: 130000,
            liabilityTotal: -6800000,
            netWorth: -6670000,
            cashLikeTotal: 70000,
            monthlyScheduledPaymentTotal: 100000,
            monthlyPaidPaymentTotal: 100000,
            monthlyUnpaidPaymentTotal: 0,
            overduePaymentCount: 0,
          ),
        ],
      );

      expect(comparisons.first.snapshot.monthKey, '2026-06');
      expect(comparisons.first.positiveAssetDelta, 30000);
      expect(comparisons.first.liabilityDelta, 200000);
      expect(comparisons.first.netWorthDelta, 230000);
      expect(comparisons.first.cashLikeDelta, 20000);
      expect(comparisons.last.hasPrevious, isFalse);
    });

    test('generates CSV data for history, payments, income, and accounts', () {
      final workbook = planningService.buildWorkbook(
        latestSnapshot: <String, double>{
          'cash': 50000,
          'bank': 10000,
          'モビット': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 20000,
        },
        paymentSourceAccountIds: const <String, String>{
          'mobit': 'custom_bank',
        },
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'income_bonus',
            date: DateTime(2026, 5, 10),
            name: 'Bonus, side income',
            amount: 30000,
            destinationAccountId: 'custom_bank',
            destinationAccountName: null,
            received: false,
          ),
        ],
        includeDefaultFixedPayments: true,
      );

      final bundle = historyService.buildCsvExportBundle(
        monthlySnapshots: <AssetLiabilityMonthlySnapshot>[
          AssetLiabilityMonthlySnapshot(
            monthKey: '2026-05',
            savedAt: DateTime(2026, 5, 31, 20),
            positiveAssetTotal: 60000,
            liabilityTotal: -100000,
            netWorth: -40000,
            cashLikeTotal: 60000,
            monthlyScheduledPaymentTotal: 20000,
            monthlyPaidPaymentTotal: 0,
            monthlyUnpaidPaymentTotal: 20000,
            overduePaymentCount: 0,
          ),
        ],
        workbook: workbook,
      );

      expect(bundle.monthlyHistoryCsv, contains('対象月,保存日時,資産合計'));
      expect(bundle.monthlyHistoryCsv, contains('2026-05'));
      expect(bundle.paymentScheduleCsv, contains('支払先'));
      expect(bundle.paymentScheduleCsv, contains('モビット'));
      expect(bundle.paymentScheduleCsv, contains('KDDI'));
      expect(bundle.paymentScheduleCsv, contains('2026-05-25'));
      expect(bundle.incomePlansCsv, contains('"Bonus, side income"'));
      expect(bundle.accountCashflowCsv, contains('口座,現在残高'));
      expect(bundle.accountCashflowCsv, contains('bank'));
    });
  });
}
