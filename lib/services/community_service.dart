import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../utils/app_logger.dart';
import '../main.dart';

/// コミュニティ機能を提供するサービス
/// NotionとEvernoteにはないソーシャル機能で差別化
class CommunityService {
  final SupabaseClient _supabase;

  CommunityService([SupabaseClient? supabaseClient])
      : _supabase = supabaseClient ?? supabase;

  // ==================== ユーザープロフィール ====================

  /// ユーザープロフィールを取得
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting user profile', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// ユーザープロフィールを更新
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .upsert(profile.toJson())
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error('Error updating user profile', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 公開プロフィールを検索
  Future<List<UserProfile>> searchPublicProfiles({
    String? query,
    int limit = 20,
  }) async {
    try {
      var queryBuilder = _supabase
          .from('user_profiles')
          .select()
          .eq('is_public', true);

      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'display_name.ilike.%$query%,bio.ilike.%$query%',
        );
      }

      final response = await queryBuilder.limit(limit);

      return (response as List)
          .map((profile) => UserProfile.fromJson(profile))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error searching profiles', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // ==================== フォロー機能 ====================

  /// ユーザーをフォロー
  Future<void> followUser(String followingId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('user_follows').insert({
        'follower_id': userId,
        'following_id': followingId,
      });

      AppLogger.info('User $userId followed $followingId');
    } catch (e, stackTrace) {
      AppLogger.error('Error following user', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// ユーザーをアンフォロー
  Future<void> unfollowUser(String followingId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('user_follows')
          .delete()
          .eq('follower_id', userId)
          .eq('following_id', followingId);

      AppLogger.info('User $userId unfollowed $followingId');
    } catch (e, stackTrace) {
      AppLogger.error('Error unfollowing user', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// フォローしているか確認
  Future<bool> isFollowing(String followingId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('user_follows')
          .select()
          .eq('follower_id', userId)
          .eq('following_id', followingId)
          .maybeSingle();

      return response != null;
    } catch (e, stackTrace) {
      AppLogger.error('Error checking follow status', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// フォロワー一覧を取得
  Future<List<UserProfile>> getFollowers(String userId, {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('user_follows')
          .select('follower_id')
          .eq('following_id', userId)
          .limit(limit);

      final followerIds = (response as List)
          .map((row) => row['follower_id'] as String)
          .toList();

      if (followerIds.isEmpty) return [];

      final profiles = await _supabase
          .from('user_profiles')
          .select()
          .in_('user_id', followerIds);

      return (profiles as List)
          .map((profile) => UserProfile.fromJson(profile))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting followers', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// フォロー中のユーザー一覧を取得
  Future<List<UserProfile>> getFollowing(String userId, {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('user_follows')
          .select('following_id')
          .eq('follower_id', userId)
          .limit(limit);

      final followingIds = (response as List)
          .map((row) => row['following_id'] as String)
          .toList();

      if (followingIds.isEmpty) return [];

      final profiles = await _supabase
          .from('user_profiles')
          .select()
          .in_('user_id', followingIds);

      return (profiles as List)
          .map((profile) => UserProfile.fromJson(profile))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting following', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// フォロワー数とフォロー数を取得
  Future<Map<String, int>> getFollowCounts(String userId) async {
    try {
      // フォロワー数
      final followersResponse = await _supabase
          .from('user_follows')
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('following_id', userId);

      // フォロー数
      final followingResponse = await _supabase
          .from('user_follows')
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('follower_id', userId);

      return {
        'followers': followersResponse.count ?? 0,
        'following': followingResponse.count ?? 0,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Error getting follow counts', error: e, stackTrace: stackTrace);
      return {'followers': 0, 'following': 0};
    }
  }

  // ==================== コメント機能 ====================

  /// メモにコメントを追加
  Future<NoteComment> addComment({
    required String noteId,
    required String content,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('note_comments')
          .insert({
            'note_id': noteId,
            'user_id': userId,
            'content': content,
          })
          .select()
          .single();

      return NoteComment.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error('Error adding comment', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// コメントを取得
  Future<List<NoteComment>> getComments(String noteId) async {
    try {
      final response = await _supabase
          .from('note_comments')
          .select('''
            *,
            user_profiles!inner(display_name, avatar_url)
          ''')
          .eq('note_id', noteId)
          .order('created_at', ascending: true);

      return (response as List).map((comment) {
        final userProfile = comment['user_profiles'];
        return NoteComment.fromJson({
          ...comment,
          'user_display_name': userProfile?['display_name'],
          'user_avatar_url': userProfile?['avatar_url'],
        });
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting comments', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// コメントを更新
  Future<NoteComment> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final response = await _supabase
          .from('note_comments')
          .update({'content': content, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', commentId)
          .select()
          .single();

      return NoteComment.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error('Error updating comment', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// コメントを削除
  Future<void> deleteComment(String commentId) async {
    try {
      await _supabase.from('note_comments').delete().eq('id', commentId);
      AppLogger.info('Comment $commentId deleted');
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting comment', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ==================== いいね機能 ====================

  /// メモにいいねを追加
  Future<void> likeNote(String noteId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('note_likes').insert({
        'note_id': noteId,
        'user_id': userId,
      });

      AppLogger.info('User $userId liked note $noteId');
    } catch (e, stackTrace) {
      AppLogger.error('Error liking note', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// いいねを解除
  Future<void> unlikeNote(String noteId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('note_likes')
          .delete()
          .eq('note_id', noteId)
          .eq('user_id', userId);

      AppLogger.info('User $userId unliked note $noteId');
    } catch (e, stackTrace) {
      AppLogger.error('Error unliking note', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// いいねしているか確認
  Future<bool> hasLiked(String noteId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('note_likes')
          .select()
          .eq('note_id', noteId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e, stackTrace) {
      AppLogger.error('Error checking like status', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// いいね数を取得
  Future<int> getLikeCount(String noteId) async {
    try {
      final response = await _supabase
          .from('note_likes')
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('note_id', noteId);

      return response.count ?? 0;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting like count', error: e, stackTrace: stackTrace);
      return 0;
    }
  }

  /// コメント数を取得
  Future<int> getCommentCount(String noteId) async {
    try {
      final response = await _supabase
          .from('note_comments')
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('note_id', noteId);

      return response.count ?? 0;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting comment count', error: e, stackTrace: stackTrace);
      return 0;
    }
  }
}
