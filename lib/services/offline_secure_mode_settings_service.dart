import 'package:shared_preferences/shared_preferences.dart';

class OfflineSecureModeSettings {
  static const bool defaultEnabled = false;
  static const bool defaultBlockExternalApiWhenEnabled = true;
  static const String defaultInferenceEngine = 'pleias-rag';
  static const List<String> supportedInferenceEngines = <String>[
    'pleias-rag',
    'llama.cpp',
    'ollama',
    'localai',
    'custom',
  ];

  final bool enabled;
  final String localModelPath;
  final String localVectorDbPath;
  final String inferenceEngine;
  final bool blockExternalApiWhenEnabled;

  const OfflineSecureModeSettings({
    this.enabled = defaultEnabled,
    this.localModelPath = '',
    this.localVectorDbPath = '',
    this.inferenceEngine = defaultInferenceEngine,
    this.blockExternalApiWhenEnabled = defaultBlockExternalApiWhenEnabled,
  });

  bool get localRuntimeConfigured =>
      localModelPath.trim().isNotEmpty && localVectorDbPath.trim().isNotEmpty;

  bool get externalApiBlocked => enabled && blockExternalApiWhenEnabled;

  bool get onlineFallbackAllowed => !externalApiBlocked;

  OfflineSecureModeSettings copyWith({
    bool? enabled,
    String? localModelPath,
    String? localVectorDbPath,
    String? inferenceEngine,
    bool? blockExternalApiWhenEnabled,
  }) {
    return OfflineSecureModeSettings(
      enabled: enabled ?? this.enabled,
      localModelPath: localModelPath ?? this.localModelPath,
      localVectorDbPath: localVectorDbPath ?? this.localVectorDbPath,
      inferenceEngine: inferenceEngine ?? this.inferenceEngine,
      blockExternalApiWhenEnabled:
          blockExternalApiWhenEnabled ?? this.blockExternalApiWhenEnabled,
    );
  }

  Map<String, dynamic> toAiHubPolicyPayload() {
    return <String, dynamic>{
      'offline_secure_mode': enabled,
      'offline_external_api_blocked': externalApiBlocked,
      'offline_runtime_configured': localRuntimeConfigured,
      'offline_inference_engine': inferenceEngine,
      if (localModelPath.trim().isNotEmpty)
        'offline_local_model_path': localModelPath.trim(),
      if (localVectorDbPath.trim().isNotEmpty)
        'offline_local_vector_db_path': localVectorDbPath.trim(),
    };
  }
}

class OfflineSecureModeSettingsService {
  static const String _enabledKey = 'offline_secure_mode_enabled_v1';
  static const String _localModelPathKey =
      'offline_secure_mode_local_model_path_v1';
  static const String _localVectorDbPathKey =
      'offline_secure_mode_local_vector_db_path_v1';
  static const String _inferenceEngineKey =
      'offline_secure_mode_inference_engine_v1';
  static const String _blockExternalApiWhenEnabledKey =
      'offline_secure_mode_block_external_api_when_enabled_v1';

  const OfflineSecureModeSettingsService();

  Future<OfflineSecureModeSettings> loadSettingsOrDefaults({
    SharedPreferences? prefs,
  }) async {
    try {
      return await loadSettings(prefs: prefs);
    } catch (_) {
      return const OfflineSecureModeSettings();
    }
  }

  Future<OfflineSecureModeSettings> loadSettings({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return OfflineSecureModeSettings(
      enabled: store.getBool(_enabledKey) ??
          OfflineSecureModeSettings.defaultEnabled,
      localModelPath: _normalizedString(store.getString(_localModelPathKey)),
      localVectorDbPath:
          _normalizedString(store.getString(_localVectorDbPathKey)),
      inferenceEngine: _normalizedEngine(store.getString(_inferenceEngineKey)),
      blockExternalApiWhenEnabled:
          store.getBool(_blockExternalApiWhenEnabledKey) ??
              OfflineSecureModeSettings.defaultBlockExternalApiWhenEnabled,
    );
  }

  Future<OfflineSecureModeSettings> saveSettings(
    OfflineSecureModeSettings settings, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final normalized = settings.copyWith(
      localModelPath: settings.localModelPath.trim(),
      localVectorDbPath: settings.localVectorDbPath.trim(),
      inferenceEngine: _normalizedEngine(settings.inferenceEngine),
    );
    await store.setBool(_enabledKey, normalized.enabled);
    await store.setString(_localModelPathKey, normalized.localModelPath);
    await store.setString(_localVectorDbPathKey, normalized.localVectorDbPath);
    await store.setString(_inferenceEngineKey, normalized.inferenceEngine);
    await store.setBool(
      _blockExternalApiWhenEnabledKey,
      normalized.blockExternalApiWhenEnabled,
    );
    return normalized;
  }

  Future<OfflineSecureModeSettings> saveEnabled(
    bool enabled, {
    SharedPreferences? prefs,
  }) async {
    final current = await loadSettings(prefs: prefs);
    return saveSettings(current.copyWith(enabled: enabled), prefs: prefs);
  }

  String _normalizedString(String? raw) => raw?.trim() ?? '';

  String _normalizedEngine(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return OfflineSecureModeSettings.defaultInferenceEngine;
    }
    if (OfflineSecureModeSettings.supportedInferenceEngines
        .contains(normalized)) {
      return normalized;
    }
    return OfflineSecureModeSettings.defaultInferenceEngine;
  }
}
