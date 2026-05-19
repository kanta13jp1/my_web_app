import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline_secure_mode_settings_service.dart';

typedef AiHubChatInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

class AiHubChatObservability {
  final String provider;
  final String? model;
  final int? latencyMs;
  final double? estimatedCostUsd;
  final String? traceId;
  final String? sessionId;
  final int? inputChars;
  final int? outputChars;
  final int? statusCode;
  final String? action;
  final String? providerChoiceReason;
  final String? routingUseCase;

  const AiHubChatObservability({
    required this.provider,
    this.model,
    this.latencyMs,
    this.estimatedCostUsd,
    this.traceId,
    this.sessionId,
    this.inputChars,
    this.outputChars,
    this.statusCode,
    this.action,
    this.providerChoiceReason,
    this.routingUseCase,
  });

  static AiHubChatObservability? fromResponseMap(
    Map<String, dynamic> data, {
    String? fallbackProvider,
  }) {
    final nested = data['observability'];
    final raw = nested is Map<String, dynamic>
        ? nested
        : nested is Map
            ? Map<String, dynamic>.from(nested)
            : data;

    final provider =
        (raw['provider'] ?? fallbackProvider)?.toString().trim() ?? '';
    final model = raw['model']?.toString().trim();
    final latencyMs = _asInt(raw['latency_ms']);
    final estimatedCostUsd = _asDouble(raw['estimated_cost_usd']);
    final traceId = raw['trace_id']?.toString().trim();
    final sessionId = raw['session_id']?.toString().trim();
    final inputChars = _asInt(raw['input_chars']);
    final outputChars = _asInt(raw['output_chars']);
    final statusCode = _asInt(raw['status_code']);
    final action = raw['action']?.toString().trim();
    final providerChoiceReason =
        raw['provider_choice_reason']?.toString().trim();
    final routingUseCase = raw['routing_use_case']?.toString().trim();

    final hasDetail = provider.isNotEmpty ||
        model != null ||
        latencyMs != null ||
        estimatedCostUsd != null ||
        traceId != null ||
        sessionId != null ||
        inputChars != null ||
        outputChars != null ||
        statusCode != null ||
        action != null ||
        providerChoiceReason != null ||
        routingUseCase != null;
    if (!hasDetail) {
      return null;
    }

    return AiHubChatObservability(
      provider: provider.isEmpty ? (fallbackProvider ?? '') : provider,
      model: _emptyToNull(model),
      latencyMs: latencyMs,
      estimatedCostUsd: estimatedCostUsd,
      traceId: _emptyToNull(traceId),
      sessionId: _emptyToNull(sessionId),
      inputChars: inputChars,
      outputChars: outputChars,
      statusCode: statusCode,
      action: _emptyToNull(action),
      providerChoiceReason: _emptyToNull(providerChoiceReason),
      routingUseCase: _emptyToNull(routingUseCase),
    );
  }

  String? get shortTraceId {
    final value = traceId;
    if (value == null || value.isEmpty) return null;
    return value.length <= 8 ? value : value.substring(0, 8);
  }

  String? get shortSessionId {
    final value = sessionId;
    if (value == null || value.isEmpty) return null;
    return value.length <= 8 ? value : value.substring(0, 8);
  }
}

class AiHubChatResponse {
  final String text;
  final String source;
  final AiHubChatObservability? observability;

  const AiHubChatResponse({
    required this.text,
    required this.source,
    this.observability,
  });
}

class AiHubAnnualRateEvidenceResponse {
  final bool verified;
  final String status;
  final double? detectedAnnualRate;
  final String summary;
  final String source;

  const AiHubAnnualRateEvidenceResponse({
    required this.verified,
    required this.status,
    required this.detectedAnnualRate,
    required this.summary,
    required this.source,
  });
}

class AiHubChatException implements Exception {
  final String message;

  const AiHubChatException(this.message);

  @override
  String toString() => message;
}

class AiHubChatService {
  final SupabaseClient? _supabase;
  final AiHubChatInvoker? _invoker;
  final OfflineSecureModeSettingsService _offlineSettingsService;

  const AiHubChatService({
    SupabaseClient? supabase,
    AiHubChatInvoker? invoker,
    OfflineSecureModeSettingsService offlineSettingsService =
        const OfflineSecureModeSettingsService(),
  })  : _supabase = supabase,
        _invoker = invoker,
        _offlineSettingsService = offlineSettingsService;

  Future<AiHubChatResponse> sendProviderChat({
    required String message,
    String provider = 'deepinfra',
    String? model,
    String? sessionId,
    String? traceId,
    String? providerChoiceReason,
    String? routingUseCase,
  }) async {
    if (AiHubChatQuotaGuard.isCoolingDown) {
      throw const AiHubChatException('AI quota cooldown');
    }

    try {
      final data = await _invoke(
        await _withOfflinePolicy({
          'action': 'provider.chat',
          'provider': provider,
          'message': message,
          if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
          if (sessionId != null && sessionId.trim().isNotEmpty)
            'session_id': sessionId.trim(),
          if (traceId != null && traceId.trim().isNotEmpty)
            'trace_id': traceId.trim(),
          if (providerChoiceReason != null &&
              providerChoiceReason.trim().isNotEmpty)
            'provider_choice_reason': providerChoiceReason.trim(),
          if (routingUseCase != null && routingUseCase.trim().isNotEmpty)
            'routing_use_case': routingUseCase.trim(),
        }),
      );
      final text = (data['text'] ?? data['result'] ?? data['message'])
          ?.toString()
          .trim();
      if (data['success'] == true && text != null && text.isNotEmpty) {
        return AiHubChatResponse(
          text: text,
          source: 'ai-hub provider.chat / $provider',
          observability: AiHubChatObservability.fromResponseMap(
            data,
            fallbackProvider: provider,
          ),
        );
      }
      throw _buildAiHubFailureException(data);
    } catch (error) {
      final message = error.toString();
      if (RegExp(
        r'429|quota|rate.?limit',
        caseSensitive: false,
      ).hasMatch(message)) {
        AiHubChatQuotaGuard.markQuotaExceeded();
      }
      if (error is AiHubChatException) {
        rethrow;
      }
      throw AiHubChatException(message);
    }
  }

  Future<AiHubChatResponse> sendAutoChat({
    required String message,
    String? tier,
    String? sessionId,
    String? traceId,
    String? providerChoiceReason,
    String? routingUseCase,
  }) async {
    if (AiHubChatQuotaGuard.isCoolingDown) {
      throw const AiHubChatException('AI quota cooldown');
    }

    try {
      final data = await _invoke(
        await _withOfflinePolicy({
          'action': 'provider.chat_auto',
          'message': message,
          if (tier != null && tier.trim().isNotEmpty) 'tier': tier.trim(),
          if (sessionId != null && sessionId.trim().isNotEmpty)
            'session_id': sessionId.trim(),
          if (traceId != null && traceId.trim().isNotEmpty)
            'trace_id': traceId.trim(),
          if (providerChoiceReason != null &&
              providerChoiceReason.trim().isNotEmpty)
            'provider_choice_reason': providerChoiceReason.trim(),
          if (routingUseCase != null && routingUseCase.trim().isNotEmpty)
            'routing_use_case': routingUseCase.trim(),
        }),
      );
      final text = (data['text'] ?? data['result'] ?? data['message'])
          ?.toString()
          .trim();
      if (data['success'] == true && text != null && text.isNotEmpty) {
        final provider = data['provider']?.toString().trim();
        final source = provider == null || provider.isEmpty
            ? 'ai-hub provider.chat_auto'
            : 'ai-hub provider.chat_auto / $provider';
        return AiHubChatResponse(
          text: text,
          source: source,
          observability: AiHubChatObservability.fromResponseMap(
            data,
            fallbackProvider: provider,
          ),
        );
      }
      throw _buildAiHubFailureException(data);
    } catch (error) {
      final message = error.toString();
      if (RegExp(
        r'429|quota|rate.?limit',
        caseSensitive: false,
      ).hasMatch(message)) {
        AiHubChatQuotaGuard.markQuotaExceeded();
      }
      if (error is AiHubChatException) {
        rethrow;
      }
      throw AiHubChatException(message);
    }
  }

  Future<AiHubAnnualRateEvidenceResponse> verifyAnnualRateEvidence({
    required String accountName,
    required double submittedAnnualRate,
    required String imageBase64,
    required String mimeType,
    String? imageName,
    String? traceId,
  }) async {
    if (AiHubChatQuotaGuard.isCoolingDown) {
      throw const AiHubChatException('AI quota cooldown');
    }

    try {
      final data = await _invoke(
        await _withOfflinePolicy({
          'action': 'asset_liability.verify_annual_rate_evidence',
          'accountName': accountName,
          'submittedAnnualRate': submittedAnnualRate,
          'imageBase64': imageBase64,
          'mimeType': mimeType,
          if (imageName != null && imageName.trim().isNotEmpty)
            'imageName': imageName.trim(),
          if (traceId != null && traceId.trim().isNotEmpty)
            'trace_id': traceId.trim(),
        }),
      );
      if (data['success'] == true) {
        return AiHubAnnualRateEvidenceResponse(
          verified: data['verified'] == true,
          status: data['status']?.toString() ?? 'unknown',
          detectedAnnualRate: _asDouble(data['detected_annual_rate']),
          summary: (data['summary'] ?? data['message'] ?? '').toString(),
          source: 'ai-hub asset_liability.verify_annual_rate_evidence',
        );
      }
      throw _buildAiHubFailureException(
        data,
        fallbackMessage: 'AI evidence check failed',
      );
    } catch (error) {
      final message = error.toString();
      if (RegExp(
        r'429|quota|rate.?limit',
        caseSensitive: false,
      ).hasMatch(message)) {
        AiHubChatQuotaGuard.markQuotaExceeded();
      }
      if (error is AiHubChatException) {
        rethrow;
      }
      throw AiHubChatException(message);
    }
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final invoker = _invoker;
    if (invoker != null) {
      return invoker(body);
    }
    final client = _supabase ?? Supabase.instance.client;
    final response = await client.functions.invoke('ai-hub', body: body);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{
      'success': false,
      'message': data?.toString() ?? 'empty response',
    };
  }

  Future<Map<String, dynamic>> _withOfflinePolicy(
    Map<String, dynamic> body,
  ) async {
    final settings = await _offlineSettingsService.loadSettingsOrDefaults();
    return <String, dynamic>{...body, ...settings.toAiHubPolicyPayload()};
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString());
}

double? _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString());
}

AiHubChatException _buildAiHubFailureException(
  Map<String, dynamic> data, {
  String fallbackMessage = 'AI response was empty',
}) {
  final parts = <String>[];
  void add(Object? value) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty && !parts.contains(text)) {
      parts.add(text.length > 300 ? '${text.substring(0, 300)}...' : text);
    }
  }

  add(data['status']);
  add(data['provider']);
  add(data['message']);
  add(data['error']);
  add(data['detail']);
  add(data['http_status']);
  add(data['secret_needed']);

  return AiHubChatException(
    parts.isEmpty ? fallbackMessage : parts.join(' / '),
  );
}

String? _emptyToNull(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class AiHubChatQuotaGuard {
  static DateTime? _lastQuotaErrorAt;
  static const Duration _cooldown = Duration(seconds: 60);

  static void markQuotaExceeded() {
    _lastQuotaErrorAt = DateTime.now();
  }

  static bool get isCoolingDown {
    final ts = _lastQuotaErrorAt;
    if (ts == null) return false;
    return DateTime.now().difference(ts) < _cooldown;
  }

  static void resetForTesting() {
    _lastQuotaErrorAt = null;
  }
}
