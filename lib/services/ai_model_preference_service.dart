import 'package:shared_preferences/shared_preferences.dart';

class AiModelPreferenceService {
  static const String _preferredModelKey = 'preferred_ai_model';

  const AiModelPreferenceService();

  Future<String?> loadPreferredModel({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final value = store.getString(_preferredModelKey)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> savePreferredModel(
    String modelName, {
    SharedPreferences? prefs,
  }) async {
    final normalized = modelName.trim();
    final store = prefs ?? await SharedPreferences.getInstance();
    if (normalized.isEmpty) {
      await store.remove(_preferredModelKey);
      return;
    }
    await store.setString(_preferredModelKey, normalized);
  }
}
