import 'dart:async';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../main.dart';
import 'dart:math';

class AIServiceException implements Exception {
  final String message;
  final String? errorType;
  final String? retryAfter;

  AIServiceException(this.message, {this.errorType, this.retryAfter});

  bool get isRateLimitError => errorType == 'RATE_LIMIT';

  @override
  String toString() => message;
}

/// AI 機能を提供するサービス
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

  /// レート制限エラー時に指数バックオフで再試行するヘルパー
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
        // レート制限エラーだけ再試行する
        if (e is AIServiceException && e.isRateLimitError) {
          if (retryCount >= _maxRetries) {
            AppLogger.error(
              'Max retries reached for $operationName after rate limit',
              error: e,
              stackTrace: stackTrace,
            );
            rethrow;
          }

          final waitTimeMs = e.retryAfter != null
              ? (int.tryParse(e.retryAfter!) ?? 0) * 1000
              : delayMs + Random().nextInt(500);
          AppLogger.info(
            'Rate limit hit for $operationName. Retrying in ${waitTimeMs}ms (attempt ${retryCount + 1}/$_maxRetries)',
          );

          await Future.delayed(Duration(milliseconds: waitTimeMs));
          retryCount++;
          delayMs = (delayMs * 2).clamp(_initialRetryDelayMs, 30000);
          continue;
        }

        AppLogger.error(
          'Non-retryable error during $operationName',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> _invokeFunction(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    AppLogger.debug('Calling Supabase Function: $functionName');
    AppLogger.debug('Request Body: $body');

    try {
      final response = await _supabase.functions.invoke(
        functionName,
        body: body,
      );

      // 正常系のレスポンスをマップとして扱う
      final data = response.data as Map<String, dynamic>;

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
      final details = e.details;
      // message だけでなく details もログへ残す
      AppLogger.error(
        'FunctionException ($functionName): $e, details: $details',
      );

      if (details is Map<String, dynamic>) {
        final errorMessage =
            details['error']?.toString() ?? 'Supabase Function からの詳細エラー';
        final errorType = details['errorType'] as String?;
        final retryAfter = details['retryAfter']?.toString();

        throw AIServiceException(
          errorMessage,
          errorType: errorType,
          retryAfter: retryAfter,
        );
      }

      // details が読めない場合もカスタム例外へ包む
      throw AIServiceException('Supabase Function エラー: ${e.toString()}');
    } on PostgrestException catch (e) {
      AppLogger.error('PostgrestException ($functionName): ${e.message}');
      throw AIServiceException('Postgrest error: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error in _invokeFunction ($functionName)',
        error: e,
        stackTrace: stackTrace,
      );
      // 予期しないエラーも AIServiceException に包む
      throw AIServiceException('予期しないエラー: ${e.toString()}');
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
      // 全ノード失敗時は、利用可能なプロバイダーでベストエフォート生成へフォールバック
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
You are MAGI system node "${profile.nodeName}".
Viewpoint: ${profile.viewpoint}
Additional instruction: ${profile.instruction}

[USER_PROMPT]
$originalPrompt
''';
  }

  String _buildMagiSynthesisPrompt({
    required String originalPrompt,
    required List<_MagiOpinion> opinions,
  }) {
    final buffer = StringBuffer()
      ..writeln('You are the MAGI synthesis node.')
      ..writeln(
        'Review the opinions from the other nodes, compare tradeoffs, and merge them into one final answer.',
      )
      ..writeln(
        'Return exactly one JSON object with the merged recommendation and key reasoning.',
      )
      ..writeln('Keep the answer concise and do not use Markdown code fences.')
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
          viewpoint: '論理・分析重視',
          instruction:
              'Provide logical, evidence-based analysis with clear tradeoffs and practical recommendations.',
          provider: _MagiProvider.openai,
          defaultModel: _defaultOpenAIModel,
        ),
        _MagiNodeProfile(
          nodeName: 'BALTHASAR',
          viewpoint: '共感・人間理解重視',
          instruction:
              'Focus on emotional nuance, empathy, and how the response will feel for the user.',
          provider: _MagiProvider.anthropic,
          defaultModel: _defaultAnthropicModel,
        ),
        _MagiNodeProfile(
          nodeName: 'CASPER',
          viewpoint: '批判・リスク検討',
          instruction:
              'Look for blind spots, edge cases, and strategic risks before making a recommendation.',
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

**Example Input:** "Time Management Techniques"

**Example Output:**
```json
{
  "Time Management Techniques": {
    "Goal Setting": {
      "SMART Goals": {},
      "Long-term Vision": {}
    },
    "Task Prioritization": {
      "Eisenhower Matrix": {},
      "ABCDE Method": {}
    },
    "Scheduling": {
      "Pomodoro Technique": {},
      "2-Minute Rule": {}
    },
    "Tools": {
      "Calendar App": {},
      "Task Management Tool": {}
    }
  }
}
```

**Your Task:**

Generate a mind map for the following topic: **"{topic}"**
''';
    final prompt = promptTemplate.replaceFirst('{topic}', topic);
    return generateContent(
      model: model,
      prompt: prompt,
      useMagi: false,
    );
  }

  // =========================================================================
  // AI assistant / text transformation
  // =========================================================================

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
    String? model,
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
            if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
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

  /// Summarize note content.
  Future<String> summarizeText(
    String content, {
    String? model,
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
            if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
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

  /// Expand note content.
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

  /// Translate text.
  Future<String> translateText(
    String content, {
    String targetLanguage = 'en',
    String? model,
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
            if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
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

  /// Suggest note titles.
  Future<List<String>> suggestTitles(
    String content, {
    String? model,
  }) async {
    return await _retryWithBackoff(
      () async {
        final data = await _invokeFunction(
          'ai-assistant',
          {
            'action': 'suggest_title',
            'content': content,
            if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
          },
        );
        return _parseTitles(data['result'] as String);
      },
      operationName: 'suggestTitles',
    );
  }

  Future<String> runCustomPrompt(
    String prompt, {
    String? model,
    String? styleName,
    String? styleInstruction,
  }) async {
    return await _retryWithBackoff(
      () async {
        final data = await _invokeFunction(
          'ai-assistant',
          {
            'action': 'custom_prompt',
            'content': prompt,
            if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
            ..._stylePayload(
              styleName: styleName,
              styleInstruction: styleInstruction,
            ),
          },
        );
        return data['result'] as String;
      },
      operationName: 'runCustomPrompt',
    );
  }

  /// 緊急役員会議の構造化レスポンスを返す
  Future<Map<String, dynamic>> holdBoardMeeting({
    required String context,
    String? model,
  }) async {
    return await _retryWithBackoff(
      () async {
        Future<Map<String, dynamic>> invokeBoardMeeting({String? targetModel}) {
          return _invokeFunction(
            'ai-assistant',
            <String, dynamic>{
              'action': 'hold_board_meeting',
              'content': context,
              if (targetModel != null && targetModel.trim().isNotEmpty)
                'model': targetModel.trim(),
            },
          );
        }

        Map<String, dynamic> data;
        try {
          data = await invokeBoardMeeting(targetModel: model);
        } on AIServiceException catch (error) {
          final errorText = error.toString().toLowerCase();
          final hasExplicitModel = model != null && model.trim().isNotEmpty;
          final shouldRetryWithoutModel = hasExplicitModel &&
              (errorText.contains('does not exist') ||
                  errorText.contains('do not have access') ||
                  errorText.contains('model_not_found') ||
                  errorText.contains('unknown model'));
          if (!shouldRetryWithoutModel) {
            rethrow;
          }
          data = await invokeBoardMeeting();
        }

        final result = data['result'];
        if (result is Map<String, dynamic>) {
          return result;
        }
        if (result is Map) {
          return Map<String, dynamic>.from(result);
        }
        throw AIServiceException(
          'Board meeting response was not a JSON object.',
        );
      },
      operationName: 'holdBoardMeeting',
    );
  }

  List<String> _parseTitles(String result) {
    return result
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map(
          (line) => line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim(),
        ) // numbering like "1." is stripped
        .where((line) => line.isNotEmpty)
        .toList();
  }

  // =========================================================================
  // AI metadata / tag suggestion
  // =========================================================================

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

  /// AI 検索
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
          throw AIServiceException('AI search results were not returned.');
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
  // AI task recommendations
  // =========================================================================

  Future<TaskRecommendations> getTaskRecommendations({
    required String userId,
    List<Map<String, dynamic>>? recentNotes,
  }) async {
    return await _retryWithBackoff(
      () async {
        // ノート一覧取得の Future を先に準備
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
              ); // Future<List> に整形
        } else {
          notesFuture = Future.value(recentNotes);
        }

        // ユーザーステータス取得の Future を先に準備
        final Future<Map<String, dynamic>> statsFuture = _supabase
            .from('user_stats')
            .select(
              'current_level, total_points, current_streak, longest_streak, notes_created',
            )
            .eq('user_id', userId)
            .single()
            .then(
              (response) => response,
            ); // Future<Map> として扱う

        final results = await Future.wait<dynamic>([
          notesFuture,
          statsFuture,
        ]);

        final notesResponse = results[0];
        final statsResponse = results[1];

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
  // AI daily challenges
  // =========================================================================

  Future<void> generateDailyChallenges({DateTime? targetDate}) async {
    final date = targetDate ?? DateTime.now();
    // 日本標準時の日付文字列 (YYYY-MM-DD)
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

// Supporting types
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

/// AI 検索の結果
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

/// AI タスク推薦の結果
class TaskRecommendations {
  final List<String> daily; // 毎日やるべきこと
  final List<String> weekly; // 毎週やるべきこと
  final List<String> monthly; // 毎月やるべきこと
  final List<String> yearly; // 毎年やるべきこと
  final String insights; // AI からのインサイト
  TaskRecommendations({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.yearly,
    required this.insights,
  });
}
