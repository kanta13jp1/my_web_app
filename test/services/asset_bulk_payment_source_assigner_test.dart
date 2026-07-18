import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_bulk_payment_source_assigner.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  const planner = AssetLiabilityPlanningService();
  const assigner = AssetBulkPaymentSourceAssigner();

  group('AssetBulkPaymentSourceAssigner', () {
    test(
        'assigns each missing row to the deposit with the largest '
        'projected balance', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 500000,
          'bank': 100000,
          'モビット': -1000000,
          'auPayカード': -200000,
        },
        baseDate: DateTime(2026, 5, 1),
      );

      final plan = assigner.buildPlan(workbook);

      // 未設定の支払いは全て割当先が決まる。
      expect(plan.unassignableRows, isEmpty);
      expect(
        plan.assignments.length,
        workbook.paymentSourceMissingRows.length,
      );
      // 見込み残高最大 = 三井住友銀行大塚支店 (50万) が全行に選ばれる。
      for (final assignment in plan.assignments) {
        expect(assignment.account.name, '三井住友銀行大塚支店');
      }
      // モビットの割当も存在する。
      expect(
        plan.assignments.any((a) => a.row.name == 'モビット'),
        isTrue,
      );
    });

    test('flags rows unassignable when no cash/deposit account exists', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'モビット': -1000000,
        },
        baseDate: DateTime(2026, 5, 1),
      );

      final plan = assigner.buildPlan(workbook);

      expect(plan.hasAssignments, isFalse);
      expect(
        plan.unassignableRows.map((row) => row.name),
        contains('モビット'),
      );
    });

    test('excludes rows that already have a payment source', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 500000,
          'モビット': -1000000,
          'auPayカード': -200000,
        },
        baseDate: DateTime(2026, 5, 1),
        paymentSourceAccountIds: const <String, String>{
          'mobit': 'smbc_otsuka_branch',
        },
      );

      final plan = assigner.buildPlan(workbook);

      // モビットは原資設定済み → 一括対象に含まれない。
      expect(
        plan.assignments.any((a) => a.row.name == 'モビット'),
        isFalse,
      );
      expect(
        plan.assignments.any((a) => a.row.name == 'auPayカード'),
        isTrue,
      );
    });

    test(
        'decrements the running balance so cumulative debits surface an '
        'overdraft instead of showing each row independently safe', () {
      // 預金1口座(5万) + 高額債務2件 → 全て同口座に集中。累積で残高を減算するので
      // 2件目の支払後見込みは「口座残高 − 両方の支払額」になり、合計超過が可視化される
      // (バグ版は各行を独立評価し 5万 − 片方 だけを見て「安全」に見せてしまう)。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 50000,
          'モビット': -1000000,
          'アコムカードローン': -1000000,
        },
        baseDate: DateTime(2026, 5, 1),
      );

      final plan = assigner.buildPlan(workbook);

      // 2件とも同一口座 (唯一の預金) に割り当てられる。
      expect(plan.assignments.length, greaterThanOrEqualTo(2));
      expect(
        plan.assignments.map((a) => a.account.name).toSet(),
        <String>{'三井住友銀行大塚支店'},
      );

      final accountProjectedBefore =
          plan.assignments.first.projectedAfterPayment +
              plan.assignments.first.row.scheduledPaymentAmount;
      final total = plan.assignments.fold<double>(
        0,
        (sum, a) => sum + a.row.scheduledPaymentAmount,
      );
      // 最後の割当の見込み残高 = 口座残高 − 全割当額 (累積)。
      expect(
        plan.assignments.last.projectedAfterPayment,
        closeTo(accountProjectedBefore - total, 1),
      );
      // 合計が残高を超えるため、最後の割当はマイナス (UI で赤警告が出る)。
      expect(plan.assignments.last.projectedAfterPayment, lessThan(0));
    });

    test('never assigns a payment to its own account id (self exclusion)', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 500000,
          'モビット': -1000000,
        },
        baseDate: DateTime(2026, 5, 1),
      );

      final plan = assigner.buildPlan(workbook);

      for (final assignment in plan.assignments) {
        expect(assignment.account.id == assignment.row.id, isFalse);
      }
    });
  });
}
