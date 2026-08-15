import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/advisory_briefing_share_service.dart';
import 'package:my_web_app/services/asset_advisory_briefing_service.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_service.dart';
import 'package:my_web_app/services/asset_debt_trend_analyzer.dart';

void main() {
  const service = AssetAdvisoryBriefingService();
  final now = DateTime(2026, 7, 13, 9, 0);

  AssetCashflowForecast shortfallForecast(DateTime date, double worst) {
    return AssetCashflowForecast(
      asOf: now,
      startingBalance: 100000,
      months: [
        AssetCashflowForecastMonth(
          month: DateTime(2026, 7, 1),
          openingBalance: 100000,
          closingBalance: worst,
          worstBalance: worst,
          incomeTotal: 0,
          outflowTotal: 0,
          firstShortfallDate: date,
        ),
      ],
      worstBalance: worst,
      safetyMargin: 0,
      firstShortfallDate: date,
    );
  }

  AssetDebtTrendInsight criticalDebt() => const AssetDebtTrendInsight(
        accountId: 'a',
        accountName: '内部口座',
        kind: AssetLiabilityAccountKind.creditCard,
        category: AssetDebtTrendCategory.negativeAmortization,
        severity: AssetDebtTrendSeverity.critical,
        currentBalance: 500000,
        priorBalance: 490000,
        balanceDelta: 10000,
        monthlyInterest: 6000,
        scheduledPayment: 3000,
        interestBreakEvenPayment: 6001,
        payoffIn24MonthsPayment: 24000,
        estimatedPayoffMonths: null,
        estimatedTotalInterest: null,
        problem: '内部説明',
        nextMonthAction: '内部アクション',
      );

  group('advisoryShortfallPhase', () {
    test('buckets by month distance without leaking the date', () {
      expect(
        advisoryShortfallPhase(forecastAvailable: false, now: now),
        'unknown',
      );
      expect(
        advisoryShortfallPhase(
          forecastAvailable: true,
          firstShortfallDate: null,
          now: now,
        ),
        'none',
      );
      expect(
        advisoryShortfallPhase(
          forecastAvailable: true,
          firstShortfallDate: DateTime(2026, 7, 28),
          now: now,
        ),
        'this_month',
      );
      expect(
        advisoryShortfallPhase(
          forecastAvailable: true,
          firstShortfallDate: DateTime(2026, 10, 1),
          now: now,
        ),
        'within_3m',
      );
      expect(
        advisoryShortfallPhase(
          forecastAvailable: true,
          firstShortfallDate: DateTime(2026, 12, 1),
          now: now,
        ),
        'within_6m',
      );
      expect(
        advisoryShortfallPhase(
          forecastAvailable: true,
          firstShortfallDate: DateTime(2027, 3, 1),
          now: now,
        ),
        'beyond_6m',
      );
    });
  });

  group('anonymizedDepartmentCount', () {
    test('buckets department counts', () {
      expect(anonymizedDepartmentCount(0), '0部署');
      expect(anonymizedDepartmentCount(1), '1〜2部署');
      expect(anonymizedDepartmentCount(2), '1〜2部署');
      expect(anonymizedDepartmentCount(3), '3部署以上');
      expect(anonymizedDepartmentCount(6), '3部署以上');
    });
  });

  group('snapshot + text are privacy-safe', () {
    final briefing = service.build(
      now: now,
      forecast: shortfallForecast(DateTime(2026, 7, 28), -20000),
      debtInsights: [criticalDebt()],
    );
    final snapshot = advisoryBriefingSnapshotFrom(
      briefing,
      firstShortfallDate: DateTime(2026, 7, 28),
      now: now,
    );

    test('snapshot derives flags from the briefing signals', () {
      expect(snapshot.active, isTrue);
      expect(snapshot.forecastAvailable, isTrue);
      expect(snapshot.hasShortfall, isTrue);
      expect(snapshot.shortfallPhase, 'this_month');
      expect(snapshot.debtTrendFlagged, isTrue);
      expect(snapshot.hasCritical, isTrue);
    });

    test('published text never leaks yen, dates, or account names', () {
      final text = buildAdvisoryBriefingText(snapshot);
      expect(text, isNot(contains('円')));
      expect(text, isNot(contains('20000')));
      expect(text, isNot(contains('20,000')));
      expect(text, isNot(contains('7月28日')));
      expect(text, isNot(contains('内部口座')));
      // データレポート型として必要な骨格 + 機能アンカー。
      expect(text, contains('AI参謀室ブリーフィング'));
      expect(text, contains('負債トレンド'));
      expect(text, contains('今月内にショート見込み'));
    });

    test('payload is tagged for the growth-hub learning loop', () {
      final payload = buildAdvisoryBriefingPostPayload(snapshot);
      expect(payload['action'], 'x.post');
      expect(payload['variant'], 'advisory_room');
      expect(payload['contentArchetype'], 'data_report');
      expect(payload['experimentKey'], 'x_first_user_growth_10k');
      expect(payload['route'], '/asset-management');
      expect(payload['text'], contains('AI参謀室ブリーフィング'));
    });

    test('a clean briefing reports standby, not a false shortfall', () {
      final clean = service.build(now: now);
      final cleanSnapshot = advisoryBriefingSnapshotFrom(clean, now: now);
      final text = buildAdvisoryBriefingText(cleanSnapshot);
      expect(cleanSnapshot.active, isFalse);
      expect(cleanSnapshot.forecastAvailable, isFalse);
      expect(text, contains('待機'));
      expect(text, contains('予測データ不足'));
    });
  });
}
