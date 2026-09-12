import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';

void main() {
  const planner = AssetLiabilityPlanningService();
  const service = AssetManagementInsightService();
  const snapshot = <String, double>{
    '財布(現金)': 1000,
    'モビット': -300000,
  };
  const paidDefaults = <String>{
    AssetLiabilityPlanningService.kddiProviderAccountId,
    AssetLiabilityPlanningService.rentAccountId,
    AssetLiabilityPlanningService.waterBillAccountId,
    AssetLiabilityPlanningService.gasBillAccountId,
  };

  test('isolated reorder fixture remains visible across calendar boundaries',
      () {
    for (var month = 1; month <= 12; month++) {
      for (final day in <int>[1, 11, 12, 22, 25, 28]) {
        final workbook = planner.buildWorkbook(
          latestSnapshot: snapshot,
          baseDate: DateTime(2026, month, day),
          paymentDayOverrides: <String, int>{'mobit': day},
          paidAccountNames: paidDefaults,
          includeDefaultFixedPayments: true,
          salaryDay: 25,
        );
        for (final priority in <bool>[false, true]) {
          final report = service.buildReport(
            workbook: workbook,
            livingExpensePriorityMode: priority,
          );
          final living = report.actionItems.indexWhere(
            (item) =>
                item.type ==
                AssetManagementInsightActionType.emergencyLivingExpense,
          );
          final overdue = report.actionItems.indexWhere(
            (item) =>
                item.type == AssetManagementInsightActionType.overduePayment &&
                item.relatedAccountId == 'mobit',
          );
          final reason = 'month=$month day=$day priority=$priority';
          expect(living, inInclusiveRange(0, 7), reason: reason);
          expect(overdue, inInclusiveRange(0, 7), reason: reason);
          expect(living < overdue, priority, reason: reason);
        }
      }
    }
  });
}
