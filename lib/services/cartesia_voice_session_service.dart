import 'package:supabase_flutter/supabase_flutter.dart';

typedef CartesiaVoiceInvoker = Future<Map<String, dynamic>> Function(
  String action,
  Map<String, dynamic> body,
);

class CartesiaVoiceSessionConfig {
  const CartesiaVoiceSessionConfig({
    required this.accessToken,
    required this.websocketUrl,
    required this.apiVersion,
    required this.modelId,
    required this.voiceId,
    required this.maxSessionSeconds,
    this.transport = 'direct',
  });

  factory CartesiaVoiceSessionConfig.fromJson(Map<String, dynamic> json) {
    final accessToken =
        (json['websocket_access_token'] ?? json['access_token'])?.toString() ??
            '';
    return CartesiaVoiceSessionConfig(
      accessToken: accessToken,
      websocketUrl: json['websocket_url']?.toString() ?? '',
      apiVersion: json['api_version']?.toString() ?? '',
      modelId: json['model_id']?.toString() ?? '',
      voiceId: json['voice_id']?.toString() ?? '',
      maxSessionSeconds: (json['max_session_seconds'] as num?)?.toInt() ?? 0,
      transport: json['transport']?.toString() ?? 'direct',
    );
  }

  final String accessToken;
  final String websocketUrl;
  final String apiVersion;
  final String modelId;
  final String voiceId;
  final int maxSessionSeconds;
  final String transport;

  bool get usesBackendProxy => transport == 'backend_proxy';

  bool get isUsable =>
      accessToken.isNotEmpty &&
      websocketUrl.startsWith('wss://') &&
      apiVersion.isNotEmpty &&
      modelId.isNotEmpty &&
      voiceId.isNotEmpty &&
      maxSessionSeconds > 0 &&
      (transport == 'direct' || usesBackendProxy);
}

class CartesiaVoiceUnavailable implements Exception {
  const CartesiaVoiceUnavailable(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

class CartesiaVoiceTranscriptEntry {
  const CartesiaVoiceTranscriptEntry({
    required this.role,
    required this.text,
    required this.recordedAt,
  });

  final String role;
  final String text;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'role': role,
        'text': text,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      };
}

class CartesiaVoiceStyle {
  const CartesiaVoiceStyle({
    required this.emotion,
    required this.speed,
    this.addLaughter = false,
  });

  final String emotion;
  final double speed;
  final bool addLaughter;

  String prepareTranscript(String text) {
    if (!addLaughter) return text;
    return text.replaceAll('(笑)', '[laughter]').replaceAll('（笑）', '[laughter]');
  }

  static CartesiaVoiceStyle infer(String text) {
    final normalized = text.toLowerCase();
    final addLaughter = normalized.contains('(笑)') ||
        normalized.contains('（笑）') ||
        normalized.contains('haha') ||
        normalized.contains('lol');
    if (_containsAny(normalized, const <String>[
      '申し訳',
      'すみません',
      'ご不便',
      '残念',
      'sorry',
      'apolog',
    ])) {
      return CartesiaVoiceStyle(
        emotion: 'sympathetic',
        speed: 0.9,
        addLaughter: addLaughter,
      );
    }
    if (_containsAny(normalized, const <String>[
      '至急',
      'すぐに',
      '重要',
      'urgent',
      'immediately',
    ])) {
      return CartesiaVoiceStyle(
        emotion: 'determined',
        speed: 1.1,
        addLaughter: addLaughter,
      );
    }
    if (normalized.contains('?') || normalized.contains('？')) {
      return CartesiaVoiceStyle(
        emotion: 'curious',
        speed: 1,
        addLaughter: addLaughter,
      );
    }
    if (_containsAny(normalized, const <String>[
      'ありがとう',
      'よかった',
      'うれしい',
      'success',
      'great',
    ])) {
      return CartesiaVoiceStyle(
        emotion: 'content',
        speed: 1.05,
        addLaughter: addLaughter,
      );
    }
    return CartesiaVoiceStyle(
      emotion: 'calm',
      speed: 1,
      addLaughter: addLaughter,
    );
  }

  static bool _containsAny(String text, List<String> candidates) =>
      candidates.any(text.contains);
}

class CartesiaVoiceSessionService {
  CartesiaVoiceSessionService({
    SupabaseClient? supabaseClient,
    CartesiaVoiceInvoker? invoker,
  }) : _invoker = invoker ??
            ((action, body) async {
              final client = supabaseClient ?? Supabase.instance.client;
              final response = await client.functions.invoke(
                'ai-hub',
                body: <String, dynamic>{'action': action, ...body},
              );
              final data = response.data;
              if (data is Map<String, dynamic>) return data;
              if (data is Map) return Map<String, dynamic>.from(data);
              throw const FormatException('Invalid AI Hub response');
            });

  final CartesiaVoiceInvoker _invoker;

  Future<CartesiaVoiceSessionConfig> createSession() async {
    final data = await _invoker(
      'voice.cartesia_session.start',
      const <String, dynamic>{},
    );
    if (data['success'] != true || data['available'] != true) {
      throw CartesiaVoiceUnavailable(
        data['reason']?.toString() ?? 'Cartesia voice is unavailable',
      );
    }
    final config = CartesiaVoiceSessionConfig.fromJson(data);
    if (!config.isUsable) {
      throw const FormatException('Incomplete Cartesia session response');
    }
    return config;
  }

  Future<String?> finishSession({
    required String sessionId,
    required Duration duration,
    required int assistantCharacterCount,
    required List<CartesiaVoiceTranscriptEntry> transcript,
  }) async {
    if (transcript.isEmpty) return null;
    final data = await _invoker(
      'voice.cartesia_session.finish',
      <String, dynamic>{
        'session_id': sessionId,
        'duration_seconds': duration.inSeconds,
        'assistant_character_count': assistantCharacterCount,
        'transcript': transcript.map((entry) => entry.toJson()).toList(),
      },
    );
    if (data['success'] != true) {
      throw StateError(
        data['error']?.toString() ?? 'Voice transcript sync failed',
      );
    }
    return data['ticket_id']?.toString();
  }
}
