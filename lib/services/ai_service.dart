import 'dart:async';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../main.dart';
import 'dart:math';

/// AI機能のカスタム例外
class AIServiceException implements Exception {
  final String message;
  final String? errorType;
  final String? retryAfter;

  AIServiceException(this.message, {this.errorType, this.retryAfter});

  bool get isRateLimitError => errorType == 'RATE_LIMIT';

  @override
  String toString() => message;
}

/// AI機能を提供するサービス
class AIService {
  final SupabaseClient _supabase;
  final String? _googleAIApiKey;
  final String? _openAIApiKey;
  final String? _anthropicApiKey;
  final http.Client _httpClient;
  static const int _maxRetries = 3;
  static const int _initialRetryDelayMs = 1000;
  static const bool _magiDefaultEnabled = true;
  static const int _magiOpinionMaxLength = 900;
  static const String _defaultOpenAIModel = 'gpt-4o-mini';
  static const String _defaultAnthropicModel = 'claude-3-5-sonnet-latest';

  AIService([
    SupabaseClient? supabaseClient,
    this._googleAIApiKey,
    String? openAIApiKey,
    String? anthropicApiKey,
    http.Client? httpClient,
  ])  : _supabase = supabaseClient ?? supabase,
        _openAIApiKey = openAIApiKey,
        _anthropicApiKey = anthropicApiKey,
        _httpClient = httpClient ?? http.Client();

  AIService.withMagiKeys({
    SupabaseClient? supabaseClient,
    String? geminiApiKey,
    String? openAIApiKey,
    String? anthropicApiKey,
    http.Client? httpClient,
  }) : this(
          supabaseClient,
          geminiApiKey,
          openAIApiKey,
          anthropicApiKey,
          httpClient,
        );

  /// 指数バックオフでリトライを実行するヘルパーメソッド
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation, {
    String operationName = 'AI operation',
  }) async {
    int retryCount = 0;
    int delayMs = _initialRetryDelayMs;

    while (true) {
      try {
        return await operation();
      } catch (e, stackTrace) {
        // AIServiceExceptionの場合、レート制限エラーかチェック
        if (e is AIServiceException && e.isRateLimitError) {
          if (retryCount >= _maxRetries) {
            AppLogger.error(
              'Max retries reached for $operationName after rate limit',
              error: e,
              stackTrace: stackTrace,
            );
            rethrow;
          }

          // retryAfterがあればそれを使用、なければ指数バックオフ
          final waitTimeMs = e.retryAfter != null
              ? (int.tryParse(e.retryAfter!) ?? 0) * 1000 // 数値としてパースした後、1000を乗算
              : delayMs + Random().nextInt(500); // ジッターを追加してサーバー負荷を軽減

          AppLogger.info(
            'Rate limit hit for $operationName. Retrying in ${waitTimeMs}ms (attempt ${retryCount + 1}/$_maxRetries)',
          );

          await Future.delayed(Duration(milliseconds: waitTimeMs));
          retryCount++;
          delayMs =
              (delayMs * 2).clamp(_initialRetryDelayMs, 30000); // 最大遅延時間を設定
          continue;
        }

        // AIServiceException 以外のエラー、またはその他のエラーはそのまま投げる
        AppLogger.error(
          'Non-retryable error during $operationName',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }
  }

  /// Supabase Functionsを呼び出すヘルパーメソッド（エラーハンドリング付き）
  Future<Map<String, dynamic>> _invokeFunction(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    // 🔍 リクエスト前のログ出力
    AppLogger.debug('Calling Supabase Function: $functionName');
    AppLogger.debug('Request Body: $body');

    try {
      final response = await _supabase.functions.invoke(
        functionName,
        body: body,
      );

      // エラーレスポンスのチェック
      final data = response.data as Map<String, dynamic>;

      // 🔍 レスポンス受信時のログ出力
      AppLogger.debug('Supabase Function Response ($functionName): $data');

      if (data['success'] != true) {
        final errorMessage = (data['error'] as String?) ?? 'AI処理に失敗しました';
        final errorType = data['errorType'] as String?;
        final retryAfter = data['retryAfter']?.toString();

        AppLogger.error(
          'Supabase Function Error ($functionName): $errorMessage',
        );

        throw AIServiceException(
          errorMessage,
          errorType: errorType,
          retryAfter: retryAfter,
        );
      }

      return data;
    } on FunctionException catch (e) {
      // FunctionExceptionの場合、詳細を解析
      final details = e.details;
      // 【修正点】e.message ではなく $e (e.toString()) を使用
      AppLogger.error(
        'FunctionException ($functionName): $e, details: $details',
      );

      if (details is Map<String, dynamic>) {
        final errorMessage =
            details['error']?.toString() ?? 'Supabase Functionからの応答エラー';
        final errorType = details['errorType'] as String?;
        final retryAfter = details['retryAfter']?.toString();

        throw AIServiceException(
          errorMessage,
          errorType: errorType,
          retryAfter: retryAfter,
        );
      }

      // 詳細情報がない場合もカスタム例外に変換
      throw AIServiceException('Supabase Functionエラー: ${e.toString()}');
    } on PostgrestException catch (e) {
      AppLogger.error('PostgrestException ($functionName): ${e.message}');
      // ポストグレストのエラー（例: 権限不足）
      throw AIServiceException('データベース操作エラー: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error in _invokeFunction ($functionName)',
        error: e,
        stackTrace: stackTrace,
      );
      // その他のネットワークエラーなど
      throw AIServiceException('予期せぬエラー: ${e.toString()}');
    }
  }

  // =========================================================================
  // Direct model methods (OpenAI / Anthropic / Gemini)
  // =========================================================================

  Future<String?> generateContent({
    required String model,
    required String prompt,
    bool useMagi = _magiDefaultEnabled,
    String? melchiorModel,
    String? balthasarModel,
    String? casperModel,
    String? synthesisModel,
  }) async {
    if (useMagi && !_hasAnyMagiProvider) {
      throw AIServiceException(
        'MAGI providers are not configured. Set at least one API key.',
      );
    }

    return _retryWithBackoff(
      () async {
        if (!useMagi) {
          final provider = _inferProviderFromModel(model);
          return _generateSingleContentByProvider(
            provider: provider,
            model: model,
            prompt: prompt,
          );
        }
        return _generateContentWithMagi(
          model: model,
          prompt: prompt,
          melchiorModel: melchiorModel,
          balthasarModel: balthasarModel,
          casperModel: casperModel,
          synthesisModel: synthesisModel,
        );
      },
      operationName: useMagi ? 'generateContent(MAGI)' : 'generateContent',
    );
  }

  bool get _hasAnyMagiProvider {
    return _isProviderConfigured(_MagiProvider.openai) ||
        _isProviderConfigured(_MagiProvider.anthropic) ||
        _isProviderConfigured(_MagiProvider.gemini);
  }

  bool _isProviderConfigured(_MagiProvider provider) {
    final key = switch (provider) {
      _MagiProvider.openai => _openAIApiKey,
      _MagiProvider.anthropic => _anthropicApiKey,
      _MagiProvider.gemini => _googleAIApiKey,
    };
    return key != null && key.trim().isNotEmpty;
  }

  _MagiProvider _inferProviderFromModel(String model) {
    final lower = model.toLowerCase();
    if (lower.contains('gpt') || lower.contains('o1') || lower.contains('o3')) {
      return _MagiProvider.openai;
    }
    if (lower.contains('claude') || lower.contains('anthropic')) {
      return _MagiProvider.anthropic;
    }
    return _MagiProvider.gemini;
  }

  Future<String?> _generateSingleContentByProvider({
    required _MagiProvider provider,
    required String model,
    required String prompt,
  }) async {
    return switch (provider) {
      _MagiProvider.openai => _generateSingleOpenAIContent(
          model: model,
          prompt: prompt,
        ),
      _MagiProvider.anthropic => _generateSingleAnthropicContent(
          model: model,
          prompt: prompt,
        ),
      _MagiProvider.gemini => _generateSingleGeminiContent(
          model: model,
          prompt: prompt,
        ),
    };
  }

  Future<String?> _generateSingleGeminiContent({
    required String model,
    required String prompt,
  }) async {
    final apiKey = _googleAIApiKey;
    if (apiKey == null) {
      throw AIServiceException('Google AI API key is not configured.');
    }
    try {
      final genModel = GenerativeModel(model: model, apiKey: apiKey);
      final content = [Content.text(prompt)];
      final response = await genModel.generateContent(content);
      return response.text;
    } catch (e) {
      throw _mapAiModelError(e);
    }
  }

  Future<String?> _generateSingleOpenAIContent({
    required String model,
    required String prompt,
  }) async {
    final apiKey = _openAIApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw AIServiceException('OpenAI API key is not configured.');
    }
    try {
      final response = await _httpClient.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: <String, String>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'model': model,
          'messages': <Map<String, String>>[
            <String, String>{'role': 'user', 'content': prompt},
          ],
        }),
      );
      if (response.statusCode >= 400) {
        throw _mapHttpApiError('OpenAI', response);
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        return null;
      }
      final firstChoice = choices.first;
      if (firstChoice is! Map<String, dynamic>) {
        return null;
      }
      final message = firstChoice['message'];
      if (message is! Map<String, dynamic>) {
        return null;
      }
      final content = message['content'];
      if (content is String) {
        return content;
      }
      if (content is List) {
        final text = content
            .whereType<Map<String, dynamic>>()
            .map((part) => part['text']?.toString() ?? '')
            .where((part) => part.trim().isNotEmpty)
            .join('\n')
            .trim();
        return text.isEmpty ? null : text;
      }
      return null;
    } catch (e) {
      if (e is AIServiceException) rethrow;
      throw _mapAiModelError(e);
    }
  }

  Future<String?> _generateSingleAnthropicContent({
    required String model,
    required String prompt,
  }) async {
    final apiKey = _anthropicApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw AIServiceException('Anthropic API key is not configured.');
    }
    try {
      final response = await _httpClient.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode(<String, dynamic>{
          'model': model,
          'max_tokens': 1024,
          'messages': <Map<String, String>>[
            <String, String>{'role': 'user', 'content': prompt},
          ],
        }),
      );
      if (response.statusCode >= 400) {
        throw _mapHttpApiError('Anthropic', response);
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final content = decoded['content'];
      if (content is! List || content.isEmpty) {
        return null;
      }
      final text = content
          .whereType<Map<String, dynamic>>()
          .map((part) => part['text']?.toString() ?? '')
          .where((part) => part.trim().isNotEmpty)
          .join('\n')
          .trim();
      return text.isEmpty ? null : text;
    } catch (e) {
      if (e is AIServiceException) rethrow;
      throw _mapAiModelError(e);
    }
  }

  AIServiceException _mapHttpApiError(String provider, http.Response response) {
    final retryAfter = response.headers['retry-after'];
    final detail = _extractApiErrorMessage(response.body);
    final status = response.statusCode;
    if (status == 429) {
      return AIServiceException(
        '$provider API rate limit exceeded.',
        errorType: 'RATE_LIMIT',
        retryAfter: retryAfter,
      );
    }
    return AIServiceException(
      '$provider API error ($status): $detail',
    );
  }

  String _extractApiErrorMessage(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error;
        }
        if (error is Map<String, dynamic>) {
          final message = error['message']?.toString();
          if (message != null && message.trim().isNotEmpty) {
            return message;
          }
          final type = error['type']?.toString();
          if (type != null && type.trim().isNotEmpty) {
            return type;
          }
        }
        final message = decoded['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    final trimmed = body.trim();
    return trimmed.isEmpty ? 'Unknown error' : trimmed;
  }

  Future<String?> _generateContentWithMagi({
    required String model,
    required String prompt,
    String? melchiorModel,
    String? balthasarModel,
    String? casperModel,
    String? synthesisModel,
  }) async {
    final profiles = _magiProfiles;
    final results = await Future.wait<_MagiOpinion?>(
      profiles.map((profile) {
        final nodeModel = _resolveMagiNodeModel(
          profile: profile,
          fallbackGeminiModel: model,
          melchiorModel: melchiorModel,
          balthasarModel: balthasarModel,
          casperModel: casperModel,
        );
        return _runMagiNode(
          model: nodeModel,
          prompt: prompt,
          profile: profile,
        );
      }),
    );

    final validOpinions = results.whereType<_MagiOpinion>().toList();
    if (validOpinions.isEmpty) {
      // 全ノード失敗時は、利用可能なプロバイダで単発実行にフォールバック
      return _generateBestEffortSingle(
        fallbackGeminiModel: model,
        prompt: prompt,
        melchiorModel: melchiorModel,
        balthasarModel: balthasarModel,
        casperModel: casperModel,
        synthesisModel: synthesisModel,
      );
    }

    if (validOpinions.length == 1) {
      return validOpinions.first.content;
    }

    final synthesisPrompt = _buildMagiSynthesisPrompt(
      originalPrompt: prompt,
      opinions: validOpinions,
    );
    return _synthesizeMagiOpinions(
      fallbackGeminiModel: model,
      prompt: synthesisPrompt,
      opinions: validOpinions,
      melchiorModel: melchiorModel,
      balthasarModel: balthasarModel,
      casperModel: casperModel,
      synthesisModel: synthesisModel,
    );
  }

  String _resolveMagiNodeModel({
    required _MagiNodeProfile profile,
    required String fallbackGeminiModel,
    String? melchiorModel,
    String? balthasarModel,
    String? casperModel,
  }) {
    return switch (profile.provider) {
      _MagiProvider.openai =>
        (melchiorModel != null && melchiorModel.trim().isNotEmpty)
            ? melchiorModel.trim()
            : profile.defaultModel,
      _MagiProvider.anthropic =>
        (balthasarModel != null && balthasarModel.trim().isNotEmpty)
            ? balthasarModel.trim()
            : profile.defaultModel,
      _MagiProvider.gemini =>
        (casperModel != null && casperModel.trim().isNotEmpty)
            ? casperModel.trim()
            : fallbackGeminiModel,
    };
  }

  List<_MagiSynthesisPlan> _buildMagiSynthesisPlans({
    required String fallbackGeminiModel,
    String? melchiorModel,
    String? balthasarModel,
    String? casperModel,
    String? synthesisModel,
  }) {
    final plans = <_MagiSynthesisPlan>[];
    final addedProviders = <_MagiProvider>{};

    void addPlan(_MagiProvider provider, String model) {
      if (addedProviders.contains(provider) ||
          !_isProviderConfigured(provider)) {
        return;
      }
      plans.add(_MagiSynthesisPlan(provider: provider, model: model));
      addedProviders.add(provider);
    }

    if (synthesisModel != null && synthesisModel.trim().isNotEmpty) {
      final synthesisModelValue = synthesisModel.trim();
      addPlan(
        _inferProviderFromModel(synthesisModelValue),
        synthesisModelValue,
      );
    }

    addPlan(
      _MagiProvider.gemini,
      (casperModel != null && casperModel.trim().isNotEmpty)
          ? casperModel.trim()
          : fallbackGeminiModel,
    );
    addPlan(
      _MagiProvider.openai,
      (melchiorModel != null && melchiorModel.trim().isNotEmpty)
          ? melchiorModel.trim()
          : _defaultOpenAIModel,
    );
    addPlan(
      _MagiProvider.anthropic,
      (balthasarModel != null && balthasarModel.trim().isNotEmpty)
          ? balthasarModel.trim()
          : _defaultAnthropicModel,
    );

    return plans;
  }

  Future<String?> _generateBestEffortSingle({
    required String fallbackGeminiModel,
    required String prompt,
    String? melchiorModel,
    String? balthasarModel,
    String? casperModel,
    String? synthesisModel,
  }) async {
    final plans = _buildMagiSynthesisPlans(
      fallbackGeminiModel: fallbackGeminiModel,
      melchiorModel: melchiorModel,
      balthasarModel: balthasarModel,
      casperModel: casperModel,
      synthesisModel: synthesisModel,
    );
    for (final plan in plans) {
      try {
        final response = await _generateSingleContentByProvider(
          provider: plan.provider,
          model: plan.model,
          prompt: prompt,
        );
        final normalized = _normalizeMagiOpinion(response);
        if (normalized != null) {
          return normalized;
        }
      } catch (e, stackTrace) {
        AppLogger.warning(
          'MAGI fallback single failed: ${plan.provider.name}',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    return null;
  }

  Future<String?> _synthesizeMagiOpinions({
    required String fallbackGeminiModel,
    required String prompt,
    required List<_MagiOpinion> opinions,
    String? melchiorModel,
    String? balthasarModel,
    String? casperModel,
    String? synthesisModel,
  }) async {
    final plans = _buildMagiSynthesisPlans(
      fallbackGeminiModel: fallbackGeminiModel,
      melchiorModel: melchiorModel,
      balthasarModel: balthasarModel,
      casperModel: casperModel,
      synthesisModel: synthesisModel,
    );
    for (final plan in plans) {
      try {
        final response = await _generateSingleContentByProvider(
          provider: plan.provider,
          model: plan.model,
          prompt: prompt,
        );
        final normalized = _normalizeMagiOpinion(response);
        if (normalized != null) {
          return normalized;
        }
      } catch (e, stackTrace) {
        AppLogger.warning(
          'MAGI synthesis failed: ${plan.provider.name}',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    // 統合が全滅した場合は、先頭意見を返して無回答化を防ぐ
    return opinions.first.content;
  }

  Future<_MagiOpinion?> _runMagiNode({
    required String model,
    required String prompt,
    required _MagiNodeProfile profile,
  }) async {
    if (!_isProviderConfigured(profile.provider)) {
      AppLogger.info('MAGI node skipped: ${profile.nodeName} (no API key)');
      return null;
    }

    final nodePrompt = _buildMagiNodePrompt(
      originalPrompt: prompt,
      profile: profile,
    );
    try {
      final text = await _generateSingleContentByProvider(
        provider: profile.provider,
        model: model,
        prompt: nodePrompt,
      );
      final normalized = _normalizeMagiOpinion(text);
      if (normalized == null) {
        return null;
      }
      return _MagiOpinion(
        nodeName: profile.nodeName,
        viewpoint: profile.viewpoint,
        content: normalized,
      );
    } catch (e, stackTrace) {
      // 単一ノード失敗は全体失敗にせず、残ノードで継続
      AppLogger.error(
        'MAGI node failed: ${profile.nodeName}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  String _buildMagiNodePrompt({
    required String originalPrompt,
    required _MagiNodeProfile profile,
  }) {
    return '''
あなたはMAGIシステムの「${profile.nodeName}」です。
担当観点: ${profile.viewpoint}
分析方針: ${profile.instruction}

以下のユーザー依頼に対して、あなたの観点だけで回答案を作成してください。
元依頼の制約（形式・言語・文量・JSON必須など）は厳守してください。
余計な前置きは不要です。

[USER_PROMPT]
$originalPrompt
''';
  }

  String _buildMagiSynthesisPrompt({
    required String originalPrompt,
    required List<_MagiOpinion> opinions,
  }) {
    final buffer = StringBuffer()
      ..writeln('あなたはMAGI統合モジュールです。')
      ..writeln('下記3系統の回答案を統合し、最終回答を1つだけ返してください。')
      ..writeln('最重要: 元依頼の制約（形式・JSON・1文制約など）を厳守。')
      ..writeln('余計な説明、前置き、Markdown装飾は不要です。')
      ..writeln()
      ..writeln('[ORIGINAL_PROMPT]')
      ..writeln(originalPrompt)
      ..writeln();

    for (final opinion in opinions) {
      buffer
        ..writeln('[${opinion.nodeName} / ${opinion.viewpoint}]')
        ..writeln(opinion.content)
        ..writeln();
    }
    return buffer.toString();
  }

  String? _normalizeMagiOpinion(String? text) {
    final normalized = text?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (normalized.length <= _magiOpinionMaxLength) {
      return normalized;
    }
    return normalized.substring(0, _magiOpinionMaxLength);
  }

  AIServiceException _mapAiModelError(Object error) {
    final message = error.toString();
    final lower = message.toLowerCase();
    if (lower.contains('rate') ||
        lower.contains('429') ||
        lower.contains('too many requests') ||
        lower.contains('quota')) {
      return AIServiceException(
        'AI rate limit exceeded.',
        errorType: 'RATE_LIMIT',
      );
    }
    return AIServiceException(message);
  }

  List<_MagiNodeProfile> get _magiProfiles => const <_MagiNodeProfile>[
        _MagiNodeProfile(
          nodeName: 'MELCHIOR',
          viewpoint: '論理・整合性',
          instruction: '要件を分解し、矛盾を排除し、結論を短く明確にする。',
          provider: _MagiProvider.openai,
          defaultModel: _defaultOpenAIModel,
        ),
        _MagiNodeProfile(
          nodeName: 'BALTHASAR',
          viewpoint: '実務・実行可能性',
          instruction: 'すぐ実行できる手順、制約、リスクを重視する。',
          provider: _MagiProvider.anthropic,
          defaultModel: _defaultAnthropicModel,
        ),
        _MagiNodeProfile(
          nodeName: 'CASPER',
          viewpoint: '継続性・心理',
          instruction: '受け手が動ける表現、負荷の低い実践性、継続性を最適化する。',
          provider: _MagiProvider.gemini,
          defaultModel: '',
        ),
      ];

  Future<String?> generateMindMap({
    required String model,
    required String topic,
  }) {
    const promptTemplate = '''
You are an expert mind map generator. Your task is to take a central topic and generate a hierarchical structure of related ideas, concepts, and sub-topics. The output must be a valid JSON object.

The JSON object should have a single root key representing the central topic. The value should be an object where each key is a child idea. This can be nested recursively for sub-ideas.

**Example Input:** "時間管理術" (Time Management Techniques)

**Example Output:**
```json
{
  "時間管理術": {
    "目標設定": {
      "SMARTの法則": {},
      "短期・長期目標": {}
    },
    "タスクの優先順位付け": {
      "アイゼンハワー・マトリクス": {},
      "ABCDEメソッド": {}
    },
    "テクニック": {
      "ポモドーロ・テクニック": {},
      "2分ルール": {}
    },
    "ツール": {
      "カレンダーアプリ": {},
      "タスク管理ツール": {}
    }
  }
}
```

**Your Task:**

Generate a mind map for the following topic: **"{topic}"**
''';
    final prompt = promptTemplate.replaceFirst('{topic}', topic);
    return generateContent(model: model, prompt: prompt);
  }

  // =========================================================================
  // AIアシスタント機能
  // =========================================================================

  /// 文章改善
  Map<String, dynamic> _stylePayload({
    String? styleName,
    String? styleInstruction,
  }) {
    final normalizedInstruction = styleInstruction?.trim();
    if (normalizedInstruction == null || normalizedInstruction.isEmpty) {
      return const <String, dynamic>{};
    }
    final normalizedName = styleName?.trim();
    return <String, dynamic>{
      'styleName': (normalizedName == null || normalizedName.isEmpty)
          ? 'custom'
          : normalizedName,
      'styleInstruction': normalizedInstruction,
    };
  }

  Future<String> improveText(
    String content, {
    String? styleName,
    String? styleInstruction,
  }) async {
    return await _retryWithBackoff(
      () async {
        final data = await _invokeFunction(
          'ai-assistant',
          {
            'action': 'improve',
            'content': content,
            ..._stylePayload(
              styleName: styleName,
              styleInstruction: styleInstruction,
            ),
          },
        );
        return data['result'] as String;
      },
      operationName: 'improveText',
    );
  }

  /// 要約生成
  Future<String> summarizeText(
    String content, {
    String? styleName,
    String? styleInstruction,
  }) async {
    return await _retryWithBackoff(
      () async {
        final data = await _invokeFunction(
          'ai-assistant',
          {
            'action': 'summarize',
            'content': content,
            ..._stylePayload(
              styleName: styleName,
              styleInstruction: styleInstruction,
            ),
          },
        );
        return data['result'] as String;
      },
      operationName: 'summarizeText',
    );
  }

  /// 文章展開
  Future<String> expandText(String content) async {
    return await _retryWithBackoff(
      () async {
        final data = await _invokeFunction(
          'ai-assistant',
          {
            'action': 'expand',
            'content': content,
          },
        );
        return data['result'] as String;
      },
      operationName: 'expandText',
    );
  }

  /// 翻訳
  Future<String> translateText(
    String content, {
    String targetLanguage = 'en',
    String? styleName,
    String? styleInstruction,
  }) async {
    return await _retryWithBackoff(
      () async {
        final data = await _invokeFunction(
          'ai-assistant',
          {
            'action': 'translate',
            'content': content,
            'targetLanguage': targetLanguage,
            ..._stylePayload(
              styleName: styleName,
              styleInstruction: styleInstruction,
            ),
          },
        );
        return data['result'] as String;
      },
      operationName: 'translateText',
    );
  }

  /// タイトル提案
  Future<List<String>> suggestTitles(String content) async {
    return await _retryWithBackoff(
      () async {
        final data = await _invokeFunction(
          'ai-assistant',
          {
            'action': 'suggest_title',
            'content': content,
          },
        );
        return _parseTitles(data['result'] as String);
      },
      operationName: 'suggestTitles',
    );
  }

  /// タイトル文字列をリストに解析するヘルパー
  List<String> _parseTitles(String result) {
    return result
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map(
          (line) => line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim(),
        ) // ナンバリングを除去
        .where((line) => line.isNotEmpty)
        .toList();
  }

  // =========================================================================
  // AIメタデータ/検索機能
  // =========================================================================

  /// タグとカテゴリの自動提案
  Future<TagSuggestion> suggestTags({
    required String content,
    String? title,
    List<String>? existingCategories,
  }) async {
    return await _retryWithBackoff(
      () async {
        final responseData = await _invokeFunction(
          'ai-suggest-tags',
          {
            'content': content,
            'title': title,
            'existingCategories': existingCategories,
          },
        );

        final suggestions = responseData['suggestions'] as Map<String, dynamic>;

        return TagSuggestion(
          tags: List<String>.from(suggestions['tags'] as List<dynamic>? ?? []),
          category: suggestions['category'] as String? ?? '',
          reason: suggestions['reason'] as String? ?? '',
        );
      },
      operationName: 'suggestTags',
    );
  }

  /// AI検索
  Future<AISearchResult> searchNotes({
    required String query,
    int limit = 20,
  }) async {
    return await _retryWithBackoff(
      () async {
        final responseData = await _invokeFunction(
          'ai-search',
          {
            'query': query,
            'limit': limit,
          },
        );

        if (responseData['results'] == null) {
          throw AIServiceException('AI検索結果が不正です。');
        }

        return AISearchResult(
          results: List<Map<String, dynamic>>.from(
            responseData['results'] as List<dynamic>,
          ),
          totalResults: responseData['totalResults'] as int? ?? 0,
          explanation: responseData['explanation'] as String? ?? '',
        );
      },
      operationName: 'searchNotes',
    );
  }

  /// ユーザーのAI使用統計を取得
  Future<AIUsageStats> getUsageStats(String userId) async {
    try {
      final response = await _supabase
          .from('ai_usage_log')
          .select('action, total_tokens, cost_estimate, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);

      int totalUsage = 0;
      double totalCost = 0.0;
      final Map<String, int> usageByAction = {};

      for (var record in response) {
        totalUsage += (record['total_tokens'] as int?) ?? 0;
        totalCost += (record['cost_estimate'] as num?)?.toDouble() ?? 0.0;

        final action = record['action'] as String;
        usageByAction[action] = (usageByAction[action] ?? 0) + 1;
      }

      return AIUsageStats(
        totalUsage: totalUsage,
        totalCost: totalCost,
        usageByAction: usageByAction,
        recentUsageCount: response.length,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error getting AI usage stats',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // =========================================================================
  // AI秘書機能
  // =========================================================================

  /// AI秘書機能：タスク推奨を取得
  Future<TaskRecommendations> getTaskRecommendations({
    required String userId,
    List<Map<String, dynamic>>? recentNotes,
  }) async {
    return await _retryWithBackoff(
      () async {
        // ノート取得処理の Future を定義
        final Future<List<Map<String, dynamic>>> notesFuture;

        if (recentNotes == null || recentNotes.isEmpty) {
          notesFuture = _supabase
              .from('notes')
              .select('id, title, content, created_at, updated_at')
              .eq('user_id', userId)
              .eq('is_archived', false)
              .order('updated_at', ascending: false)
              .limit(20)
              .then(
                (response) => List<Map<String, dynamic>>.from(
                  response,
                ),
              ); // 明示的に Future<List> を返す
        } else {
          notesFuture = Future.value(recentNotes);
        }

        // 統計情報取得処理の Future を定義
        final Future<Map<String, dynamic>> statsFuture = _supabase
            .from('user_stats')
            .select(
              'current_level, total_points, current_streak, longest_streak, notes_created',
            )
            .eq('user_id', userId)
            .single()
            .then(
              (response) => response,
            ); // 明示的に Future<Map> を返す

        // Future.wait で並列実行
        final results = await Future.wait<dynamic>([
          notesFuture,
          statsFuture,
        ]);

        final notesResponse = results[0];
        final statsResponse = results[1];

        // 🔍 パラメータのログ出力
        AppLogger.debug(
          'getTaskRecommendations - notes count: ${(notesResponse as List).length}',
        );
        AppLogger.debug('getTaskRecommendations - stats: $statsResponse');

        final notes = List<Map<String, dynamic>>.from(notesResponse);

        final data = await _invokeFunction(
          'ai-assistant',
          {
            'action': 'task_recommendations',
            'userId': userId,
            'recentNotes': notes,
            'userStats': statsResponse,
          },
        );

        final result = data['result'] as Map<String, dynamic>;

        return TaskRecommendations(
          daily: List<String>.from(result['daily'] ?? []),
          weekly: List<String>.from(result['weekly'] ?? []),
          monthly: List<String>.from(result['monthly'] ?? []),
          yearly: List<String>.from(result['yearly'] ?? []),
          insights: result['insights'] as String? ?? '',
        );
      },
      operationName: 'getTaskRecommendations',
    );
  }

  // =========================================================================
  // AI管理機能
  // =========================================================================

  /// デイリーチャレンジの生成（AIおまかせ）
  Future<void> generateDailyChallenges({DateTime? targetDate}) async {
    final date = targetDate ?? DateTime.now();
    // 日本時間の日付文字列 (YYYY-MM-DD)
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    await _retryWithBackoff(
      () async {
        await _invokeFunction(
          'generate-daily-challenges',
          {
            'date': dateStr,
          },
        );
        return;
      },
      operationName: 'generateDailyChallenges',
    );

    AppLogger.info('Daily challenges generated successfully for $dateStr');
  }
}

// ... (クラス定義はそのまま)
enum _MagiProvider {
  openai,
  anthropic,
  gemini,
}

class _MagiSynthesisPlan {
  final _MagiProvider provider;
  final String model;

  const _MagiSynthesisPlan({
    required this.provider,
    required this.model,
  });
}

class _MagiNodeProfile {
  final String nodeName;
  final String viewpoint;
  final String instruction;
  final _MagiProvider provider;
  final String defaultModel;

  const _MagiNodeProfile({
    required this.nodeName,
    required this.viewpoint,
    required this.instruction,
    required this.provider,
    required this.defaultModel,
  });
}

class _MagiOpinion {
  final String nodeName;
  final String viewpoint;
  final String content;

  const _MagiOpinion({
    required this.nodeName,
    required this.viewpoint,
    required this.content,
  });
}

/// タグ提案の結果
class TagSuggestion {
  final List<String> tags;
  final String category;
  final String reason;

  TagSuggestion({
    required this.tags,
    required this.category,
    required this.reason,
  });
}

/// AI検索の結果
class AISearchResult {
  final List<Map<String, dynamic>> results;
  final int totalResults;
  final String explanation;

  AISearchResult({
    required this.results,
    required this.totalResults,
    required this.explanation,
  });
}

/// AI使用統計
class AIUsageStats {
  final int totalUsage;
  final double totalCost;
  final Map<String, int> usageByAction;
  final int recentUsageCount;

  AIUsageStats({
    required this.totalUsage,
    required this.totalCost,
    required this.usageByAction,
    required this.recentUsageCount,
  });
}

/// AI秘書のタスク推奨
class TaskRecommendations {
  final List<String> daily; // 今日やるべきこと
  final List<String> weekly; // 今週やるべきこと
  final List<String> monthly; // 今月やるべきこと
  final List<String> yearly; // 今年やるべきこと
  final String insights; // AIからのインサイト

  TaskRecommendations({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.yearly,
    required this.insights,
  });
}
