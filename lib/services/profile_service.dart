// lib/services/profile_service.dart
import 'dart:typed_data'; // 👈 Uint8Listのために必要

import 'package:my_web_app/services/profile_egress_policy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import 'package:my_web_app/services/supabase_client_provider.dart';
import '../utils/app_logger.dart';

/// ユーザープロフィール管理サービス
class ProfileService {
  final SupabaseClient _supabase;
  // Supabase Storageのバケット名
  static const String _avatarBucket = 'avatars';
  static const String _profileColumns =
      'user_id,display_name,bio,avatar_url,website_url,location,'
      'twitter_handle,github_handle,gender,occupation,annual_income,address,'
      'education,career_history,hobbies,alcohol_use,smoking_use,'
      'favorite_foods,is_public,birth_date,target_death_age,'
      'disposable_time_ratio,created_at,updated_at';
  static final ProfileReadCache _profileCache = ProfileReadCache();

  ProfileService([SupabaseClient? supabaseClient])
      : _supabase = supabaseClient ?? supabase;

  // 🚨 新規: プロフィール画像 (アバター) をSupabase Storageにアップロードする
  ///
  /// [userId] ユーザーID (ファイル名として使用)
  /// [fileBytes] アップロードする画像のバイトデータ (Uint8List)
  /// [fileExtension] ファイルの拡張子 (例: 'png', 'jpg', 'webp')
  /// [contentType] ファイルのMIMEタイプ (例: 'image/png', 'image/jpeg', 'image/webp')
  ///
  /// 成功した場合、新しいアバター画像の公開URLを返す。
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List fileBytes,
    required String fileExtension, // 例: 'png', 'jpg', 'webp'
    required String contentType, // 例: 'image/png', 'image/jpeg', 'image/webp'
  }) async {
    // ユーザーIDをファイル名として使用し、ファイルパスを決定
    ProfileEgressPolicy.validateAvatar(
      fileBytes: fileBytes,
      fileExtension: fileExtension,
      contentType: contentType,
    );
    final normalizedExtension = ProfileEgressPolicy.normalizeExtension(
      fileExtension,
    );
    final normalizedContentType = ProfileEgressPolicy.normalizeContentType(
      contentType,
    );
    final filePath = '$userId.$normalizedExtension';

    try {
      // 既存のファイルを上書きするようにアップロード
      await _supabase.storage.from(_avatarBucket).uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(
              upsert: true, // 既存のファイルがあれば上書き
              contentType: normalizedContentType,
              cacheControl: ProfileEgressPolicy.avatarCacheControl,
            ),
          );

      // アップロード後、アバターの公開URLを取得して返す
      final publicUrl = ProfileEgressPolicy.versionedPublicUrl(
        _supabase.storage.from(_avatarBucket).getPublicUrl(
              filePath,
              transform: ProfileEgressPolicy.avatarTransformOptions(),
            ),
        fileBytes,
      );

      // DBの avatar_url も更新する必要があるため、ここで更新メソッドも呼び出します
      await updateAvatarUrl(userId, publicUrl);

      AppLogger.info(
        'Avatar uploaded and URL updated for user $userId: $publicUrl',
      );
      return publicUrl;
    } on StorageException catch (e, stackTrace) {
      AppLogger.error('Storage upload error', error: e, stackTrace: stackTrace);
      // Storage固有のエラーメッセージを分かりやすくして再スロー
      throw Exception('画像アップロードに失敗しました: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('General upload error', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // --- 以下、既存のメソッド ---

  /// プロフィールを取得
  Future<UserProfile?> getProfile(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _profileCache.read(userId);
      if (cached != null) {
        return cached;
      }
    }
    try {
      final response = await _supabase
          .from('user_profiles')
          .select(_profileColumns)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // プロフィールが存在しない場合、デフォルトプロフィールを作成
        return await _createDefaultProfile(userId);
      }

      final profile = UserProfile.fromJson(response);
      _profileCache.write(profile);
      return profile;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error getting profile',
        error: e,
        stackTrace: stackTrace,
      );
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
      await _supabase
          .from('user_profiles')
          .update(profile.toJson())
          .eq('user_id', profile.userId);

      AppLogger.info('Profile updated successfully for user ${profile.userId}');
      _profileCache.write(profile);
      return profile;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error updating profile',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 表示名を更新
  Future<bool> updateDisplayName(String userId, String displayName) async {
    try {
      await _supabase.from('user_profiles').update({
        'display_name': displayName,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      AppLogger.info('Display name updated to "$displayName" for user $userId');
      _profileCache.invalidate(userId);
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error updating display name',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// 自己紹介を更新
  Future<bool> updateBio(String userId, String bio) async {
    try {
      final updatedAt = DateTime.now().toIso8601String();
      final updates = {'bio': bio, 'updated_at': updatedAt};
      await _supabase
          .from('user_profiles')
          .update(updates)
          .eq('user_id', userId);

      AppLogger.info('Bio updated for user $userId');
      _profileCache.invalidate(userId);
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error updating bio', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// アバターURLを更新
  Future<bool> updateAvatarUrl(String userId, String avatarUrl) async {
    try {
      await _supabase.from('user_profiles').update({
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      AppLogger.info('Avatar URL updated for user $userId');
      _profileCache.invalidate(userId);
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error updating avatar URL',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// プロフィールの公開設定を更新
  Future<bool> updatePublicStatus(String userId, bool isPublic) async {
    try {
      await _supabase.from('user_profiles').update({
        'is_public': isPublic,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      AppLogger.info('Public status updated to $isPublic for user $userId');
      _profileCache.invalidate(userId);
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error updating public status',
        error: e,
        stackTrace: stackTrace,
      );
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

      await _supabase.from('user_profiles').insert(profile.toJson());

      AppLogger.info('Default profile created for user $userId');
      _profileCache.write(profile);
      return profile;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error creating default profile',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// プロフィールを削除
  Future<bool> deleteProfile(String userId) async {
    try {
      await _supabase.from('user_profiles').delete().eq('user_id', userId);

      AppLogger.info('Profile deleted for user $userId');
      _profileCache.invalidate(userId);
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error deleting profile',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
