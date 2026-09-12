import 'dart:async';

import 'package:flutter/foundation.dart';

/// 保存状態の列挙型
enum SaveState {
  saved,
  saving,
  modified,
  error,
}

/// Debounced saves, manual saves and recovery operations share one FIFO lane.
/// This coordinates one editor instance, not cross-device database transactions.
class AutoSaveService extends ChangeNotifier {
  static const Duration _debounceDuration = Duration(seconds: 2);
  static const Duration _retryDelay = Duration(seconds: 5);
  Timer? _debounceTimer;
  Timer? _retryTimer;
  Future<void> Function()? _lastSaveCallback;
  Future<void> _tail = Future<void>.value();
  int _revision = 0;
  int _pendingOperations = 0;
  bool _closing = false;
  bool _disposed = false;

  SaveState _saveState = SaveState.saved;
  DateTime? _lastSavedTime;

  SaveState get saveState => _saveState;
  DateTime? get lastSavedTime => _lastSavedTime;
  bool get hasPendingOperations => _pendingOperations > 0;
  bool get _active => !_disposed && !_closing;

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    _pendingOperations++;
    final result = _tail.then((_) async {
      try {
        return await operation();
      } finally {
        _pendingOperations--;
      }
    });
    // A failed operation must reach its caller but not poison the next entry.
    _tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  void _cancelTimers() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
  }

  /// Serialize a recovery operation with saves. Do not enqueue another operation
  /// from inside this callback and await it: that would wait on itself.
  Future<T> runExclusive<T>(Future<T> Function() operation) => _enqueue(() {
        if (!_active) throw StateError('The editor save lane is closed');
        return operation();
      });

  /// Capture all required data before calling this during editor disposal.
  /// Only this final callback survives disposal; it must not access editor UI.
  Future<void> saveOnExit(Future<void> Function() saveCallback) {
    if (!_active) {
      return Future<void>.error(StateError('The editor save lane is closed'));
    }
    _closing = true;
    _revision++;
    _cancelTimers();
    _lastSaveCallback = null;
    return _enqueue(saveCallback);
  }

  /// 入力停止後2秒で保存。新しい編集は古い待機保存・再試行を失効させる。
  void triggerAutoSave(Future<void> Function() saveCallback) {
    if (!_active) return;
    final revision = ++_revision;
    _lastSaveCallback = saveCallback;
    _cancelTimers();
    _saveState = SaveState.modified;
    notifyListeners();
    _debounceTimer = Timer(_debounceDuration, () async {
      await _performSave(
        saveCallback,
        scheduleRetryOnError: true,
        scheduledRevision: revision,
      );
    });
  }

  /// 手動保存も先行リクエストの完了を待つ。失敗は呼び出し元へ伝える。
  Future<void> saveImmediately(Future<void> Function() saveCallback) async {
    if (!_active) throw StateError('The editor save lane is closed');
    _revision++;
    _lastSaveCallback = saveCallback;
    _cancelTimers();
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
    int? scheduledRevision,
  }) =>
      _enqueue(() async {
        if (!_active ||
            (scheduledRevision != null && scheduledRevision != _revision)) {
          return;
        }
        final revision = _revision;
        _saveState = SaveState.saving;
        notifyListeners();
        try {
          await saveCallback();
          if (_active &&
              revision == _revision &&
              _saveState != SaveState.modified) {
            _saveState = SaveState.saved;
            _lastSavedTime = DateTime.now();
            _retryTimer?.cancel();
          }
        } catch (_) {
          if (_active &&
              revision == _revision &&
              _saveState != SaveState.modified) {
            _saveState = SaveState.error;
            if (scheduleRetryOnError) _scheduleRetry(revision);
          }
          if (rethrowOnError) rethrow;
        } finally {
          if (_active) notifyListeners();
        }
      });

  void _scheduleRetry(int revision) {
    _retryTimer?.cancel();
    final callback = _lastSaveCallback;
    if (callback == null || !_active) return;
    _retryTimer = Timer(_retryDelay, () async {
      await _performSave(
        callback,
        scheduleRetryOnError: true,
        scheduledRevision: revision,
      );
    });
  }

  void markAsSaved() {
    if (!_active) return;
    _saveState = SaveState.saved;
    _lastSavedTime = DateTime.now();
    notifyListeners();
  }

  void markAsModified() {
    if (!_active) return;
    // Do not invalidate an already scheduled save for the latest draft.
    _saveState = SaveState.modified;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    _lastSaveCallback = null;
    super.dispose();
  }
}
