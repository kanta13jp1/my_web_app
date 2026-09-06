import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/user_profile.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';
import 'package:my_web_app/services/asset_triage_guide_service.dart';

void main() {
  group('AssetManagementInsightService', () {
    const service = AssetManagementInsightService();
    const planner = AssetLiabilityPlanningService();

    test('does not present inferred discipline results as facts', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000},
        baseDate: DateTime(2026, 9, 6),
      );
      final report = service.buildReport(workbook: workbook);
      final prompt = const AssetManagementInsightPromptBuilder()
          .buildDetailedAdvicePrompt(report);

      expect(prompt, contains('判定保留（取引証拠との照合が必要）'));
      expect(prompt, isNot(contains('違反あり')));
      expect(prompt, isNot(contains('今月は両誓約を守れています')));
      expect(prompt, contains('「期限超過:いいえ」は支払完了を意味しません'));
      expect(prompt, contains('引落確認待ちは未払い確定ではありません'));
      expect(prompt, contains('支払予定0円だけで返済なし'));
    });

    test('marks missing payment day as an action item', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'Custom Card': -10000,
        },
        baseDate: DateTime(2026, 5, 1),
      );

      final report = service.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
      );

      expect(
        report.actionItems.any(
          (item) =>
              item.type == AssetManagementInsightActionType.missingPaymentDay,
        ),
        true,
      );
    });

    test('payday rule supersedes the legacy one-shot record', () {
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

      final report = service.buildReport(workbook: workbook);
      final prompt = const AssetManagementInsightPromptBuilder()
          .buildDetailedAdvicePrompt(report);

      expect(report.disciplineReport!.revolvingCardViolations, isEmpty);
      expect(
        report.triagePlan!.weekSteps.any(
          (step) => step.kind == AssetTriageStepKind.disableRevolving,
        ),
        isFalse,
      );
      expect(prompt, contains('新規利用分を全額返済する設定記録: ファミペイ'));
      expect(prompt, contains('残高一括返済やリボ/分割設定の即時解除を促さず'));
      expect(prompt, contains('返済日は毎月25日'));
    });

    test('clears missing payment day item once an override is entered', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'Custom Card': -10000,
        },
        baseDate: DateTime(2026, 5, 1),
        paymentDayOverrides: const <String, int>{'Custom Card': 27},
      );

      final report = service.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
      );

      expect(
        report.actionItems.any(
          (item) =>
              item.type == AssetManagementInsightActionType.missingPaymentDay,
        ),
        false,
      );
    });

    test('marks missing annual rate as an action item', () {
      final workbook = _workbook(
        debtRows: <AssetLiabilityDebtRow>[
          _debtRow(annualRate: 0, kind: AssetLiabilityAccountKind.cardLoan),
        ],
      );

      final report = service.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
      );

      expect(
        report.actionItems.any(
          (item) =>
              item.type == AssetManagementInsightActionType.missingAnnualRate,
        ),
        true,
      );
    });

    test('does not require annual rate for full-payment fixed costs', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000},
        baseDate: DateTime(2026, 5, 1),
        includeDefaultFixedPayments: true,
      );

      final report = service.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
      );

      expect(
        workbook.debtMasterRows.any(
          (row) =>
              row.id == AssetLiabilityPlanningService.rentAccountId &&
              row.fullPaymentEstimate &&
              row.annualRate == 0,
        ),
        true,
      );
      expect(
        report.actionItems.any(
          (item) =>
              item.type == AssetManagementInsightActionType.missingAnnualRate,
        ),
        false,
      );
    });

    test('marks missing payment source as an action item', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'paypay_card': 20000},
      );

      final report = service.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
      );

      expect(
        report.actionItems.any(
          (item) =>
              item.type ==
              AssetManagementInsightActionType.missingPaymentSource,
        ),
        true,
      );
    });

    test('marks overdue payments as critical', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'auPayカード': -10000,
        },
        baseDate: DateTime(2026, 5, 15),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.auPayCardAccountId: 10000,
        },
        paymentSourceAccountIds: const <String, String>{
          AssetLiabilityPlanningService.auPayCardAccountId: 'bank',
        },
      );

      final report = service.buildReport(workbook: workbook);

      final overdue = report.actionItems.where(
        (item) => item.type == AssetManagementInsightActionType.overduePayment,
      );
      expect(overdue.isNotEmpty, true);
      expect(overdue.first.severity, AssetManagementInsightSeverity.critical);
    });

    test('overdue payment action names amount and flags unset payment source',
        () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布': 50000,
          'モビット': -300000,
        },
        baseDate: DateTime(2026, 5, 15),
        monthlyPaymentOverrides: const <String, double>{'mobit': 37000},
      );

      final report = service.buildReport(workbook: workbook);

      final overdue = report.actionItems.firstWhere(
        (item) => item.type == AssetManagementInsightActionType.overduePayment,
      );
      // 金額は支払予定額 (残高を延滞額扱いしない)。
      expect(overdue.description.contains('37,000円'), true);
      expect(overdue.suggestedAction.contains('支払原資口座が未設定'), true);
    });

    test(
        'overdue payment action computes transfer shortage from source balance',
        () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布': 3000,
          'モビット': -300000,
        },
        baseDate: DateTime(2026, 5, 15),
        monthlyPaymentOverrides: const <String, double>{'mobit': 37000},
        paymentSourceAccountIds: const <String, String>{'mobit': 'wallet_cash'},
      );

      final report = service.buildReport(workbook: workbook);

      final overdue = report.actionItems.firstWhere(
        (item) => item.type == AssetManagementInsightActionType.overduePayment,
      );
      // 不足額 = 37,000 − 3,000 = 34,000。
      expect(overdue.suggestedAction.contains('34,000円'), true);
      expect(overdue.suggestedAction.contains('財布'), true);
      expect(overdue.suggestedAction.contains('移動'), true);
    });

    test(
        'overdue payment action confirms payable when source balance covers it',
        () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布': 50000,
          'モビット': -300000,
        },
        baseDate: DateTime(2026, 5, 15),
        monthlyPaymentOverrides: const <String, double>{'mobit': 37000},
        paymentSourceAccountIds: const <String, String>{'mobit': 'wallet_cash'},
      );

      final report = service.buildReport(workbook: workbook);

      final overdue = report.actionItems.firstWhere(
        (item) => item.type == AssetManagementInsightActionType.overduePayment,
      );
      expect(overdue.suggestedAction.contains('支払可能'), true);
      expect(overdue.suggestedAction.contains('支払済みチェック'), true);
    });

    test('overdue actions on a shared source use the account-level shortfall',
        () {
      // 同一原資口座 (財布 40,000) に期限超過が2件 (30,000×2)。行単位の
      // 生残高比較だと両方「支払可能」になるが、口座別見込み (40,000−60,000
      // = −20,000) で判定し、不足バナーと同じ 20,000円不足を両方に出す。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布': 40000,
          'モビット': -300000,
          'auPayカード': -200000,
        },
        baseDate: DateTime(2026, 5, 15),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 30000,
          AssetLiabilityPlanningService.auPayCardAccountId: 30000,
        },
        paymentSourceAccountIds: const <String, String>{
          'mobit': 'wallet_cash',
          AssetLiabilityPlanningService.auPayCardAccountId: 'wallet_cash',
        },
      );

      final report = service.buildReport(workbook: workbook);

      final overdueActions = report.actionItems
          .where(
            (item) =>
                item.type == AssetManagementInsightActionType.overduePayment,
          )
          .toList();
      expect(overdueActions.length, 2);
      for (final action in overdueActions) {
        expect(action.suggestedAction.contains('20,000円'), true);
        expect(action.suggestedAction.contains('支払可能'), false);
      }
    });

    test('overdue action does not claim unset when source id is unresolvable',
        () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布': 50000,
          'モビット': -300000,
        },
        baseDate: DateTime(2026, 5, 15),
        monthlyPaymentOverrides: const <String, double>{'mobit': 37000},
        paymentSourceAccountIds: const <String, String>{
          'mobit': 'ghost_account',
        },
      );

      final report = service.buildReport(workbook: workbook);

      final overdue = report.actionItems.firstWhere(
        (item) => item.type == AssetManagementInsightActionType.overduePayment,
      );
      expect(overdue.suggestedAction.contains('確認できません'), true);
      expect(overdue.suggestedAction.contains('支払原資口座が未設定'), false);
    });

    test('missing payment source candidate is ranked by projected balance', () {
      // 三井住友は残高最大 (500,000) だがモビットの支払 480,000 が割当済みで
      // 見込み 20,000。財布 (100,000・割当なし) が候補になるべき —
      // ページ上部バナーの候補順位 (支払後見込み降順) と一致させる。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '三井住友銀行大塚支店': 500000,
          '財布': 100000,
          'モビット': -600000,
          'PayPay': -20000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 480000,
          'paypay_card': 20000,
        },
        paymentSourceAccountIds: const <String, String>{
          'mobit': 'smbc_otsuka_branch',
        },
      );

      final report = service.buildReport(workbook: workbook);

      final missing = report.actionItems.firstWhere(
        (item) =>
            item.type == AssetManagementInsightActionType.missingPaymentSource,
      );
      expect(missing.suggestedAction.contains('候補: 財布'), true);
      expect(missing.suggestedAction.contains('候補: 三井住友銀行大塚支店'), false);
    });

    test('report carries a triage plan and the prompt includes the section',
        () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 4817,
          '三井住友銀行大塚支店': 400000,
          'モビット': -3200000,
        },
        baseDate: DateTime(2026, 5, 15),
        monthlyPaymentOverrides: const <String, double>{'mobit': 37000},
      );

      final report = service.buildReport(workbook: workbook);

      expect(report.triagePlan, isNotNull);
      expect(report.triagePlan!.hasContent, isTrue);
      expect(
        report.triagePlan!.todaySteps.first.detail.contains('三井住友銀行大塚支店'),
        isTrue,
      );

      final prompt =
          const AssetManagementInsightPromptBuilder().buildDetailedAdvicePrompt(
        report,
      );
      expect(prompt.contains('今日やることトリアージ'), isTrue);
      expect(prompt.contains('食費・移動費を確保する'), isTrue);
      expect(prompt.contains('法テラス'), isTrue);
    });

    test('missing payment source action suggests the largest cash-like account',
        () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布': 1000,
          '三井住友銀行大塚支店': 500000,
          'PayPay': -20000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'paypay_card': 20000},
      );

      final report = service.buildReport(workbook: workbook);

      final missing = report.actionItems.firstWhere(
        (item) =>
            item.type == AssetManagementInsightActionType.missingPaymentSource,
      );
      expect(missing.description.contains('20,000円'), true);
      expect(missing.suggestedAction.contains('候補: 三井住友銀行大塚支店'), true);
      expect(missing.suggestedAction.contains('500,000円'), true);
    });

    test('calculates today, week, and month available amounts', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'paypay_card': 20000},
        paymentSourceAccountIds: const <String, String>{'paypay_card': 'bank'},
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'salary',
            date: DateTime(2026, 5, 2),
            name: 'salary',
            amount: 5000,
            destinationAccountId: 'bank',
            destinationAccountName: 'bank',
            received: false,
          ),
        ],
      );

      final report = service.buildReport(
        workbook: workbook,
        minimumSafetyBalance: 10000,
      );

      // 新式: 今月 = 利用可能資産(bank 50000) − 給料日(5/25)までの未払い(0:
      // paypay は 5/27 で給料日後) − 安全余裕(10000) = 40000。
      // 本日 = 今月 ÷ 残日数(5/1→5/25=24)。今週 = 本日 × 今週末までの日数。
      // 2026-05-01 は金曜 → 今週末(日)まで 3 日。
      expect(report.monthAvailable.availableAmount, 40000);
      expect(report.todayAvailable.availableAmount, closeTo(40000 / 24, 0.001));
      expect(
        report.weekAvailable.availableAmount,
        closeTo(40000 / 24 * 3, 0.001),
      );
    });

    test('generates movement suggestions from accounts with surplus', () {
      // モビット(支払日15)は給料日(5/25)までに期日が来るので未払いに計上される。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'モビット': -45000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 45000},
        paymentSourceAccountIds: const <String, String>{'mobit': 'bank'},
      );

      final report = service.buildReport(
        workbook: workbook,
        minimumSafetyBalance: 10000,
      );

      // 今月 = 50000 − 45000 − 10000 = -5000。
      expect(report.monthAvailable.availableAmount, -5000);
      expect(report.movementSuggestions.isNotEmpty, true);
      expect(report.movementSuggestions.first.fromAccountId, 'custom_bank');
      expect(report.movementSuggestions.first.amount, 5000);
    });

    test('generates emergency living advice for negative today cashflow', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'PayPay': -200000,
        },
        baseDate: DateTime(2026, 5, 28),
        monthlyPaymentOverrides: const <String, double>{'paypay_card': 200000},
        paymentSourceAccountIds: const <String, String>{'paypay_card': 'bank'},
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'salary',
            date: DateTime(2026, 5, 31),
            name: 'salary',
            amount: 250000,
            destinationAccountId: 'bank',
            destinationAccountName: 'bank',
            received: false,
          ),
        ],
      );

      final report = service.buildReport(
        workbook: workbook,
        minimumSafetyBalance: 10000,
      );

      // 今月 = bank 50000 − 未払い(paypay 200000, 5/27<給料日6/25) − 10000
      //      = -160000。本日はその日割りで負。
      expect(report.monthAvailable.availableAmount, closeTo(-160000, 0.001));
      expect(report.todayAvailable.availableAmount, lessThan(0));
      expect(report.emergencyAdvices.isNotEmpty, true);
      expect(report.emergencyAdvices.first.title, contains('今日の食費'));
      expect(report.emergencyAdvices.first.description, contains('水だけ'));
      expect(report.emergencyAdvices.first.description, contains('危険'));
      expect(
        report.actionItems.any(
          (item) =>
              item.type ==
              AssetManagementInsightActionType.emergencyLivingExpense,
        ),
        true,
      );
    });

    test('living expense priority mode follows emergency advice order', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 1000,
          'アコムカードローン': -100000,
          'モビット': -100000,
        },
        baseDate: DateTime(2026, 5, 10),
        includeDefaultFixedPayments: true,
      );

      final defaultReport = service.buildReport(
        workbook: workbook,
        upcomingPaymentWarningDays: 20,
      );
      final explicitOffReport = service.buildReport(
        workbook: workbook,
        upcomingPaymentWarningDays: 20,
        livingExpensePriorityMode: false,
      );
      final priorityReport = service.buildReport(
        workbook: workbook,
        upcomingPaymentWarningDays: 20,
        livingExpensePriorityMode: true,
      );

      expect(
        explicitOffReport.actionItems.map((item) => item.title),
        defaultReport.actionItems.map((item) => item.title),
      );

      int indexOf(
        AssetManagementInsightReport report,
        bool Function(AssetManagementInsightActionItem item) predicate,
      ) =>
          report.actionItems.indexWhere(predicate);

      final defaultLivingExpense = indexOf(
        defaultReport,
        (item) =>
            item.type ==
            AssetManagementInsightActionType.emergencyLivingExpense,
      );
      final defaultContact = indexOf(
        defaultReport,
        (item) =>
            item.type == AssetManagementInsightActionType.overduePayment &&
            item.relatedAccountId == 'acom_card_loan',
      );
      expect(defaultContact, lessThan(defaultLivingExpense));

      final livingExpense = indexOf(
        priorityReport,
        (item) =>
            item.type ==
            AssetManagementInsightActionType.emergencyLivingExpense,
      );
      final lifeline = indexOf(
        priorityReport,
        (item) =>
            item.relatedAccountId ==
            AssetLiabilityPlanningService.rentAccountId,
      );
      final contact = indexOf(
        priorityReport,
        (item) =>
            item.type == AssetManagementInsightActionType.overduePayment &&
            item.relatedAccountId == 'acom_card_loan',
      );
      final highInterest = indexOf(
        priorityReport,
        (item) =>
            item.type == AssetManagementInsightActionType.upcomingPayment &&
            item.relatedAccountId == 'mobit',
      );

      expect(livingExpense, greaterThanOrEqualTo(0));
      expect(lifeline, greaterThanOrEqualTo(0));
      expect(contact, greaterThanOrEqualTo(0));
      expect(highInterest, greaterThanOrEqualTo(0));
      expect(livingExpense, lessThan(contact));
      expect(lifeline, lessThan(contact));
      expect(contact, lessThan(highInterest));
    });

    test('flags account shortfall with matched transfer suggestion', () {
      // 全体では黒字(三井住友 500000)でも、支払原資に割り当てた現金だけが
      // 不足するケース。口座別見込みの先読み警告と移動提案の紐付けを検証する。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 1000,
          '三井住友銀行大塚支店': 500000,
          'モビット': -45000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 5000},
        paymentSourceAccountIds: const <String, String>{'mobit': 'wallet_cash'},
      );

      final report = service.buildReport(
        workbook: workbook,
        minimumSafetyBalance: 10000,
      );

      // 全体の使用可能額は黒字のまま。
      expect(report.monthAvailable.availableAmount, greaterThan(0));

      // 口座別では現金が 1000 − 5000 = -4000 で不足する。
      expect(report.accountShortfallAlerts.length, 1);
      final alert = report.accountShortfallAlerts.first;
      expect(alert.accountId, 'wallet_cash');
      expect(alert.projectedBalance, -4000);
      expect(alert.shortfallAmount, 4000);

      // 三井住友からの不足額ちょうどの移動提案が紐付く。
      expect(alert.hasTransferSuggestion, true);
      expect(alert.transferSuggestion!.fromAccountId, 'smbc_otsuka_branch');
      expect(alert.transferSuggestion!.toAccountId, 'wallet_cash');
      expect(alert.transferSuggestion!.amount, 4000);
    });

    test(
        'account shortfall emits critical action item and emergency advice '
        'even when windows are positive', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 1000,
          '三井住友銀行大塚支店': 500000,
          'モビット': -45000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'mobit': 5000},
        paymentSourceAccountIds: const <String, String>{'mobit': 'wallet_cash'},
      );

      final report = service.buildReport(
        workbook: workbook,
        minimumSafetyBalance: 10000,
      );
      final cashName = workbook.accounts
          .firstWhere((account) => account.id == 'wallet_cash')
          .name;
      final donorName = workbook.accounts
          .firstWhere((account) => account.id == 'smbc_otsuka_branch')
          .name;

      final shortfallActions = report.actionItems.where(
        (item) =>
            item.type == AssetManagementInsightActionType.accountShortfallRisk,
      );
      expect(shortfallActions.length, 1);
      expect(
        shortfallActions.first.severity,
        AssetManagementInsightSeverity.critical,
      );
      expect(shortfallActions.first.title, contains(cashName));

      // ウィンドウ黒字でも口座別不足の緊急アドバイスが先頭に出る。
      expect(report.emergencyAdvices.isNotEmpty, true);
      final advice = report.emergencyAdvices.first;
      expect(advice.severity, AssetManagementInsightSeverity.critical);
      expect(advice.title, contains(cashName));
      expect(advice.suggestedAction, contains(donorName));
      expect(advice.amount, 4000);
    });

    test(
        'no-donor account shortfall advice precedes living-expense advice '
        'under combined shortage', () {
      // 移動元候補が無く(現金のみ)、全体ウィンドウも赤字のケース。
      // 口座別不足アドバイスが生活費アドバイスより先頭に来ることと、
      // 提案なし文言(確保してから)へのフォールバックを検証する。
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 1000,
          'モビット': -300000,
        },
        baseDate: DateTime(2026, 5, 28),
        monthlyPaymentOverrides: const <String, double>{'mobit': 200000},
        paymentSourceAccountIds: const <String, String>{'mobit': 'wallet_cash'},
      );

      final report = service.buildReport(
        workbook: workbook,
        minimumSafetyBalance: 10000,
      );

      expect(report.todayAvailable.availableAmount, lessThan(0));
      expect(report.accountShortfallAlerts.length, 1);
      expect(report.accountShortfallAlerts.first.hasTransferSuggestion, false);

      expect(report.emergencyAdvices.first.title, contains('残高不足を先に解消'));
      expect(report.emergencyAdvices.first.suggestedAction, contains('確保してから'));
      expect(
        report.emergencyAdvices.any(
          (advice) => advice.title.contains('今日の食費'),
        ),
        true,
      );
    });

    test('orders account shortfall alerts by shortfall descending', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          '財布(現金)': 1000,
          '三井住友銀行大塚支店': 2000,
          'モビット': -45000,
          'auPayカード': -30000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 5000,
          'aupay_card': 12000,
        },
        paymentSourceAccountIds: const <String, String>{
          'mobit': 'wallet_cash',
          'aupay_card': 'smbc_otsuka_branch',
        },
      );

      final report = service.buildReport(workbook: workbook);

      // 三井住友(不足10000) → 現金(不足4000) の降順。
      expect(report.accountShortfallAlerts.length, 2);
      expect(report.accountShortfallAlerts[0].accountId, 'smbc_otsuka_branch');
      expect(report.accountShortfallAlerts[0].shortfallAmount, 10000);
      expect(report.accountShortfallAlerts[1].accountId, 'wallet_cash');
      expect(report.accountShortfallAlerts[1].shortfallAmount, 4000);
    });

    test('no account shortfall artifacts when projections stay positive', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000},
        baseDate: DateTime(2026, 5, 1),
      );

      final report = service.buildReport(workbook: workbook);

      expect(report.accountShortfallAlerts, isEmpty);
      expect(report.hasAccountShortfallAlerts, false);
      expect(
        report.actionItems.any(
          (item) =>
              item.type ==
              AssetManagementInsightActionType.accountShortfallRisk,
        ),
        false,
      );
    });

    test('generates developer improvement requests', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
        baseDate: DateTime(2026, 5, 1),
      );

      final report = service.buildReport(workbook: workbook);

      expect(report.developerRequests.isNotEmpty, true);
      expect(report.developerRequests.first.description.contains('現状では'), true);
      expect(report.developerRequests.first.evidence.isNotEmpty, true);
      expect(
        report.developerRequests.first.implementationSteps.isNotEmpty,
        true,
      );
      expect(
        report.developerRequests.first.acceptanceCriteria.isNotEmpty,
        true,
      );
      expect(report.implementationContexts.isNotEmpty, true);
    });

    test('detects card billing configuration action items', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'KDDI': -5764},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 5764,
        },
        cardBillingAccountIds: const <String, String>{
          AssetLiabilityPlanningService.kddiProviderAccountId: 'missing_card',
        },
      );

      final report = service.buildReport(workbook: workbook);

      expect(
        report.actionItems.any(
          (item) =>
              item.type ==
              AssetManagementInsightActionType.cardBillingConfiguration,
        ),
        true,
      );
    });

    test('accepts explicit zero yen billing without configuration item', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{'paypay_card': 0},
      );

      final report = service.buildReport(workbook: workbook);

      expect(
        report.actionItems.any(
          (item) =>
              item.type ==
              AssetManagementInsightActionType.cardBillingConfiguration,
        ),
        false,
      );
    });

    test('keeps zero-yen unpaid debt in review-only prompt data', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'じぶん銀行カードローン': -100000,
        },
        baseDate: DateTime(2026, 5, 29),
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.jibunBankCardLoanAccountId: 0,
        },
      );

      final report = service.buildReport(workbook: workbook);
      final prompt = const AssetManagementInsightPromptBuilder()
          .buildDetailedAdvicePrompt(report);

      expect(
        report.actionItems.where(
          (item) =>
              item.type == AssetManagementInsightActionType.overduePayment,
        ),
        isEmpty,
      );
      expect(prompt, contains('対象:じぶん銀行カードローン'));
      expect(prompt, contains('区分:確認のみ'));
      expect(prompt, contains('状態:確認のみ'));
      expect(prompt, contains('要対応:いいえ'));
    });

    test('builds prompt with deterministic calculated values', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'bank': 50000,
          'Custom Card': -10000,
        },
        baseDate: DateTime(2026, 5, 1),
      );
      final report = service.buildReport(
        workbook: workbook,
        userProfile: _userProfile(),
      );

      final prompt = const AssetManagementInsightPromptBuilder()
          .buildDetailedAdvicePrompt(report);

      expect(prompt.contains('Dart側で完了'), true);
      // リボ払いカードの照合不一致を指摘させない明示指示が含まれること。
      expect(prompt.contains('リボ払いカードの扱い'), true);
      // 残高を延滞額・今月の支払額として提示させない明示指示が含まれること。
      expect(prompt.contains('残高と支払額の区別'), true);
      expect(
        prompt.contains('「残高」を延滞額・今月の支払額として並べてはいけません'),
        true,
      );
      expect(prompt.contains('本日'), true);
      expect(prompt.contains('プロフィール詳細'), true);
      expect(prompt.contains('職業: 会社員'), true);
      expect(prompt.contains('負債マスタ詳細'), true);
      expect(prompt.contains('現実装コンテキスト'), true);
      expect(prompt.contains('asset_management_page.dart'), true);
      expect(prompt.contains('開発者向け改善提案候補'), true);
      expect(prompt.contains('受け入れ条件'), true);
      expect(prompt.contains(report.actionItems.first.title), true);
    });
  });
}

AssetLiabilityWorkbook _workbook({
  required List<AssetLiabilityDebtRow> debtRows,
}) {
  return AssetLiabilityWorkbook(
    baseDate: DateTime(2026, 5, 1),
    accounts: const <AssetLiabilityAccount>[
      AssetLiabilityAccount(
        id: 'bank',
        name: 'bank',
        kind: AssetLiabilityAccountKind.deposit,
        balance: 50000,
      ),
    ],
    debtMasterRows: debtRows,
    repaymentPriorityRows: debtRows,
    paymentDayRisks: const <AssetLiabilityPaymentDayRisk>[],
    cashflowRows: const <AssetLiabilityCashflowRow>[],
    incomePlans: const <AssetLiabilityIncomePlan>[],
    transferTasks: const <AssetLiabilityTransferTask>[],
    accountCashflowSummaries: const <AssetLiabilityAccountCashflowSummary>[],
    transferSuggestions: const <AssetLiabilityTransferSuggestion>[],
    cardBillingReview: const AssetLiabilityCardBillingReviewData(
      directPaymentItems: <AssetLiabilityCardBillingReviewItem>[],
      cardBillingGroups: <AssetLiabilityCardBillingGroup>[],
      missingBillingAccountItems: <AssetLiabilityCardBillingReviewItem>[],
      needsReviewItems: <AssetLiabilityCardBillingReviewItem>[],
      doubleCountingRiskItems: <AssetLiabilityCardBillingReviewItem>[],
    ),
    cardStatementReconciliation:
        const AssetLiabilityCardStatementReconciliationData(
      groups: <AssetLiabilityCardStatementReconciliationGroup>[],
      unmatchedStatementLines: <AssetLiabilityCardStatementLine>[],
    ),
    cashLikeTotal: 50000,
    securitiesTotal: 0,
    positiveAssetTotal: 50000,
    liabilityTotal: -10000,
    netWorth: 40000,
    monthlyMinimumPaymentEstimateTotal: 10000,
    monthlyScheduledPaymentTotal: 10000,
    monthlyActualPaymentTotal: 0,
    monthlyPaymentDifferenceTotal: 0,
    monthlyUnpaidPaymentTotal: 10000,
    monthlyUnreceivedIncomeTotal: 0,
    cashAfterMinimumPayments: 40000,
    cashAfterScheduledPayments: 40000,
    debtToAssetRatio: 0.2,
    topFourDebtShare: 1,
    manualPaymentCount: 1,
    estimatedPaymentCount: 0,
  );
}

AssetLiabilityDebtRow _debtRow({
  required double annualRate,
  required AssetLiabilityAccountKind kind,
}) {
  return AssetLiabilityDebtRow(
    id: 'loan',
    name: 'loan',
    kind: kind,
    balance: -10000,
    paymentDay: 15,
    paymentSourceAccountId: 'bank',
    paymentSourceAccountName: 'bank',
    paymentMethod: AssetLiabilityPaymentMethod.direct,
    paymentMethodLabel: '直接支払い',
    paymentMethodSettingSource:
        AssetLiabilityPaymentMethodSettingSource.builtInDefault,
    billingAccountId: null,
    billingAccountName: null,
    includedInBillingAccount: false,
    annualRate: annualRate,
    minimumPaymentEstimate: 10000,
    manualPaymentAmount: 10000,
    scheduledPaymentAmount: 10000,
    monthlyInterestEstimate: 0,
    principalPaymentEstimate: 10000,
    balanceAfterPaymentEstimate: 0,
    liabilityShare: 1,
    priorityLabel: 'test',
    paymentAmountEstimated: false,
    billingConfirmed: true,
    paid: false,
    requiresAction: true,
  );
}

UserProfile _userProfile() {
  return UserProfile(
    userId: 'user-1',
    displayName: 'テスト太郎',
    birthDate: DateTime(1978, 9, 30),
    gender: '男',
    occupation: '会社員',
    annualIncome: 4500000,
    address: '東京都',
    education: '大学卒',
    careerHistory: '営業職10年',
    hobbies: '音楽、AI',
    alcoholUse: '時々',
    smokingUse: '吸わない',
    favoriteFoods: 'カレー',
  );
}
