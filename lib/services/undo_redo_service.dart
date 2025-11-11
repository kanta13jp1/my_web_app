import 'package:flutter/foundation.dart';
import '../models/note_snapshot.dart';

/// UNDO/REDO機能を提供するサービス
class UndoRedoService extends ChangeNotifier {
  static const int _maxHistorySize = 50;

  final List<NoteSnapshot> _history = [];
  int _currentIndex = -1;

  bool get canUndo => _currentIndex > 0;
  bool get canRedo => _currentIndex < _history.length - 1;

  /// 現在の履歴数を取得
  int get historyCount => _history.length;

  /// スナップショットを追加
  void addSnapshot(NoteSnapshot snapshot) {
    // 現在の位置より後の履歴を削除（新しい分岐）
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    // 前回と同じ内容なら追加しない
    if (_history.isNotEmpty && _history.last.isIdenticalTo(snapshot)) {
      if (kDebugMode) {
        print('↩️  [UndoRedoService] Skipping identical snapshot');
      }
      return;
    }

    // 履歴を追加
    _history.add(snapshot);
    _currentIndex++;

    if (kDebugMode) {
      print('📝 [UndoRedoService] Snapshot added: $_currentIndex/${_history.length - 1}');
    }

    // 履歴サイズ制限
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
      _currentIndex--;
      if (kDebugMode) {
        print('🗑️  [UndoRedoService] History trimmed to $_maxHistorySize');
      }
    }

    notifyListeners();
  }

  /// Undo（元に戻す）
  NoteSnapshot? undo() {
    if (!canUndo) {
      if (kDebugMode) {
        print('❌ [UndoRedoService] Cannot undo: at the beginning');
      }
      return null;
    }

    _currentIndex--;
    if (kDebugMode) {
      print('⬅️  [UndoRedoService] Undo to: $_currentIndex/${_history.length - 1}');
    }
    notifyListeners();
    return _history[_currentIndex];
  }

  /// Redo（やり直し）
  NoteSnapshot? redo() {
    if (!canRedo) {
      if (kDebugMode) {
        print('❌ [UndoRedoService] Cannot redo: at the end');
      }
      return null;
    }

    _currentIndex++;
    if (kDebugMode) {
      print('➡️  [UndoRedoService] Redo to: $_currentIndex/${_history.length - 1}');
    }
    notifyListeners();
    return _history[_currentIndex];
  }

  /// 現在のスナップショット
  NoteSnapshot? get currentSnapshot {
    if (_currentIndex >= 0 && _currentIndex < _history.length) {
      return _history[_currentIndex];
    }
    return null;
  }

  /// 履歴をクリア
  void clear() {
    _history.clear();
    _currentIndex = -1;
    if (kDebugMode) {
      print('🗑️  [UndoRedoService] History cleared');
    }
    notifyListeners();
  }
}
