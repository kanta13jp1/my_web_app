import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/advisory_briefing_share_service.dart';
import 'package:my_web_app/services/asset_advisory_briefing_service.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_service.dart';

void main() {
  test('advisory and share text do not predict onset for negative opening', () {
    final anchor = DateTime(2026, 6, 15);
    final forecast = AssetCashflowForecastService.project(
      asOf: anchor,
      startingBalance: -500,
      horizonMonths: 1,
      oneTimeIncome: [
        AssetCashflowDatedEntry(date: DateTime(2026, 6, 17), amount: 1000),
      ],
    );
    final briefing = const AssetAdvisoryBriefingService().build(
      now: anchor,
      forecast: forecast,
    );
    final action = briefing.actions.singleWhere(
      (action) => action.signalKey == 'cashflow_shortfall',
    );
    expect(action.detail, contains('登録した起点残高は0円未満'));
    expect(action.detail, isNot(contains('見込み残高がマイナスへ')));
    final snapshot = advisoryBriefingSnapshotFrom(
      briefing,
      now: anchor,
      firstShortfallDate: forecast.firstShortfallDate,
    );
    expect(snapshot.shortfallPhase, 'this_month');
    expect(shortfallPhaseLabel(snapshot), '今月の残高不足に要注意');
    expect(
      buildAdvisoryBriefingText(snapshot),
      contains('資金繰り予測: 今月の残高不足に要注意'),
    );
  });
}
