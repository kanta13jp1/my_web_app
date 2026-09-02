import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_advisory_briefing_service.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_service.dart';
import 'package:my_web_app/services/asset_debt_discipline_monitor.dart';
import 'package:my_web_app/services/asset_debt_trend_analyzer.dart';

void main() {
  const service = AssetAdvisoryBriefingService();
  final now = DateTime(2026, 7, 13, 9, 0);

  AssetCashflowForecast forecast({
    required double worstBalance,
    double safetyMargin = 0,
    DateTime? firstShortfallDate,
    int monthsCount = 6,
  }) {
    final months = List<AssetCashflowForecastMonth>.generate(
      monthsCount,
      (i) => AssetCashflowForecastMonth(
        month: DateTime(2026, 7 + i, 1),
        openingBalance: 100000,
        closingBalance: 100000,
        worstBalance: worstBalance,
        incomeTotal: 0,
        outflowTotal: 0,
      ),
    );
    return AssetCashflowForecast(
      asOf: now,
      startingBalance: 100000,
      months: months,
      worstBalance: worstBalance,
      safetyMargin: safetyMargin,
      firstShortfallDate: firstShortfallDate,
    );
  }

  AssetDebtTrendInsight debtInsight({
    String id = 'acc',
    AssetDebtTrendCategory category = AssetDebtTrendCategory.balanceIncreasing,
    AssetDebtTrendSeverity severity = AssetDebtTrendSeverity.warning,
    String nextMonthAction = '返済額を利息超えへ',
  }) {
    return AssetDebtTrendInsight(
      accountId: id,
      accountName: '内部口座-$id',
      kind: AssetLiabilityAccountKind.creditCard,
      category: category,
      severity: severity,
      currentBalance: 500000,
      priorBalance: 480000,
      balanceDelta: 20000,
      monthlyInterest: 6000,
      scheduledPayment: 5000,
      interestBreakEvenPayment: 6001,
      payoffIn24MonthsPayment: 24000,
      estimatedPayoffMonths: null,
      estimatedTotalInterest: null,
      problem: '内部説明',
      nextMonthAction: nextMonthAction,
    );
  }

  AssetDebtDisciplineViolation violation({
    AssetDebtDisciplineViolationType type =
        AssetDebtDisciplineViolationType.newBorrowing,
    AssetDebtTrendSeverity severity = AssetDebtTrendSeverity.warning,
  }) {
    return AssetDebtDisciplineViolation(
      type: type,
      severity: severity,
      accountId: 'd1',
      accountName: '内部口座',
      kind: AssetLiabilityAccountKind.creditCard,
      amount: 30000,
      currentBalance: 200000,
      problem: '内部説明',
      action: '最低返済額に新規利用分を上乗せし25日に返済する',
    );
  }

  AssetDebtDisciplineReport discipline({
    List<AssetDebtDisciplineViolation> newBorrowing =
        const <AssetDebtDisciplineViolation>[],
    List<AssetDebtDisciplineViolation> revolving =
        const <AssetDebtDisciplineViolation>[],
    int monitored = 2,
    bool hasPriorMonthData = true,
  }) {
    return AssetDebtDisciplineReport(
      newBorrowingViolations: newBorrowing,
      revolvingCardViolations: revolving,
      hasPriorMonthData: hasPriorMonthData,
      totalNewBorrowing: newBorrowing.isEmpty ? 0 : 30000,
      totalCarriedOver: revolving.isEmpty ? 0 : 20000,
      monitoredAccountCount: monitored,
    );
  }

  AdvisoryAction? actionFor(AdvisoryBriefing b, String signalKey) {
    for (final a in b.actions) {
      if (a.signalKey == signalKey) return a;
    }
    return null;
  }

  group('AssetAdvisoryBriefingService.build', () {
    test('empty inputs produce an empty briefing with a clean headline', () {
      final briefing = service.build(now: now);
      expect(briefing.isEmpty, isTrue);
      expect(briefing.actions, isEmpty);
      expect(briefing.headline, contains('赤信号なし'));
    });

    test('cashflow shortfall raises a CFO critical + CHO self-care', () {
      final briefing = service.build(
        now: now,
        forecast: forecast(
          worstBalance: -20000,
          firstShortfallDate: DateTime(2026, 8, 20),
        ),
      );
      final cfo = actionFor(briefing, 'cashflow_shortfall');
      expect(cfo, isNotNull);
      expect(cfo!.department, AdvisoryDepartment.cfo);
      expect(cfo.severity, AdvisorySeverity.critical);
      expect(cfo.detail, contains('8月20日'));
      expect(cfo.detail, contains('20,000円'));

      // 財務クリティカルがあると CHO のセルフケアが自動で加わる。
      final cho = actionFor(briefing, 'health_stress');
      expect(cho, isNotNull);
      expect(cho!.department, AdvisoryDepartment.cho);

      // クリティカルが 1 件だけなら CEO の優先順位裁定は出さない。
      expect(actionFor(briefing, 'ceo_priority'), isNull);
    });

    test('cashflow clear yields a CFO info (no false alarm)', () {
      final briefing = service.build(
        now: now,
        forecast: forecast(worstBalance: 80000, safetyMargin: 0),
      );
      final cfo = actionFor(briefing, 'cashflow_clear');
      expect(cfo, isNotNull);
      expect(cfo!.severity, AdvisorySeverity.info);
      expect(actionFor(briefing, 'health_stress'), isNull);
    });

    test('worst balance under safety margin yields a CFO warning', () {
      final briefing = service.build(
        now: now,
        forecast: forecast(worstBalance: 5000, safetyMargin: 30000),
      );
      final cfo = actionFor(briefing, 'cashflow_safety');
      expect(cfo, isNotNull);
      expect(cfo!.severity, AdvisorySeverity.warning);
      expect(cfo.detail, contains('25,000円'));
    });

    test('critical debt trend adds CFO debt action and CMO revenue loop', () {
      final briefing = service.build(
        now: now,
        debtInsights: [
          debtInsight(
            id: 'a',
            category: AssetDebtTrendCategory.negativeAmortization,
            severity: AssetDebtTrendSeverity.critical,
            nextMonthAction: '最低でも利息超えの返済へ',
          ),
          debtInsight(id: 'b', severity: AssetDebtTrendSeverity.warning),
        ],
      );
      final debt = actionFor(briefing, 'debt_trend');
      expect(debt, isNotNull);
      expect(debt!.department, AdvisoryDepartment.cfo);
      expect(debt.severity, AdvisorySeverity.critical);
      expect(debt.detail, contains('最低でも利息超えの返済へ'));
      expect(debt.detail, contains('監視2口座'));

      final cmo = actionFor(briefing, 'revenue_loop');
      expect(cmo, isNotNull);
      expect(cmo!.department, AdvisoryDepartment.cmo);
      expect(cmo.detail, contains('負債トレンド'));
    });

    test('discipline violation is owned by CHRO', () {
      final briefing = service.build(
        now: now,
        disciplineReport: discipline(newBorrowing: [violation()]),
      );
      final chro = actionFor(briefing, 'discipline_violation');
      expect(chro, isNotNull);
      expect(chro!.department, AdvisoryDepartment.chro);
      expect(chro.detail, contains('未達'));
    });

    test('compliant-but-relevant discipline yields a CHRO info', () {
      final briefing = service.build(now: now, disciplineReport: discipline());
      final chro = actionFor(briefing, 'discipline_ok');
      expect(chro, isNotNull);
      expect(chro!.severity, AdvisorySeverity.info);
      expect(chro.detail, contains('達成'));
    });

    test('never claims 追加借入ゼロ was achieved when it was never evaluated', () {
      // 前月残高が無いと誓約①の評価ループに入らず違反リストが必ず空になる。
      // その状態を「達成」と書くと規律カードの「判定保留」チップと矛盾する。
      final briefing = service.build(
        now: now,
        disciplineReport: discipline(hasPriorMonthData: false),
      );
      final chro = actionFor(briefing, 'discipline_ok');
      expect(chro, isNotNull);
      expect(chro!.severity, AdvisorySeverity.info);
      expect(chro.detail, contains('判定'));
      expect(
        chro.detail.contains('カード以外の追加借入ゼロ・新規利用分の25日全額返済を達成'),
        isFalse,
      );
      expect(chro.headline.contains('規律を維持'), isFalse);
    });

    test('marks pledge 1 as 判定保留 in the violation detail when unevaluated', () {
      final briefing = service.build(
        now: now,
        disciplineReport: discipline(
          revolving: [
            violation(type: AssetDebtDisciplineViolationType.revolvingCard),
          ],
          hasPriorMonthData: false,
        ),
      );
      final chro = actionFor(briefing, 'discipline_violation');
      expect(chro, isNotNull);
      expect(chro!.detail, contains('誓約①カード以外の追加借入ゼロ: 判定保留'));
      // 誓約②は前月データ不要なので、そのまま未達と出る。
      expect(chro.detail, contains('誓約②新規利用分の25日全額返済: 未達'));
    });

    test('two criticals trigger a CEO priority ruling sorted to the top', () {
      final briefing = service.build(
        now: now,
        forecast: forecast(
          worstBalance: -50000,
          firstShortfallDate: DateTime(2026, 7, 28),
        ),
        debtInsights: [
          debtInsight(
            category: AssetDebtTrendCategory.negativeAmortization,
            severity: AssetDebtTrendSeverity.critical,
          ),
        ],
      );
      final ceo = actionFor(briefing, 'ceo_priority');
      expect(ceo, isNotNull);
      expect(ceo!.severity, AdvisorySeverity.critical);
      // CEO の裁定はソートで最上段に来る(統合レイヤ)。
      expect(briefing.actions.first.signalKey, 'ceo_priority');
      expect(briefing.criticalCount, greaterThanOrEqualTo(3));
      expect(briefing.headline, contains('クリティカル'));
      // CFO/CMO/CHO/CEO が関与。
      expect(briefing.engagedDepartmentCount, greaterThanOrEqualTo(4));
    });

    test('actions are ordered critical -> warning -> info', () {
      final briefing = service.build(
        now: now,
        forecast: forecast(worstBalance: 80000),
        debtInsights: [
          debtInsight(
            category: AssetDebtTrendCategory.negativeAmortization,
            severity: AssetDebtTrendSeverity.critical,
          ),
        ],
      );
      final ranks = briefing.actions
          .map(
            (a) => a.severity == AdvisorySeverity.critical
                ? 0
                : a.severity == AdvisorySeverity.warning
                    ? 1
                    : 2,
          )
          .toList();
      final sorted = [...ranks]..sort();
      expect(ranks, sorted);
    });

    test('department profiles match the real agent_org blueprint slugs', () {
      expect(kAdvisoryDepartments[AdvisoryDepartment.cfo]!.slug, 'cfo');
      expect(kAdvisoryDepartments[AdvisoryDepartment.cmo]!.slug, 'cmo');
      expect(kAdvisoryDepartments[AdvisoryDepartment.cho]!.slug, 'cho');
      expect(kAdvisoryDepartments[AdvisoryDepartment.chro]!.slug, 'chro');
      expect(kAdvisoryDepartments[AdvisoryDepartment.ceo]!.slug, 'ceo');
      expect(
        kAdvisoryDepartments[AdvisoryDepartment.planning]!.slug,
        'planning-director',
      );
    });
  });

  group('formatAdvisoryYen', () {
    test('adds thousands separators and yen suffix', () {
      expect(formatAdvisoryYen(0), '0円');
      expect(formatAdvisoryYen(1234), '1,234円');
      expect(formatAdvisoryYen(1234567), '1,234,567円');
      expect(formatAdvisoryYen(-20000), '-20,000円');
      expect(formatAdvisoryYen(999.6), '1,000円');
    });
  });
}
