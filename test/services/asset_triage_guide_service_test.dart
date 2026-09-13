import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
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
      // 現金4,817円 + 本日期日のモビット + 期限超過のauPay + ファミペイのリボ/新規利用。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 4817,
          '三井住友銀行大塚支店': 400000,
          'ファミペイ': -3200000,
          'モビット': -100000,
          'auPayカード': -200000,
        },
        baseDate: DateTime(2026, 5, 15),
        monthlyPaymentOverrides: const <String, double>{
          'ファミペイ': 3000,
          'mobit': 10000,
          'aupay_card': 20000,
        },
        paymentDayOverrides: const <String, int>{'モビット': 15, 'auPayカード': 10},
        revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
          'famipay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 3000,
            newUsageAmount: 100000,
          ),
        },
        actualPaymentAmounts: const <String, double>{'famipay_card': 3000},
        paidAccountNames: const <String>{'famipay_card'},
      );
      final famipayId =
          workbook.debtMasterRows.firstWhere((row) => row.name == 'ファミペイ').id;
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
      // 今週: 期限超過処理 + 新規利用分の25日返済確保。期限超過は昨日以前の支払のみ
      // (本日期日のモビット10,000円は②に載せ、④へは二重計上しない)。
      expect(
        plan.weekSteps.map((step) => step.kind),
        containsAll(<AssetTriageStepKind>[
          AssetTriageStepKind.processOverdue,
          AssetTriageStepKind.disableRevolving,
        ]),
      );
      final overdueStep = plan.weekSteps.firstWhere(
        (step) => step.kind == AssetTriageStepKind.processOverdue,
      );
      expect(overdueStep.detail.contains('1件'), isTrue);
      expect(overdueStep.detail.contains('20,000円'), isTrue);
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

    test('configured payday rule needs no corrective triage', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'ファミペイ': -100000,
        },
        baseDate: DateTime(2026, 8, 29),
        revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
          'famipay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 5000,
            newUsageAmount: 10000,
          ),
        },
        cardUsagePolicies: <String, AssetCardUsagePolicy>{
          'famipay_card': AssetCardUsagePolicy(
            enforceOneShot: true,
            changedAt: DateTime.utc(2026, 8, 29),
            memo: '受付 ABC123',
          ),
        },
      );
      final discipline = monitor.evaluate(
        workbook: workbook,
        cardUsagePolicies: workbook.cardUsagePolicies,
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: discipline,
      );

      expect(discipline.revolvingCardViolations, isEmpty);
      expect(
        plan.weekSteps.any(
          (step) => step.kind == AssetTriageStepKind.disableRevolving,
        ),
        isFalse,
      );
      expect(
        plan.monthSteps.any(
          (step) => step.kind == AssetTriageStepKind.reviewRepaymentPace,
        ),
        isFalse,
      );
    });

    test(
      'legacy one-shot record does not hide an actual repayment shortfall',
      () {
        final workbook = planner.buildWorkbook(
          latestSnapshot: const <String, double>{
            'bank': 500000,
            'ファミペイ': -100000,
          },
          baseDate: DateTime(2026, 8, 29),
          revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
            'famipay_card': AssetLiabilityRevolvingCreditConfig(
              monthlyAmount: 5000,
              newUsageAmount: 30000,
            ),
          },
          actualPaymentAmounts: const <String, double>{'famipay_card': 5000},
          paidAccountNames: const <String>{'famipay_card'},
          cardUsagePolicies: const <String, AssetCardUsagePolicy>{
            'famipay_card': AssetCardUsagePolicy(enforceOneShot: true),
          },
        );
        final discipline = monitor.evaluate(
          workbook: workbook,
          cardUsagePolicies: workbook.cardUsagePolicies,
        );

        final plan = triage.buildPlan(
          workbook: workbook,
          disciplineReport: discipline,
        );

        final settingStep = plan.weekSteps.singleWhere(
          (step) => step.kind == AssetTriageStepKind.disableRevolving,
        );
        expect(settingStep.detail, contains('ファミペイ'));
        expect(settingStep.detail, contains('25日'));
        expect(settingStep.detail, contains('既存残高の一括返済は求めず'));
      },
    );

    test('overdue step ignores unreceived income and due-today payments', () {
      // 未受領の給料 (期日超過で overdue フラグが立つ) と本日期日の支払は
      // 「期限超過」ステップに数えない。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 50000,
          'モビット': -100000,
        },
        baseDate: DateTime(2026, 5, 15),
        monthlyPaymentOverrides: const <String, double>{'mobit': 10000},
        paymentDayOverrides: const <String, int>{'モビット': 15},
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'salary',
            date: DateTime(2026, 5, 10),
            name: '給料',
            amount: 200000,
            destinationAccountId: null,
            destinationAccountName: null,
            received: false,
          ),
        ],
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      expect(
        plan.weekSteps.where(
          (step) => step.kind == AssetTriageStepKind.processOverdue,
        ),
        isEmpty,
      );
      expect(
        plan.todaySteps.any(
          (step) => step.kind == AssetTriageStepKind.dueTodayPayment,
        ),
        isTrue,
      );
    });

    test('prompts to register an income plan when none exists', () {
      // 収入予定ゼロ = 資金繰りが「収入なし」で計算され実態より厳しく出るため、
      // まず登録を促す。支払予定のある家計にだけ出す。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 50000,
          'モビット': -1000000,
        },
        baseDate: DateTime(2026, 5, 15),
      );
      expect(workbook.incomePlans, isEmpty);

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      final step = plan.todaySteps.firstWhere(
        (s) => s.kind == AssetTriageStepKind.registerIncomePlan,
      );
      expect(step.detail.contains('収入予定が1件も登録されていません'), isTrue);
      // 数字が実態より厳しく出ていることを明示し、過度な不安を防ぐ。
      expect(step.detail.contains('実際より大幅に厳しい数字'), isTrue);
    });

    test('does not prompt to register income when a plan already exists', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 50000,
          'モビット': -1000000,
        },
        baseDate: DateTime(2026, 5, 15),
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'salary',
            date: DateTime(2026, 5, 25),
            name: '給料',
            amount: 450000,
            destinationAccountId: null,
            destinationAccountName: null,
            received: false,
          ),
        ],
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      expect(
        plan.todaySteps.where(
          (s) => s.kind == AssetTriageStepKind.registerIncomePlan,
        ),
        isEmpty,
      );
    });

    test('does not prompt to register income without scheduled payments', () {
      // 支払予定が無い (データ未入力の新規利用者) には出さない。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'財布(現金)': 50000},
        baseDate: DateTime(2026, 5, 15),
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      expect(
        plan.todaySteps.where(
          (s) => s.kind == AssetTriageStepKind.registerIncomePlan,
        ),
        isEmpty,
      );
    });

    test('confirms unreceived past-due income as a today step', () {
      // 期日を過ぎても未受取の給料は「着金確認」を今日ステップに出す。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 50000,
          'モビット': -100000,
        },
        baseDate: DateTime(2026, 5, 26),
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'salary',
            date: DateTime(2026, 5, 25),
            name: '給料',
            amount: 450000,
            destinationAccountId: 'smbc_otsuka_branch',
            destinationAccountName: '三井住友銀行大塚支店',
            received: false,
          ),
        ],
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      final income = plan.todaySteps.firstWhere(
        (step) => step.kind == AssetTriageStepKind.confirmIncomeArrival,
      );
      expect(income.detail.contains('給料'), isTrue);
      expect(income.detail.contains('450,000円'), isTrue);
      expect(income.detail.contains('三井住友銀行大塚支店'), isTrue);
    });

    test('does not confirm income that is not yet due', () {
      // 入金予定日が未来の場合は「着金確認」を出さない。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'財布(現金)': 50000},
        baseDate: DateTime(2026, 5, 20),
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'salary',
            date: DateTime(2026, 5, 25),
            name: '給料',
            amount: 450000,
            destinationAccountId: null,
            destinationAccountName: null,
            received: false,
          ),
        ],
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      expect(
        plan.todaySteps.where(
          (step) => step.kind == AssetTriageStepKind.confirmIncomeArrival,
        ),
        isEmpty,
      );
    });

    test(
        'surfaces directly-debited rent as a lifeline but excludes '
        'card-billed telecom', () {
      // 家賃は口座直接引落の生命線→出す。au(通信)は auPay カード請求に内包され
      // (includedInBillingAccount=true)、そのカードの請求行で支払われるため、
      // 「口座に先に確保せよ」から除外する (二重計上防止)。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          '家賃': -63000,
          'au': -28741,
        },
        baseDate: DateTime(2026, 5, 1),
      );

      final lifelineDebtRow = workbook.debtMasterRows.firstWhere(
        (row) => row.name == 'au',
      );
      // 前提: au はカード請求内包として分類されている。
      expect(lifelineDebtRow.includedInBillingAccount, isTrue);

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      final lifeline = plan.weekSteps.firstWhere(
        (step) => step.kind == AssetTriageStepKind.secureLifeline,
      );
      expect(lifeline.detail.contains('家賃'), isTrue);
      expect(lifeline.detail.contains('生命線'), isTrue);
      expect(lifeline.detail.contains('au'), isFalse);
    });

    test('lifeline step excludes subscriptions but keeps utilities', () {
      // サブスク (ChatGPT Pro) は fullPaymentEstimate=true でも「生命線を優先確保」
      // には出さない (解約候補であって優先支払い対象ではない)。光熱費は残す。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 500000},
        baseDate: DateTime(2026, 5, 1),
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'chatgpt_pro',
            name: 'ChatGPT Pro',
            amount: 30000,
            paymentDay: 3,
            category: AssetRecurringFixedCostCategory.subscription,
          ),
          AssetRecurringFixedCost(
            id: 'denki',
            name: '電気代',
            amount: 12000,
            paymentDay: 20,
            category: AssetRecurringFixedCostCategory.utility,
          ),
        ],
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      final lifeline = plan.weekSteps.firstWhere(
        (step) => step.kind == AssetTriageStepKind.secureLifeline,
      );
      expect(lifeline.detail.contains('電気代'), isTrue);
      expect(lifeline.detail.contains('ChatGPT'), isFalse);
      // 合計にもサブスク額 (30,000) を含めない。
      expect(lifeline.detail.contains('30,000円'), isFalse);
    });

    test(
        'cancelSubscriptions names subscription fixed costs but not '
        'utilities', () {
      // サブスク (ChatGPT/Claude) は名指しで解約候補に。光熱費 (電気代) は含めない。
      // 借入 (モビット) がある家計でのみ発火する。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'モビット': -1000000,
        },
        baseDate: DateTime(2026, 5, 1),
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'chatgpt_pro',
            name: 'ChatGPT Pro',
            amount: 30000,
            paymentDay: 20,
            category: AssetRecurringFixedCostCategory.subscription,
          ),
          AssetRecurringFixedCost(
            id: 'claude',
            name: 'Claude',
            amount: 36000,
            paymentDay: 26,
            category: AssetRecurringFixedCostCategory.subscription,
          ),
          AssetRecurringFixedCost(
            id: 'denki',
            name: '電気代',
            amount: 12000,
            paymentDay: 20,
            category: AssetRecurringFixedCostCategory.utility,
          ),
        ],
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      final step = plan.monthSteps.firstWhere(
        (s) => s.kind == AssetTriageStepKind.cancelSubscriptions,
      );
      expect(step.detail.contains('ChatGPT Pro'), isTrue);
      expect(step.detail.contains('Claude'), isTrue);
      // 光熱費は解約候補に混ぜない (誤って生活必需の停止を促さない)。
      expect(step.detail.contains('電気代'), isFalse);
      // 合計 (30,000 + 36,000 = 66,000) を提示。
      expect(step.detail.contains('66,000円'), isTrue);
    });

    test('no cancelSubscriptions step when there are no subscriptions', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'モビット': -1000000,
        },
        baseDate: DateTime(2026, 5, 1),
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      expect(
        plan.monthSteps.where(
          (s) => s.kind == AssetTriageStepKind.cancelSubscriptions,
        ),
        isEmpty,
      );
    });

    test('no cancelSubscriptions step for a debt-free household', () {
      // 無借金の利用者にはサブスク解約を促さない (ノイズ回避)。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 500000},
        baseDate: DateTime(2026, 5, 1),
        recurringFixedCosts: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'chatgpt_pro',
            name: 'ChatGPT Pro',
            amount: 30000,
            paymentDay: 20,
            category: AssetRecurringFixedCostCategory.subscription,
          ),
        ],
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      expect(
        plan.monthSteps.where(
          (s) => s.kind == AssetTriageStepKind.cancelSubscriptions,
        ),
        isEmpty,
      );
    });

    test('protects high-interest loans as a distinct week step', () {
      // モビット (年18% cardLoan) は高金利ローンとして最低額死守ステップに出る。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'モビット': -1000000,
        },
        baseDate: DateTime(2026, 5, 1),
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      final loan = plan.weekSteps.firstWhere(
        (step) => step.kind == AssetTriageStepKind.protectHighInterestLoan,
      );
      expect(loan.detail.contains('モビット'), isTrue);
      expect(loan.detail.contains('18%'), isTrue);
      expect(loan.detail.contains('最低'), isTrue);
    });

    test('high-interest step also covers 14.5% bank card loans', () {
      // じぶん銀行カードローン (年14.5% cardLoan) も高金利として死守対象に含める。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'じぶん銀行カードローン': -800000,
        },
        baseDate: DateTime(2026, 5, 1),
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      final loan = plan.weekSteps.firstWhere(
        (step) => step.kind == AssetTriageStepKind.protectHighInterestLoan,
      );
      expect(loan.detail.contains('じぶん'), isTrue);
    });

    test('no fake cash crisis for users without a cash account', () {
      // 現金口座を記録していないだけの健全ユーザーには生活費ステップを出さない。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'三井住友銀行大塚支店': 500000},
        baseDate: DateTime(2026, 5, 1),
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
        todayAvailableAmount: 100000,
      );

      expect(
        plan.todaySteps.where(
          (step) => step.kind == AssetTriageStepKind.secureLivingExpense,
        ),
        isEmpty,
      );
    });

    test('consultation threshold counts only borrowing-kind debt', () {
      // 家賃 (毎月全額払いの固定費) は借入合計に含めない → 閾値未満で案内なし。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          '家賃': -80000,
          'モビット': -2950000,
        },
        baseDate: DateTime(2026, 5, 1),
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      expect(plan.showConsultation, isFalse);
    });

    test('repayment pace example picks the highest annual rate card', () {
      // PayPay (繰越額最大・年利15%) より ファミペイ (年利18%) を例示する。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 500000,
          'PayPay': -800000,
          'ファミペイ': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'paypay_card': 10000,
          'ファミペイ': 10000,
        },
        revolvingConfigs: const <String, AssetLiabilityRevolvingCreditConfig>{
          'paypay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 10000,
            newUsageAmount: 30000,
          ),
          'famipay_card': AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 10000,
            newUsageAmount: 30000,
          ),
        },
        actualPaymentAmounts: const <String, double>{
          'paypay_card': 10000,
          'famipay_card': 10000,
        },
        paidAccountNames: const <String>{'paypay_card', 'famipay_card'},
        annualRateOverrides: const <String, double>{'famipay_card': 0.18},
      );

      final plan = triage.buildPlan(
        workbook: workbook,
        disciplineReport: monitor.evaluate(workbook: workbook),
      );

      final pace = plan.monthSteps.firstWhere(
        (step) => step.kind == AssetTriageStepKind.reviewRepaymentPace,
      );
      expect(pace.detail.contains('例: ファミペイ'), isTrue);
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

    test(
      'living expense step degrades gracefully without a deposit account',
      () {
        final workbook = planner.buildWorkbook(
          latestSnapshot: const <String, double>{'財布(現金)': 500, 'モビット': -50000},
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
      },
    );
  });
}
