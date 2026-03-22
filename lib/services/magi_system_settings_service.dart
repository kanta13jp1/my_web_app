import 'package:shared_preferences/shared_preferences.dart';

enum MagiNodeRole {
  melchior,
  balthasar,
  casper,
  synthesis,
}

extension MagiNodeRoleX on MagiNodeRole {
  String get label {
    switch (this) {
      case MagiNodeRole.melchior:
        return 'MELCHIOR';
      case MagiNodeRole.balthasar:
        return 'BALTHASAR';
      case MagiNodeRole.casper:
        return 'CASPER';
      case MagiNodeRole.synthesis:
        return 'SYNTHESIS';
    }
  }

  String get description {
    switch (this) {
      case MagiNodeRole.melchior:
        return '論理・分析';
      case MagiNodeRole.balthasar:
        return '共感・人間理解';
      case MagiNodeRole.casper:
        return '批判・リスク検討';
      case MagiNodeRole.synthesis:
        return '最終統合';
    }
  }
}

class MagiSystemSettings {
  static const bool defaultEnabled = true;
  static const String defaultMelchiorModel = 'gpt-4o-mini';
  static const String defaultBalthasarModel = 'claude-sonnet-4-6';
  static const String defaultCasperModel = 'gemini-2.5-flash';
  static const String defaultSynthesisModel = 'claude-sonnet-4-6';

  final bool enabled;
  final String melchiorModel;
  final String balthasarModel;
  final String casperModel;
  final String synthesisModel;

  const MagiSystemSettings({
    this.enabled = defaultEnabled,
    this.melchiorModel = defaultMelchiorModel,
    this.balthasarModel = defaultBalthasarModel,
    this.casperModel = defaultCasperModel,
    this.synthesisModel = defaultSynthesisModel,
  });

  String modelFor(MagiNodeRole role) {
    switch (role) {
      case MagiNodeRole.melchior:
        return melchiorModel;
      case MagiNodeRole.balthasar:
        return balthasarModel;
      case MagiNodeRole.casper:
        return casperModel;
      case MagiNodeRole.synthesis:
        return synthesisModel;
    }
  }

  MagiSystemSettings copyWith({
    bool? enabled,
    String? melchiorModel,
    String? balthasarModel,
    String? casperModel,
    String? synthesisModel,
  }) {
    return MagiSystemSettings(
      enabled: enabled ?? this.enabled,
      melchiorModel: melchiorModel ?? this.melchiorModel,
      balthasarModel: balthasarModel ?? this.balthasarModel,
      casperModel: casperModel ?? this.casperModel,
      synthesisModel: synthesisModel ?? this.synthesisModel,
    );
  }

  Map<String, dynamic> toRequestPayload() {
    final payload = <String, dynamic>{
      'useMagi': enabled,
    };
    if (!enabled) {
      return payload;
    }

    payload['melchiorModel'] = melchiorModel;
    payload['balthasarModel'] = balthasarModel;
    payload['casperModel'] = casperModel;
    payload['synthesisModel'] = synthesisModel;
    return payload;
  }
}

class MagiSystemSettingsService {
  static const String _enabledKey = 'magi_system_enabled_v1';
  static const String _melchiorKey = 'magi_system_melchior_model_v1';
  static const String _balthasarKey = 'magi_system_balthasar_model_v1';
  static const String _casperKey = 'magi_system_casper_model_v1';
  static const String _synthesisKey = 'magi_system_synthesis_model_v1';

  const MagiSystemSettingsService();

  Future<MagiSystemSettings> loadSettings({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return MagiSystemSettings(
      enabled: store.getBool(_enabledKey) ?? MagiSystemSettings.defaultEnabled,
      melchiorModel: _normalizedValue(
        store.getString(_melchiorKey),
        fallback: MagiSystemSettings.defaultMelchiorModel,
      ),
      balthasarModel: _normalizedValue(
        store.getString(_balthasarKey),
        fallback: MagiSystemSettings.defaultBalthasarModel,
      ),
      casperModel: _normalizedValue(
        store.getString(_casperKey),
        fallback: MagiSystemSettings.defaultCasperModel,
      ),
      synthesisModel: _normalizedValue(
        store.getString(_synthesisKey),
        fallback: MagiSystemSettings.defaultSynthesisModel,
      ),
    );
  }

  Future<MagiSystemSettings> saveSettings(
    MagiSystemSettings settings, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setBool(_enabledKey, settings.enabled);
    await store.setString(_melchiorKey, settings.melchiorModel.trim());
    await store.setString(_balthasarKey, settings.balthasarModel.trim());
    await store.setString(_casperKey, settings.casperModel.trim());
    await store.setString(_synthesisKey, settings.synthesisModel.trim());
    return settings;
  }

  Future<MagiSystemSettings> saveEnabled(
    bool enabled, {
    SharedPreferences? prefs,
  }) async {
    final current = await loadSettings(prefs: prefs);
    return saveSettings(current.copyWith(enabled: enabled), prefs: prefs);
  }

  Future<MagiSystemSettings> saveNodeModel(
    MagiNodeRole role,
    String model, {
    SharedPreferences? prefs,
  }) async {
    final normalized = model.trim();
    final current = await loadSettings(prefs: prefs);
    final next = switch (role) {
      MagiNodeRole.melchior => current.copyWith(melchiorModel: normalized),
      MagiNodeRole.balthasar => current.copyWith(balthasarModel: normalized),
      MagiNodeRole.casper => current.copyWith(casperModel: normalized),
      MagiNodeRole.synthesis => current.copyWith(synthesisModel: normalized),
    };
    return saveSettings(next, prefs: prefs);
  }

  Future<Map<String, dynamic>> buildAiAssistantPayload({
    required Map<String, dynamic> baseBody,
    SharedPreferences? prefs,
    bool? useMagi,
  }) async {
    final settings = await loadSettings(prefs: prefs);
    final effectiveSettings = settings.copyWith(enabled: useMagi);
    return <String, dynamic>{
      ...baseBody,
      ...effectiveSettings.toRequestPayload(),
    };
  }

  String _normalizedValue(String? raw, {required String fallback}) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }
}
