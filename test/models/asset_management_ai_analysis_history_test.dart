import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_management_ai_analysis_history.dart';

void main() {
  group('AssetManagementAiAnalysisHistoryEntry.toPromptContextJson', () {
    AssetManagementAiAnalysisHistoryEntry entry({
      Map<String, dynamic> inputPayload = const <String, dynamic>{},
      String summaryText = '前回は横浜銀行が期限超過で未払い、本日-27337円で不足よ。',
    }) {
      return AssetManagementAiAnalysisHistoryEntry(
        id: 'history-1',
        requestFingerprint: 'fp-1',
        summaryText: summaryText,
        status: 'ai_generated',
        source: 'ai-hub provider.chat / openai',
        generatedAt: DateTime(2026, 6, 16, 12),
        createdAt: DateTime(2026, 6, 16, 12),
        reportBaseDate: DateTime(2026, 6, 16),
        providerChoiceReason: 'test',
        providerRoute: const <String, dynamic>{'provider': 'openai'},
        inputPayload: inputPayload,
      );
    }

    test('does not leak the past analysis prose (no summary text/excerpt)', () {
      final json = entry().toPromptContextJson();

      expect(json.containsKey('summary_excerpt'), isFalse);
      expect(json.containsKey('summary_text'), isFalse);
      // 過去本文に含まれる期限超過/負の値の語が一切混入しないこと。
      expect(json.toString().contains('期限超過'), isFalse);
      expect(json.toString().contains('-27337'), isFalse);
    });

    test('extracts numeric metrics snapshot from stored input payload', () {
      final json = entry(
        inputPayload: const <String, dynamic>{
          'workbook': <String, dynamic>{
            'totals': <String, dynamic>{
              'net_worth': -7261960,
              'liability_total': -7412535,
              'monthly_unpaid_payment_total': 356052,
              'monthly_actual_payment_total': 0,
            },
          },
          'available_money': <String, dynamic>{
            'today': <String, dynamic>{'available_amount': -27337},
            'week': <String, dynamic>{'available_amount': -20000},
            'month': <String, dynamic>{'available_amount': -10000},
          },
        },
      ).toPromptContextJson();

      final metrics = json['metrics_snapshot'] as Map<String, dynamic>;
      expect(metrics['net_worth'], -7261960);
      expect(metrics['liability_total'], -7412535);
      expect(metrics['monthly_unpaid_payment_total'], 356052);
      expect(metrics['monthly_actual_payment_total'], 0);
      expect(metrics['today_available_amount'], -27337);
      expect(metrics['week_available_amount'], -20000);
      expect(metrics['month_available_amount'], -10000);
    });

    test('yields null metrics when payload lacks the expected shape', () {
      final json = entry(inputPayload: const <String, dynamic>{'sample': true})
          .toPromptContextJson();

      final metrics = json['metrics_snapshot'] as Map<String, dynamic>;
      expect(metrics['net_worth'], isNull);
      expect(metrics['today_available_amount'], isNull);
    });
  });

  group('AssetManagementAiAnalysisHistoryEntry.hasSummaryText', () {
    Map<String, dynamic> baseJson() => <String, dynamic>{
          'id': 'history-1',
          'request_fingerprint': 'fp-1',
          'status': 'ai_generated',
          'source': 'ai-hub provider.chat / openai',
          'generated_at': '2026-06-16T12:00:00Z',
          'created_at': '2026-06-16T12:00:00Z',
        };

    test('summary_text 列を取得した行は本文の有無で判定する', () {
      final withText = AssetManagementAiAnalysisHistoryEntry.fromJson(
        <String, dynamic>{...baseJson(), 'summary_text': '本文あり'},
      );
      final emptyText = AssetManagementAiAnalysisHistoryEntry.fromJson(
        <String, dynamic>{...baseJson(), 'summary_text': '  '},
      );

      expect(withText.summaryTextOmitted, isFalse);
      expect(withText.hasSummaryText, isTrue);
      expect(emptyText.summaryTextOmitted, isFalse);
      expect(emptyText.hasSummaryText, isFalse);
    });

    test('縮小 projection (summary_text 列なし) は存在保証済みとして扱う', () {
      // loadRecent は summary_text <> '' を server-side filter で保証した上で
      // 列自体を取得しない。この行が prompt 文脈から脱落しないこと。
      final omitted =
          AssetManagementAiAnalysisHistoryEntry.fromJson(baseJson());

      expect(omitted.summaryText, isEmpty);
      expect(omitted.summaryTextOmitted, isTrue);
      expect(omitted.hasSummaryText, isTrue);
    });
  });
}
