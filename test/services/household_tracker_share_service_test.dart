import 'package:flutter_test/flutter_test.dart';
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
    now: DateTime(2026, 7, 12, 9, 30),
  );

  group('R24b household tracker (data-report scoreboard)', () {
    test('daysUntilSalaryDay: before/on/after the salary day', () {
      expect(daysUntilSalaryDay(DateTime(2026, 7, 12), 25), 13);
      expect(daysUntilSalaryDay(DateTime(2026, 7, 25), 25), 0);
      // 給料日を過ぎたら翌月へ回る(7/26 → 8/25 = 30日)。
      expect(daysUntilSalaryDay(DateTime(2026, 7, 26), 25), 30);
      // 月末跨ぎ(12月→1月)。
      expect(daysUntilSalaryDay(DateTime(2026, 12, 30), 25), 26);
    });

    test('scoreboard text: counts/days/directions only, no yen amounts', () {
      final text = buildHouseholdTrackerText(snapshot);
      expect(text, contains('家計トラッカー 2026/07/12'));
      expect(text, contains('監視口座数: 4'));
      expect(text, contains('負債トレンド検出: 3件'));
      expect(text, contains('内訳: 残高増加 1 / 利息超過 0 / 長期化 2'));
      expect(text, contains('アラート: 🔴1件 / 🟡2件'));
      expect(text, contains('給料日まで: あと13日（毎月25日起点）'));
      expect(text, contains('金額は非公開'));
      // プライバシー規律: 円記号や金額パターンを含まない。
      expect(text.contains('円'), isFalse);
      expect(text.contains('¥'), isFalse);
    });

    test('no findings → アラート: なし', () {
      final calm = HouseholdTrackerSnapshot(
        monitoredAccounts: 3,
        balanceIncreasing: 0,
        negativeAmortization: 0,
        slowPayoff: 0,
        criticalCount: 0,
        warningCount: 0,
        salaryDay: 25,
        now: DateTime(2026, 7, 12),
      );
      final text = buildHouseholdTrackerText(calm);
      expect(text, contains('負債トレンド検出: 0件'));
      expect(text, contains('アラート: なし'));
    });

    test('post payload: variant/archetype tagging (learning-loop ready)', () {
      final p = buildHouseholdTrackerPostPayload(snapshot);
      expect(p['action'], 'x.post');
      expect(p['variant'], 'household_tracker');
      expect(p['contentArchetype'], 'data_report');
      expect(p['source'], 'household_tracker');
      expect(p['text'], contains('家計トラッカー'));
    });
  });
}
