import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:my_web_app/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileAvatarValidationException implements Exception {
  const ProfileAvatarValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileEgressPolicy {
  static const int maxAvatarBytes = 5 * 1024 * 1024;
  static const String avatarCacheControl = '31536000';
  static const Duration profileCacheTtl = Duration(minutes: 5);
  static const int maxProfileCacheEntries = 32;
  static const String imageTransformFlagName =
      'SUPABASE_AVATAR_IMAGE_TRANSFORM_ENABLED';
  static const bool imageTransformEnabled = bool.fromEnvironment(
    imageTransformFlagName,
    defaultValue: false,
  );

  static const Map<String, String> _contentTypeByExtension = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'gif': 'image/gif',
  };

  static void validateAvatar({
    required Uint8List fileBytes,
    required String fileExtension,
    required String contentType,
  }) {
    if (fileBytes.isEmpty) {
      throw const ProfileAvatarValidationException('画像ファイルが空です。別の画像を選択してください。');
    }
    if (fileBytes.length > maxAvatarBytes) {
      throw const ProfileAvatarValidationException('プロフィール画像は5MB以下にしてください。');
    }

    final normalizedExtension = normalizeExtension(fileExtension);
    final expectedContentType = _contentTypeByExtension[normalizedExtension];
    if (expectedContentType == null) {
      throw const ProfileAvatarValidationException(
        'PNG、JPEG、WebP、GIF形式の画像を選択してください。',
      );
    }
    if (normalizeContentType(contentType) != expectedContentType) {
      throw const ProfileAvatarValidationException('画像の拡張子とMIMEタイプが一致しません。');
    }
  }

  static String normalizeExtension(String extension) =>
      extension.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), '');

  static String normalizeContentType(String contentType) =>
      contentType.trim().toLowerCase();

  static TransformOptions? avatarTransformOptions({bool? enabled}) {
    if (!(enabled ?? imageTransformEnabled)) {
      return null;
    }
    return const TransformOptions(
      width: 256,
      height: 256,
      resize: ResizeMode.cover,
      quality: 80,
    );
  }

  static String versionedPublicUrl(String publicUrl, Uint8List fileBytes) {
    final digest = sha256.convert(fileBytes).toString().substring(0, 16);
    final uri = Uri.parse(publicUrl);
    final versionedParameters = {...uri.queryParameters, 'v': digest};
    return uri.replace(queryParameters: versionedParameters).toString();
  }
}

class ProfileReadCache {
  ProfileReadCache({
    this.ttl = ProfileEgressPolicy.profileCacheTtl,
    this.maxEntries = ProfileEgressPolicy.maxProfileCacheEntries,
    DateTime Function()? now,
  })  : assert(maxEntries > 0),
        _now = now ?? DateTime.now;

  final Duration ttl;
  final int maxEntries;
  final DateTime Function() _now;
  final Map<String, _CachedProfile> _entries = {};

  UserProfile? read(String userId) {
    final cached = _entries[userId];
    if (cached == null) {
      return null;
    }
    if (_now().difference(cached.cachedAt) >= ttl) {
      _entries.remove(userId);
      return null;
    }
    return cached.profile;
  }

  void write(UserProfile profile) {
    if (!_entries.containsKey(profile.userId) &&
        _entries.length >= maxEntries) {
      final oldest = _entries.entries.reduce(
        (left, right) =>
            left.value.cachedAt.isBefore(right.value.cachedAt) ? left : right,
      );
      _entries.remove(oldest.key);
    }
    _entries[profile.userId] = _CachedProfile(
      profile: profile,
      cachedAt: _now(),
    );
  }

  void invalidate(String userId) => _entries.remove(userId);

  void clear() => _entries.clear();

  int get length => _entries.length;
}

class _CachedProfile {
  const _CachedProfile({required this.profile, required this.cachedAt});

  final UserProfile profile;
  final DateTime cachedAt;
}
