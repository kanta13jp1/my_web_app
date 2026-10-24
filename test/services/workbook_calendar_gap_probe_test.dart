import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_history_service.dart';
import 'package:my_web_app/services/asset_liability_monthly_report_service.dart';

AssetLiabilityMonthlySnapshot snap(String month, double worth) =>
    AssetLiabilityMonthlySnapshot(
      monthKey: month,
      savedAt: DateTime.parse('$month-28'),
      positiveAssetTotal: worth,
      liabilityTotal: 0,
      netWorth: worth,
      cashLikeTotal: worth,
      monthlyScheduledPaymentTotal: 0,
      monthlyPaidPaymentTotal: 0,
      monthlyUnpaidPaymentTotal: 0,
      overduePaymentCount: 0,
    );

void main() {
  const history = AssetLiabilityHistoryService();
  const reports = AssetLiabilityMonthlyReportService();
  test('missing September is not an August-to-October month delta in history', () {
    final rows = history.compareSnapshots([snap('2026-08', 100), snap('2026-10', 200),],);
    expect(rows.first.snapshot.monthKey, '2026-10');
    expect(rows.first.netWorthDelta, isNull);
    expect(rows.first.positiveAssetDelta, isNull);
    expect(rows.first.liabilityDelta, isNull);
    expect(rows.first.cashLikeDelta, isNull);
  },);
  test('missing September does not produce a chart month delta', () {
    final chart = history.buildMonthlyChartData([snap('2026-08', 100), snap('2026-10', 200),],);
    for (final series in chart.series) {
      expect(series.points.last.deltaFromPrevious, isNull);
      expect(series.points.last.worsened, isFalse);
    }
  },);
  test('missing September does not produce a report month delta', () {
    final views = reports.buildReportViews(
      snapshots: [snap('2026-08', 100), snap('2026-10', 200),],
      reports: const <AssetLiabilityMonthlyReport>[],
    );
    expect(views.first.netWorthDelta, isNull);
  },);
  test('adjacent months still produce a delta', () {
    final rows = history.compareSnapshots([snap('2026-09', 100), snap('2026-10', 200),],);
    expect(rows.first.netWorthDelta, 100);
  },);
  test('January compares the previous December', () {
    final rows = history.compareSnapshots([snap('2025-12', 100), snap('2026-01', 200),],);
    expect(rows.first.netWorthDelta, 100);
  },);
}
