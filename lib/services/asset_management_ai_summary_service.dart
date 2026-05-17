import 'dart:convert';

import 'ai_hub_chat_service.dart';
import 'asset_management_insight_service.dart';

class AssetManagementAiSummaryFeatureFlag {
  static const String dartDefineName = 'ASSET_MANAGEMENT_AI_SUMMARY_ENABLED';

  static const bool enabled = bool.fromEnvironment(
    dartDefineName,
    defaultValue: false,
  );

  const AssetManagementAiSummaryFeatureFlag._();
}

enum AssetManagementAiSummaryStatus { disabled, aiGenerated, fallback }

class AssetManagementAiSummaryResult {
  final AssetManagementAiSummaryStatus status;
  final String text;
  final String source;
  final String? errorMessage;
  final DateTime generatedAt;
  final Map<String, dynamic> payload;

  const AssetManagementAiSummaryResult({
    required this.status,
    required this.text,
    required this.source,
    required this.errorMessage,
    required this.generatedAt,
    required this.payload,
  });

  bool get usedExternalAi =>
      status == AssetManagementAiSummaryStatus.aiGenerated;
}

class AssetManagementAiSummaryService {
  final bool _aiEnabled;
  final AiHubChatService _chatService;
  final AssetManagementInsightPromptBuilder _promptBuilder;
  final DateTime Function() _now;
  final String? _provider;

  AssetManagementAiSummaryService({
    bool aiEnabled = AssetManagementAiSummaryFeatureFlag.enabled,
    AiHubChatService chatService = const AiHubChatService(),
    AssetManagementInsightPromptBuilder promptBuilder =
        const AssetManagementInsightPromptBuilder(),
    DateTime Function()? now,
    String? provider,
  })  : _aiEnabled = aiEnabled,
        _chatService = chatService,
        _promptBuilder = promptBuilder,
        _now = now ?? DateTime.now,
        _provider = provider;

  bool get aiEnabled => _aiEnabled;

  Future<AssetManagementAiSummaryResult> generateSummary({
    required AssetManagementInsightReport report,
  }) async {
    final payload = buildPayload(report);
    final fallback = buildDeterministicSummary(report);
    if (!_aiEnabled) {
      return AssetManagementAiSummaryResult(
        status: AssetManagementAiSummaryStatus.disabled,
        text: fallback,
        source: 'deterministic fallback / feature flag off',
        errorMessage: null,
        generatedAt: _now(),
        payload: payload,
      );
    }

    try {
      final prompt = _buildPrompt(report: report, payload: payload);
      final response = _provider == null || _provider == 'auto'
          ? await _chatService.sendAutoChat(
              message: prompt,
              tier: 'cheap',
              traceId: 'asset-management-ai-summary',
            )
          : await _chatService.sendProviderChat(
              message: prompt,
              provider: _provider,
              traceId: 'asset-management-ai-summary',
            );
      return AssetManagementAiSummaryResult(
        status: AssetManagementAiSummaryStatus.aiGenerated,
        text: response.text,
        source: response.source,
        errorMessage: null,
        generatedAt: _now(),
        payload: payload,
      );
    } catch (error) {
      return AssetManagementAiSummaryResult(
        status: AssetManagementAiSummaryStatus.fallback,
        text: fallback,
        source: 'deterministic fallback / ai-hub failed',
        errorMessage: error.toString(),
        generatedAt: _now(),
        payload: payload,
      );
    }
  }

  AssetManagementAiSummaryResult buildDisabledResult(
    AssetManagementInsightReport report,
  ) {
    final payload = buildPayload(report);
    return AssetManagementAiSummaryResult(
      status: AssetManagementAiSummaryStatus.disabled,
      text: buildDeterministicSummary(report),
      source: 'deterministic fallback / feature flag off',
      errorMessage: null,
      generatedAt: _now(),
      payload: payload,
    );
  }

  AssetManagementAiSummaryResult buildWaitingForAiResult(
    AssetManagementInsightReport report,
  ) {
    final payload = buildPayload(report);
    return AssetManagementAiSummaryResult(
      status: AssetManagementAiSummaryStatus.fallback,
      text: buildDeterministicSummary(report),
      source: 'deterministic fallback / waiting for ai-hub',
      errorMessage: null,
      generatedAt: _now(),
      payload: payload,
    );
  }

  Map<String, dynamic> buildPayload(AssetManagementInsightReport report) {
    return <String, dynamic>{
      'available_money': <String, dynamic>{
        'today': _availableToJson(report.todayAvailable),
        'week': _availableToJson(report.weekAvailable),
        'month': _availableToJson(report.monthAvailable),
      },
      'action_items': report.actionItems
          .map(
            (item) => <String, dynamic>{
              'type': item.type.name,
              'severity': item.severity.name,
              'title': item.title,
              'description': item.description,
              'related_account_id': item.relatedAccountId,
              'due_date': item.dueDate?.toIso8601String(),
              'payment_day': item.paymentDay,
              'suggested_action': item.suggestedAction,
            },
          )
          .toList(growable: false),
      'movement_suggestions': report.movementSuggestions
          .map(
            (suggestion) => <String, dynamic>{
              'from_account_id': suggestion.fromAccountId,
              'from_account_name': suggestion.fromAccountName,
              'to_account_id': suggestion.toAccountId,
              'to_account_name': suggestion.toAccountName,
              'amount': suggestion.amount,
              'needed_by': suggestion.neededBy?.toIso8601String(),
              'reason': suggestion.reason,
            },
          )
          .toList(growable: false),
      'emergency_advices': report.emergencyAdvices
          .map(
            (advice) => <String, dynamic>{
              'severity': advice.severity.name,
              'title': advice.title,
              'description': advice.description,
              'suggested_action': advice.suggestedAction,
              'amount': advice.amount,
            },
          )
          .toList(growable: false),
      'developer_requests': report.developerRequests
          .map(
            (request) => <String, dynamic>{
              'title': request.title,
              'description': request.description,
              'severity': request.severity.name,
            },
          )
          .toList(growable: false),
      'guardrails': const <String, dynamic>{
        'calculation_owner': 'dart_service',
        'external_ai_may_summarize_only': true,
        'external_ai_may_recalculate_amounts': false,
        'must_not_recommend_starvation_or_water_only': true,
        'must_prioritize_food_shelter_health_and_contacting_creditors': true,
      },
    };
  }

  String buildDeterministicSummary(AssetManagementInsightReport report) {
    final critical = report.criticalActions.length;
    final actionCount = report.actionItems.length;
    final today = _formatYen(report.todayAvailable.availableAmount);
    final week = _formatYen(report.weekAvailable.availableAmount);
    final month = _formatYen(report.monthAvailable.availableAmount);
    final movement = report.movementSuggestions.isEmpty
        ? '現時点で口座移動・出金提案はありません。'
        : '口座移動・出金提案を${report.movementSuggestions.length}件確認してください。';
    final emergency = report.emergencyAdvices.isEmpty
        ? '緊急の生活費防衛アドバイスはありません。'
        : report.emergencyAdvices
            .take(3)
            .map(
              (advice) => '${advice.title}: ${advice.description} '
                  '${advice.suggestedAction}',
            )
            .join(' ');
    final status = critical > 0 ? '緊急の資金繰り項目があります。' : '緊急度の高い資金繰り項目は検出されていません。';
    return [
      status,
      '要対応: $actionCount件、緊急: $critical件。',
      '使用可能額: 本日 $today、今週 $week、今月 $month。',
      emergency,
      movement,
      '金額はDartルールで計算済みです。Amounts are calculated by Dart rules; AI summary is optional.',
    ].join(' ');
  }

  String _buildPrompt({
    required AssetManagementInsightReport report,
    required Map<String, dynamic> payload,
  }) {
    return [
      _promptBuilder.buildPrompt(report),
      '',
      '## Computed insight payload',
      jsonEncode(payload),
      '',
      'Rules: summarize only. Do not recalculate amounts. Do not provide legal, investment, or credit advice. Never recommend starvation, water-only survival, or skipping meals as a solution. Prioritize food, shelter, health, contacting creditors, and emergency public/community support. Keep the response concise and action-oriented.',
    ].join('\n');
  }

  Map<String, dynamic> _availableToJson(
    AssetManagementAvailableMoneyInsight insight,
  ) {
    return <String, dynamic>{
      'window': insight.window.name,
      'start_date': insight.startDate.toIso8601String(),
      'end_date': insight.endDate.toIso8601String(),
      'cash_like_total': insight.cashLikeTotal,
      'unpaid_payment_total': insight.unpaidPaymentTotal,
      'unreceived_income_total': insight.unreceivedIncomeTotal,
      'minimum_safety_balance': insight.minimumSafetyBalance,
      'available_amount': insight.availableAmount,
      'summary': insight.summary,
    };
  }

  String _formatYen(double amount) {
    final sign = amount < 0 ? '-' : '';
    final digits = amount.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i += 1) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$sign$buffer円';
  }
}
