import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_debt_trend_analyzer.dart';
import 'package:my_web_app/services/household_tracker_share_service.dart';

void main() {
  final snapshot = HouseholdTrackerSnapshot(
    monitoredAccounts: 4,
    balanceIncreasing: 1,
    negativeAmortization: 0,
    slowPayoff: 2,
    criticalCount: 1,
    warningCount: 2,
    salaryDay: 25,
    salaryDayConfigured: true,
    now: DateTime(2026, 7, 12, 9, 30),
  );

  AssetDebtTrendInsight insight({
    required String id,
    required AssetDebtTrendCategory category,
    required AssetDebtTrendSeverity severity,
  }) {
    return AssetDebtTrendInsight(
      accountId: id,
      accountName: '非公開口座-$id',
      kind: AssetLiabilityAccountKind.creditCard,
      category: category,
      severity: severity,
      currentBalance: 987654,
      priorBalance: 900000,
      balanceDelta: 87654,
      monthlyInterest: 12345,
      scheduledPayment: 10000,
      interestBreakEvenPayment: 12346,
      payoffIn24MonthsPayment: 50000,
      estimatedPayoffMonths: 80,
      estimatedTotalInterest: 222222,
      problem: '口座名と金額を含む内部説明',
      nextMonthAction: '内部アクション',
    );
  }

  group('R24/R26 household tracker privacy-safe scoreboard', () {
    test('daysUntilSalaryDay: before/on/after the salary day', () {
      expect(daysUntilSalaryDay(DateTime(2026, 7, 12), 25), 13);
      expect(daysUntilSalaryDay(DateTime(2026, 7, 25), 25), 0);
      expect(daysUntilSalaryDay(DateTime(2026, 7, 26), 25), 30);
      expect(daysUntilSalaryDay(DateTime(2026, 12, 30), 25), 26);
    });

    test('small cells and salary day are bucketed', () {
      expect(anonymizedHouseholdCount(0), '0件');
      expect(anonymizedHouseholdCount(1), '1〜2件');
      expect(anonymizedHouseholdCount(2), '1〜2件');
      expect(anonymizedHouseholdCount(3), '3〜5件');
      expect(anonymizedHouseholdCount(8), '6〜10件');
      expect(anonymizedHouseholdCount(12), '11件以上');
      expect(salaryCyclePhase(DateTime(2026, 7, 12), 25), '給料日まで1〜2週間');
      expect(salaryCyclePhase(DateTime(2026, 7, 25), 25), '給料日まで3日以内');
    });

    test('scoreboard excludes exact time, salary date, names, and amounts', () {
      final text = buildHouseholdTrackerText(snapshot);
      expect(text, contains('家計トラッカー 2026/07/12'));
      expect(text, contains('トレンド検出口座: 3〜5件'));
      expect(text, contains('負債トレンド検出: 3〜5件'));
      expect(
        text,
        contains('内訳: 残高増加 1〜2件 / 利息超過 0件 / 長期化 1〜2件'),
      );
      expect(text, contains('アラート: 🔴1〜2件 / 🟡1〜2件'));
      expect(text, contains('給料日サイクル: 給料日まで1〜2週間'));
      expect(text, contains('件数は幅表示'));
      expect(text, isNot(contains('09:30')));
      expect(text, isNot(contains('毎月25日')));
      expect(text, isNot(contains('円')));
      expect(text, isNot(contains('¥')));
    });

    test('unset salary day is disclosed, never presented as measured', () {
      final unset = HouseholdTrackerSnapshot(
        monitoredAccounts: 0,
        balanceIncreasing: 0,
        negativeAmortization: 0,
        slowPayoff: 0,
        criticalCount: 0,
        warningCount: 0,
        salaryDay: 25,
        salaryDayConfigured: false,
        now: DateTime(2026, 7, 12),
      );
      expect(
        buildHouseholdTrackerText(unset),
        contains('給料日サイクル: 未設定'),
      );
    });

    test('insight lineage reads categories only and drops private fields', () {
      final insights = [
        insight(
          id: 'debt-a',
          category: AssetDebtTrendCategory.balanceIncreasing,
          severity: AssetDebtTrendSeverity.critical,
        ),
        insight(
          id: 'debt-b',
          category: AssetDebtTrendCategory.slowPayoff,
          severity: AssetDebtTrendSeverity.warning,
        ),
      ];
      final derived = householdSnapshotFromInsights(
        insights,
        salaryDay: 25,
        salaryDayConfigured: true,
        now: DateTime(2026, 7, 12),
      );
      expect(derived.monitoredAccounts, 2);
      expect(derived.balanceIncreasing, 1);
      expect(derived.slowPayoff, 1);
      final text = buildHouseholdTrackerText(derived);
      expect(text, isNot(contains('非公開口座')));
      expect(text, isNot(contains('987654')));
      expect(text, isNot(contains('内部説明')));
    });

    test('mirror is allowlisted, round-trips, and fails closed', () {
      final value = encodeHouseholdTrackerPublishMirror(snapshot);
      expect(value.keys, isNot(contains('enabled')));
      expect(value['salary_day_configured'], isTrue);
      expect(value.keys, isNot(contains('amount')));
      expect(value.keys, isNot(contains('account_name')));

      final decoded = decodeHouseholdTrackerPublishMirror(value);
      expect(decoded?.snapshot.totalFindings, 3);
      expect(
        decodeHouseholdTrackerPublishMirror(<String, dynamic>{
          ...value,
          'salary_day': 31,
        }),
        isNull,
      );
      expect(
        decodeHouseholdTrackerPublishConsent(
          encodeHouseholdTrackerPublishConsent(true),
        ),
        isTrue,
      );
      expect(
        decodeHouseholdTrackerPublishConsent({'enabled': true}),
        isNull,
      );
    });

    test('post payload carries the measured learning-loop contract', () {
      final p = buildHouseholdTrackerPostPayload(snapshot);
      expect(p['action'], 'x.post');
      expect(p['variant'], 'household_tracker');
      expect(p['contentArchetype'], 'data_report');
      expect(p['contentKind'], 'data_report');
      expect(p['source'], 'household_tracker');
      expect(p['promptProfile'], 'household_tracker_scoreboard_v2');
      expect(p['text'], contains('家計トラッカー'));
    });
  });
}
