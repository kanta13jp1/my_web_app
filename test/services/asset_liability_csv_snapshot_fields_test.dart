import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_csv_restore_service.dart';
import 'package:my_web_app/services/asset_liability_history_service.dart';

void main() {
  const history = AssetLiabilityHistoryService();
  const restore = AssetLiabilityCsvRestoreService();

  for (final securities in <double?>[null, 0, 123.5]) {
    for (final income in <double?>[null, 0, 456.75]) {
      test('monthly CSV round-trips all fields: $securities / $income', () {
        final input = AssetLiabilityMonthlySnapshot(
          monthKey: '2026-10',
          savedAt: DateTime.utc(2026, 10, 23, 3, 6, 7, 123),
          positiveAssetTotal: 200,
          liabilityTotal: -20,
          netWorth: 180,
          cashLikeTotal: 100,
          monthlyScheduledPaymentTotal: 60,
          monthlyPaidPaymentTotal: 40,
          monthlyUnpaidPaymentTotal: 20,
          overduePaymentCount: 7,
          monthlyActualPaymentTotal: 34,
          monthlyPaymentDifferenceTotal: -6,
          securitiesTotal: securities,
          monthlyReceivedIncomeTotal: income,
        );
        final preview = restore.previewCsvSections({
          AssetLiabilityCsvRestoreSection.monthlyHistory:
              history.buildMonthlyHistoryCsv([input]),
        });

        expect(preview.rejectedRows, isEmpty);
        final actual = preview.monthlySnapshots.single;
        expect(actual.monthKey, input.monthKey);
        expect(actual.savedAt.toUtc(), input.savedAt);
        expect(actual.positiveAssetTotal, input.positiveAssetTotal);
        expect(actual.liabilityTotal, input.liabilityTotal);
        expect(actual.netWorth, input.netWorth);
        expect(actual.cashLikeTotal, input.cashLikeTotal);
        expect(
          actual.monthlyScheduledPaymentTotal,
          input.monthlyScheduledPaymentTotal,
        );
        expect(actual.monthlyPaidPaymentTotal, input.monthlyPaidPaymentTotal);
        expect(
          actual.monthlyUnpaidPaymentTotal,
          input.monthlyUnpaidPaymentTotal,
        );
        expect(actual.overduePaymentCount, input.overduePaymentCount);
        expect(
          actual.monthlyActualPaymentTotal,
          input.monthlyActualPaymentTotal,
        );
        expect(
          actual.monthlyPaymentDifferenceTotal,
          input.monthlyPaymentDifferenceTotal,
        );
        expect(actual.securitiesTotal, securities);
        expect(actual.monthlyReceivedIncomeTotal, income);
      });
    }
  }

  test('legacy monthly CSV keeps absent optional totals unknown', () {
    final preview = restore.previewCsvSections({
      AssetLiabilityCsvRestoreSection.monthlyHistory: [
        'month_key,saved_at,assets,liabilities,net_worth,cash,scheduled,paid,'
            'unpaid,overdue,actual_paid_payment_total,payment_difference_total',
        '2026-10,2026-10-23T03:06:07.123Z,200,-20,180,100,60,40,20,7,34,-6',
      ].join('\n'),
    });

    expect(preview.rejectedRows, isEmpty);
    final actual = preview.monthlySnapshots.single;
    expect(actual.securitiesTotal, isNull);
    expect(actual.monthlyReceivedIncomeTotal, isNull);
    expect(actual.monthlyActualPaymentTotal, 34);
    expect(actual.monthlyPaymentDifferenceTotal, -6);
    expect(actual.savedAt.toUtc(), DateTime.utc(2026, 10, 23, 3, 6, 7, 123));
  });
}
