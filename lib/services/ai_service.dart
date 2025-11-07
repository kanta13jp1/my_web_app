import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../main.dart';

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
/// NotionのAI機能に対抗する包括的なAI支援機能
class AIService {
  final SupabaseClient _supabase;
  static const int _maxRetries = 3;
  static const int _initialRetryDelayMs = 1000;

  AIService([SupabaseClient? supabaseClient])
      : _supabase = supabaseClient ?? supabase;

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
      } catch (e) {
        // AIServiceExceptionの場合、レート制限エラーかチェック
        if (e is AIServiceException && e.isRateLimitError) {
          if (retryCount >= _maxRetries) {
            AppLogger.error(
              'Max retries reached for $operationName after rate limit',
              error: e,
            );
            rethrow;
          }

          // retryAfterがあればそれを使用、なければ指数バックオフ
          final waitTimeMs = e.retryAfter != null
              ? int.parse(e.retryAfter!) * 1000
              : delayMs;

          AppLogger.info(
            'Rate limit hit for $operationName. Retrying in ${waitTimeMs}ms (attempt ${retryCount + 1}/$_maxRetries)',
          );

          await Future.delayed(Duration(milliseconds: waitTimeMs));
          retryCount++;
          delayMs *= 2; // 指数バックオフ
          continue;
        }

        // その他のエラーはそのまま投げる
        rethrow;
      }
    }
  }

  /// Supabase Functionsを呼び出すヘルパーメソッド（エラーハンドリング付き）
  Future<Map<String, dynamic>> _invokeFunction(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        functionName,
        body: body,
      );

      // エラーレスポンスのチェック
      if (response.data['success'] != true) {
        final errorMessage = response.data['error'] ?? 'AI処理に失敗しました';
        final errorType = response.data['errorType'] as String?;
        final retryAfter = response.data['retryAfter']?.toString();

        throw AIServiceException(
          errorMessage,
          errorType: errorType,
          retryAfter: retryAfter,
        );
      }

      return response.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      // FunctionExceptionの場合、詳細を解析
      final details = e.details;
      if (details is Map<String, dynamic>) {
        final errorMessage = details['error']?.toString() ?? 'AI処理に失敗しました';
        final errorType = details['errorType'] as String?;
        final retryAfter = details['retryAfter']?.toString();

        throw AIServiceException(
          errorMessage,
          errorType: errorType,
          retryAfter: retryAfter,
        );
      }

      throw AIServiceException(e.toString());
    }
  }

  /// 文章改善
  /// ユーザーの文章をより明確で読みやすく改善
  Future<String> improveText(String content) async {
    try {
      return await _retryWithBackoff(
        () async {
          final data = await _invokeFunction(
            'ai-assistant',
            {
              'action': 'improve',
              'content': content,
            },
          );
          return data['result'] as String;
        },
        operationName: 'improveText',
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error improving text', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 要約生成
  /// 長い文章を簡潔に要約
  Future<String> summarizeText(String content) async {
    try {
      return await _retryWithBackoff(
        () async {
          final data = await _invokeFunction(
            'ai-assistant',
            {
              'action': 'summarize',
              'content': content,
            },
          );
          return data['result'] as String;
        },
        operationName: 'summarizeText',
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error summarizing text', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 文章展開
  /// 短い文章やアイデアを詳細に展開
  Future<String> expandText(String content) async {
    try {
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
    } catch (e, stackTrace) {
      AppLogger.error('Error expanding text', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 翻訳
  /// 指定した言語に翻訳
  Future<String> translateText(
    String content, {
    String targetLanguage = 'en',
  }) async {
    try {
      return await _retryWithBackoff(
        () async {
          final data = await _invokeFunction(
            'ai-assistant',
            {
              'action': 'translate',
              'content': content,
              'targetLanguage': targetLanguage,
            },
          );
          return data['result'] as String;
        },
        operationName: 'translateText',
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error translating text', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// タイトル提案
  /// 文章内容から魅力的なタイトルを提案
  Future<List<String>> suggestTitles(String content) async {
    try {
      return await _retryWithBackoff(
        () async {
          final data = await _invokeFunction(
            'ai-assistant',
            {
              'action': 'suggest_title',
              'content': content,
            },
          );
          final result = data['result'] as String;
          // Parse the result to extract title suggestions
          // Assuming the result contains titles separated by newlines or numbers
          final titles = result
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map((line) => line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim())
              .where((line) => line.isNotEmpty)
              .toList();
          return titles;
        },
        operationName: 'suggestTitles',
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error suggesting titles', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// タグとカテゴリの自動提案
  /// メモの内容から適切なタグとカテゴリを提案
  Future<TagSuggestion> suggestTags({
    required String content,
    String? title,
    List<String>? existingCategories,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-suggest-tags',
        body: {
          'content': content,
          'title': title,
          'existingCategories': existingCategories,
        },
      );

      if (response.data['success'] == true) {
        final suggestions = response.data['suggestions'];
        return TagSuggestion(
          tags: List<String>.from(suggestions['tags'] ?? []),
          category: suggestions['category'] as String? ?? '',
          reason: suggestions['reason'] as String? ?? '',
        );
      } else {
        throw Exception(response.data['error'] ?? 'AI処理に失敗しました');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error suggesting tags', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// AI検索
  /// 自然言語検索とセマンティックサーチ
  Future<AISearchResult> searchNotes({
    required String query,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-search',
        body: {
          'query': query,
          'limit': limit,
        },
      );

      if (response.data['success'] == true) {
        return AISearchResult(
          results: List<Map<String, dynamic>>.from(response.data['results'] ?? []),
          totalResults: response.data['totalResults'] as int? ?? 0,
          explanation: response.data['explanation'] as String? ?? '',
        );
      } else {
        throw Exception(response.data['error'] ?? 'AI処理に失敗しました');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error in AI search', error: e, stackTrace: stackTrace);
      rethrow;
    }
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
      Map<String, int> usageByAction = {};

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
      AppLogger.error('Error getting AI usage stats', error: e, stackTrace: stackTrace);
      return AIUsageStats(
        totalUsage: 0,
        totalCost: 0.0,
        usageByAction: {},
        recentUsageCount: 0,
      );
    }
  }
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
