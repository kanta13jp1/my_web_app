import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 音声入力・クロスデバイス引き継ぎ元のデバイス種別。
enum VoiceDevicePlatform {
  iosSafariTab('ios_safari_tab', 'iOS Safari タブ'),
  iosPwaStandalone('ios_pwa_standalone', 'iOS PWA (ホーム画面)'),
  androidPwa('android_pwa', 'Android PWA'),
  desktopWeb('desktop_web', 'デスクトップ Web'),
  mobileWebview('mobile_webview', 'アプリ内 WebView'),
  unknown('unknown', '不明な環境');

  const VoiceDevicePlatform(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;

  static VoiceDevicePlatform tryParse(String raw) {
    final String normalized = raw.trim();
    for (final VoiceDevicePlatform value in VoiceDevicePlatform.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return VoiceDevicePlatform.unknown;
  }
}

/// デバイス間同期ステータス。
enum VoiceSyncStatus {
  draftLocal('draft_local', 'ローカル下書き'),
  queuedOffline('queued_offline', 'オフライン保留'),
  synced('synced', '同期済み'),
  conflictResolved('conflict_resolved', '競合解決済み'),
  handedOff('handed_off', '他デバイス引継済み');

  const VoiceSyncStatus(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;

  static VoiceSyncStatus tryParse(String raw) {
    final String normalized = raw.trim();
    for (final VoiceSyncStatus value in VoiceSyncStatus.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return VoiceSyncStatus.draftLocal;
  }
}

/// 注入可能なプラットフォーム環境プローブ入力。ブラウザ固有 HTML API 非依存。
@immutable
class VoiceCapabilityProbeInput {
  const VoiceCapabilityProbeInput({
    required this.platform,
    required this.hasSpeechRecognition,
    required this.hasWebkitSpeechRecognition,
    required this.isStandalonePwa,
    this.isInAppWebView = false,
  });

  final VoiceDevicePlatform platform;
  final bool hasSpeechRecognition;
  final bool hasWebkitSpeechRecognition;
  final bool isStandalonePwa;
  final bool isInAppWebView;
}

/// Web Speech API 利用可否とフォールバック判定結果。
@immutable
class VoiceSpeechCapability {
  const VoiceSpeechCapability({
    required this.platform,
    required this.speechRecognitionAvailable,
    required this.usesWebkitPrefix,
    required this.isStandalonePwa,
    required this.requiresManualFallback,
    required this.environmentLabel,
    this.warningMessage,
  });

  final VoiceDevicePlatform platform;
  final bool speechRecognitionAvailable;
  final bool usesWebkitPrefix;
  final bool isStandalonePwa;
  final bool requiresManualFallback;
  final String environmentLabel;
  final String? warningMessage;
}

typedef VoiceCapabilityProbe = VoiceSpeechCapability Function();

/// MDN Web Speech API / Safari WebKit 制約に基づいた決定論的環境判定。
VoiceSpeechCapability evaluateVoiceEnvironment(
  VoiceCapabilityProbeInput input,
) {
  final bool hasAnySpeechApi =
      input.hasSpeechRecognition || input.hasWebkitSpeechRecognition;
  final bool usesWebkit =
      !input.hasSpeechRecognition && input.hasWebkitSpeechRecognition;

  if (input.isInAppWebView ||
      input.platform == VoiceDevicePlatform.mobileWebview) {
    return const VoiceSpeechCapability(
      platform: VoiceDevicePlatform.mobileWebview,
      speechRecognitionAvailable: false,
      usesWebkitPrefix: false,
      isStandalonePwa: false,
      requiresManualFallback: true,
      environmentLabel: 'アプリ内 WebView（音声入力制限環境）',
      warningMessage:
          'アプリ内 WebView / SafariViewController 環境では Web Speech API が不安定または非対応のため、手動テキスト入力フォールバックを使用します。',
    );
  }

  if (input.platform == VoiceDevicePlatform.iosPwaStandalone ||
      (input.platform == VoiceDevicePlatform.iosSafariTab &&
          input.isStandalonePwa)) {
    return VoiceSpeechCapability(
      platform: VoiceDevicePlatform.iosPwaStandalone,
      speechRecognitionAvailable: false,
      usesWebkitPrefix: usesWebkit,
      isStandalonePwa: true,
      requiresManualFallback: true,
      environmentLabel: 'iOS ホーム画面追加 PWA（Standalone）',
      warningMessage:
          'iOS ホーム画面 PWA（Standalone）では webkitSpeechRecognition や権限持続性が制限される場合があるため、手動テキスト入力フォールバックを優先有効化しています。',
    );
  }

  if (!hasAnySpeechApi) {
    return VoiceSpeechCapability(
      platform: input.platform,
      speechRecognitionAvailable: false,
      usesWebkitPrefix: false,
      isStandalonePwa: input.isStandalonePwa,
      requiresManualFallback: true,
      environmentLabel: '${input.platform.labelJa}（Web Speech 未検出）',
      warningMessage:
          '現在のブラウザ環境では SpeechRecognition API を利用できないため、手動テキスト入力でプロンプトを引き継ぎます。',
    );
  }

  if (input.platform == VoiceDevicePlatform.iosSafariTab || usesWebkit) {
    return VoiceSpeechCapability(
      platform: input.platform,
      speechRecognitionAvailable: true,
      usesWebkitPrefix: true,
      isStandalonePwa: input.isStandalonePwa,
      requiresManualFallback: false,
      environmentLabel: '${input.platform.labelJa}（webkitSpeechRecognition）',
      warningMessage:
          'WebKit 環境ではユーザージェスチャー同期起動・SpeechGrammar 非対応・<audio> 併用制約があるため、必要に応じて手動編集を併用してください。',
    );
  }

  return VoiceSpeechCapability(
    platform: input.platform,
    speechRecognitionAvailable: true,
    usesWebkitPrefix: false,
    isStandalonePwa: input.isStandalonePwa,
    requiresManualFallback: false,
    environmentLabel: '${input.platform.labelJa}（SpeechRecognition 標準対応）',
  );
}

/// クロスデバイスで同期する音声/プロンプト引き継ぎセッションモデル。
@immutable
class CrossDeviceVoiceSession {
  const CrossDeviceVoiceSession({
    required this.sessionKey,
    required this.sourceDevice,
    required this.browserEnvironment,
    required this.transcriptDraft,
    this.promptState = const <String, Object?>{},
    this.revision = 1,
    this.syncStatus = VoiceSyncStatus.draftLocal,
    this.updatedAtIso = '',
  });

  final String sessionKey;
  final VoiceDevicePlatform sourceDevice;
  final String browserEnvironment;
  final String transcriptDraft;
  final Map<String, Object?> promptState;
  final int revision;
  final VoiceSyncStatus syncStatus;
  final String updatedAtIso;

  CrossDeviceVoiceSession copyWith({
    VoiceDevicePlatform? sourceDevice,
    String? browserEnvironment,
    String? transcriptDraft,
    Map<String, Object?>? promptState,
    int? revision,
    VoiceSyncStatus? syncStatus,
    String? updatedAtIso,
  }) {
    return CrossDeviceVoiceSession(
      sessionKey: sessionKey,
      sourceDevice: sourceDevice ?? this.sourceDevice,
      browserEnvironment: browserEnvironment ?? this.browserEnvironment,
      transcriptDraft: transcriptDraft ?? this.transcriptDraft,
      promptState: promptState ?? this.promptState,
      revision: revision ?? this.revision,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'session_key': sessionKey,
      'source_device': sourceDevice.dbValue,
      'browser_environment': browserEnvironment,
      'transcript_draft': transcriptDraft,
      'prompt_state_json': promptState,
      'revision': revision,
      'sync_status': syncStatus.dbValue,
      'updated_at': updatedAtIso,
    };
  }

  Map<String, Object?> toUpsertPayload(String userId) {
    return <String, Object?>{
      'session_key': sessionKey,
      'user_id': userId,
      'source_device': sourceDevice.dbValue,
      'browser_environment': browserEnvironment,
      'transcript_draft': transcriptDraft,
      'prompt_state_json': promptState,
      'revision': revision,
      'sync_status': syncStatus.dbValue,
      'updated_at': updatedAtIso,
    };
  }

  static CrossDeviceVoiceSession fromJson(Map<String, Object?> json) {
    return CrossDeviceVoiceSession(
      sessionKey: _readString(json, 'session_key', fallback: 'default-handoff'),
      sourceDevice: VoiceDevicePlatform.tryParse(
        _readString(json, 'source_device', fallback: 'unknown'),
      ),
      browserEnvironment: _readString(
        json,
        'browser_environment',
        fallback: 'unknown',
      ),
      transcriptDraft: _readString(json, 'transcript_draft'),
      promptState: _readMap(json['prompt_state_json']),
      revision: _readInt(json, 'revision', fallback: 1),
      syncStatus: VoiceSyncStatus.tryParse(
        _readString(json, 'sync_status', fallback: 'synced'),
      ),
      updatedAtIso: _readString(json, 'updated_at'),
    );
  }

  static String _readString(
    Map<String, Object?> json,
    String key, {
    String fallback = '',
  }) {
    final Object? value = json[key];
    if (value == null) {
      return fallback;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int _readInt(
    Map<String, Object?> json,
    String key, {
    required int fallback,
  }) {
    final Object? value = json[key];
    if (value is int) {
      return value < 1 ? fallback : value;
    }
    if (value is num) {
      final int parsed = value.toInt();
      return parsed < 1 ? fallback : parsed;
    }
    if (value is String) {
      final int? parsed = int.tryParse(value.trim());
      if (parsed != null && parsed >= 1) {
        return parsed;
      }
    }
    return fallback;
  }

  static Map<String, Object?> _readMap(Object? raw) {
    if (raw is Map<Object?, Object?>) {
      final Map<String, Object?> result = <String, Object?>{};
      raw.forEach((Object? k, Object? v) {
        if (k != null) {
          result[k.toString()] = v;
        }
      });
      return Map<String, Object?>.unmodifiable(result);
    }
    return const <String, Object?>{};
  }
}

/// クロスデバイス音声セッション用オフラインキャッシュストア抽象。
abstract class VoiceSessionCacheStore {
  Future<void> writeSessionJson(String rawJson);
  Future<String?> readSessionJson();
}

/// `SharedPreferences` を用いた本番向けオフラインキャッシュストア。
class SharedPreferencesVoiceSessionCacheStore
    implements VoiceSessionCacheStore {
  const SharedPreferencesVoiceSessionCacheStore({
    this.storageKey = defaultStorageKey,
  });

  static const String defaultStorageKey = 'cross_device_voice_session_v1';

  final String storageKey;

  @override
  Future<String?> readSessionJson() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  @override
  Future<void> writeSessionJson(String rawJson) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, rawJson);
  }
}

/// テスト・オフライン動作検証用のメモリキャッシュストア。
class InMemoryVoiceSessionCacheStore implements VoiceSessionCacheStore {
  InMemoryVoiceSessionCacheStore([this._raw]);

  String? _raw;

  @override
  Future<String?> readSessionJson() async => _raw;

  @override
  Future<void> writeSessionJson(String rawJson) async {
    _raw = rawJson;
  }
}

typedef VoiceRemoteSyncFn = Future<CrossDeviceVoiceSession> Function(
  CrossDeviceVoiceSession session,
);

/// PWA 音声入力・手動フォールバック・Supabase クロスデバイス同期サービス。
class CrossDeviceVoiceSyncService extends ChangeNotifier {
  CrossDeviceVoiceSyncService({
    SupabaseClient Function()? clientResolver,
    VoiceSessionCacheStore? cacheStore,
    VoiceCapabilityProbe? capabilityProbe,
    VoiceRemoteSyncFn? remoteSync,
    CrossDeviceVoiceSession? initialSession,
  })  : _clientResolver = clientResolver,
        _cacheStore =
            cacheStore ?? const SharedPreferencesVoiceSessionCacheStore(),
        _capabilityProbe = capabilityProbe ?? _defaultCapabilityProbe,
        _remoteSync = remoteSync,
        _session = initialSession ??
            const CrossDeviceVoiceSession(
              sessionKey: 'default-pwa-handoff',
              sourceDevice: VoiceDevicePlatform.desktopWeb,
              browserEnvironment: 'unprobed',
              transcriptDraft: '',
            );

  final SupabaseClient Function()? _clientResolver;
  final VoiceSessionCacheStore _cacheStore;
  final VoiceCapabilityProbe _capabilityProbe;
  final VoiceRemoteSyncFn? _remoteSync;

  CrossDeviceVoiceSession _session;
  VoiceSpeechCapability? _baselineCapability;
  VoiceSpeechCapability? _cachedCapability;
  bool _isSyncing = false;
  bool _hasLocalUnsyncedEdit = false;
  String _statusMessage = '';
  String _conflictBanner = '';

  CrossDeviceVoiceSession get session => _session;
  VoiceSpeechCapability get capability =>
      _cachedCapability ??= (_baselineCapability ??= _capabilityProbe());
  bool get isSyncing => _isSyncing;
  bool get hasPendingOfflineSync =>
      _session.syncStatus == VoiceSyncStatus.queuedOffline;
  String get statusMessage => _statusMessage;
  String get conflictBanner => _conflictBanner;

  static VoiceSpeechCapability _defaultCapabilityProbe() {
    return evaluateVoiceEnvironment(
      VoiceCapabilityProbeInput(
        platform: kIsWeb
            ? VoiceDevicePlatform.desktopWeb
            : VoiceDevicePlatform.unknown,
        hasSpeechRecognition: false,
        hasWebkitSpeechRecognition: false,
        isStandalonePwa: false,
      ),
    );
  }

  void selectDevicePlatform(VoiceDevicePlatform platform) {
    final VoiceSpeechCapability baseline =
        _baselineCapability ??= _capabilityProbe();
    final VoiceSpeechCapability refreshed = evaluateVoiceEnvironment(
      VoiceCapabilityProbeInput(
        platform: platform,
        hasSpeechRecognition:
            baseline.speechRecognitionAvailable && !baseline.usesWebkitPrefix,
        hasWebkitSpeechRecognition: baseline.usesWebkitPrefix,
        isStandalonePwa: platform == VoiceDevicePlatform.iosPwaStandalone,
        isInAppWebView: platform == VoiceDevicePlatform.mobileWebview,
      ),
    );
    _cachedCapability = refreshed;
    _session = _session.copyWith(
      sourceDevice: platform,
      browserEnvironment: refreshed.environmentLabel,
    );
    notifyListeners();
  }

  Future<void> restoreCachedSession() async {
    final String? raw = await _cacheStore.readSessionJson();
    if (raw == null || raw.trim().isEmpty) {
      return;
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map<Object?, Object?>) {
      final Map<String, Object?> typed = <String, Object?>{};
      decoded.forEach((Object? k, Object? v) {
        if (k != null) {
          typed[k.toString()] = v;
        }
      });
      _session = CrossDeviceVoiceSession.fromJson(typed);
      notifyListeners();
    }
  }

  Future<bool> captureAndSync({
    required String transcriptDraft,
    required bool fromVoiceInput,
    String promptContextNote = '',
  }) async {
    final String cleaned = transcriptDraft.trim();
    if (cleaned.isEmpty) {
      _statusMessage = '引き継ぐプロンプトまたは文字起こし内容を入力してください。';
      notifyListeners();
      return false;
    }

    _hasLocalUnsyncedEdit = true;
    final VoiceSpeechCapability env = capability;
    final String nowIso = DateTime.now().toUtc().toIso8601String();
    final Map<String, Object?> nextPromptState = <String, Object?>{
      'capture_mode': fromVoiceInput ? 'web_speech' : 'manual_fallback',
      'requires_manual_fallback': env.requiresManualFallback,
      if (promptContextNote.trim().isNotEmpty)
        'context_note': promptContextNote.trim(),
    };

    final CrossDeviceVoiceSession candidate = _session.copyWith(
      sourceDevice: env.platform,
      browserEnvironment: env.environmentLabel,
      transcriptDraft: cleaned,
      promptState: Map<String, Object?>.unmodifiable(nextPromptState),
      revision: _session.revision + 1,
      syncStatus: VoiceSyncStatus.draftLocal,
      updatedAtIso: nowIso,
    );

    return _performSync(candidate);
  }

  Future<bool> retryPendingSync() async {
    if (!hasPendingOfflineSync) {
      return true;
    }
    return _performSync(_session);
  }

  /// Supabase Realtime 等から受信した他デバイスのセッション更新を適用する。
  void applyRemoteSnapshot(CrossDeviceVoiceSession remote) {
    if (remote.revision <= _session.revision) {
      return;
    }
    if (_hasLocalUnsyncedEdit && _session.transcriptDraft.isNotEmpty) {
      _conflictBanner = '他デバイス (${remote.sourceDevice.labelJa}) から新しいリビジョン '
          'Rev ${remote.revision} を受信したため、競合を解決して最新状態へ更新しました。';
      _session = remote.copyWith(syncStatus: VoiceSyncStatus.conflictResolved);
    } else {
      _conflictBanner = '';
      _session = remote.copyWith(syncStatus: VoiceSyncStatus.handedOff);
    }
    _hasLocalUnsyncedEdit = false;
    _statusMessage = 'Rev ${_session.revision} を引き継ぎました。';
    notifyListeners();
  }

  Future<bool> _performSync(CrossDeviceVoiceSession candidate) async {
    _isSyncing = true;
    _conflictBanner = '';
    notifyListeners();

    try {
      final CrossDeviceVoiceSession synced = await _pushToRemote(candidate);
      _session = synced.copyWith(syncStatus: VoiceSyncStatus.synced);
      _hasLocalUnsyncedEdit = false;
      _statusMessage =
          'Rev ${_session.revision} を Supabase へ同期しました (${_session.sourceDevice.labelJa})。';
      await _cacheStore.writeSessionJson(jsonEncode(_session.toJson()));
      return true;
    } catch (_) {
      _session = candidate.copyWith(syncStatus: VoiceSyncStatus.queuedOffline);
      _statusMessage = 'オフラインまたは同期エラーのためローカルキャッシュに退避しました。再同期してください。';
      await _cacheStore.writeSessionJson(jsonEncode(_session.toJson()));
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<CrossDeviceVoiceSession> _pushToRemote(
    CrossDeviceVoiceSession candidate,
  ) async {
    final VoiceRemoteSyncFn? customSync = _remoteSync;
    if (customSync != null) {
      return customSync(candidate);
    }
    final SupabaseClient? client = _resolveClientOrNull();
    final String? userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      return candidate;
    }
    final List<Map<String, Object?>> rows = await client
        .from('cross_device_voice_sessions')
        .upsert(
          candidate.toUpsertPayload(userId),
          onConflict: 'user_id,session_key',
        )
        .select();
    if (rows.isEmpty) {
      return candidate;
    }
    return CrossDeviceVoiceSession.fromJson(rows.first);
  }

  SupabaseClient? _resolveClientOrNull() {
    final SupabaseClient Function()? resolver = _clientResolver;
    if (resolver != null) {
      return resolver();
    }
    try {
      return Supabase.instance.client;
    } on AssertionError {
      return null;
    } catch (_) {
      return null;
    }
  }
}
