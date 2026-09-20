import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Jev 判定 API で分類対象となる選択肢定義。
class JevChoice {
  final String id;
  final String label;
  final String description;

  const JevChoice({
    required this.id,
    required this.label,
    this.description = '',
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      if (description.isNotEmpty) 'description': description,
    };
  }

  factory JevChoice.fromJson(Map<String, dynamic> json) {
    return JevChoice(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  @override
  String toString() => 'JevChoice(id: $id, label: $label)';
}

/// Jev 判定 API の分類結果。
class JevClassificationResult {
  final String bestChoiceId;
  final JevChoice? bestChoice;
  final double confidence;
  final Map<String, double> scores;
  final int latencyMs;
  final bool fallback;
  final String? fallbackReason;

  const JevClassificationResult({
    required this.bestChoiceId,
    this.bestChoice,
    required this.confidence,
    required this.scores,
    required this.latencyMs,
    this.fallback = false,
    this.fallbackReason,
  });

  /// 確信度が 0.96 (96%) 以上で確定採用可能
  bool get isHighConfidence => confidence >= 0.96;

  /// 確信度が 0.40 (40%) 以下のため大型LLM（Gemini/Claude等）へのフォールバック推奨
  bool get shouldFallbackToHeavyLlm => fallback || confidence <= 0.40;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'best_choice_id': bestChoiceId,
      'confidence': confidence,
      'scores': scores,
      'latency_ms': latencyMs,
      'fallback': fallback,
      if (fallbackReason != null) 'fallback_reason': fallbackReason,
    };
  }
}

/// TypeSafe AI の判定特化型モデル「Jev」のクライアント。
///
/// テキスト生成を行わず、最大256個の選択肢に対する確率分布を
/// 約500ms（極低遅延）かつ低コスト（$0.0001/回）で判定する。
///
/// APIキー未設定やネットワーク不達、タイムアウト時は安全に null を返す
/// Fail-Open（障害時継続）設計となっている。
class JevClient {
  static const String defaultEndpoint = 'https://api.typesafe.ai/v1/classify';
  static const String defaultLocalJevEndpoint =
      'http://127.0.0.1:8080/v1/systemone';
  static const Duration defaultTimeout = Duration(milliseconds: 800);

  final String? apiKey;
  final String endpoint;
  final Duration timeout;
  final http.Client _client;
  final bool _shouldCloseClient;

  JevClient({
    this.apiKey,
    String? endpoint,
    this.timeout = defaultTimeout,
    http.Client? httpClient,
  })  : endpoint = endpoint ?? _resolveEndpoint(),
        _client = httpClient ?? http.Client(),
        _shouldCloseClient = httpClient == null;

  static String _resolveEndpoint() {
    const configuredEndpoint = String.fromEnvironment('JEV_ENDPOINT');
    if (configuredEndpoint.isNotEmpty) {
      return configuredEndpoint;
    }
    const useLocalJev = bool.fromEnvironment(
      'USE_LOCAL_JEV',
      defaultValue: false,
    );
    if (useLocalJev) {
      return defaultLocalJevEndpoint;
    }
    return defaultEndpoint;
  }

  /// ローカルサーバー（LocalJev / 127.0.0.1 / localhost）を指しているかどうか
  bool get isLocalMode =>
      endpoint.contains('127.0.0.1') || endpoint.contains('localhost');

  /// API キーが設定されているか、または認証不要なローカルモードであるか
  bool get isConfigured =>
      isLocalMode || (apiKey != null && apiKey!.trim().isNotEmpty);

  /// プロンプトと選択肢を渡して分類（スコアリング）を実行する。
  ///
  /// 失敗時（キー未設定、タイムアウト、例外）は null を返し、呼び出し側で
  /// 安全に既存の LLM やルールベースへフォールバックできるようにする。
  Future<JevClassificationResult?> classify({
    required String input,
    required List<JevChoice> choices,
    String? context,
  }) async {
    if (!isConfigured || choices.isEmpty) {
      return null;
    }

    final stopwatch = Stopwatch()..start();

    try {
      final payload = jsonEncode(<String, dynamic>{
        'input': input,
        if (context != null && context.isNotEmpty) 'context': context,
        'choices': choices.map((c) => c.toJson()).toList(growable: false),
      });

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (apiKey != null && apiKey!.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer ${apiKey!.trim()}';
        headers['x-api-key'] = apiKey!.trim();
      } else if (isLocalMode) {
        headers['x-api-key'] = 'localjev';
      }

      final response = await _client
          .post(Uri.parse(endpoint), headers: headers, body: payload)
          .timeout(timeout);

      stopwatch.stop();

      if (response.statusCode != 200) {
        debugPrint(
          'JevClient: classification failed with status ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final dynamic rawBestChoice = decoded['best_choice'];
      final bestChoiceId = decoded['best_choice_id'] as String? ??
          (rawBestChoice is Map ? rawBestChoice['id'] as String? : null) ??
          decoded['choice_id'] as String? ??
          '';
      final confidence = (decoded['confidence'] as num?)?.toDouble() ?? 0.0;
      final rawScores = decoded['scores'] as Map<String, dynamic>? ??
          decoded['probabilities'] as Map<String, dynamic>? ??
          {};

      final scores = <String, double>{};
      for (final entry in rawScores.entries) {
        if (entry.value is num) {
          scores[entry.key] = (entry.value as num).toDouble();
        }
      }

      JevChoice? bestChoice;
      for (final c in choices) {
        if (c.id == bestChoiceId) {
          bestChoice = c;
          break;
        }
      }

      return JevClassificationResult(
        bestChoiceId: bestChoiceId,
        bestChoice: bestChoice,
        confidence: confidence,
        scores: scores,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint('JevClient error: $e\n$stack');
      return null;
    }
  }

  void dispose() {
    if (_shouldCloseClient) {
      _client.close();
    }
  }
}
