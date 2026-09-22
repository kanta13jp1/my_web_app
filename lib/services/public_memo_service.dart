import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/public_memo.dart';
import '../utils/app_logger.dart';
import 'app_share_service.dart';
import 'supabase_runtime_config.dart';

abstract interface class MemoReactionService {
  Future<Map<String, dynamic>> loadReactions(int memoId);

  Future<Map<String, dynamic>> toggleReaction({
    required int memoId,
    required String reaction,
  });
}

class PublicMemoService implements MemoReactionService {
  static const String publicMemoShareSignal = 'public_memo_share';
  static const String publicMemoCopySignal = 'public_memo_copy';

  final SupabaseClient _supabase;

  PublicMemoService(this._supabase);

  static String buildPublicMemoAppUrl(int memoId) {
    final baseUri = Uri.parse(AppShareService.appUrl);
    return baseUri.replace(
      path: '/public-memo',
      queryParameters: <String, String>{
        'id': memoId.toString(),
        'utm_source': 'public_memo',
        'utm_medium': 'share',
        'utm_campaign': 'growth_mission',
      },
    ).toString();
  }

  static String buildPublicMemoUrl(int memoId) {
    // public-memo-share EF は hub統合時に削除済みのためアプリURLに切替 (Issue #607)
    return buildPublicMemoAppUrl(memoId);
  }

  static String buildPublicMemoOgpUrl(int memoId) {
    // get-public-memo-ogp EF は hub統合時に削除済みのためアプリURLに切替
    return buildPublicMemoAppUrl(memoId);
  }

  /// ChatGPT 等の外部 AI・クローラー向けの bot 可読 URL。
  ///
  /// Flutter SPA の /public-memo は JS 実行後に本文を描画するため bot は
  /// 内容を読めない。core-hub の匿名 action `memo.public.view` が同じメモを
  /// サーバー描画済み HTML (format=json / md も可) で返す。
  static String buildPublicMemoReaderUrl(
    int memoId, {
    String? format,
    String? supabaseUrl,
  }) {
    final baseUrl =
        supabaseUrl ?? SupabaseRuntimeConfig.fromCompileTimeEnvironment().url;
    final endpoint = Uri.parse(baseUrl).resolve('/functions/v1/core-hub');
    return endpoint.replace(
      queryParameters: <String, String>{
        'action': 'memo.public.view',
        'id': memoId.toString(),
        if (format != null) 'format': format,
      },
    ).toString();
  }

  static String buildShareMessage(PublicMemo memo) {
    final excerpt = _buildShareExcerpt(memo.content);
    final category = memo.category?.trim();
    final title = (category == null || category.isEmpty)
        ? memo.title
        : '[$category] ${memo.title}';

    return [
      title,
      if (excerpt.isNotEmpty) excerpt,
      'Read the full memo:',
      buildPublicMemoUrl(memo.id),
    ].join('\n\n');
  }

  @override
  Future<Map<String, dynamic>> loadReactions(int memoId) async {
    final response = await _supabase.functions.invoke(
      'core-hub',
      body: buildLoadReactionsRequest(memoId),
    );
    return _asMap(response.data);
  }

  @override
  Future<Map<String, dynamic>> toggleReaction({
    required int memoId,
    required String reaction,
  }) async {
    final response = await _supabase.functions.invoke(
      'core-hub',
      body: buildToggleReactionRequest(memoId: memoId, reaction: reaction),
    );
    return _asMap(response.data);
  }

  static Map<String, dynamic> buildLoadReactionsRequest(int memoId) {
    return <String, dynamic>{'action': 'memo.react.list', 'memo_id': memoId};
  }

  static Map<String, dynamic> buildToggleReactionRequest({
    required int memoId,
    required String reaction,
  }) {
    return <String, dynamic>{
      'action': 'memo.react.toggle',
      'memo_id': memoId,
      'reaction': reaction,
    };
  }

  static String _buildShareExcerpt(String? content) {
    final normalized = content?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.length <= 140) {
      return normalized;
    }
    return '${normalized.substring(0, 137)}...';
  }

  Future<void> recordShareSignal({
    required int memoId,
    required String signalKey,
    DateTime? now,
  }) async {
    if (signalKey != publicMemoShareSignal &&
        signalKey != publicMemoCopySignal) {
      throw ArgumentError.value(
        signalKey,
        'signalKey',
        'Unsupported public memo share signal',
      );
    }

    final dateKey = _formatDate(now ?? DateTime.now());

    try {
      final response = await _supabase.functions.invoke(
        'growth-hub',
        body: <String, dynamic>{
          'action': 'acquisition.signal',
          'signalKey': signalKey,
          'dateKey': dateKey,
          'shareIncrement': 1,
          'contextId': memoId,
        },
      );
      final payload = _asMap(response.data);
      if (payload['success'] == true) {
        return;
      }
      AppLogger.warning(
        'Growth share signal function returned an unexpected payload: $payload',
      );
    } catch (e, stackTrace) {
      AppLogger.warning(
        'Growth share signal failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Publish a note as public memo
  Future<bool> publishMemo({
    required int noteId,
    required String userId,
    required String title,
    String? content,
    String? category,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final memo = await upsertMemo(
      noteId: noteId,
      userId: userId,
      title: title,
      content: content,
      category: category,
      metadata: metadata,
    );
    return memo != null;
  }

  Future<PublicMemo?> upsertMemo({
    required int noteId,
    required String userId,
    required String title,
    String? content,
    String? category,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    try {
      AppLogger.info('Publishing memo: $noteId');

      final response = await _supabase
          .from('public_memos')
          .upsert(
            {
              'note_id': noteId,
              'user_id': userId,
              'title': title,
              'content': content,
              'category': category,
              'metadata': metadata,
              'is_public': true,
              'published_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'note_id,user_id',
          )
          .select()
          .single();

      AppLogger.info('Memo published successfully');
      return PublicMemo.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to publish memo',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Creates or updates a generated note before publishing it.
  ///
  /// Public memos must reference a note owned by the authenticated user. A
  /// stable [sourceKey] lets generated surfaces update the same backing note
  /// without using a synthetic value as the `notes.id` primary key.
  Future<PublicMemo?> upsertGeneratedMemo({
    required String sourceKey,
    required String userId,
    required String title,
    String? content,
    String? category,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty) {
      throw ArgumentError.value(
        sourceKey,
        'sourceKey',
        'Generated memo source key must not be empty',
      );
    }

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final note = await _supabase
          .from('notes')
          .upsert(
            <String, dynamic>{
              'user_id': userId,
              'source_key': normalizedSourceKey,
              'title': title,
              'content': content,
              'is_archived': false,
              'is_pinned': false,
              'capture_status': 'organized',
              'capture_source': 'public_memo_generated',
              'updated_at': now,
            },
            onConflict: 'user_id,source_key',
          )
          .select('id')
          .single();
      final noteId = int.tryParse(note['id'].toString());
      if (noteId == null) {
        throw StateError('Generated memo note upsert returned no numeric id.');
      }

      return upsertMemo(
        noteId: noteId,
        userId: userId,
        title: title,
        content: content,
        category: category,
        metadata: <String, dynamic>{
          ...metadata,
          'source_key': normalizedSourceKey,
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to persist generated memo backing note',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<PublicMemo?> getUserGeneratedPublicMemoBySourceKey({
    required String sourceKey,
    required String userId,
  }) async {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty) {
      return null;
    }

    try {
      final note = await _supabase
          .from('notes')
          .select('id')
          .eq('user_id', userId)
          .eq('source_key', normalizedSourceKey)
          .maybeSingle();
      if (note == null) {
        return null;
      }
      final noteId = int.tryParse(note['id'].toString());
      if (noteId == null) {
        return null;
      }
      return getUserPublicMemoByNoteId(noteId: noteId, userId: userId);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to load generated public memo',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // Unpublish a memo
  Future<bool> unpublishMemo(int noteId, String userId) async {
    try {
      await _supabase
          .from('public_memos')
          .update({'is_public': false})
          .eq('note_id', noteId)
          .eq('user_id', userId);

      AppLogger.info('Memo unpublished successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to unpublish memo',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // Get public memos (gallery)
  Future<List<PublicMemo>> getPublicMemos({
    int limit = 20,
    int offset = 0,
    String? category,
    String? searchQuery,
    String sortBy = 'published_at', // published_at, like_count, view_count
  }) async {
    try {
      var builder =
          _supabase.from('public_memos').select().eq('is_public', true);

      if (category != null && category.isNotEmpty) {
        builder = builder.eq('category', category);
      }

      final normalizedQuery = searchQuery?.trim();
      if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
        final escaped = normalizedQuery.replaceAll(',', ' ');
        builder = builder.or(
          'title.ilike.%$escaped%,content.ilike.%$escaped%,category.ilike.%$escaped%',
        );
      }

      final response = await builder
          .order(sortBy, ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => PublicMemo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get public memos',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<PublicMemo?> getPublicMemoById(int memoId) async {
    try {
      final response = await _supabase
          .from('public_memos')
          .select()
          .eq('id', memoId)
          .eq('is_public', true)
          .maybeSingle();

      if (response == null) {
        return null;
      }
      return PublicMemo.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get public memo by id',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<PublicMemo?> getUserPublicMemoByNoteId({
    required int noteId,
    required String userId,
  }) async {
    try {
      final response = await _supabase
          .from('public_memos')
          .select()
          .eq('note_id', noteId)
          .eq('user_id', userId)
          .eq('is_public', true)
          .maybeSingle();

      if (response == null) {
        return null;
      }
      return PublicMemo.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get user public memo by note id',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // Get trending memos (high likes + views)
  Future<List<PublicMemo>> getTrendingMemos({int limit = 10}) async {
    try {
      // Get memos from last 7 days sorted by engagement
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final response = await _supabase
          .from('public_memos')
          .select()
          .eq('is_public', true)
          .gte('published_at', sevenDaysAgo.toIso8601String())
          .order('like_count', ascending: false)
          .order('view_count', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => PublicMemo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get trending memos',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Increment view count
  Future<void> incrementViewCount(int memoId) async {
    try {
      final memo = await _supabase
          .from('public_memos')
          .select('view_count')
          .eq('id', memoId)
          .single();

      final currentCount = memo['view_count'] as int;

      await _supabase
          .from('public_memos')
          .update({'view_count': currentCount + 1}).eq('id', memoId);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to increment view count',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Like a memo
  Future<bool> likeMemo(int memoId, String userId) async {
    try {
      // Check if already liked
      final existingLike = await _supabase
          .from('memo_likes')
          .select()
          .eq('memo_id', memoId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        AppLogger.warning('Memo already liked');
        return false;
      }

      // Add like
      await _supabase.from('memo_likes').insert({
        'memo_id': memoId,
        'user_id': userId,
      });

      // Increment like count
      final memo = await _supabase
          .from('public_memos')
          .select('like_count')
          .eq('id', memoId)
          .single();

      final currentCount = memo['like_count'] as int;

      await _supabase
          .from('public_memos')
          .update({'like_count': currentCount + 1}).eq('id', memoId);

      AppLogger.info('Memo liked successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to like memo', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Unlike a memo
  Future<bool> unlikeMemo(int memoId, String userId) async {
    try {
      // Remove like
      await _supabase
          .from('memo_likes')
          .delete()
          .eq('memo_id', memoId)
          .eq('user_id', userId)
          .select();

      // Decrement like count
      final memo = await _supabase
          .from('public_memos')
          .select('like_count')
          .eq('id', memoId)
          .single();

      final currentCount = memo['like_count'] as int;
      final newCount = currentCount > 0 ? currentCount - 1 : 0;

      await _supabase
          .from('public_memos')
          .update({'like_count': newCount}).eq('id', memoId);

      AppLogger.info('Memo unliked successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to unlike memo',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // Check if user has liked a memo
  Future<bool> hasUserLikedMemo(int memoId, String userId) async {
    try {
      final like = await _supabase
          .from('memo_likes')
          .select()
          .eq('memo_id', memoId)
          .eq('user_id', userId)
          .maybeSingle();

      return like != null;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to check if user liked memo',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // Get user's public memos
  Future<List<PublicMemo>> getUserPublicMemos(String userId) async {
    try {
      final response = await _supabase
          .from('public_memos')
          .select()
          .eq('user_id', userId)
          .eq('is_public', true)
          .order('published_at', ascending: false);

      return (response as List)
          .map((json) => PublicMemo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get user public memos',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Get popular categories
  Future<List<Map<String, dynamic>>> getPopularCategories({
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('public_memos')
          .select('category')
          .eq('is_public', true)
          .not('category', 'is', null);

      // Count categories
      final Map<String, int> categoryCount = {};
      for (final item in response) {
        final category = item['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }
      }

      // Sort and return top categories
      final sorted = categoryCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted
          .take(limit)
          .map((e) => {'category': e.key, 'count': e.value})
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get popular categories',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _formatDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }
}
