import 'dart:convert';

import 'ai_hub_chat_service.dart';
import 'asset_management_ai_provider_router.dart';
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
  final Map<String, dynamic>? providerRoute;
  final String? providerChoiceReason;

  const AssetManagementAiSummaryResult({
    required this.status,
    required this.text,
    required this.source,
    required this.errorMessage,
    required this.generatedAt,
    required this.payload,
    this.providerRoute,
    this.providerChoiceReason,
  });

  bool get usedExternalAi =>
      status == AssetManagementAiSummaryStatus.aiGenerated;
}

class AssetManagementAiSummaryService {
  final bool _aiEnabled;
  final AiHubChatService _chatService;
  final AssetManagementInsightPromptBuilder _promptBuilder;
  final AssetManagementAiProviderRouter _providerRouter;
  final AssetManagementAiProviderUseCase _useCase;
  final DateTime Function() _now;
  final String? _provider;

  AssetManagementAiSummaryService({
    bool aiEnabled = AssetManagementAiSummaryFeatureFlag.enabled,
    AiHubChatService chatService = const AiHubChatService(),
    AssetManagementInsightPromptBuilder promptBuilder =
        const AssetManagementInsightPromptBuilder(),
    AssetManagementAiProviderRouter providerRouter =
        const AssetManagementAiProviderRouter(),
    AssetManagementAiProviderUseCase useCase =
        AssetManagementAiProviderUseCase.summary,
    DateTime Function()? now,
    String? provider,
  }) : _aiEnabled = aiEnabled,
       _chatService = chatService,
       _promptBuilder = promptBuilder,
       _providerRouter = providerRouter,
       _useCase = useCase,
       _now = now ?? DateTime.now,
       _provider = provider;

  bool get aiEnabled => _aiEnabled;

  Future<AssetManagementAiSummaryResult> generateSummary({
    required AssetManagementInsightReport report,
  }) async {
    final payload = buildPayload(report);
    final route = _providerRouter.routeFor(
      useCase: _useCase,
      explicitProvider: _provider,
    );
    final fallback = buildDeterministicSummary(report);
    if (!_aiEnabled) {
      return AssetManagementAiSummaryResult(
        status: AssetManagementAiSummaryStatus.disabled,
        text: fallback,
        source: 'deterministic fallback / feature flag off',
        errorMessage: null,
        generatedAt: _now(),
        payload: payload,
        providerRoute: route.toLogPayload(),
        providerChoiceReason: route.providerChoiceReason,
      );
    }

    try {
      final aiSafePayload = buildAiSafePayload(report);
      final prompt = _buildPrompt(report: report, payload: aiSafePayload);
      final response = route.routingEnabled
          ? await _sendRoutedSummary(prompt: prompt, route: route)
          : _provider == null || _provider == 'auto'
          ? await _chatService.sendAutoChat(
              message: prompt,
              tier: 'performance',
              traceId: 'asset-management-ai-summary',
              providerChoiceReason: route.providerChoiceReason,
              routingUseCase: route.useCase.id,
            )
          : await _chatService.sendProviderChat(
              message: prompt,
              provider: _provider,
              traceId: 'asset-management-ai-summary',
              providerChoiceReason: route.providerChoiceReason,
              routingUseCase: route.useCase.id,
            );
      if (!_containsJapaneseText(response.text)) {
        throw const AiHubChatException('AI要約が日本語ではありませんでした');
      }
      return AssetManagementAiSummaryResult(
        status: AssetManagementAiSummaryStatus.aiGenerated,
        text: response.text.trim(),
        source: response.source,
        errorMessage: null,
        generatedAt: _now(),
        payload: payload,
        providerRoute: route.toLogPayload(),
        providerChoiceReason: route.providerChoiceReason,
      );
    } catch (error) {
      return AssetManagementAiSummaryResult(
        status: AssetManagementAiSummaryStatus.fallback,
        text: fallback,
        source: 'deterministic fallback / ai-hub failed',
        errorMessage: error.toString(),
        generatedAt: _now(),
        payload: payload,
        providerRoute: route.toLogPayload(),
        providerChoiceReason: route.providerChoiceReason,
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

  Map<String, dynamic> buildAiSafePayload(AssetManagementInsightReport report) {
    return <String, dynamic>{
      'available_money_bands': <String, dynamic>{
        'today': _availableToAiSafeJson(report.todayAvailable),
        'week': _availableToAiSafeJson(report.weekAvailable),
        'month': _availableToAiSafeJson(report.monthAvailable),
      },
      'action_inventory': <String, dynamic>{
        'total': report.actionItems.length,
        'by_type': _countBy(report.actionItems.map((item) => item.type.name)),
        'by_severity': _countBy(
          report.actionItems.map((item) => item.severity.name),
        ),
        'has_due_dates': report.actionItems.any((item) => item.dueDate != null),
        'has_payment_day_metadata': report.actionItems.any(
          (item) => item.paymentDay != null,
        ),
      },
      'movement_suggestions': <String, dynamic>{
        'count': report.movementSuggestions.length,
        'amount_pressure_bands': _countBy(
          report.movementSuggestions.map(
            (suggestion) => _amountPressureBand(suggestion.amount),
          ),
        ),
      },
      'emergency_advices': <String, dynamic>{
        'count': report.emergencyAdvices.length,
        'by_severity': _countBy(
          report.emergencyAdvices.map((advice) => advice.severity.name),
        ),
        'amount_pressure_bands': _countBy(
          report.emergencyAdvices.map(
            (advice) => _amountPressureBand(advice.amount),
          ),
        ),
      },
      'developer_requests': <String, dynamic>{
        'count': report.developerRequests.length,
        'by_severity': _countBy(
          report.developerRequests.map((request) => request.severity.name),
        ),
      },
      'guardrails': const <String, dynamic>{
        'calculation_owner': 'dart_service',
        'response_language': 'ja-JP',
        'must_respond_in_japanese': true,
        'must_not_use_english_headings': true,
        'external_ai_may_summarize_only': true,
        'external_ai_may_recalculate_amounts': false,
        'external_ai_payload_redacts_exact_money_values': true,
        'external_ai_payload_redacts_account_identifiers': true,
        'must_not_recommend_starvation_or_water_only': true,
        'must_prioritize_food_shelter_health_and_contacting_creditors': true,
      },
    };
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
                (advice) =>
                    '${advice.title}: ${advice.description} '
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
      '金額はDartルールで計算済みです。AIは要約のみを行います。',
    ].join(' ');
  }

  String _buildPrompt({
    required AssetManagementInsightReport report,
    required Map<String, dynamic> payload,
  }) {
    return [
      _promptBuilder.buildRedactedPrompt(report),
      '',
      '## 計算済みインサイトの安全化ペイロード',
      jsonEncode(payload),
      '',
      '出力ルール: 必ず自然な日本語だけで回答してください。Markdownの見出し、箇条書き、ラベルも日本語にしてください。英語の見出しや英語ラベルは使わないでください。安全化されたカテゴリだけを要約し、金額を再計算しないでください。正確な残高の追加開示を求めないでください。法的助言、投資助言、信用判断の断定はしないでください。飢える、水だけで耐える、食事を抜くといった健康を害する提案は絶対にしないでください。食費、住居、医療、支払先への連絡、公的・地域の緊急支援を優先してください。短く、今日実行できる行動に寄せてください。',
    ].join('\n');
  }

  Future<AiHubChatResponse> _sendRoutedSummary({
    required String prompt,
    required AssetManagementAiProviderRouteDecision route,
  }) async {
    Object? lastError;
    for (final candidate in route.candidates) {
      try {
        return await _chatService.sendProviderChat(
          message: prompt,
          provider: candidate.providerId,
          model: candidate.modelId,
          traceId: 'asset-management-ai-summary',
          providerChoiceReason: route.providerChoiceReason,
          routingUseCase: route.useCase.id,
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw AiHubChatException(
      lastError == null
          ? route.localFallbackReason
          : '${route.localFallbackReason}: $lastError',
    );
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

  Map<String, dynamic> _availableToAiSafeJson(
    AssetManagementAvailableMoneyInsight insight,
  ) {
    return <String, dynamic>{
      'window': insight.window.name,
      'risk_band': _availableRiskBand(insight),
      'date_window_days':
          insight.endDate.difference(insight.startDate).inDays + 1,
      'cash_like_status': _amountPressureBand(insight.cashLikeTotal),
      'unpaid_payment_status': _amountPressureBand(insight.unpaidPaymentTotal),
      'unreceived_income_status': _amountPressureBand(
        insight.unreceivedIncomeTotal,
      ),
      'minimum_safety_balance_policy': 'configured_in_dart',
    };
  }

  Map<String, int> _countBy(Iterable<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts;
  }

  String _availableRiskBand(AssetManagementAvailableMoneyInsight insight) {
    final amount = insight.availableAmount;
    if (amount < 0) return 'shortage';
    if (amount < insight.minimumSafetyBalance) return 'below_safety_balance';
    if (amount < insight.minimumSafetyBalance * 2) return 'near_safety_buffer';
    return 'buffer_available';
  }

  String _amountPressureBand(double? amount) {
    if (amount == null) return 'not_applicable';
    final absolute = amount.abs();
    if (absolute == 0) return 'none';
    if (absolute < 10000) return 'low';
    if (absolute < 100000) return 'medium';
    return 'high';
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

  bool _containsJapaneseText(String value) {
    return RegExp('[\u3040-\u30ff\u3400-\u9fff]').hasMatch(value);
  }
}
