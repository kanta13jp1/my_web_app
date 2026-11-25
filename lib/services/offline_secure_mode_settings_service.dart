import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef OfflineSecureAuditInvoker = Future<Map<String, Object?>> Function(
  Map<String, Object?> body,
);

class OfflineSecureModeSettings {
  static const bool defaultEnabled = false;
  static const bool defaultBlockExternalApiWhenEnabled = true;
  static const String defaultInferenceEngine = 'pleias-rag';
  static const String defaultLocalRuntimeUrl = 'http://127.0.0.1:8765/rag';
  static const int defaultMemoryLimitMb = 8192;
  static const int minMemoryLimitMb = 512;
  static const List<int> supportedMemoryLimitsMb = <int>[
    2048,
    4096,
    8192,
  ];
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
  final String localRuntimeUrl;
  final bool blockExternalApiWhenEnabled;
  final int memoryLimitMb;

  const OfflineSecureModeSettings({
    this.enabled = defaultEnabled,
    this.localModelPath = '',
    this.localVectorDbPath = '',
    this.inferenceEngine = defaultInferenceEngine,
    this.localRuntimeUrl = defaultLocalRuntimeUrl,
    this.blockExternalApiWhenEnabled = defaultBlockExternalApiWhenEnabled,
    this.memoryLimitMb = defaultMemoryLimitMb,
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
    String? localRuntimeUrl,
    bool? blockExternalApiWhenEnabled,
    int? memoryLimitMb,
  }) {
    return OfflineSecureModeSettings(
      enabled: enabled ?? this.enabled,
      localModelPath: localModelPath ?? this.localModelPath,
      localVectorDbPath: localVectorDbPath ?? this.localVectorDbPath,
      inferenceEngine: inferenceEngine ?? this.inferenceEngine,
      localRuntimeUrl: localRuntimeUrl ?? this.localRuntimeUrl,
      blockExternalApiWhenEnabled:
          blockExternalApiWhenEnabled ?? this.blockExternalApiWhenEnabled,
      memoryLimitMb: memoryLimitMb ?? this.memoryLimitMb,
    );
  }

  Map<String, dynamic> toAiHubPolicyPayload() {
    return <String, dynamic>{
      'offline_secure_mode': enabled,
      'offline_external_api_blocked': externalApiBlocked,
      'offline_runtime_configured': localRuntimeConfigured,
      'offline_inference_engine': inferenceEngine,
      'offline_local_runtime_url': localRuntimeUrl,
      'offline_memory_limit_mb': memoryLimitMb.clamp(
        minMemoryLimitMb,
        defaultMemoryLimitMb,
      ),
      if (localModelPath.trim().isNotEmpty)
        'offline_local_model_path': localModelPath.trim(),
      if (localVectorDbPath.trim().isNotEmpty)
        'offline_local_vector_db_path': localVectorDbPath.trim(),
    };
  }
}

class OfflineSecureModeAuditEntry {
  final String id;
  final String action;
  final String provider;
  final String status;
  final bool secureModeEnabled;
  final bool externalApiBlocked;
  final int memoryLimitMb;
  final bool localRuntimeConfigured;
  final String recordedAt;

  const OfflineSecureModeAuditEntry({
    required this.id,
    required this.action,
    required this.provider,
    required this.status,
    required this.secureModeEnabled,
    required this.externalApiBlocked,
    required this.memoryLimitMb,
    required this.localRuntimeConfigured,
    required this.recordedAt,
  });

  factory OfflineSecureModeAuditEntry.fromMap(Map<String, Object?> map) {
    return OfflineSecureModeAuditEntry(
      id: map['id']?.toString().trim() ?? '',
      action: map['action']?.toString().trim() ?? 'unknown',
      provider: map['provider']?.toString().trim() ?? 'pleias-rag',
      status: map['status']?.toString().trim() ?? 'recorded',
      secureModeEnabled: map['secure_mode_enabled'] == true,
      externalApiBlocked: map['external_api_blocked'] == true,
      memoryLimitMb: _clampMemoryLimitMb(map['memory_limit_mb']),
      localRuntimeConfigured: map['local_runtime_configured'] == true,
      recordedAt: map['recorded_at']?.toString().trim() ?? '',
    );
  }
}

abstract class OfflineSecureModeAuditGateway {
  Future<List<OfflineSecureModeAuditEntry>> listRecent({int limit = 10});

  Future<bool> recordPolicyEvent({
    required OfflineSecureModeSettings settings,
    required String auditAction,
    required String status,
  });
}

class SupabaseOfflineSecureModeAuditGateway
    implements OfflineSecureModeAuditGateway {
  final SupabaseClient? _client;
  final OfflineSecureAuditInvoker? _invoker;

  const SupabaseOfflineSecureModeAuditGateway({
    SupabaseClient? client,
    OfflineSecureAuditInvoker? invoker,
  })  : _client = client,
        _invoker = invoker;

  @override
  Future<List<OfflineSecureModeAuditEntry>> listRecent({
    int limit = 10,
  }) async {
    final data = await _invoke(<String, Object?>{
      'action': 'offline_secure_mode.audit_list',
      'limit': limit,
    });
    if (data == null || data['success'] != true) {
      return const <OfflineSecureModeAuditEntry>[];
    }
    final rawLogs = data['logs'];
    if (rawLogs is! List) return const <OfflineSecureModeAuditEntry>[];
    return rawLogs
        .whereType<Map>()
        .map(
          (item) => OfflineSecureModeAuditEntry.fromMap(
            Map<String, Object?>.from(item),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<bool> recordPolicyEvent({
    required OfflineSecureModeSettings settings,
    required String auditAction,
    required String status,
  }) async {
    final payload = <String, Object?>{
      'action': 'offline_secure_mode.audit_record',
      'audit_action': auditAction,
      'status': status,
      'provider': settings.inferenceEngine,
      ...settings.toAiHubPolicyPayload(),
    };
    final data = await _invoke(payload);
    return data?['success'] == true && data?['recorded'] == true;
  }

  Future<Map<String, Object?>?> _invoke(Map<String, Object?> body) async {
    try {
      final invoker = _invoker;
      if (invoker != null) {
        return await invoker(body);
      }
      final client = _client ?? _tryCurrentClient();
      if (client == null || client.auth.currentUser == null) {
        return null;
      }
      final res = await client.functions.invoke('app-hub', body: body);
      final raw = res.data;
      if (raw is Map<String, Object?>) return raw;
      if (raw is Map) return Map<String, Object?>.from(raw);
      return null;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient? _tryCurrentClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}

int _clampMemoryLimitMb(Object? raw) {
  final parsed = raw is int
      ? raw
      : raw is num
          ? raw.toInt()
          : int.tryParse(raw?.toString() ?? '');
  if (parsed == null || parsed <= 0) {
    return OfflineSecureModeSettings.defaultMemoryLimitMb;
  }
  return parsed
      .clamp(
        OfflineSecureModeSettings.minMemoryLimitMb,
        OfflineSecureModeSettings.defaultMemoryLimitMb,
      )
      .toInt();
}

class OfflineSecureModeSettingsService {
  static const String _enabledKey = 'offline_secure_mode_enabled_v1';
  static const String _localModelPathKey =
      'offline_secure_mode_local_model_path_v1';
  static const String _localVectorDbPathKey =
      'offline_secure_mode_local_vector_db_path_v1';
  static const String _inferenceEngineKey =
      'offline_secure_mode_inference_engine_v1';
  static const String _localRuntimeUrlKey =
      'offline_secure_mode_local_runtime_url_v1';
  static const String _blockExternalApiWhenEnabledKey =
      'offline_secure_mode_block_external_api_when_enabled_v1';
  static const String _memoryLimitMbKey =
      'offline_secure_mode_memory_limit_mb_v1';

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
      localRuntimeUrl: _normalizedRuntimeUrl(
        store.getString(_localRuntimeUrlKey),
      ),
      blockExternalApiWhenEnabled:
          store.getBool(_blockExternalApiWhenEnabledKey) ??
              OfflineSecureModeSettings.defaultBlockExternalApiWhenEnabled,
      memoryLimitMb: _clampMemoryLimitMb(store.getInt(_memoryLimitMbKey)),
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
      localRuntimeUrl: _normalizedRuntimeUrl(settings.localRuntimeUrl),
      memoryLimitMb: _clampMemoryLimitMb(settings.memoryLimitMb),
    );
    await store.setBool(_enabledKey, normalized.enabled);
    await store.setString(_localModelPathKey, normalized.localModelPath);
    await store.setString(_localVectorDbPathKey, normalized.localVectorDbPath);
    await store.setString(_inferenceEngineKey, normalized.inferenceEngine);
    await store.setString(_localRuntimeUrlKey, normalized.localRuntimeUrl);
    await store.setBool(
      _blockExternalApiWhenEnabledKey,
      normalized.blockExternalApiWhenEnabled,
    );
    await store.setInt(_memoryLimitMbKey, normalized.memoryLimitMb);
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

  String _normalizedRuntimeUrl(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return OfflineSecureModeSettings.defaultLocalRuntimeUrl;
    }
    return normalized;
  }

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
