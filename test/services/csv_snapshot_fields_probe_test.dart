import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_history_service.dart';
import 'package:my_web_app/services/asset_liability_csv_restore_service.dart';
void main() {
  for (final value in <double?>[null, 0, 123]) {
    test('monthly CSV preserves tracked optional totals: $value', () {
      final input = AssetLiabilityMonthlySnapshot(
        monthKey: '2026-10', savedAt: DateTime.utc(2026, 10, 23),
        positiveAssetTotal: 200, liabilityTotal: -20, netWorth: 180,
        cashLikeTotal: 100, monthlyScheduledPaymentTotal: 10,
        monthlyPaidPaymentTotal: 0, monthlyUnpaidPaymentTotal: 10,
        overduePaymentCount: 0, securitiesTotal: value,
        monthlyReceivedIncomeTotal: value,
      );
      final csv = const AssetLiabilityHistoryService().buildMonthlyHistoryCsv([input]);
      final result = const AssetLiabilityCsvRestoreService().previewCsvSections({
        AssetLiabilityCsvRestoreSection.monthlyHistory: csv,
      });
      expect(result.rejectedRows, isEmpty);
      expect(result.monthlySnapshots.single.securitiesTotal, value);
      expect(result.monthlySnapshots.single.monthlyReceivedIncomeTotal, value);
    });
  }
}
