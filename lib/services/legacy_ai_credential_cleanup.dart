import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef LegacyCredentialDelete = Future<void> Function(String key);

/// Deletes obsolete client-side AI credentials without reading or forwarding
/// their values. AI provider credentials are now resolved only by Edge
/// Functions from server-managed secrets.
class LegacyAiCredentialCleanup {
  LegacyAiCredentialCleanup({
    Future<SharedPreferences> Function()? preferencesProvider,
    LegacyCredentialDelete? secureDelete,
  })  : _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance,
        _secureDelete = secureDelete ?? _deleteSecureValue;

  static const List<String> legacyCredentialKeys = <String>[
    'gemini_api_key',
  ];

  final Future<SharedPreferences> Function() _preferencesProvider;
  final LegacyCredentialDelete _secureDelete;

  static Future<void> _deleteSecureValue(String key) {
    return const FlutterSecureStorage().delete(key: key);
  }

  Future<void> run() async {
    final preferences = await _preferencesProvider();
    for (final key in legacyCredentialKeys) {
      await preferences.remove(key);
      await _secureDelete(key);
    }
  }
}
