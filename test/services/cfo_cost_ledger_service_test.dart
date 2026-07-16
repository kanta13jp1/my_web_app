import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/cfo_cost_ledger.dart';
import 'package:my_web_app/services/cfo_cost_ledger_service.dart';

void main() {
  group('CfoCostLedgerService', () {
    test('summarizes fixed and variable costs with budget difference', () {
      final entries = <CfoCostEntry>[
        CfoCostEntry(
          id: '1',
          item: 'Supabase Pro',
          category: 'infrastructure',
          amountJpy: 3800,
          incurredOn: DateTime(2026, 5, 1),
          costType: CfoCostType.fixed,
          note: '',
        ),
        CfoCostEntry(
          id: '2',
          item: '広告テスト',
          category: 'marketing',
          amountJpy: 12000,
          incurredOn: DateTime(2026, 5, 2),
          costType: CfoCostType.variable,
          note: 'LP検証',
        ),
      ];

      final summary = CfoCostLedgerService.summarize(
        entries: entries,
        month: '2026-05',
        budgetJpy: 20000,
      );

      expect(summary.fixedCostJpy, 3800);
      expect(summary.variableCostJpy, 12000);
      expect(summary.totalCostJpy, 15800);
      expect(summary.budgetRemainingJpy, 4200);
      expect(summary.isOverBudget, isFalse);
      expect(summary.categoryTotals.keys.first, 'marketing');
    });

    test('detects over-budget month', () {
      final summary = CfoCostLedgerService.summarize(
        entries: <CfoCostEntry>[
          CfoCostEntry(
            id: '1',
            item: '外注レビュー',
            category: 'operations',
            amountJpy: 45000,
            incurredOn: DateTime(2026, 5, 3),
            costType: CfoCostType.variable,
            note: '',
          ),
        ],
        month: '2026-05',
        budgetJpy: 30000,
      );

      expect(summary.isOverBudget, isTrue);
      expect(summary.budgetRemainingJpy, -15000);
      expect(summary.budgetUsageRatio, greaterThan(1));
    });
  });

  group('CfoCostEntry', () {
    test('parses Supabase rows', () {
      final entry = CfoCostEntry.fromMap(<String, dynamic>{
        'id': 'row-1',
        'item': 'AIツール',
        'category': 'tools',
        'amount_jpy': 9800,
        'incurred_on': '2026-05-03',
        'cost_type': 'fixed',
        'note': 'monthly',
        'created_at': '2026-05-03T00:00:00Z',
      });

      expect(entry.id, 'row-1');
      expect(entry.item, 'AIツール');
      expect(entry.amountJpy, 9800);
      expect(entry.costType, CfoCostType.fixed);
      expect(cfoLedgerMonth(entry.incurredOn), '2026-05');
    });

    test('draft serializes insert payload with user id', () {
      final draft = CfoCostEntryDraft(
        item: '交通費',
        category: 'travel',
        amountJpy: 1200,
        incurredOn: DateTime(2026, 5, 3),
        costType: CfoCostType.variable,
        note: '顧客訪問',
      );

      final payload = draft.toInsertMap('user-1');
      expect(payload['user_id'], 'user-1');
      expect(payload['amount_jpy'], 1200);
      expect(payload['incurred_on'], '2026-05-03');
      expect(payload['cost_type'], 'variable');
    });
  });
}
