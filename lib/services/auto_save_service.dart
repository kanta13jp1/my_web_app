import 'dart:async';
import 'package:flutter/foundation.dart';

/// 保存状態の列挙型
enum SaveState {
  saved, // 保存済み
  saving, // 保存中
  modified, // 未保存の変更あり
  error, // エラー
}

/// 自動保存サービス
/// デバウンス付きで自動保存を実現
class AutoSaveService extends ChangeNotifier {
  static const Duration _debounceDuration = Duration(seconds: 2);
  static const Duration _retryDelay = Duration(seconds: 5);
  Timer? _debounceTimer;
  Timer? _retryTimer;
  Future<void> Function()? _lastSaveCallback;

  SaveState _saveState = SaveState.saved;
  DateTime? _lastSavedTime;

  SaveState get saveState => _saveState;
  DateTime? get lastSavedTime => _lastSavedTime;

  /// 自動保存のトリガー（デバウンス付き）
  /// 入力停止後2秒で自動保存を実行
  void triggerAutoSave(Future<void> Function() saveCallback) {
    _lastSaveCallback = saveCallback;
    // 既存のタイマーをキャンセル
    _debounceTimer?.cancel();
    _retryTimer?.cancel();

    // 状態を「未保存」に変更
    _saveState = SaveState.modified;
    notifyListeners();

    // 2秒後に保存
    _debounceTimer = Timer(_debounceDuration, () async {
      await _performSave(
        saveCallback,
        scheduleRetryOnError: true,
      );
    });
  }

  /// 即座に保存（手動保存ボタン用）
  Future<void> saveImmediately(Future<void> Function() saveCallback) async {
    _lastSaveCallback = saveCallback;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();

    await _performSave(
      saveCallback,
      scheduleRetryOnError: false,
      rethrowOnError: true,
    );
  }

  Future<void> _performSave(
    Future<void> Function() saveCallback, {
    required bool scheduleRetryOnError,
    bool rethrowOnError = false,
  }) async {
    _saveState = SaveState.saving;
    notifyListeners();

    try {
      await saveCallback();
      _saveState = SaveState.saved;
      _lastSavedTime = DateTime.now();
      _retryTimer?.cancel();
    } catch (e) {
      _saveState = SaveState.error;
      if (kDebugMode) {
        debugPrint('💾 [AutoSaveService] Save error: $e');
      }
      if (scheduleRetryOnError) {
        _scheduleRetry();
      }
      if (rethrowOnError) {
        rethrow;
      }
    }

    notifyListeners();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final callback = _lastSaveCallback;
    if (callback == null) return;

    _retryTimer = Timer(_retryDelay, () async {
      await _performSave(
        callback,
        scheduleRetryOnError: true,
      );
    });
  }

  /// 保存状態を強制的に「保存済み」にリセット
  void markAsSaved() {
    _saveState = SaveState.saved;
    _lastSavedTime = DateTime.now();
    notifyListeners();
  }

  /// 保存状態を強制的に「未保存」にリセット
  void markAsModified() {
    _saveState = SaveState.modified;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
