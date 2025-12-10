import 'dart:async'; // Future.wait, Timer のために追加
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../main.dart';
import 'dart:math'; // 指数バックオフのために追加

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

// ... (TagSuggestion, AISearchResult, AIUsageStats, TaskRecommendations のクラス定義はファイル末尾に保持)

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
        AppLogger.error('Non-retryable error during $operationName',
            error: e, stackTrace: stackTrace);
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
            'Supabase Function Error ($functionName): $errorMessage');

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
          'FunctionException ($functionName): $e, details: $details');

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
      AppLogger.error('Unexpected error in _invokeFunction ($functionName)',
          error: e, stackTrace: stackTrace);
      // その他のネットワークエラーなど
      throw AIServiceException('予期せぬエラー: ${e.toString()}');
    }
  }

  // =========================================================================
  // AIアシスタント機能
  // =========================================================================

  /// 文章改善
  Future<String> improveText(String content) async {
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
  }

  /// 要約生成
  Future<String> summarizeText(String content) async {
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
  }) async {
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
        .map((line) =>
            line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim()) // ナンバリングを除去
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

        if (suggestions == null) {
          throw AIServiceException('AIからの提案データが不正です。');
        }

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
              .then((response) => List<Map<String, dynamic>>.from(
                  response)); // 明示的に Future<List> を返す
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
            .then((response) =>
                response as Map<String, dynamic>); // 明示的に Future<Map> を返す

        // Future.wait で並列実行
        final results = await Future.wait<dynamic>([
          notesFuture,
          statsFuture,
        ]);

        final notesResponse = results[0];
        final statsResponse = results[1];

        // 🔍 パラメータのログ出力
        AppLogger.debug(
            'getTaskRecommendations - notes count: ${(notesResponse as List).length}');
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
