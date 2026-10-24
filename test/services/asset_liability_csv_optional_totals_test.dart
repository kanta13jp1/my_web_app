import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_history_service.dart';
import 'package:my_web_app/services/asset_liability_csv_restore_service.dart';

void main() {
  for (final value in <double?>[null, 0, 123]) {
    test('monthly CSV preserves tracked optional totals: $value', () {
      final input = AssetLiabilityMonthlySnapshot(
        monthKey: '2026-10',
        savedAt: DateTime.utc(2026, 10, 23),
        positiveAssetTotal: 200,
        liabilityTotal: -20,
        netWorth: 180,
        cashLikeTotal: 100,
        monthlyScheduledPaymentTotal: 60,
        monthlyPaidPaymentTotal: 40,
        monthlyUnpaidPaymentTotal: 20,
        monthlyActualPaymentTotal: 34,
        monthlyPaymentDifferenceTotal: -6,
        overduePaymentCount: 7,
        securitiesTotal: value,
        monthlyReceivedIncomeTotal: value,
      );
      final csv =
          const AssetLiabilityHistoryService().buildMonthlyHistoryCsv([input]);
      final result =
          const AssetLiabilityCsvRestoreService().previewCsvSections({
        AssetLiabilityCsvRestoreSection.monthlyHistory: csv,
      });
      expect(result.rejectedRows, isEmpty);
      final restored = result.monthlySnapshots.single;
      expect(restored.monthKey, input.monthKey);
      expect(restored.savedAt.toUtc(), input.savedAt.toUtc());
      expect(restored.positiveAssetTotal, 200);
      expect(restored.liabilityTotal, -20);
      expect(restored.netWorth, 180);
      expect(restored.cashLikeTotal, 100);
      expect(restored.monthlyScheduledPaymentTotal, 60);
      expect(restored.monthlyPaidPaymentTotal, 40);
      expect(restored.monthlyUnpaidPaymentTotal, 20);
      expect(restored.overduePaymentCount, 7);
      expect(restored.monthlyActualPaymentTotal, 34);
      expect(restored.monthlyPaymentDifferenceTotal, -6);
      expect(result.monthlySnapshots.single.securitiesTotal, value);
      expect(result.monthlySnapshots.single.monthlyReceivedIncomeTotal, value);
    });
  }
}
