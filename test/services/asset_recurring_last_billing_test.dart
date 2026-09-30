import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_fixed_cost_summary_service.dart';
import 'package:my_web_app/services/asset_recurring_fixed_cost_store.dart';

void main() {
  const original = AssetRecurringFixedCost(
    id: 'synthetic', name: 'Synthetic subscription', amount: 1000,
    paymentDay: 31, category: AssetRecurringFixedCostCategory.subscription,
  );
  test('old JSON remains active and strict dates reject calendar overflow', () {
    final restored = AssetRecurringFixedCost.fromJson('synthetic', original.toJson())!;
    expect(restored.lastBillingDate, isNull);
    expect(restored.appliesToBillingMonth(DateTime(2027, 1)), isTrue);
    expect(AssetRecurringFixedCost.parseBillingDate('2026-02-30'), isNull);
    expect(AssetRecurringFixedCost.parseBillingDate('2026-2-28'), isNull);
  });
  test('last billing is inclusive and month end is clamped', () {
    final cost = original.copyWith(lastBillingDate: DateTime(2026, 2, 28));
    expect(cost.appliesToBillingMonth(DateTime(2026, 2)), isTrue);
    expect(cost.appliesToPaymentDate(DateTime(2026, 3, 1)), isFalse);
    expect(cost.appliesToBillingMonth(DateTime(2026, 3)), isFalse);
    expect(cost.appliesToBillingMonth(DateTime(2026, 1)), isTrue);
    final odd = cost.copyWith(cadence: AssetRecurringFixedCostCadence.bimonthlyOddMonth);
    expect(odd.appliesToBillingMonth(DateTime(2026, 2)), isFalse);
    expect(odd.appliesToBillingMonth(DateTime(2026, 1)), isTrue);
  });
  test('mirror roundtrip and edits retain last billing until explicit clear', () {
    final cost = original.copyWith(lastBillingDate: DateTime(2026, 12, 31));
    final restored = AssetRecurringFixedCostStore.decodeMirrorValue(
      AssetRecurringFixedCostStore.encodeMirrorValue([cost]),
    ).single;
    expect(restored.lastBillingDate, DateTime(2026, 12, 31));
    expect(restored.copyWith(amount: 2000).lastBillingDate, cost.lastBillingDate);
    expect(restored.copyWith(clearLastBillingDate: true).lastBillingDate, isNull);
  });
  test('salary cycle uses actual billing year and keeps direct unpaid debt', () {
    final cost = original.copyWith(paymentDay: 5, lastBillingDate: DateTime(2026, 12, 5));
    const service = AssetLiabilityPlanningService();
    final prior = service.buildWorkbook(
      latestSnapshot: const {'bank': 30000.0}, baseDate: DateTime(2026, 11, 26),
      salaryDay: 25, recurringFixedCosts: [cost],
    );
    expect(prior.debtMasterRows.any((row) => row.name == cost.name), isTrue);
    final future = service.buildWorkbook(
      latestSnapshot: const {'bank': 30000.0}, baseDate: DateTime(2026, 12, 26),
      salaryDay: 25, recurringFixedCosts: [cost],
    );
    expect(future.debtMasterRows.any((row) => row.name == cost.name), isFalse);
    final unpaid = service.buildWorkbook(
      latestSnapshot: {cost.name: -1000.0}, baseDate: DateTime(2027, 1, 5),
      recurringFixedCosts: [cost],
    );
    expect(unpaid.debtMasterRows.any((row) => row.name == cost.name), isTrue);
    expect(unpaid.liabilityTotal.abs(), 1000);
  });
  test('summary excludes future plans without erasing known legacy invoices', () {
    final cost = original.copyWith(lastBillingDate: DateTime(2026, 2, 28));
    const service = AssetManagementFixedCostSummaryService();
    expect(service.build(month: DateTime(2026, 2), recurringFixedCosts: [cost]).total, 1000);
    final summary = service.build(
      month: DateTime(2026, 3), recurringFixedCosts: [cost],
      legacySubscriptions: const [
        {'service_name': 'Synthetic subscription', 'price': 600,
          'due_date': '2026-03-05', 'is_paid': false},
      ],
    );
    expect(summary.recurringEntryCount, 0);
    expect(summary.legacyUnpaidTotal, 600);
  });
}
