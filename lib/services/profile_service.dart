import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../main.dart';
import '../utils/app_logger.dart';

/// ユーザープロフィール管理サービス
class ProfileService {
  final SupabaseClient _supabase;

  ProfileService([SupabaseClient? supabaseClient])
      : _supabase = supabaseClient ?? supabase;

  /// プロフィールを取得
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // プロフィールが存在しない場合、デフォルトプロフィールを作成
        return await _createDefaultProfile(userId);
      }

      return UserProfile.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting profile', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// 現在のユーザーのプロフィールを取得
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return null;
    }
    return await getProfile(user.id);
  }

  /// プロフィールを更新
  Future<UserProfile?> updateProfile(UserProfile profile) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .update(profile.toJson())
          .eq('user_id', profile.userId)
          .select()
          .single();

      AppLogger.info('Profile updated successfully for user ${profile.userId}');
      return UserProfile.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error('Error updating profile', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 表示名を更新
  Future<bool> updateDisplayName(String userId, String displayName) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({
            'display_name': displayName,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      AppLogger.info('Display name updated to "$displayName" for user $userId');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error updating display name', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 自己紹介を更新
  Future<bool> updateBio(String userId, String bio) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({
            'bio': bio,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      AppLogger.info('Bio updated for user $userId');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error updating bio', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// アバターURLを更新
  Future<bool> updateAvatarUrl(String userId, String avatarUrl) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({
            'avatar_url': avatarUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      AppLogger.info('Avatar URL updated for user $userId');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error updating avatar URL', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// プロフィールの公開設定を更新
  Future<bool> updatePublicStatus(String userId, bool isPublic) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({
            'is_public': isPublic,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      AppLogger.info('Public status updated to $isPublic for user $userId');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error updating public status', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// デフォルトプロフィールを作成
  Future<UserProfile> _createDefaultProfile(String userId) async {
    try {
      final user = await _supabase.auth.getUser();
      final email = user.user?.email ?? 'ユーザー';

      final profile = UserProfile(
        userId: userId,
        displayName: email,
        isPublic: true,
      );

      final response = await _supabase
          .from('user_profiles')
          .insert(profile.toJson())
          .select()
          .single();

      AppLogger.info('Default profile created for user $userId');
      return UserProfile.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error('Error creating default profile', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// プロフィールを削除
  Future<bool> deleteProfile(String userId) async {
    try {
      await _supabase
          .from('user_profiles')
          .delete()
          .eq('user_id', userId);

      AppLogger.info('Profile deleted for user $userId');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting profile', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
