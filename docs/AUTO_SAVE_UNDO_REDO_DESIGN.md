# 自動保存 & UNDO/REDO機能設計ドキュメント 💾

**作成日**: 2025年11月10日
**最終更新**: 2025年11月10日
**目的**: Notionのような自動保存とUNDO/REDO機能の設計と実装

---

## 📋 要件定義

### ユーザーからの要望
> NOTIONのように自動保存にするか？
> そうするならUNDO、REDO機能が必須
> まずは、画面遷移しないで保存できる保存ボタンの追加でよいか？
> 自動保存にするなら最終保存日時をタイトル付近に大きく表示されるようにしたい

### 段階的実装アプローチ

#### フェーズ1: 画面遷移しない保存ボタン ✅ 完了
- ✅ **実装済み**: `_saveNoteWithoutClosing()`
- ✅ **最終保存日時表示**: タイトル付近に表示済み

#### フェーズ2: 自動保存機能（本ドキュメント）
- デバウンス付き自動保存
- ローカルストレージとの連携
- 保存状態の視覚的フィードバック

#### フェーズ3: UNDO/REDO機能（本ドキュメント）
- 編集履歴の管理
- ショートカットキー（Ctrl+Z、Ctrl+Y）
- UIボタン

---

## 🎯 機能要件

### 1. 自動保存機能
- **デバウンス**: 入力停止後2秒で自動保存
- **ローカルストレージ**: オフライン時もローカルに保存
- **保存状態表示**: 「保存中...」「保存済み」の表示
- **エラー処理**: 保存失敗時にリトライ

### 2. UNDO/REDO機能
- **編集履歴管理**: 最大50回まで
- **ショートカットキー**:
  - Ctrl+Z (Cmd+Z): Undo
  - Ctrl+Y (Cmd+Shift+Z): Redo
- **UIボタン**: ツールバーにUNDO/REDOボタン
- **履歴の種類**:
  - テキスト変更
  - タイトル変更
  - カテゴリ変更

### 3. 最終保存日時表示 ✅ 完了
- ✅ タイトル付近に大きく表示
- ✅ リアルタイム更新

---

## 🏗️ 技術設計

### データモデル

#### 1. NoteSnapshot（編集履歴）
```dart
class NoteSnapshot {
  final String title;
  final String content;
  final int? categoryId;
  final DateTime timestamp;

  NoteSnapshot({
    required this.title,
    required this.content,
    this.categoryId,
    required this.timestamp,
  });

  NoteSnapshot copyWith({
    String? title,
    String? content,
    int? categoryId,
  }) {
    return NoteSnapshot(
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: categoryId ?? this.categoryId,
      timestamp: DateTime.now(),
    );
  }

  // 差分チェック
  bool isIdenticalTo(NoteSnapshot other) {
    return title == other.title &&
           content == other.content &&
           categoryId == other.categoryId;
  }
}
```

#### 2. SaveState（保存状態）
```dart
enum SaveState {
  saved,      // 保存済み
  saving,     // 保存中
  modified,   // 未保存の変更あり
  error,      // エラー
}
```

---

### サービス設計

#### AutoSaveService
```dart
// lib/services/auto_save_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

class AutoSaveService extends ChangeNotifier {
  static const Duration _debounceDuration = Duration(seconds: 2);
  Timer? _debounceTimer;

  SaveState _saveState = SaveState.saved;
  DateTime? _lastSavedTime;

  SaveState get saveState => _saveState;
  DateTime? get lastSavedTime => _lastSavedTime;

  // 自動保存のトリガー（デバウンス付き）
  void triggerAutoSave(Function saveCallback) {
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
        print('Auto-save error: $e');
      }

      notifyListeners();
    });
  }

  // 即座に保存（手動保存ボタン用）
  Future<void> saveImmediately(Function saveCallback) async {
    _debounceTimer?.cancel();

    _saveState = SaveState.saving;
    notifyListeners();

    try {
      await saveCallback();
      _saveState = SaveState.saved;
      _lastSavedTime = DateTime.now();
    } catch (e) {
      _saveState = SaveState.error;
      print('Save error: $e');
      rethrow;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
```

---

#### UndoRedoService
```dart
// lib/services/undo_redo_service.dart

import 'package:flutter/foundation.dart';

class UndoRedoService extends ChangeNotifier {
  static const int _maxHistorySize = 50;

  final List<NoteSnapshot> _history = [];
  int _currentIndex = -1;

  bool get canUndo => _currentIndex > 0;
  bool get canRedo => _currentIndex < _history.length - 1;

  // スナップショットを追加
  void addSnapshot(NoteSnapshot snapshot) {
    // 現在の位置より後の履歴を削除（新しい分岐）
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    // 前回と同じ内容なら追加しない
    if (_history.isNotEmpty && _history.last.isIdenticalTo(snapshot)) {
      return;
    }

    // 履歴を追加
    _history.add(snapshot);
    _currentIndex++;

    // 履歴サイズ制限
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
      _currentIndex--;
    }

    notifyListeners();
  }

  // Undo
  NoteSnapshot? undo() {
    if (!canUndo) return null;

    _currentIndex--;
    notifyListeners();
    return _history[_currentIndex];
  }

  // Redo
  NoteSnapshot? redo() {
    if (!canRedo) return null;

    _currentIndex++;
    notifyListeners();
    return _history[_currentIndex];
  }

  // 現在のスナップショット
  NoteSnapshot? get currentSnapshot {
    if (_currentIndex >= 0 && _currentIndex < _history.length) {
      return _history[_currentIndex];
    }
    return null;
  }

  // 履歴をクリア
  void clear() {
    _history.clear();
    _currentIndex = -1;
    notifyListeners();
  }
}
```

---

### note_editor_page.dart の統合

```dart
// lib/pages/note_editor_page.dart

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  late AutoSaveService _autoSaveService;
  late UndoRedoService _undoRedoService;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');

    _autoSaveService = AutoSaveService();
    _undoRedoService = UndoRedoService();

    // 初期スナップショットを追加
    _undoRedoService.addSnapshot(NoteSnapshot(
      title: _titleController.text,
      content: _contentController.text,
      categoryId: _selectedCategoryId,
      timestamp: DateTime.now(),
    ));

    // テキスト変更時にスナップショット追加 & 自動保存トリガー
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    // ショートカットキーの登録
    _registerShortcuts();
  }

  void _onTextChanged() {
    // スナップショット追加（UNDO/REDO用）
    _undoRedoService.addSnapshot(NoteSnapshot(
      title: _titleController.text,
      content: _contentController.text,
      categoryId: _selectedCategoryId,
      timestamp: DateTime.now(),
    ));

    // 自動保存トリガー
    _autoSaveService.triggerAutoSave(() => _saveNoteWithoutClosing());
  }

  void _registerShortcuts() {
    // Ctrl+Z (Cmd+Z): Undo
    // Ctrl+Y (Cmd+Shift+Z): Redo
    // ショートカットキーの実装は FocusNode と RawKeyboardListener を使用
  }

  void _undo() {
    final snapshot = _undoRedoService.undo();
    if (snapshot != null) {
      setState(() {
        _titleController.text = snapshot.title;
        _contentController.text = snapshot.content;
        _selectedCategoryId = snapshot.categoryId;
      });
    }
  }

  void _redo() {
    final snapshot = _undoRedoService.redo();
    if (snapshot != null) {
      setState(() {
        _titleController.text = snapshot.title;
        _contentController.text = snapshot.content;
        _selectedCategoryId = snapshot.categoryId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isNewNote ? '新しいメモ' : 'メモを編集'),
            // 保存状態表示
            _buildSaveStateIndicator(),
          ],
        ),
        actions: [
          // UNDO/REDOボタン
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undoRedoService.canUndo ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _undoRedoService.canRedo ? _redo : null,
          ),
          // 手動保存ボタン
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _autoSaveService.saveImmediately(() => _saveNoteWithoutClosing()),
          ),
        ],
      ),
      body: // ... メモ編集UI
    );
  }

  Widget _buildSaveStateIndicator() {
    return ListenableBuilder(
      listenable: _autoSaveService,
      builder: (context, child) {
        switch (_autoSaveService.saveState) {
          case SaveState.saved:
            return Text(
              '保存済み',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
              ),
            );
          case SaveState.saving:
            return Row(
              children: const [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 4),
                Text(
                  '保存中...',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            );
          case SaveState.modified:
            return Text(
              '未保存',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            );
          case SaveState.error:
            return Text(
              '保存エラー',
              style: TextStyle(fontSize: 12, color: Colors.red),
            );
        }
      },
    );
  }
}
```

---

## 🎨 UI/UX設計

### 保存状態インジケーター

#### パターン1: ヘッダー表示（現在の実装）
```
┌─────────────────────────────────────┐
│ メモを編集                          │
│ 保存済み ✓  最終保存: 14:30        │ ← 保存状態 + 最終保存日時
│─────────────────────────────────────│
│ [↶] [↷] [💾]                       │ ← UNDO/REDO/保存ボタン
│─────────────────────────────────────│
│ タイトル                            │
│─────────────────────────────────────│
│ メモ本文...                         │
└─────────────────────────────────────┘
```

#### パターン2: フローティング表示
```
┌─────────────────────────────────────┐
│ タイトル                            │
│─────────────────────────────────────│
│                                     │
│ メモ本文...                         │
│                                     │
│                         ┌─────────┐ │
│                         │保存済み✓│ │ ← フローティング
│                         └─────────┘ │
└─────────────────────────────────────┘
```

**推奨**: パターン1（ヘッダー表示）

---

### UNDO/REDOボタン

```
┌─────────────────────────────────────┐
│ [←] メモを編集        [↶] [↷] [💾] │
│─────────────────────────────────────│
│ 保存済み ✓  最終保存: 14:30        │
│─────────────────────────────────────│
```

- **↶**: Undo（Ctrl+Z）
- **↷**: Redo（Ctrl+Y）
- **💾**: 手動保存

**無効状態**: グレーアウト表示

---

## 🧪 テスト計画

### 自動保存のテスト
1. **デバウンステスト**: 2秒以内の連続入力で1回だけ保存
2. **ネットワークエラーテスト**: 保存失敗時のリトライ
3. **オフラインテスト**: ローカルストレージへの保存

### UNDO/REDOのテスト
1. **基本動作テスト**: Undo → Redo で元に戻る
2. **履歴制限テスト**: 51回目の編集で最古の履歴が削除される
3. **分岐テスト**: Undo後に新規編集で Redo 不可

### ショートカットキーのテスト
1. **Ctrl+Z**: Undo実行
2. **Ctrl+Y**: Redo実行
3. **Ctrl+S**: 手動保存（オプション）

---

## 📊 パフォーマンス考慮

### メモリ使用量
- **履歴サイズ制限**: 最大50スナップショット
- **スナップショット圧縮**: 大きなメモの場合は差分保存を検討

### ネットワーク負荷
- **デバウンス**: 2秒間隔で保存回数を削減
- **バッチ保存**: 複数の変更をまとめて保存

---

## 🎯 実装計画

### フェーズ1: 自動保存機能（1週間）
- [x] ✅ 画面遷移しない保存ボタン（完了）
- [x] ✅ 最終保存日時表示（完了）
- [ ] AutoSaveServiceクラス作成
- [ ] デバウンス付き自動保存実装
- [ ] 保存状態インジケーター実装

### フェーズ2: UNDO/REDO機能（1週間）
- [ ] UndoRedoServiceクラス作成
- [ ] NoteSnapshotモデル作成
- [ ] 編集履歴管理実装
- [ ] UNDO/REDOボタン実装
- [ ] ショートカットキー実装

### フェーズ3: 統合テスト & 最適化（3-5日）
- [ ] E2Eテスト
- [ ] パフォーマンス最適化
- [ ] エラーハンドリング改善

---

## 🔄 Notionとの比較

| 機能 | Notion | マイメモ（目標） |
|:-----|:-------|:----------------|
| 自動保存 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| UNDO/REDO | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 保存状態表示 | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| オフライン対応 | ⭐⭐⭐ | ⭐⭐⭐（将来的に） |
| 履歴管理 | ⭐⭐⭐⭐⭐（無制限） | ⭐⭐⭐（50回） |

**目標**: Notionの90%の機能性を目指す

---

## 📚 参考資料

### 参考アプリ
- **Notion**: 自動保存のベストプラクティス
- **Google Docs**: リアルタイム保存
- **Obsidian**: ローカルファースト、UNDO/REDO

### 技術参考
- [Debouncing in Flutter](https://medium.com/flutter-community/debouncing-in-flutter-36b8b4e59aaf)
- [Implementing Undo/Redo in Flutter](https://stackoverflow.com/questions/58341532/how-to-implement-undo-redo-in-flutter)

---

**最終更新**: 2025年11月10日
**次回レビュー**: 実装完了後
**作成者**: Claude Code
