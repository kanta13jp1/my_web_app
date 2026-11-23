import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';
import 'package:my_web_app/services/asset_transfer_conflict_service.dart';

void main() {
  group('AssetTransferConflictService (#3298)', () {
    test('detects reverse-direction task vs suggestion within maxDayGap', () {
      final tasks = [
        AssetLiabilityTransferTask(
          id: 't-active-match',
          fromAccountId: 'smbc',
          fromAccountName: '三井住友銀行大塚支店',
          toAccountId: 'jibun',
          toAccountName: 'じぶん銀行',
          amount: 80000,
          dueDate: DateTime(2026, 6, 26),
        ),
        AssetLiabilityTransferTask(
          id: 't-too-far',
          fromAccountId: 'smbc',
          fromAccountName: '三井住友銀行大塚支店',
          toAccountId: 'jibun',
          toAccountName: 'じぶん銀行',
          amount: 10000,
          dueDate: DateTime(2026, 6, 20),
        ),
        AssetLiabilityTransferTask(
          id: 't-completed',
          fromAccountId: 'smbc',
          fromAccountName: '三井住友銀行大塚支店',
          toAccountId: 'jibun',
          toAccountName: 'じぶん銀行',
          amount: 30000,
          dueDate: DateTime(2026, 6, 26),
          completed: true,
        ),
        AssetLiabilityTransferTask(
          id: 't-canceled',
          fromAccountId: 'smbc',
          fromAccountName: '三井住友銀行大塚支店',
          toAccountId: 'jibun',
          toAccountName: 'じぶん銀行',
          amount: 30000,
          dueDate: DateTime(2026, 6, 26),
          canceled: true,
        ),
      ];
      final suggestions = [
        AssetLiabilityTransferSuggestion(
          fromAccountId: 'jibun',
          fromAccountName: 'じぶん銀行',
          toAccountId: 'smbc',
          toAccountName: '三井住友銀行大塚支店',
          amount: 56461,
          neededBy: DateTime(2026, 6, 26),
        ),
      ];

      final conflicts = AssetTransferConflictService.detectReverseConflicts(
        tasks: tasks,
        suggestions: suggestions,
      );

      expect(conflicts.length, 1);
      expect(conflicts.single.task.id, 't-active-match');
      expect(conflicts.single.dayGap, 0);
      expect(conflicts.single.recommendedDifferenceAmount, 23539);
      expect(conflicts.single.summary, contains('逆方向提案'));
    });

    test('populates workbook.collisionTransfers and warning insight action',
        () {
      final workbook = const AssetLiabilityPlanningService().buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 100000,
          'じぶん銀行': 150000,
          'モビット': -500000,
        },
        baseDate: DateTime(2026, 6, 25),
        paymentDayOverrides: const <String, int>{'モビット': 26},
        monthlyPaymentOverrides: const <String, double>{'モビット': 120000},
        defaultPaymentSourceAccountIds: const <String, String>{
          'モビット': 'smbc_otsuka_branch',
        },
        transferTasks: [
          AssetLiabilityTransferTask(
            id: 'conflict-task-1',
            fromAccountId: 'smbc_otsuka_branch',
            fromAccountName: '三井住友銀行大塚支店',
            toAccountId: 'jibun_bank',
            toAccountName: 'じぶん銀行',
            amount: 80000,
            dueDate: DateTime(2026, 6, 26),
          ),
        ],
        includeDefaultFixedPayments: false,
        salaryDay: 25,
      );

      expect(workbook.transferSuggestions, isNotEmpty);
      expect(workbook.collisionTransfers, isNotEmpty);

      final report = const AssetManagementInsightService().buildReport(
        workbook: workbook,
      );
      expect(
        report.actionItems.any(
          (item) =>
              item.type == AssetManagementInsightActionType.transferConflict,
        ),
        isTrue,
      );
    });
  });
}
