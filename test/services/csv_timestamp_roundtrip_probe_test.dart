import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_history_service.dart';
import 'package:my_web_app/services/asset_liability_csv_restore_service.dart';

void main() {
  test('monthly CSV preserves a UTC observation instant including milliseconds', () {
    final observed = DateTime.utc(2026, 10, 23, 3, 6, 7, 123);
    final snapshot = AssetLiabilityMonthlySnapshot(
      monthKey: '2026-10', savedAt: observed,
      positiveAssetTotal: 100, liabilityTotal: -20, netWorth: 80,
      cashLikeTotal: 100, monthlyScheduledPaymentTotal: 10,
      monthlyPaidPaymentTotal: 0, monthlyUnpaidPaymentTotal: 10,
      overduePaymentCount: 0,
    );
    final csv = const AssetLiabilityHistoryService().buildMonthlyHistoryCsv([snapshot]);
    final preview = const AssetLiabilityCsvRestoreService().previewCsvSections({
      AssetLiabilityCsvRestoreSection.monthlyHistory: csv,
    });
    expect(preview.rejectedRows, isEmpty);
    expect(preview.monthlySnapshots.single.monthKey, '2026-10');
    expect(preview.monthlySnapshots.single.savedAt.toUtc(), observed);
  });
}
