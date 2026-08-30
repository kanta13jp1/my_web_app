import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Duration evernoteTusResumeLifetime = Duration(hours: 23);
const String _evernoteTusResumeKeyPrefix = 'evernote_tus_resume_v1_';

abstract class EvernoteTusResumeStore {
  Future<Uri?> load({
    required Uri endpoint,
    required String bucketId,
    required String objectPath,
  });

  Future<void> save({
    required Uri endpoint,
    required String bucketId,
    required String objectPath,
    required Uri uploadUrl,
  });

  Future<void> remove({
    required String bucketId,
    required String objectPath,
  });
}

class SharedPreferencesEvernoteTusResumeStore
    implements EvernoteTusResumeStore {
  SharedPreferencesEvernoteTusResumeStore({
    SharedPreferences? preferences,
    DateTime Function()? now,
  })  : _preferences = preferences,
        _now = now ?? DateTime.now;

  final SharedPreferences? _preferences;
  final DateTime Function() _now;

  Future<SharedPreferences> _store() async {
    final preferences = _preferences;
    if (preferences != null) return preferences;
    return SharedPreferences.getInstance();
  }

  @override
  Future<Uri?> load({
    required Uri endpoint,
    required String bucketId,
    required String objectPath,
  }) async {
    final preferences = await _store();
    final key = _storageKey(bucketId: bucketId, objectPath: objectPath);
    try {
      final encoded = preferences.getString(key);
      if (encoded == null) return null;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        await preferences.remove(key);
        return null;
      }
      final uploadUrl = Uri.tryParse(decoded['upload_url']?.toString() ?? '');
      final expiresAt = DateTime.tryParse(
        decoded['expires_at']?.toString() ?? '',
      );
      if (uploadUrl == null ||
          expiresAt == null ||
          !_isSafeUploadUrl(endpoint: endpoint, uploadUrl: uploadUrl) ||
          !_now().toUtc().isBefore(expiresAt.toUtc())) {
        await preferences.remove(key);
        return null;
      }
      return uploadUrl;
    } catch (_) {
      try {
        await preferences.remove(key);
      } catch (_) {
        // A broken preference backend must not block the cloud upload.
      }
      return null;
    }
  }

  @override
  Future<void> save({
    required Uri endpoint,
    required String bucketId,
    required String objectPath,
    required Uri uploadUrl,
  }) async {
    if (!_isSafeUploadUrl(endpoint: endpoint, uploadUrl: uploadUrl)) {
      throw ArgumentError.value(
        uploadUrl,
        'uploadUrl',
        'A same-project Supabase resumable upload URL is required.',
      );
    }
    final preferences = await _store();
    final key = _storageKey(bucketId: bucketId, objectPath: objectPath);
    await preferences.setString(
      key,
      jsonEncode(<String, String>{
        'upload_url': uploadUrl.toString(),
        'expires_at':
            _now().toUtc().add(evernoteTusResumeLifetime).toIso8601String(),
      }),
    );
  }

  @override
  Future<void> remove({
    required String bucketId,
    required String objectPath,
  }) async {
    final preferences = await _store();
    await preferences.remove(
      _storageKey(bucketId: bucketId, objectPath: objectPath),
    );
  }

  static String _storageKey({
    required String bucketId,
    required String objectPath,
  }) {
    final digest = sha256.convert(
      utf8.encode('v1\u0000$bucketId\u0000$objectPath'),
    );
    return '$_evernoteTusResumeKeyPrefix$digest';
  }

  static bool _isSafeUploadUrl({
    required Uri endpoint,
    required Uri uploadUrl,
  }) {
    return endpoint.scheme == 'https' &&
        endpoint.host.endsWith('.storage.supabase.co') &&
        endpoint.port == 443 &&
        endpoint.userInfo.isEmpty &&
        endpoint.query.isEmpty &&
        endpoint.fragment.isEmpty &&
        endpoint.path == '/storage/v1/upload/resumable' &&
        uploadUrl.scheme == 'https' &&
        uploadUrl.host == endpoint.host &&
        uploadUrl.port == 443 &&
        uploadUrl.userInfo.isEmpty &&
        uploadUrl.query.isEmpty &&
        uploadUrl.fragment.isEmpty &&
        uploadUrl.path.startsWith('/storage/v1/upload/resumable/');
  }
}
