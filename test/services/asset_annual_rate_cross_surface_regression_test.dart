import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/user_profile.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_liability_repayment_simulation_service.dart';
import 'package:my_web_app/services/asset_management_ai_summary_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';
import 'package:my_web_app/services/asset_pain_metric_service.dart';

UserProfile _syntheticProfile() {
  return UserProfile(
    userId: 'synthetic-user-5196',
    displayName: 'tester',
    bio: 'synthetic profile for annual rate cross-surface regression',
    location: '東京都',
    birthDate: DateTime(1985, 4, 1),
    targetDeathAge: 85,
    gender: '未設定',
    occupation: '会社員',
    annualIncome: 4800000,
    address: '東京都',
    education: '大学卒',
    careerHistory: 'ソフトウェア開発',
    hobbies: '読書',
    alcoholUse: '飲まない',
    smokingUse: '吸わない',
    favoriteFoods: 'カレー',
  );
}

void main() {
  group('Issue #5196 annual rate cross-surface regression', () {
    setUp(AiHubChatQuotaGuard.resetForTesting);

    test(
      'overridden annual rates stay consistent across workbook, pain metrics, repayment simulation, and AI payload',
      () {
        const planner = AssetLiabilityPlanningService();
        final workbook = planner.buildWorkbook(
          baseDate: DateTime(2026, 9, 3),
          latestSnapshot: const <String, double>{
            'bank': 300000,
            'アコムカードローン': -1200000,
            'じぶんローン': -600000,
            'アコムショッピング': -400000,
          },
          annualRateOverrides: const <String, double>{
            'acom_card_loan': 0.15,
            AssetLiabilityPlanningService.jibunBankCardLoanAccountId: 0.134,
            AssetLiabilityPlanningService.acomShoppingAccountId: 0.146,
          },
        );

        final expectedRatesById = <String, double>{
          'acom_card_loan': 0.15,
          AssetLiabilityPlanningService.jibunBankCardLoanAccountId: 0.134,
          AssetLiabilityPlanningService.acomShoppingAccountId: 0.146,
        };

        for (final entry in expectedRatesById.entries) {
          final debtRow = workbook.debtMasterRows.singleWhere(
            (row) => row.id == entry.key,
          );
          final account = workbook.accounts.singleWhere(
            (item) => item.id == entry.key,
          );
          expect(debtRow.annualRate, closeTo(entry.value, 1e-9));
          expect(account.annualRate, closeTo(entry.value, 1e-9));
        }

        const expectedMonthlyInterest =
            1200000 * 0.15 / 12 + 600000 * 0.134 / 12 + 400000 * 0.146 / 12;
        const staleDefaultMonthlyInterest =
            1200000 * 0.18 / 12 + 600000 * 0.145 / 12 + 400000 * 0.146 / 12;

        final dailyBleed = AssetPainMetricService.calculateDailyInterestBleed(
          workbook,
        );
        expect(dailyBleed, closeTo(expectedMonthlyInterest / 30.0, 0.01));
        expect(
          dailyBleed,
          isNot(closeTo(staleDefaultMonthlyInterest / 30.0, 1.0)),
        );

        final lostHours = AssetPainMetricService.dailyLostLaborHours(
          workbook,
          hourlyWage: 2500,
        );
        expect(
          lostHours,
          closeTo((expectedMonthlyInterest / 30.0) / 2500.0, 1e-6),
        );

        final stolenSixMonths = AssetPainMetricService.stolenFutureTotal(
          workbook: workbook,
          months: 6,
        );
        expect(stolenSixMonths, closeTo(expectedMonthlyInterest * 6.0, 0.01));

        const simulationService = AssetLiabilityRepaymentSimulationService();
        final simResult = simulationService.buildPanelComparison(
          workbook: workbook,
        );
        final ratePlan = simResult.planFor(
          AssetLiabilityRepaymentSimulationStrategy.interestRate,
        )!;
        for (final row in ratePlan.priorityRows) {
          expect(row.annualRate, closeTo(expectedRatesById[row.id]!, 1e-9));
        }
        expect(
          ratePlan.monthSnapshots.first.interestTotal,
          closeTo(expectedMonthlyInterest, 1.0),
        );

        final report = const AssetManagementInsightService().buildReport(
          workbook: workbook,
          userProfile: _syntheticProfile(),
          minimumSafetyBalance: 10000,
        );
        final payload = AssetManagementAiSummaryService().buildPayload(report);
        final workbookPayload = payload['workbook'] as Map<String, dynamic>;
        final payloadAccounts = (workbookPayload['accounts'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final payloadDebtRows =
            (workbookPayload['debt_master_rows'] as List<dynamic>)
                .cast<Map<String, dynamic>>();

        for (final entry in expectedRatesById.entries) {
          final accountJson = payloadAccounts.singleWhere(
            (item) => item['id'] == entry.key,
          );
          final debtJson = payloadDebtRows.singleWhere(
            (item) => item['id'] == entry.key,
          );
          expect(
            (accountJson['annual_rate'] as num).toDouble(),
            closeTo(entry.value, 1e-9),
          );
          expect(
            (debtJson['annual_rate'] as num).toDouble(),
            closeTo(entry.value, 1e-9),
          );
        }
      },
    );

    test(
      'rejects AI summary using prefix rate phrasing with stale default rate',
      () async {
        const planner = AssetLiabilityPlanningService();
        final workbook = planner.buildWorkbook(
          baseDate: DateTime(2026, 9, 3),
          latestSnapshot: const <String, double>{
            'bank': 300000,
            'アコムカードローン': -1200000,
            'じぶんローン': -600000,
            'アコムショッピング': -400000,
          },
          annualRateOverrides: const <String, double>{
            'acom_card_loan': 0.15,
            AssetLiabilityPlanningService.jibunBankCardLoanAccountId: 0.134,
            AssetLiabilityPlanningService.acomShoppingAccountId: 0.146,
          },
        );
        final report = const AssetManagementInsightService().buildReport(
          workbook: workbook,
          userProfile: _syntheticProfile(),
          minimumSafetyBalance: 10000,
        );
        final service = AssetManagementAiSummaryService(
          aiEnabled: true,
          chatService: AiHubChatService(
            invoker: (_) async => <String, dynamic>{
              'success': true,
              'text': '純資産は-1,900,000円、負債合計は2,200,000円です。'
                  '年利18.0%のアコムカードローンを最優先で返済してください。',
              'provider': 'openai',
            },
          ),
          now: () => DateTime(2026, 9, 3, 12),
        );

        final result = await service.generateSummary(report: report);

        expect(result.status, AssetManagementAiSummaryStatus.fallback);
        expect(result.usedExternalAi, isFalse);
        expect(result.errorMessage, contains('アコムカードローンの年利が確定値と不一致'));
      },
    );

    test(
      'accepts AI summary using prefix rate phrasing with confirmed overridden rates',
      () async {
        const planner = AssetLiabilityPlanningService();
        final workbook = planner.buildWorkbook(
          baseDate: DateTime(2026, 9, 3),
          latestSnapshot: const <String, double>{
            'bank': 300000,
            'アコムカードローン': -1200000,
            'じぶんローン': -600000,
            'アコムショッピング': -400000,
          },
          annualRateOverrides: const <String, double>{
            'acom_card_loan': 0.15,
            AssetLiabilityPlanningService.jibunBankCardLoanAccountId: 0.134,
            AssetLiabilityPlanningService.acomShoppingAccountId: 0.146,
          },
        );
        final report = const AssetManagementInsightService().buildReport(
          workbook: workbook,
          userProfile: _syntheticProfile(),
          minimumSafetyBalance: 10000,
        );
        final service = AssetManagementAiSummaryService(
          aiEnabled: true,
          chatService: AiHubChatService(
            invoker: (_) async => <String, dynamic>{
              'success': true,
              'text': '純資産は-1,900,000円、負債合計は2,200,000円です。'
                  '年利15.00%のアコムカードローン、年利13.40%のじぶんローン、'
                  '年利14.60%のアコムショッピングの順で優先管理します。',
              'provider': 'openai',
            },
          ),
          now: () => DateTime(2026, 9, 3, 12),
        );

        final result = await service.generateSummary(report: report);

        expect(result.status, AssetManagementAiSummaryStatus.aiGenerated);
        expect(result.usedExternalAi, isTrue);
        expect(result.errorMessage, isNull);
      },
    );

    test(
      'accepts valid postfix comparison without misattributing rate to the following debt',
      () async {
        const planner = AssetLiabilityPlanningService();
        final workbook = planner.buildWorkbook(
          baseDate: DateTime(2026, 9, 3),
          latestSnapshot: const <String, double>{
            'bank': 300000,
            'アコムカードローン': -1200000,
            'じぶんローン': -600000,
            'アコムショッピング': -400000,
          },
          annualRateOverrides: const <String, double>{
            'acom_card_loan': 0.15,
            AssetLiabilityPlanningService.jibunBankCardLoanAccountId: 0.134,
            AssetLiabilityPlanningService.acomShoppingAccountId: 0.146,
          },
        );
        final report = const AssetManagementInsightService().buildReport(
          workbook: workbook,
          userProfile: _syntheticProfile(),
          minimumSafetyBalance: 10000,
        );
        final service = AssetManagementAiSummaryService(
          aiEnabled: true,
          chatService: AiHubChatService(
            invoker: (_) async => <String, dynamic>{
              'success': true,
              'text': '純資産は-1,900,000円、負債合計は2,200,000円です。'
                  'アコムカードローンは年利15.0%でじぶんローンより高いです。',
              'provider': 'openai',
            },
          ),
          now: () => DateTime(2026, 9, 3, 12),
        );

        final result = await service.generateSummary(report: report);

        expect(result.status, AssetManagementAiSummaryStatus.aiGenerated);
        expect(result.usedExternalAi, isTrue);
        expect(result.errorMessage, isNull);
      },
    );

    test(
      'rejects stale postfix rate even when another debt follows a predicate particle',
      () async {
        const planner = AssetLiabilityPlanningService();
        final workbook = planner.buildWorkbook(
          baseDate: DateTime(2026, 9, 3),
          latestSnapshot: const <String, double>{
            'bank': 300000,
            'アコムカードローン': -1200000,
            'じぶんローン': -600000,
            'アコムショッピング': -400000,
          },
          annualRateOverrides: const <String, double>{
            'acom_card_loan': 0.15,
            AssetLiabilityPlanningService.jibunBankCardLoanAccountId: 0.134,
            AssetLiabilityPlanningService.acomShoppingAccountId: 0.146,
          },
        );
        final report = const AssetManagementInsightService().buildReport(
          workbook: workbook,
          userProfile: _syntheticProfile(),
          minimumSafetyBalance: 10000,
        );
        final service = AssetManagementAiSummaryService(
          aiEnabled: true,
          chatService: AiHubChatService(
            invoker: (_) async => <String, dynamic>{
              'success': true,
              'text': '純資産は-1,900,000円、負債合計は2,200,000円です。'
                  'アコムカードローンは年利18.0%でじぶんローンより高いです。',
              'provider': 'openai',
            },
          ),
          now: () => DateTime(2026, 9, 3, 12),
        );

        final result = await service.generateSummary(report: report);

        expect(result.status, AssetManagementAiSummaryStatus.fallback);
        expect(result.usedExternalAi, isFalse);
        expect(result.errorMessage, contains('アコムカードローンの年利が確定値と不一致'));
      },
    );
  });
}
