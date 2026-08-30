import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/toeic_progress_model.dart';

abstract interface class ToeicProgressService {
  Future<ToeicProgressModel> load();

  Future<void> save(ToeicProgressModel progress);
}

class SharedPreferencesToeicProgressService implements ToeicProgressService {
  SharedPreferencesToeicProgressService({SharedPreferences? preferences})
      : _preferences = preferences;

  static const String storageKey = 'ai_university_toeic_progress_v1';

  final SharedPreferences? _preferences;

  @override
  Future<ToeicProgressModel> load() async {
    final preferences = await _resolvePreferences();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return ToeicProgressModel.initial();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return ToeicProgressModel.initial();
      return ToeicProgressModel.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return ToeicProgressModel.initial();
    }
  }

  @override
  Future<void> save(ToeicProgressModel progress) async {
    final preferences = await _resolvePreferences();
    await preferences.setString(storageKey, jsonEncode(progress.toJson()));
  }

  Future<SharedPreferences> _resolvePreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }
}
