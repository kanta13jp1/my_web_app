import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/user_profile.dart';
import 'package:my_web_app/services/asset_debt_discipline_monitor.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_triage_guide_service.dart';

void main() {
  const planner = AssetLiabilityPlanningService();
  const monitor = AssetDebtDisciplineMonitor();
  const triage = AssetTriageGuideService();

  group('AssetTriageGuideService', () {
    test('crisis state produces at most 3 ordered today steps', () {
      // 現金4,817円 + 本日期日のモビット + ファミペイのリボ/新規利用。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 4817,
          '三井住友銀行大塚支店': 400000,
          'ファミペイ': -3200000,
          'モビット': -100000,
        },
        baseDate: DateTime(2026, 5, 15),
        monthlyPaymentOverrides: const <String, double>{
          'ファミペイ': 3000,
          'mobit': 10000,
        },
        paymentDayOverrides: const <String, int>{'モビット': 15},
      );
      final famipayId = workbook.debtMasterRows
          .firstWhere((row) => row.name == 'ファミペイ')
          .id;
      final discipline = monitor.evaluate(
        workbook: workbook,
        priorBalancesByAccountId: <String, double>{famipayId: 200000},
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: discipline,
        todayAvailableAmount: -5619,
      );

      expect(plan.hasContent, isTrue);
      expect(plan.todaySteps.length, AssetTriageGuideService.maxTodaySteps);
      // ① 生活費確保が最優先 (最大残高の預金口座と手元現金額を名指し)。
      expect(plan.todaySteps[0].kind, AssetTriageStepKind.secureLivingExpense);
      expect(plan.todaySteps[0].detail.contains('4,817円'), isTrue);
      expect(plan.todaySteps[0].detail.contains('三井住友銀行大塚支店'), isTrue);
      // ② 本日期日の支払い。
      expect(plan.todaySteps[1].kind, AssetTriageStepKind.dueTodayPayment);
      expect(plan.todaySteps[1].detail.contains('モビット'), isTrue);
      // ③ 止血 (カード新規利用停止)。
      expect(plan.todaySteps[2].kind, AssetTriageStepKind.stopNewCardUsage);
      expect(plan.todaySteps[2].detail.contains('ファミペイ'), isTrue);
      // 今週: 期限超過処理 + リボ解除電話。
      expect(
        plan.weekSteps.map((step) => step.kind),
        containsAll(<AssetTriageStepKind>[
          AssetTriageStepKind.processOverdue,
          AssetTriageStepKind.disableRevolving,
        ]),
      );
      // 今月: 脱却プランに基づく返済ペース。
      expect(
        plan.monthSteps.any(
          (step) => step.kind == AssetTriageStepKind.reviewRepaymentPace,
        ),
        isTrue,
      );
      // 負債330万 ≥ 300万 → 専門窓口案内。
      expect(plan.showConsultation, isTrue);
      expect(plan.consultationNote, isNotNull);
      expect(plan.consultationNote!.contains('法テラス'), isTrue);
      expect(plan.consultationNote!.contains('188'), isTrue);
    });

    test('calm state has no content', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'財布(現金)': 50000},
        baseDate: DateTime(2026, 5, 1),
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      expect(plan.hasContent, isFalse);
      expect(plan.todaySteps, isEmpty);
      expect(plan.showConsultation, isFalse);
    });

    test('income gap step appears when payments outweigh monthly income', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 50000,
          'モビット': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 13000},
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
        userProfile: UserProfile(userId: 'u', annualIncome: 150000),
      );

      final gap = plan.monthSteps.where(
        (step) => step.kind == AssetTriageStepKind.closeIncomeGap,
      );
      expect(gap.length, 1);
      expect(gap.first.detail.contains('13,000円'), isTrue);
      expect(gap.first.detail.contains('12,500円'), isTrue);
    });

    test('living expense step degrades gracefully without a deposit account',
        () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 500,
          'モビット': -50000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 5000},
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      final living = plan.todaySteps.firstWhere(
        (step) => step.kind == AssetTriageStepKind.secureLivingExpense,
      );
      expect(living.detail.contains('フードバンク'), isTrue);
      expect(living.detail.contains('食事を抜く判断はしないでください'), isTrue);
    });
  });
}
