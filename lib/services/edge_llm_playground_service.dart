import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/ai_hub_chat_service.dart';

typedef EdgeLlmPlaygroundInvoker = AiHubChatInvoker;

class EdgeLlmPlaygroundException implements Exception {
  final String message;

  const EdgeLlmPlaygroundException(this.message);

  @override
  String toString() => message;
}

class EdgeLlmPlaygroundResponse {
  final String text;
  final String source;
  final String provider;
  final String? tier;
  final String? model;
  final String responseFormat;
  final Map<String, dynamic>? parsedJson;
  final String? parseError;
  final AiHubChatObservability? observability;

  const EdgeLlmPlaygroundResponse({
    required this.text,
    required this.source,
    required this.provider,
    required this.responseFormat,
    this.tier,
    this.model,
    this.parsedJson,
    this.parseError,
    this.observability,
  });
}

class EdgeLlmPlaygroundService {
  final SupabaseClient? _supabase;
  final EdgeLlmPlaygroundInvoker? _invoker;

  const EdgeLlmPlaygroundService({
    SupabaseClient? supabase,
    EdgeLlmPlaygroundInvoker? invoker,
  })  : _supabase = supabase,
        _invoker = invoker;

  Future<EdgeLlmPlaygroundResponse> invoke({
    required String userPrompt,
    String systemPrompt = '',
    String provider = 'auto',
    String? tier,
    String responseFormat = 'text',
    String contextDraft = '',
    String? sessionId,
    String? traceId,
  }) async {
    final normalizedPrompt = userPrompt.trim();
    if (normalizedPrompt.isEmpty) {
      throw const EdgeLlmPlaygroundException('プロンプトを入力してください。');
    }

    final normalizedProvider =
        provider.trim().isEmpty ? 'auto' : provider.trim();
    final normalizedTier = tier?.trim();
    final normalizedFormat =
        responseFormat.trim().toLowerCase() == 'json' ? 'json' : 'text';

    final body = <String, dynamic>{
      'action': 'edge_llm.invoke',
      'user_prompt': normalizedPrompt,
      'response_format': normalizedFormat,
      if (systemPrompt.trim().isNotEmpty) 'system_prompt': systemPrompt.trim(),
      if (normalizedProvider != 'auto') 'provider': normalizedProvider,
      if (normalizedProvider == 'auto' &&
          normalizedTier != null &&
          normalizedTier.isNotEmpty)
        'tier': normalizedTier,
      if (sessionId != null && sessionId.trim().isNotEmpty)
        'session_id': sessionId.trim(),
      if (traceId != null && traceId.trim().isNotEmpty)
        'trace_id': traceId.trim(),
    };

    final normalizedContextDraft = contextDraft.trim();
    if (normalizedContextDraft.isNotEmpty) {
      body['context_data'] = _parseContextDraft(normalizedContextDraft);
    }

    final data = await _invoke(body);
    if (data['success'] != true) {
      final detail =
          (data['message'] ?? data['detail'] ?? 'LLM invocation failed')
              .toString()
              .trim();
      throw EdgeLlmPlaygroundException(
        detail.isEmpty ? 'LLM invocation failed' : detail,
      );
    }

    final text = (data['text'] ?? data['result'] ?? data['message'])
            ?.toString()
            .trim() ??
        '';
    if (text.isEmpty) {
      throw const EdgeLlmPlaygroundException('LLM response was empty');
    }

    final providerUsed =
        (data['provider'] ?? normalizedProvider).toString().trim();
    final tierUsed = data['tier']?.toString().trim();
    final model = data['model']?.toString().trim();
    final parseError = data['parse_error']?.toString().trim();
    final parsedJson = _toStringMap(data['parsed_json']);
    final source = providerUsed.isEmpty
        ? 'ai-hub edge_llm.invoke'
        : 'ai-hub edge_llm.invoke / $providerUsed';

    return EdgeLlmPlaygroundResponse(
      text: text,
      source: source,
      provider: providerUsed.isEmpty ? normalizedProvider : providerUsed,
      tier: _emptyToNull(tierUsed),
      model: _emptyToNull(model),
      responseFormat: normalizedFormat,
      parsedJson: parsedJson,
      parseError: _emptyToNull(parseError),
      observability: AiHubChatObservability.fromResponseMap(
        data,
        fallbackProvider:
            providerUsed.isEmpty ? normalizedProvider : providerUsed,
      ),
    );
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

  Object _parseContextDraft(String draft) {
    try {
      final decoded = jsonDecode(draft);
      return decoded;
    } catch (_) {
      return draft;
    }
  }

  Map<String, dynamic>? _toStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return null;
  }
}

String? _emptyToNull(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
