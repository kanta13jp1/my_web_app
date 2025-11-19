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
  Timer? _debounceTimer;

  SaveState _saveState = SaveState.saved;
  DateTime? _lastSavedTime;

  SaveState get saveState => _saveState;
  DateTime? get lastSavedTime => _lastSavedTime;

  /// 自動保存のトリガー（デバウンス付き）
  /// 入力停止後2秒で自動保存を実行
  void triggerAutoSave(Future<void> Function() saveCallback) {
    // 既存のタイマーをキャンセル
    _debounceTimer?.cancel();

    // 状態を「未保存」に変更
    _saveState = SaveState.modified;
    notifyListeners();

    // 2秒後に保存
    _debounceTimer = Timer(_debounceDuration, () async {
      _saveState = SaveState.saving;
      notifyListeners();

      try {
        await saveCallback();
        _saveState = SaveState.saved;
        _lastSavedTime = DateTime.now();
      } catch (e) {
        _saveState = SaveState.error;
        if (kDebugMode) {
          debugPrint('💾 [AutoSaveService] Auto-save error: $e');
        }
      }

      notifyListeners();
    });
  }

  /// 即座に保存（手動保存ボタン用）
  Future<void> saveImmediately(Future<void> Function() saveCallback) async {
    _debounceTimer?.cancel();

    _saveState = SaveState.saving;
    notifyListeners();

    try {
      await saveCallback();
      _saveState = SaveState.saved;
      _lastSavedTime = DateTime.now();
    } catch (e) {
      _saveState = SaveState.error;
      if (kDebugMode) {
        debugPrint('💾 [AutoSaveService] Save error: $e');
      }
      rethrow;
    }

    notifyListeners();
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
    super.dispose();
  }
}
