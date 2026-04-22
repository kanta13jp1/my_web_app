import 'package:supabase_flutter/supabase_flutter.dart';

typedef AiHubChatInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

class AiHubChatResponse {
  final String text;
  final String source;

  const AiHubChatResponse({
    required this.text,
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

  const AiHubChatService({
    SupabaseClient? supabase,
    AiHubChatInvoker? invoker,
  })  : _supabase = supabase,
        _invoker = invoker;

  Future<AiHubChatResponse> sendProviderChat({
    required String message,
    String provider = 'deepinfra',
  }) async {
    if (AiHubChatQuotaGuard.isCoolingDown) {
      throw const AiHubChatException('AI quota cooldown');
    }

    try {
      final data = await _invoke({
        'action': 'provider.chat',
        'provider': provider,
        'message': message,
      });
      final text = (data['text'] ?? data['result'] ?? data['message'])
          ?.toString()
          .trim();
      if (data['success'] == true && text != null && text.isNotEmpty) {
        return AiHubChatResponse(
          text: text,
          source: 'ai-hub provider.chat / $provider',
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
