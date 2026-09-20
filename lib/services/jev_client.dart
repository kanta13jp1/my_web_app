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
/// /v1/systemone では型付き質問と回答を使用する。
/// 推論速度・料金・選択肢上限は接続先とモデルに依存する。
///
/// APIキー未設定やネットワーク不達、タイムアウト時は安全に null を返す
/// Fail-Open（障害時継続）設計となっている。
class JevClient {
  static const String defaultEndpoint = 'https://api.typesafe.ai/v1/systemone';
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
  bool get isLocalMode {
    final host = Uri.tryParse(endpoint)?.host;
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  bool get _usesSystemOne =>
      Uri.tryParse(endpoint)?.path.replaceFirst(RegExp(r'/+$'), '') ==
      '/v1/systemone';

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
    if (!isConfigured ||
        choices.isEmpty ||
        choices.any((choice) => choice.id.trim().isEmpty) ||
        choices.map((choice) => choice.id).toSet().length != choices.length ||
        (_usesSystemOne && choices.length < 2)) {
      return null;
    }

    final stopwatch = Stopwatch()..start();

    try {
      final payload = jsonEncode(
        _usesSystemOne
            ? <String, dynamic>{
                'model': 'jev-latest',
                'state': input,
                'questions': <String, dynamic>{
                  'classification': <String, dynamic>{
                    'type': 'choice',
                    'instructions': context != null && context.trim().isNotEmpty
                        ? context
                        : 'Classify the state using the supplied choices.',
                    'criteria': <String, String>{
                      for (final choice in choices)
                        choice.id: choice.description.isEmpty
                            ? choice.label
                            : '${choice.label}: ${choice.description}',
                    },
                  },
                },
              }
            : <String, dynamic>{
                'input': input,
                if (context != null && context.isNotEmpty) 'context': context,
                'choices':
                    choices.map((c) => c.toJson()).toList(growable: false),
              },
      );

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
          'JevClient: classification failed with status ${response.statusCode}',
        );
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      Map<String, dynamic> answer = decoded;
      if (_usesSystemOne) {
        final answers = decoded['answers'];
        final classification =
            answers is Map ? answers['classification'] : null;
        if (classification is! Map<String, dynamic> ||
            classification['type'] != 'choice') {
          return null;
        }
        answer = classification;
      }
      final dynamic rawBestChoice = answer['best_choice'];
      final bestChoiceId = _usesSystemOne
          ? answer['choice'] as String? ?? ''
          : answer['best_choice_id'] as String? ??
              (rawBestChoice is Map ? rawBestChoice['id'] as String? : null) ??
              answer['choice_id'] as String? ??
              '';
      final confidence = (answer['confidence'] as num?)?.toDouble();
      final rawScores = (_usesSystemOne
          ? answer['probabilities']
          : answer['scores'] ?? answer['probabilities']);
      final validIds = choices.map((choice) => choice.id).toSet();
      if (!validIds.contains(bestChoiceId) ||
          confidence == null ||
          !confidence.isFinite ||
          confidence < 0 ||
          confidence > 1 ||
          rawScores is! Map<String, dynamic>) {
        return null;
      }
      final scores = <String, double>{};
      for (final entry in rawScores.entries) {
        final value = entry.value;
        if (!validIds.contains(entry.key) ||
            value is! num ||
            !value.isFinite ||
            value < 0 ||
            value > 1) {
          return null;
        }
        scores[entry.key] = value.toDouble();
      }
      if (_usesSystemOne &&
          (scores.length != validIds.length ||
              (scores.values.fold<double>(0, (sum, value) => sum + value) - 1)
                      .abs() >
                  0.01)) {
        return null;
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
