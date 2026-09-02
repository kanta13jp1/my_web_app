import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import 'supabase_client_provider.dart';
import 'dart:math';
import 'magi_system_settings_service.dart';
import 'offline_secure_mode_settings_service.dart';

class AIServiceException implements Exception {
  final String message;
  final String? errorType;
  final String? retryAfter;
  final String? code;
  final int? statusCode;
  final String? upgradeUrl;

  AIServiceException(
    this.message, {
    this.errorType,
    this.retryAfter,
    this.code,
    this.statusCode,
    this.upgradeUrl,
  });

  factory AIServiceException.fromFunctionPayload(
    Map<String, dynamic> payload, {
    String fallbackMessage = 'AI処理に失敗しました',
  }) {
    final statusCode = _payloadStatusCode(payload);
    final code = payload['code']?.toString();
    final message = _payloadMessage(payload, fallbackMessage);
    final upgradeUrl = _payloadString(payload, 'upgrade_url') ??
        _payloadString(payload, 'upgradeUrl');
    if (statusCode == 402 && code == 'free_limit_reached') {
      return AIServiceException(
        message,
        errorType: 'FREE_LIMIT_REACHED',
        code: code,
        statusCode: statusCode,
        upgradeUrl: upgradeUrl,
      );
    }

    return AIServiceException(
      message,
      errorType: payload['errorType'] as String?,
      retryAfter: payload['retryAfter']?.toString(),
      code: code,
      statusCode: statusCode,
      upgradeUrl: upgradeUrl,
    );
  }

  bool get isRateLimitError => errorType == 'RATE_LIMIT';
  bool get isFreeLimitReached =>
      statusCode == 402 && code == 'free_limit_reached';

  @override
  String toString() => message;
}

String? _payloadString(Map<String, dynamic> payload, String key) {
  final value = payload[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

int? _payloadStatusCode(Map<String, dynamic> payload) {
  final value =
      payload['status'] ?? payload['statusCode'] ?? payload['http_status'];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString());
}

String _payloadMessage(Map<String, dynamic> payload, String fallbackMessage) {
  return _payloadString(payload, 'message') ??
      _payloadString(payload, 'error') ??
      _payloadString(payload, 'detail') ??
      fallbackMessage;
}

/// グローバル 429 サーキットブレイカー
///
/// 上流 API (OpenAI/Anthropic/Gemini) が quota 枯渇すると ai-assistant EF が
/// 連続的に 429 を返す。Flutter 側で複数コンポーネントが同時呼び出しすると
/// リクエストが雪崩式に増え UX が崩壊する。
///
/// 最後の 429 発生時刻を記録し、cooldown 中の呼び出しを即座に例外で弾くことで
/// API への無駄な再試行を防ぐ。
class AiQuotaGuard {
  static DateTime? _lastQuotaErrorAt;
  static const Duration _cooldown = Duration(seconds: 60);

  /// 429 を検知した際に呼び出す
  static void markQuotaExceeded() {
    _lastQuotaErrorAt = DateTime.now();
    AppLogger.warning(
      'AiQuotaGuard: quota exceeded — cooldown ${_cooldown.inSeconds}s',
    );
  }

  /// cooldown 中なら true
  static bool get isCoolingDown {
    final ts = _lastQuotaErrorAt;
    if (ts == null) return false;
    return DateTime.now().difference(ts) < _cooldown;
  }

  /// cooldown 残り秒数 (UI 表示用)
  static int get remainingSeconds {
    final ts = _lastQuotaErrorAt;
    if (ts == null) return 0;
    final elapsed = DateTime.now().difference(ts);
    final remaining = _cooldown - elapsed;
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  /// テスト用リセット
  static void reset() {
    _lastQuotaErrorAt = null;
  }
}

/// AI 機能を提供するサービス
class AIService {
  final SupabaseClient _supabase;
  final MagiSystemSettingsService _magiSettingsService;
  final OfflineSecureModeSettingsService _offlineSettingsService;
  static const int _maxRetries = 3;
  static const int _initialRetryDelayMs = 1000;
  static const int _magiOpinionMaxLength = 900;
  static const String _defaultOpenAIModel =
      MagiSystemSettings.defaultMelchiorModel;
  static const String _defaultAnthropicModel =
      MagiSystemSettings.defaultBalthasarModel;
  static const String _defaultGeminiModel =
      MagiSystemSettings.defaultCasperModel;
  static const String _defaultDeepSeekModel = 'deepseek-chat';

  AIService([
    SupabaseClient? supabaseClient,
    String? _legacyGoogleAiApiKey,
    String? _legacyOpenAiApiKey,
    String? _legacyAnthropicApiKey,
    String? _legacyDeepSeekApiKey,
    Object? _legacyHttpClient,
    MagiSystemSettingsService magiSettingsService =
        const MagiSystemSettingsService(),
    OfflineSecureModeSettingsService offlineSettingsService =
        const OfflineSecureModeSettingsService(),
  ])  : _supabase = supabaseClient ?? supabase,
        _magiSettingsService = magiSettingsService,
        _offlineSettingsService = offlineSettingsService;

  AIService.withMagiKeys({
    SupabaseClient? supabaseClient,
    String? geminiApiKey,
    String? openAIApiKey,
    String? anthropicApiKey,
    String? deepSeekApiKey,
    Object? httpClient,
    MagiSystemSettingsService magiSettingsService =
        const MagiSystemSettingsService(),
    OfflineSecureModeSettingsService offlineSettingsService =
        const OfflineSecureModeSettingsService(),
  }) : this(
          supabaseClient,
          geminiApiKey,
          openAIApiKey,
          anthropicApiKey,
          deepSeekApiKey,
          httpClient,
          magiSettingsService,
          offlineSettingsService,
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

    // サーキットブレイカー: 直近 429 検知中はリクエストを送らず即座に例外
    if (AiQuotaGuard.isCoolingDown) {
      final sec = AiQuotaGuard.remainingSeconds;
      throw AIServiceException(
        'AI 呼び出しを一時停止しています (quota 回復待ち・残り $sec 秒)',
        errorType: 'RATE_LIMIT',
        retryAfter: sec.toString(),
      );
    }

    try {
      final requestBody = await _withOfflinePolicy(functionName, body);
      final response = await _supabase.functions.invoke(
        functionName,
        body: requestBody,
      );

      // 正常系のレスポンスをマップとして扱う
      // Supabase SDK は Content-Type: application/json がないと
      // String を返す場合があるため、安全に変換する
      final dynamic rawData = response.data;
      final Map<String, dynamic> data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else if (rawData is String) {
        try {
          final parsed = jsonDecode(rawData);
          data = parsed is Map<String, dynamic>
              ? parsed
              : Map<String, dynamic>.from(parsed as Map);
        } catch (_) {
          throw AIServiceException('AI応答の解析に失敗しました: 不正なレスポンス形式');
        }
      } else {
        throw AIServiceException(
          'AI応答の解析に失敗しました: 予期しない型 ${rawData.runtimeType}',
        );
      }

      AppLogger.debug('Supabase Function Response ($functionName): $data');

      if (data['success'] != true) {
        final exception = AIServiceException.fromFunctionPayload(data);

        AppLogger.error(
          'Supabase Function Error ($functionName): ${exception.message}',
        );

        throw exception;
      }

      return data;
    } on FunctionException catch (e) {
      final details = e.details;
      // message だけでなく details もログへ残す
      AppLogger.error(
        'FunctionException ($functionName): $e, details: $details',
      );

      if (details is Map<String, dynamic>) {
        final exception = AIServiceException.fromFunctionPayload(
          details,
          fallbackMessage: 'Supabase Function からの詳細エラー',
        );

        // 429 / quota / rate limit を検知して circuit breaker を作動
        final isQuota = exception.errorType == 'RATE_LIMIT' ||
            RegExp(r'quota|rate.?limit|429', caseSensitive: false)
                .hasMatch(exception.message);
        if (isQuota) {
          AiQuotaGuard.markQuotaExceeded();
        }

        if (isQuota && !exception.isRateLimitError) {
          throw AIServiceException(
            exception.message,
            errorType: 'RATE_LIMIT',
            retryAfter: exception.retryAfter,
            code: exception.code,
            statusCode: exception.statusCode,
            upgradeUrl: exception.upgradeUrl,
          );
        }

        throw exception;
      }

      // details が読めない場合も 429 メッセージなら guard 作動
      final msgStr = e.toString();
      if (RegExp(r'429|quota|rate.?limit', caseSensitive: false)
          .hasMatch(msgStr)) {
        AiQuotaGuard.markQuotaExceeded();
        throw AIServiceException(
          'AI API quota を超過しました (上流プロバイダー側で課金要確認)',
          errorType: 'RATE_LIMIT',
        );
      }
      throw AIServiceException('Supabase Function エラー: $msgStr');
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

  Future<Map<String, dynamic>> _withOfflinePolicy(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    if (functionName != 'ai-hub') return body;
    final action = body['action']?.toString().trim();
    if (action != 'provider.generate' &&
        action != 'provider.chat' &&
        action != 'provider.chat_auto' &&
        action != 'edge_llm.invoke') {
      return body;
    }
    final settings = await _offlineSettingsService.loadSettingsOrDefaults();
    return <String, dynamic>{
      ...body,
      ...settings.toAiHubPolicyPayload(),
    };
  }

  // =========================================================================
  // Direct model methods (OpenAI / Anthropic / Gemini)
  // =========================================================================

  Future<String?> generateContent({
    required String model,
    required String prompt,
    bool? useMagi,
    String? melchiorModel,
    String? balthasarModel,
    String? casperModel,
    String? synthesisModel,
  }) async {
    final magiSettings = await _loadMagiSettings();
    final effectiveUseMagi = useMagi ?? magiSettings.enabled;
    final resolvedMelchiorModel = _resolveMagiSettingModel(
      overrideValue: melchiorModel,
      fallback: magiSettings.melchiorModel,
    );
    final resolvedBalthasarModel = _resolveMagiSettingModel(
      overrideValue: balthasarModel,
      fallback: magiSettings.balthasarModel,
    );
    final resolvedCasperModel = _resolveMagiSettingModel(
      overrideValue: casperModel,
      fallback: magiSettings.casperModel,
    );
    final resolvedSynthesisModel = _resolveMagiSettingModel(
      overrideValue: synthesisModel,
      fallback: magiSettings.synthesisModel,
    );

    return _retryWithBackoff(
      () async {
        if (!effectiveUseMagi) {
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
          melchiorModel: resolvedMelchiorModel,
          balthasarModel: resolvedBalthasarModel,
          casperModel: resolvedCasperModel,
          synthesisModel: resolvedSynthesisModel,
        );
      },
      operationName:
          effectiveUseMagi ? 'generateContent(MAGI)' : 'generateContent',
    );
  }

  Future<MagiSystemSettings> _loadMagiSettings() {
    return _magiSettingsService.loadSettings();
  }

  String _resolveMagiSettingModel({
    required String? overrideValue,
    required String fallback,
  }) {
    final normalized = overrideValue?.trim();
    if (normalized == null || normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }

  Future<Map<String, dynamic>> _buildAiAssistantPayload(
    Map<String, dynamic> baseBody, {
    bool? useMagi,
  }) {
    return _magiSettingsService.buildAiAssistantPayload(
      baseBody: baseBody,
      useMagi: useMagi,
    );
  }

  bool _isProviderConfigured(_MagiProvider provider) {
    // Provider credentials are resolved only inside ai-hub. Availability is
    // reported by the Edge Function without exposing secret values.
    return _MagiProvider.values.contains(provider);
  }

  _MagiProvider _inferProviderFromModel(String model) {
    final lower = model.toLowerCase();
    if (lower.startsWith('deepseek')) {
      return _MagiProvider.deepseek;
    }
    if (lower.startsWith('claude') || lower.contains('anthropic')) {
      return _MagiProvider.anthropic;
    }
    if (lower.startsWith('gemini') || lower.startsWith('gemma')) {
      return _MagiProvider.gemini;
    }
    if (lower.startsWith('gpt') || lower.startsWith('o')) {
      return _MagiProvider.openai;
    }
    return _MagiProvider.openai;
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
      _MagiProvider.deepseek => _generateSingleDeepSeekContent(
          model: model,
          prompt: prompt,
        ),
    };
  }

  Future<String?> _generateSingleGeminiContent({
    required String model,
    required String prompt,
  }) async {
    // Gemini calls are proxied through the ai-assistant Edge Function to avoid
    // exposing the API key client-side and to prevent 429 rate-limit errors.
    try {
      final data = await _invokeFunction('ai-assistant', {
        'action': 'generate',
        'model': model,
        'content': prompt,
        'useMagi': false,
      });
      return data['result'] as String?;
    } catch (e) {
      if (e is AIServiceException) rethrow;
      throw _mapAiModelError(e);
    }
  }

  Future<String?> _generateSingleOpenAIContent({
    required String model,
    required String prompt,
  }) async {
    return _generateServerManagedContent(
      provider: 'openai',
      model: model,
      prompt: prompt,
    );
  }

  Future<String?> _generateSingleAnthropicContent({
    required String model,
    required String prompt,
  }) async {
    return _generateServerManagedContent(
      provider: 'anthropic',
      model: model,
      prompt: prompt,
    );
  }

  Future<String?> _generateSingleDeepSeekContent({
    required String model,
    required String prompt,
  }) async {
    return _generateServerManagedContent(
      provider: 'deepseek',
      model: model,
      prompt: prompt,
    );
  }

  Future<String?> _generateServerManagedContent({
    required String provider,
    required String model,
    required String prompt,
  }) async {
    try {
      final data = await _invokeFunction('ai-hub', {
        'action': 'provider.generate',
        'provider': provider,
        'model': model,
        'message': prompt,
      });
      if (data['success'] != true) {
        throw AIServiceException(
          data['message']?.toString() ?? 'Server-managed AI request failed.',
        );
      }
      final text = data['text']?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    } catch (e) {
      if (e is AIServiceException) rethrow;
      throw _mapAiModelError(e);
    }
  }

  Future<String?> _generateContentWithMagi({
    required String model,
    required String prompt,
    String? melchiorModel,
    String? balthasarModel,
    String? casperModel,
    String? synthesisModel,
  }) async {
    final safeGeminiModel =
        _inferProviderFromModel(model) == _MagiProvider.gemini
            ? model
            : _defaultGeminiModel;
    final profiles = _magiProfiles;
    final results = await Future.wait<_MagiOpinion?>(
      profiles.map((profile) {
        final nodeModel = _resolveMagiNodeModel(
          profile: profile,
          fallbackGeminiModel: safeGeminiModel,
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
        fallbackGeminiModel: safeGeminiModel,
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
      fallbackGeminiModel: safeGeminiModel,
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
      _MagiProvider.deepseek => profile.defaultModel.isNotEmpty
          ? profile.defaultModel
          : _defaultDeepSeekModel,
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
    addPlan(_MagiProvider.deepseek, _defaultDeepSeekModel);

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
    final provider = _inferProviderFromModel(model);
    if (!_isProviderConfigured(provider)) {
      AppLogger.info(
        'MAGI node skipped: ${profile.nodeName} (${provider.name}, no API key)',
      );
      return null;
    }

    final nodePrompt = _buildMagiNodePrompt(
      originalPrompt: prompt,
      profile: profile,
    );
    try {
      final text = await _generateSingleContentByProvider(
        provider: provider,
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
Preserve the user's requested output language and any explicit format constraints from the original prompt.

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
      ..writeln(
        'Preserve the original prompt language and any explicit format constraints.',
      )
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
    String outputLanguage = 'Japanese',
  }) {
    const promptTemplate = '''
You are an expert mind map generator.
Return exactly one valid JSON object and nothing else.

The JSON object should have a single root key representing the central topic. The value should be an object where each key is a child idea. This can be nested recursively for sub-ideas.

Language rules:
- Use {outputLanguage} for every generated node label.
- Keep the root key exactly equal to "{topic}".
- If the topic is Japanese or the expected language is Japanese, write every generated label in natural Japanese.
- Never translate Japanese text into Simplified Chinese.
- Do not mix multiple languages in the same mind map.
- Keep each label short and easy to read.
- Do not wrap the JSON in Markdown code fences.

**Example Input:** "Time Management Techniques"

**Example Output:**
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

**Your Task:**

Generate a mind map for the following topic: **"{topic}"**
''';
    final prompt = promptTemplate
        .replaceAll('{topic}', topic)
        .replaceAll('{outputLanguage}', outputLanguage);
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
        final payload = await _buildAiAssistantPayload(
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
        final data = await _invokeFunction(
          'ai-assistant',
          payload,
        );
        return data['result'] as String;
      },
      operationName: 'improveText',
    );
  }

  /// バランス型 改善 (Win版#107): Nebius Llama-3.3-70B-Instruct で
  /// 中品質・中コスト・EU GDPR 準拠データセンター。
  ///
  /// 使い分け:
  /// - `improveText` (premium): gpt-4o $2.50/M ・最高品質・単発推敲
  /// - **`improveTextBalanced`** (performance): Nebius $0.60/M ・バランス・量産推敲
  /// - `summarizeTextBulk` (budget): DeepInfra $0.30/M ・最安・バルク要約
  ///
  /// EU 居住データ処理が必要な医療/法律/個人情報 ノートに最適。
  Future<String> improveTextBalanced(
    String content, {
    String? styleInstruction,
  }) async {
    return await _retryWithBackoff(
      () async {
        final styleHint =
            (styleInstruction != null && styleInstruction.isNotEmpty)
                ? '\nスタイル指示: $styleInstruction'
                : '';
        final prompt = '''
以下のテキストを推敲してください。元の意図を保ち、文体を整え、
冗長な表現を削り、読みやすくします。$styleHint

入力テキスト:
$content

出力 (推敲済テキストのみ・前置き不要):
''';

        final responseData = await _invokeFunction(
          'ai-hub',
          {
            'action': 'provider.chat',
            'provider': 'nebius',
            'message': prompt,
          },
        );

        if (responseData['success'] != true) {
          throw Exception(
            'Nebius balanced improve failed: ${responseData['message'] ?? responseData['detail'] ?? 'unknown'}',
          );
        }

        return (responseData['text'] as String? ?? '').trim();
      },
      operationName: 'improveTextBalanced',
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
        final payload = await _buildAiAssistantPayload(
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
        final data = await _invokeFunction(
          'ai-assistant',
          payload,
        );
        return data['result'] as String;
      },
      operationName: 'summarizeText',
    );
  }

  /// バルク要約 (Win版#106): DeepInfra Llama-3.1-70B-Instruct-Turbo で
  /// 10x 安価に要約。複数ノート一括処理・自動定期要約・低優先度要約に最適。
  ///
  /// `summarizeText` は ai-assistant (openai/anthropic/google) で高品質。
  /// 本メソッドは ai-hub:provider.chat (deepinfra) で **コスト最適化**。
  ///
  /// 料金目安: Llama-3.1-70B-Turbo $0.30/M tokens (vs gpt-4o $2.50/M = 8x安価)
  /// 速度目安: ~2-3秒 / 500 tokens 入力
  Future<String> summarizeTextBulk(
    String content, {
    int maxLines = 3,
    String? language,
  }) async {
    return await _retryWithBackoff(
      () async {
        final lang =
            (language != null && language.isNotEmpty) ? language : '日本語';
        final prompt = '''
以下のテキストを $lang で $maxLines 行以内に要約してください。
箇条書きや前置き不要・要約本文のみ出力。

テキスト:
$content
''';

        final responseData = await _invokeFunction(
          'ai-hub',
          {
            'action': 'provider.chat',
            'provider': 'deepinfra',
            'message': prompt,
          },
        );

        if (responseData['success'] != true) {
          throw Exception(
            'DeepInfra bulk summarize failed: ${responseData['message'] ?? responseData['detail'] ?? 'unknown'}',
          );
        }

        return (responseData['text'] as String? ?? '').trim();
      },
      operationName: 'summarizeTextBulk',
    );
  }

  /// Expand note content.
  Future<String> expandText(String content) async {
    return await _retryWithBackoff(
      () async {
        final payload = await _buildAiAssistantPayload(
          {
            'action': 'expand',
            'content': content,
          },
        );
        final data = await _invokeFunction(
          'ai-assistant',
          payload,
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
        final payload = await _buildAiAssistantPayload(
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
        final data = await _invokeFunction(
          'ai-assistant',
          payload,
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
        final payload = await _buildAiAssistantPayload(
          {
            'action': 'suggest_title',
            'content': content,
            if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
          },
        );
        final data = await _invokeFunction(
          'ai-assistant',
          payload,
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
        final payload = await _buildAiAssistantPayload(
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
        final data = await _invokeFunction(
          'ai-assistant',
          payload,
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
        Future<Map<String, dynamic>> invokeBoardMeeting({
          String? targetModel,
        }) async {
          final payload = await _buildAiAssistantPayload(
            <String, dynamic>{
              'action': 'hold_board_meeting',
              'content': context,
              if (targetModel != null && targetModel.trim().isNotEmpty)
                'model': targetModel.trim(),
            },
          );
          return _invokeFunction('ai-assistant', payload);
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
    // Win版#105: ai-hub:provider.chat (Groq llama-3.3-70b) にリダイレクト。
    // 旧 ai-suggest-tags EF は SVG quote generator (関数名不一致) のため使用不可。
    // Groq = 超高速 (LPU) + 無料枠 = タグ提案ユースケースに最適。
    return await _retryWithBackoff(
      () async {
        final categoriesHint =
            (existingCategories != null && existingCategories.isNotEmpty)
                ? '\n既存カテゴリ (再利用優先): ${existingCategories.join(", ")}'
                : '';
        final titleLine =
            (title != null && title.isNotEmpty) ? 'タイトル: $title\n' : '';
        final prompt = '''
以下のノート本文を分析し、最適なタグ・カテゴリ・理由を JSON で返答してください。

$titleLine本文:
$content
$categoriesHint

レスポンス形式 (JSON のみ・他の文章は不要):
{
  "tags": ["タグ1", "タグ2", "タグ3"],
  "category": "メインカテゴリ",
  "reason": "なぜこれらを選んだかの一文"
}

ルール:
- tags は 3-5 個・短い名詞句 (例: "Flutter", "学習メモ")
- category は 1 つ・既存カテゴリがあれば優先再利用
- 出力は JSON 1 オブジェクトのみ・前後の説明文は禁止
''';

        final responseData = await _invokeFunction(
          'ai-hub',
          {
            'action': 'provider.chat',
            'provider': 'groq',
            'message': prompt,
          },
        );

        if (responseData['success'] != true) {
          throw Exception(
            'Groq tag suggestion failed: ${responseData['message'] ?? responseData['detail'] ?? 'unknown'}',
          );
        }

        final text = (responseData['text'] as String? ?? '').trim();
        // Strip markdown code fences if Groq added them
        final jsonStr = text
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```\s*$'), '')
            .trim();
        final suggestions = jsonDecode(jsonStr) as Map<String, dynamic>;

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
        // ai-search EF は ai-hub:search.query に統合済み (Windowsアプリ版#92)
        final responseData = await _invokeFunction(
          'ai-hub',
          {
            'action': 'search.query',
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
          'growth-hub',
          {
            'action': 'daily.challenges_generate',
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
  deepseek,
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
