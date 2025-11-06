import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/public_memo.dart';
import '../utils/app_logger.dart';

class PublicMemoService {
  final SupabaseClient _supabase;

  PublicMemoService(this._supabase);

  // Publish a note as public memo
  Future<bool> publishMemo({
    required int noteId,
    required String userId,
    required String title,
    String? content,
    String? category,
  }) async {
    try {
      AppLogger.info('Publishing memo: $noteId');

      await _supabase.from('public_memos').upsert({
        'note_id': noteId,
        'user_id': userId,
        'title': title,
        'content': content,
        'category': category,
        'is_public': true,
        'published_at': DateTime.now().toIso8601String(),
      });

      AppLogger.info('Memo published successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to publish memo', e, stackTrace);
      return false;
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
      AppLogger.error('Failed to unpublish memo', e, stackTrace);
      return false;
    }
  }

  // Get public memos (gallery)
  Future<List<PublicMemo>> getPublicMemos({
    int limit = 20,
    int offset = 0,
    String? category,
    String sortBy = 'published_at', // published_at, like_count, view_count
  }) async {
    try {
      var query = _supabase
          .from('public_memos')
          .select()
          .eq('is_public', true);

      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      query = query
          .order(sortBy, ascending: false)
          .range(offset, offset + limit - 1);

      final response = await query;

      return (response as List)
          .map((json) => PublicMemo.fromJson(json))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get public memos', e, stackTrace);
      return [];
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
          .map((json) => PublicMemo.fromJson(json))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get trending memos', e, stackTrace);
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
          .update({'view_count': currentCount + 1})
          .eq('id', memoId);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to increment view count', e, stackTrace);
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
          .update({'like_count': currentCount + 1})
          .eq('id', memoId);

      AppLogger.info('Memo liked successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to like memo', e, stackTrace);
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
          .eq('user_id', userId);

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
          .update({'like_count': newCount})
          .eq('id', memoId);

      AppLogger.info('Memo unliked successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to unlike memo', e, stackTrace);
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
      AppLogger.error('Failed to check if user liked memo', e, stackTrace);
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
          .map((json) => PublicMemo.fromJson(json))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get user public memos', e, stackTrace);
      return [];
    }
  }

  // Get popular categories
  Future<List<Map<String, dynamic>>> getPopularCategories({int limit = 10}) async {
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
      AppLogger.error('Failed to get popular categories', e, stackTrace);
      return [];
    }
  }
}
