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

    final hasDetail = provider.isNotEmpty ||
        model != null ||
        latencyMs != null ||
        estimatedCostUsd != null ||
        traceId != null ||
        sessionId != null ||
        inputChars != null ||
        outputChars != null ||
        statusCode != null ||
        action != null;
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
    String? sessionId,
    String? traceId,
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
          if (sessionId != null && sessionId.trim().isNotEmpty)
            'session_id': sessionId.trim(),
          if (traceId != null && traceId.trim().isNotEmpty)
            'trace_id': traceId.trim(),
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
      throw const AiHubChatException('AI response was empty');
    } catch (error) {
      final message = error.toString();
      if (RegExp(r'429|quota|rate.?limit', caseSensitive: false)
          .hasMatch(message)) {
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
      throw const AiHubChatException('AI response was empty');
    } catch (error) {
      final message = error.toString();
      if (RegExp(r'429|quota|rate.?limit', caseSensitive: false)
          .hasMatch(message)) {
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
    return <String, dynamic>{
      ...body,
      ...settings.toAiHubPolicyPayload(),
    };
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
}
