import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_management_ai_analysis_history.dart';
import 'package:my_web_app/services/asset_ai_history_diff_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';

AssetManagementAiAnalysisHistoryEntry _entry({
  required String id,
  required DateTime generatedAt,
  required String summaryText,
  Map<String, dynamic> inputPayload = const <String, dynamic>{},
}) {
  return AssetManagementAiAnalysisHistoryEntry(
    id: id,
    requestFingerprint: 'fp-$id',
    summaryText: summaryText,
    status: 'success',
    source: 'gemini',
    generatedAt: generatedAt,
    createdAt: generatedAt,
    reportBaseDate:
        DateTime(generatedAt.year, generatedAt.month, generatedAt.day),
    providerChoiceReason: 'test',
    providerRoute: const <String, dynamic>{},
    inputPayload: inputPayload,
  );
}

void main() {
  group('AssetAiHistoryDiffService (#3395)', () {
    test('returns null when history is empty', () {
      final result = AssetAiHistoryDiffService.compare(
        history: const <AssetManagementAiAnalysisHistoryEntry>[],
      );
      expect(result, isNull);
    });

    test(
        'extracts improved, worsened, and unresolved items from latest history',
        () {
      final older = _entry(
        id: 'old-1',
        generatedAt: DateTime(2026, 6, 1, 9, 0),
        summaryText: '古い分析要約',
        inputPayload: const <String, dynamic>{
          'workbook': <String, dynamic>{
            'totals': <String, dynamic>{
              'liability_total': -900000,
              'cash_like_total': 10000,
            },
          },
        },
      );
      final newer = _entry(
        id: 'new-2',
        generatedAt: DateTime(2026, 6, 10, 14, 30),
        summaryText: '直近分析: 負債圧縮と期日前残高移動を優先してください。',
        inputPayload: const <String, dynamic>{
          'workbook': <String, dynamic>{
            'totals': <String, dynamic>{
              'liability_total': -500000,
              'cash_like_total': 30000,
              'cash_after_scheduled_payments': -10000,
              'monthly_unpaid_payment_total': 50000,
            },
            'debt_control_review': <String, dynamic>{
              'payment_source_missing_count': 1,
            },
          },
          'action_inventory': <String, dynamic>{
            'by_type': <String, dynamic>{
              'overduePayment': 0,
            },
          },
        },
      );

      final workbook = const AssetLiabilityPlanningService().buildWorkbook(
        latestSnapshot: const <String, double>{
          'じぶん銀行': 60000,
          'アコム': -420000,
        },
        baseDate: DateTime(2026, 6, 20),
        paymentDayOverrides: const <String, int>{'アコム': 5},
        monthlyPaymentOverrides: const <String, double>{'アコム': 20000},
        paidAccountNames: const <String>{'家賃'},
        includeDefaultFixedPayments: false,
        salaryDay: 25,
      );
      final report = const AssetManagementInsightService().buildReport(
        workbook: workbook,
      );

      final comparison = AssetAiHistoryDiffService.compare(
        history: [older, newer],
        currentWorkbook: workbook,
        currentReport: report,
      );

      expect(comparison, isNotNull);
      expect(comparison!.previousGeneratedAt, newer.generatedAt);
      expect(comparison.previousSummaryExcerpt, contains('直近分析'));
      expect(
        comparison.improvedItems.any((e) => e.contains('負債残高')),
        isTrue,
      );
      expect(
        comparison.improvedItems.any((e) => e.contains('手元現金')),
        isTrue,
      );
      expect(
        comparison.worsenedItems.any((e) => e.contains('期限超過の支払い')),
        isTrue,
      );
      expect(
        comparison.unresolvedItems.any((e) => e.contains('支払原資未設定口座')),
        isTrue,
      );
    });
  });
}
