import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiShareButtonPosition { topLeft, topRight, bottomLeft, bottomRight }

/// AIシェア投稿に添付する動画の生成エンジン。
/// - [presenter]: Hedra のアバター lipsync 動画(従来動作 / 既定)。
/// - [cinematic]: fal.ai text-to-video によるシネマティック映像(顔・TTS 不要)。
enum AiShareVideoEngine { presenter, cinematic }

class AiShareButtonPreferences {
  static const AiShareButtonPosition defaultPosition =
      AiShareButtonPosition.bottomRight;
  static const AiShareVideoEngine defaultVideoEngine =
      AiShareVideoEngine.presenter;

  final bool visible;
  final AiShareButtonPosition position;
  final AiShareVideoEngine videoEngine;

  const AiShareButtonPreferences({
    this.visible = true,
    this.position = defaultPosition,
    this.videoEngine = defaultVideoEngine,
  });

  AiShareButtonPreferences copyWith({
    bool? visible,
    AiShareButtonPosition? position,
    AiShareVideoEngine? videoEngine,
  }) {
    return AiShareButtonPreferences(
      visible: visible ?? this.visible,
      position: position ?? this.position,
      videoEngine: videoEngine ?? this.videoEngine,
    );
  }
}

class AiShareButtonPreferencesService {
  static const String _visibleKey = 'ai_share_button_visible_v1';
  static const String _positionKey = 'ai_share_button_position_v1';
  static const String _videoEngineKey = 'ai_share_video_engine_v1';

  const AiShareButtonPreferencesService();

  Future<AiShareButtonPreferences> loadPreferences({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return AiShareButtonPreferences(
      visible: store.getBool(_visibleKey) ?? true,
      position: _positionFromStorage(store.getString(_positionKey)),
      videoEngine: _videoEngineFromStorage(store.getString(_videoEngineKey)),
    );
  }

  Future<AiShareButtonPreferences> savePreferences(
    AiShareButtonPreferences preferences, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setBool(_visibleKey, preferences.visible);
    await store.setString(
      _positionKey,
      _positionToStorage(preferences.position),
    );
    await store.setString(
      _videoEngineKey,
      _videoEngineToStorage(preferences.videoEngine),
    );
    return preferences;
  }

  Future<AiShareButtonPreferences> saveVisible(
    bool visible, {
    SharedPreferences? prefs,
  }) async {
    final current = await loadPreferences(prefs: prefs);
    return savePreferences(current.copyWith(visible: visible), prefs: prefs);
  }

  Future<AiShareButtonPreferences> savePosition(
    AiShareButtonPosition position, {
    SharedPreferences? prefs,
  }) async {
    final current = await loadPreferences(prefs: prefs);
    return savePreferences(current.copyWith(position: position), prefs: prefs);
  }

  Future<AiShareButtonPreferences> saveVideoEngine(
    AiShareVideoEngine videoEngine, {
    SharedPreferences? prefs,
  }) async {
    final current = await loadPreferences(prefs: prefs);
    return savePreferences(
      current.copyWith(videoEngine: videoEngine),
      prefs: prefs,
    );
  }

  static AiShareButtonPosition _positionFromStorage(String? value) {
    switch (value) {
      case 'top_left':
        return AiShareButtonPosition.topLeft;
      case 'top_right':
        return AiShareButtonPosition.topRight;
      case 'bottom_left':
        return AiShareButtonPosition.bottomLeft;
      case 'bottom_right':
        return AiShareButtonPosition.bottomRight;
      default:
        return AiShareButtonPreferences.defaultPosition;
    }
  }

  static String _positionToStorage(AiShareButtonPosition position) {
    switch (position) {
      case AiShareButtonPosition.topLeft:
        return 'top_left';
      case AiShareButtonPosition.topRight:
        return 'top_right';
      case AiShareButtonPosition.bottomLeft:
        return 'bottom_left';
      case AiShareButtonPosition.bottomRight:
        return 'bottom_right';
    }
  }

  static AiShareVideoEngine _videoEngineFromStorage(String? value) {
    switch (value) {
      case 'cinematic':
        return AiShareVideoEngine.cinematic;
      case 'presenter':
        return AiShareVideoEngine.presenter;
      default:
        return AiShareButtonPreferences.defaultVideoEngine;
    }
  }

  static String _videoEngineToStorage(AiShareVideoEngine engine) {
    switch (engine) {
      case AiShareVideoEngine.presenter:
        return 'presenter';
      case AiShareVideoEngine.cinematic:
        return 'cinematic';
    }
  }
}

class AiShareButtonPreferencesController extends ChangeNotifier {
  final AiShareButtonPreferencesService service;

  AiShareButtonPreferences _preferences = const AiShareButtonPreferences();
  Future<void>? _loadFuture;
  int _revision = 0;

  AiShareButtonPreferencesController({
    this.service = const AiShareButtonPreferencesService(),
  });

  AiShareButtonPreferences get preferences => _preferences;

  Future<void> load() {
    return _loadFuture ??= _loadPreferences();
  }

  Future<void> reload() {
    _loadFuture = _loadPreferences();
    return _loadFuture!;
  }

  Future<void> updateVisible(bool visible) {
    return updatePreferences(_preferences.copyWith(visible: visible));
  }

  Future<void> updatePosition(AiShareButtonPosition position) {
    return updatePreferences(_preferences.copyWith(position: position));
  }

  Future<void> updateVideoEngine(AiShareVideoEngine videoEngine) {
    return updatePreferences(_preferences.copyWith(videoEngine: videoEngine));
  }

  Future<void> updatePreferences(AiShareButtonPreferences next) async {
    final previous = _preferences;
    _revision += 1;
    _preferences = next;
    notifyListeners();

    try {
      await service.savePreferences(next);
      _loadFuture = Future<void>.value();
    } catch (_) {
      _preferences = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _loadPreferences() async {
    final revision = _revision;
    final loaded = await service.loadPreferences();
    if (revision != _revision) return;
    _preferences = loaded;
    notifyListeners();
  }
}

final aiShareButtonPreferencesController = AiShareButtonPreferencesController();
