import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_management_fixed_cost_summary_service.dart';

void main() {
  group('AssetManagementFixedCostSummaryService', () {
    const service = AssetManagementFixedCostSummaryService();

    test('includes current recurring fixed costs in the monthly total', () {
      final summary = service.build(
        month: DateTime(2026, 8),
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'ai_cloud',
            name: 'AI・クラウドサブスク',
            amount: 104648,
            paymentDay: 15,
            category: AssetRecurringFixedCostCategory.subscription,
          ),
        ],
      );

      expect(summary.total, 104648);
      expect(summary.entries, hasLength(1));
      expect(summary.entries.single.name, 'AI・クラウドサブスク');
      expect(summary.recurringEntryCount, 1);
    });

    test('does not double count matching legacy and recurring entries', () {
      final summary = service.build(
        month: DateTime(2026, 8),
        legacySubscriptions: const <Map<String, dynamic>>[
          <String, dynamic>{
            'service_name': 'Notion',
            'price': 3712,
            'due_date': '2026-08-17',
            'is_paid': false,
          },
        ],
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'notion',
            name: 'Notion',
            amount: 3712,
            paymentDay: 17,
            category: AssetRecurringFixedCostCategory.subscription,
          ),
        ],
      );

      expect(summary.total, 3712);
      expect(summary.entries, hasLength(1));
      expect(summary.entries.single.isLegacy, isFalse);
    });

    test('respects the recurring cadence for the selected month', () {
      final oddMonth = service.build(
        month: DateTime(2026, 7),
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'water',
            name: '水道',
            amount: 5000,
            paymentDay: 10,
            cadence: AssetRecurringFixedCostCadence.bimonthlyEvenMonth,
          ),
        ],
      );
      final evenMonth = service.build(
        month: DateTime(2026, 8),
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'water',
            name: '水道',
            amount: 5000,
            paymentDay: 10,
            cadence: AssetRecurringFixedCostCadence.bimonthlyEvenMonth,
          ),
        ],
      );

      expect(oddMonth.total, 0);
      expect(evenMonth.total, 5000);
    });
  });
}
