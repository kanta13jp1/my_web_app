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

/// AI讖溯・繧呈署萓帙☆繧九し繝ｼ繝薙せ
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

  /// 謖・焚繝舌ャ繧ｯ繧ｪ繝輔〒繝ｪ繝医Λ繧､繧貞ｮ溯｡後☆繧九・繝ｫ繝代・繝｡繧ｽ繝・ラ
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
        // AIServiceException縺ｮ蝣ｴ蜷医√Ξ繝ｼ繝亥宛髯舌お繝ｩ繝ｼ縺九メ繧ｧ繝・け
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

      // 繧ｨ繝ｩ繝ｼ繝ｬ繧ｹ繝昴Φ繧ｹ縺ｮ繝√ぉ繝・け
      final data = response.data as Map<String, dynamic>;

      AppLogger.debug('Supabase Function Response ($functionName): $data');

      if (data['success'] != true) {
        final errorMessage = (data['error'] as String?) ?? 'AI蜃ｦ逅・↓螟ｱ謨励＠縺ｾ縺励◆';
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
      // 縲蝉ｿｮ豁｣轤ｹ縲粗.message 縺ｧ縺ｯ縺ｪ縺・$e (e.toString()) 繧剃ｽｿ逕ｨ
      AppLogger.error(
        'FunctionException ($functionName): $e, details: $details',
      );

      if (details is Map<String, dynamic>) {
        final errorMessage =
            details['error']?.toString() ?? 'Supabase Function縺九ｉ縺ｮ蠢懃ｭ斐お繝ｩ繝ｼ';
        final errorType = details['errorType'] as String?;
        final retryAfter = details['retryAfter']?.toString();

        throw AIServiceException(
          errorMessage,
          errorType: errorType,
          retryAfter: retryAfter,
        );
      }

      // 隧ｳ邏ｰ諠・ｱ縺後↑縺・ｴ蜷医ｂ繧ｫ繧ｹ繧ｿ繝萓句､悶↓螟画鋤
      throw AIServiceException('Supabase Function繧ｨ繝ｩ繝ｼ: ${e.toString()}');
    } on PostgrestException catch (e) {
      AppLogger.error('PostgrestException ($functionName): ${e.message}');
      throw AIServiceException('Postgrest error: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error in _invokeFunction ($functionName)',
        error: e,
        stackTrace: stackTrace,
      );
      // 縺昴・莉悶・繝阪ャ繝医Ρ繝ｼ繧ｯ繧ｨ繝ｩ繝ｼ縺ｪ縺ｩ
      throw AIServiceException('莠域悄縺帙〓繧ｨ繝ｩ繝ｼ: ${e.toString()}');
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
      // 蜈ｨ繝弱・繝牙､ｱ謨玲凾縺ｯ縲∝茜逕ｨ蜿ｯ閭ｽ縺ｪ繝励Ο繝舌う繝縺ｧ蜊倡匱螳溯｡後↓繝輔か繝ｼ繝ｫ繝舌ャ繧ｯ
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
縺ゅ↑縺溘・MAGI繧ｷ繧ｹ繝・Β縺ｮ縲・{profile.nodeName}縲阪〒縺吶・諡・ｽ楢ｦｳ轤ｹ: ${profile.viewpoint}
蛻・梵譁ｹ驥・ ${profile.instruction}

莉･荳九・繝ｦ繝ｼ繧ｶ繝ｼ萓晞ｼ縺ｫ蟇ｾ縺励※縲√≠縺ｪ縺溘・隕ｳ轤ｹ縺縺代〒蝗樒ｭ疲｡医ｒ菴懈・縺励※縺上□縺輔＞縲・蜈・ｾ晞ｼ縺ｮ蛻ｶ邏・ｼ亥ｽ｢蠑上・險隱槭・譁・㍼繝ｻJSON蠢・医↑縺ｩ・峨・蜴ｳ螳医＠縺ｦ縺上□縺輔＞縲・菴呵ｨ医↑蜑咲ｽｮ縺阪・荳崎ｦ√〒縺吶・
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
          viewpoint: '隲也炊繝ｻ謨ｴ蜷域ｧ',
          instruction:
              'Provide logical, evidence-based analysis with clear tradeoffs and practical recommendations.',
          provider: _MagiProvider.openai,
          defaultModel: _defaultOpenAIModel,
        ),
        _MagiNodeProfile(
          nodeName: 'BALTHASAR',
          viewpoint: '螳溷漁繝ｻ螳溯｡悟庄閭ｽ諤ｧ',
          instruction:
              'Focus on emotional nuance, empathy, and how the response will feel for the user.',
          provider: _MagiProvider.anthropic,
          defaultModel: _defaultAnthropicModel,
        ),
        _MagiNodeProfile(
          nodeName: 'CASPER',
          viewpoint: '邯咏ｶ壽ｧ繝ｻ蠢・炊',
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

**Example Input:** "譎る俣邂｡逅・｡・ (Time Management Techniques)

**Example Output:**
```json
{
  "譎る俣邂｡逅・｡・: {
    "逶ｮ讓呵ｨｭ螳・: {
      "SMART縺ｮ豕募援": {},
      "遏ｭ譛溘・髟ｷ譛溽岼讓・: {}
    },
    "繧ｿ繧ｹ繧ｯ縺ｮ蜆ｪ蜈磯・ｽ堺ｻ倥￠": {
      "繧｢繧､繧ｼ繝ｳ繝上Ρ繝ｼ繝ｻ繝槭ヨ繝ｪ繧ｯ繧ｹ": {},
      "ABCDE繝｡繧ｽ繝・ラ": {}
    },
    "繝・け繝九ャ繧ｯ": {
      "繝昴Δ繝峨・繝ｭ繝ｻ繝・け繝九ャ繧ｯ": {},
      "2蛻・Ν繝ｼ繝ｫ": {}
    },
    "繝・・繝ｫ": {
      "繧ｫ繝ｬ繝ｳ繝繝ｼ繧｢繝励Μ": {},
      "繧ｿ繧ｹ繧ｯ邂｡逅・ヤ繝ｼ繝ｫ": {}
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
  // AI繧｢繧ｷ繧ｹ繧ｿ繝ｳ繝域ｩ溯・
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

  /// 譁・ｫ螻暮幕
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

  /// 鄙ｻ險ｳ
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

  /// 繧ｿ繧､繝医Ν譁・ｭ怜・繧偵Μ繧ｹ繝医↓隗｣譫舌☆繧九・繝ｫ繝代・
  Future<Map<String, dynamic>> holdBoardMeeting({
    required String context,
    String? model,
  }) async {
    return await _retryWithBackoff(
      () async {
        final data = await _invokeFunction(
          'ai-assistant',
          <String, dynamic>{
            'action': 'hold_board_meeting',
            'content': context,
            if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
          },
        );
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
        ) // 繝翫Φ繝舌Μ繝ｳ繧ｰ繧帝勁蜴ｻ
        .where((line) => line.isNotEmpty)
        .toList();
  }

  // =========================================================================
  // AI繝｡繧ｿ繝・・繧ｿ/讀懃ｴ｢讖溯・
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

  /// AI讀懃ｴ｢
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
  // AI遘俶嶌讖溯・
  // =========================================================================

  Future<TaskRecommendations> getTaskRecommendations({
    required String userId,
    List<Map<String, dynamic>>? recentNotes,
  }) async {
    return await _retryWithBackoff(
      () async {
        // 繝弱・繝亥叙蠕怜・逅・・ Future 繧貞ｮ夂ｾｩ
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
              ); // 譏守､ｺ逧・↓ Future<List> 繧定ｿ斐☆
        } else {
          notesFuture = Future.value(recentNotes);
        }

        // 邨ｱ險域ュ蝣ｱ蜿門ｾ怜・逅・・ Future 繧貞ｮ夂ｾｩ
        final Future<Map<String, dynamic>> statsFuture = _supabase
            .from('user_stats')
            .select(
              'current_level, total_points, current_streak, longest_streak, notes_created',
            )
            .eq('user_id', userId)
            .single()
            .then(
              (response) => response,
            ); // 譏守､ｺ逧・↓ Future<Map> 繧定ｿ斐☆

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
  // AI邂｡逅・ｩ溯・
  // =========================================================================

  Future<void> generateDailyChallenges({DateTime? targetDate}) async {
    final date = targetDate ?? DateTime.now();
    // 譌･譛ｬ譎る俣縺ｮ譌･莉俶枚蟄怜・ (YYYY-MM-DD)
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

// ... (繧ｯ繝ｩ繧ｹ螳夂ｾｩ縺ｯ縺昴・縺ｾ縺ｾ)
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

/// 繧ｿ繧ｰ謠先｡医・邨先棡
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

/// AI讀懃ｴ｢縺ｮ邨先棡
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

/// AI遘俶嶌縺ｮ繧ｿ繧ｹ繧ｯ謗ｨ螂ｨ
class TaskRecommendations {
  final List<String> daily; // 莉頑律繧・ｋ縺ｹ縺阪％縺ｨ
  final List<String> weekly; // 莉企ｱ繧・ｋ縺ｹ縺阪％縺ｨ
  final List<String> monthly; // 莉頑怦繧・ｋ縺ｹ縺阪％縺ｨ
  final List<String> yearly; // 莉雁ｹｴ繧・ｋ縺ｹ縺阪％縺ｨ
  final String insights; // AI縺九ｉ縺ｮ繧､繝ｳ繧ｵ繧､繝・
  TaskRecommendations({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.yearly,
    required this.insights,
  });
}
