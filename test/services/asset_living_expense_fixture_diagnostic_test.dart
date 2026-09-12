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

  test('diagnose original fixed-bill fixture across September midnight', () {
    for (final day in <int>[11, 12]) {
      final workbook = planner.buildWorkbook(
        latestSnapshot: snapshot,
        baseDate: DateTime(2026, 9, day),
        paymentDayOverrides: <String, int>{'mobit': day},
        includeDefaultFixedPayments: true,
        salaryDay: 25,
      );
      final report = service.buildReport(workbook: workbook);
      final livingIndex = report.actionItems.indexWhere(
        (item) => item.type == AssetManagementInsightActionType.emergencyLivingExpense,
      );
      // Diagnostic output is synthetic fixture data, not user finances.
      // ignore: avoid_print
      print('ORIGINAL day=$day livingIndex=$livingIndex todayAvailable=${report.todayAvailable.availableAmount}');
      for (var i = 0; i < report.actionItems.length; i++) {
        final item = report.actionItems[i];
        // ignore: avoid_print
        print('ACTION day=$day index=$i type=${item.type.name} due=${item.dueDate} title=${item.title}');
      }
      expect(report.todayAvailable.availableAmount, lessThan(0));
      expect(livingIndex, day == 11 ? lessThan(8) : greaterThanOrEqualTo(8));
    }
  });

  test('isolated reorder fixture remains visible across calendar boundaries', () {
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
            (item) => item.type == AssetManagementInsightActionType.emergencyLivingExpense,
          );
          final overdue = report.actionItems.indexWhere(
            (item) => item.type == AssetManagementInsightActionType.overduePayment &&
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