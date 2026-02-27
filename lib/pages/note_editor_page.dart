import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note_snapshot.dart';
import '../services/auto_save_service.dart';
import '../services/undo_redo_service.dart';
import '../widgets/note_editor/ai_assistant_menu.dart';

class NoteEditorPage extends StatefulWidget {
  final String? noteId;
  final String? initialTitle;
  final String? initialContent;

  const NoteEditorPage({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialContent,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late AutoSaveService _autoSaveService;
  late UndoRedoService _undoRedoService;

  String? _currentNoteId;
  bool _isLoading = false;
  bool _isApplyingSnapshot = false;
  static const String _draftKeyPrefix = 'note_editor_draft_';

  @override
  void initState() {
    super.initState();
    _currentNoteId = widget.noteId;
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
    _autoSaveService = AutoSaveService();
    _undoRedoService = UndoRedoService();

    _bootstrapEditor();
  }

  Future<void> _bootstrapEditor() async {
    if (_currentNoteId != null) {
      await _loadNote(_currentNoteId!);
    }
    await _restoreDraftFromLocal();
    _initializeEditorHistory();
    _attachTextListeners();
  }

  String _currentDraftKey() {
    return '$_draftKeyPrefix${_currentNoteId ?? 'new'}';
  }

  Future<void> _persistDraftToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final title = _titleController.text;
    final content = _contentController.text;
    if (title.trim().isEmpty && content.trim().isEmpty) {
      await prefs.remove(_currentDraftKey());
      return;
    }
    final payload = <String, dynamic>{
      'title': title,
      'content': content,
      'saved_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_currentDraftKey(), jsonEncode(payload));
  }

  Future<void> _restoreDraftFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentDraftKey());
    if (raw == null || raw.trim().isEmpty) return;

    String title;
    String content;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      title = (decoded['title'] ?? '').toString();
      content = (decoded['content'] ?? '').toString();
    } catch (_) {
      return;
    }
    if (title.isEmpty && content.isEmpty) return;

    final hasChanges =
        _titleController.text != title || _contentController.text != content;
    if (!hasChanges) return;

    _titleController.text = title;
    _contentController.text = content;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ローカル下書きを復元しました。')),
      );
    }
  }

  Future<void> _clearDraftFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentDraftKey());
  }

  void _attachTextListeners() {
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  void _detachTextListeners() {
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
  }

  NoteSnapshot _buildCurrentSnapshot() {
    return NoteSnapshot(
      title: _titleController.text,
      content: _contentController.text,
      categoryId: null,
      timestamp: DateTime.now(),
    );
  }

  void _initializeEditorHistory() {
    _undoRedoService.clear();
    _undoRedoService.addSnapshot(_buildCurrentSnapshot());

    final hasAnyInput = _titleController.text.trim().isNotEmpty ||
        _contentController.text.trim().isNotEmpty;
    if (_currentNoteId != null || !hasAnyInput) {
      _autoSaveService.markAsSaved();
    } else {
      _autoSaveService.markAsModified();
    }
  }

  void _onTextChanged() {
    if (_isApplyingSnapshot) return;
    _undoRedoService.addSnapshot(_buildCurrentSnapshot());
    _autoSaveService.triggerAutoSave(_saveNoteWithoutClosing);
    _persistDraftToLocal();
  }

  Future<void> _loadNote(String id) async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('notes')
          .select()
          .eq('id', id)
          .single();

      if (mounted) {
        setState(() {
          _titleController.text = data['title'] as String? ?? '';
          _contentController.text = data['content'] as String? ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('読み込みエラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNoteWithoutClosing() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('ログインが必要です');

    if (_currentNoteId != null) {
      await Supabase.instance.client.from('notes').update({
        'title': title,
        'content': content,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentNoteId!);
    } else {
      final dynamic inserted = await Supabase.instance.client
          .from('notes')
          .insert({
            'user_id': user.id,
            'title': title,
            'content': content,
            'is_archived': false,
            'is_pinned': false,
          })
          .select('id')
          .maybeSingle();

      if (inserted is Map && inserted['id'] != null) {
        _currentNoteId = inserted['id'].toString();
      }
    }

    _autoSaveService.markAsSaved();
    await _clearDraftFromLocal();
  }

  Future<void> _saveManually() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('タイトルまたは内容を入力してください')),
        );
      }
      return;
    }

    try {
      await _autoSaveService.saveImmediately(_saveNoteWithoutClosing);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存エラー: $e')),
        );
      }
    }
  }

  void _applySnapshot(NoteSnapshot snapshot) {
    _isApplyingSnapshot = true;
    _titleController.value = TextEditingValue(
      text: snapshot.title,
      selection: TextSelection.collapsed(offset: snapshot.title.length),
    );
    _contentController.value = TextEditingValue(
      text: snapshot.content,
      selection: TextSelection.collapsed(offset: snapshot.content.length),
    );
    _isApplyingSnapshot = false;

    _autoSaveService.triggerAutoSave(_saveNoteWithoutClosing);
  }

  void _undo() {
    final snapshot = _undoRedoService.undo();
    if (snapshot != null) {
      _applySnapshot(snapshot);
    }
  }

  void _redo() {
    final snapshot = _undoRedoService.redo();
    if (snapshot != null) {
      _applySnapshot(snapshot);
    }
  }

  String _formatTime(DateTime dateTime) {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _buildSaveStateIndicator() {
    return AnimatedBuilder(
      animation: _autoSaveService,
      builder: (context, _) {
        final state = _autoSaveService.saveState;
        final lastSaved = _autoSaveService.lastSavedTime;
        switch (state) {
          case SaveState.saved:
            final suffix =
                lastSaved != null ? '  最終保存: ${_formatTime(lastSaved)}' : '';
            return Text(
              '保存済み$suffix',
              style: const TextStyle(fontSize: 12, color: Colors.green),
            );
          case SaveState.saving:
            return const Text(
              '保存中...',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            );
          case SaveState.modified:
            return const Text(
              '未保存',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            );
          case SaveState.error:
            return const Text(
              '保存エラー',
              style: TextStyle(fontSize: 12, color: Colors.red),
            );
        }
      },
    );
  }

  Widget _buildEditorBody() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'タイトル',
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText: '内容を入力...',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  expands: true,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: AiAssistantMenu(
            contentController: _contentController,
            onApply: (text) => _contentController.text = text,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _detachTextListeners();
    _autoSaveService.dispose();
    _undoRedoService.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _currentNoteId != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEditing ? 'メモ編集' : '新規メモ'),
            _buildSaveStateIndicator(),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: _undoRedoService,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoRedoService.canUndo ? _undo : null,
              tooltip: '元に戻す (Ctrl+Z)',
            ),
          ),
          AnimatedBuilder(
            animation: _undoRedoService,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _undoRedoService.canRedo ? _redo : null,
              tooltip: 'やり直し (Ctrl+Y / Ctrl+Shift+Z)',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveManually,
            tooltip: '保存',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.keyZ, control: true):
                    _UndoIntent(),
                SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
                    _UndoIntent(),
                SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  control: true,
                  shift: true,
                ): _RedoIntent(),
                SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  meta: true,
                  shift: true,
                ): _RedoIntent(),
                SingleActivator(LogicalKeyboardKey.keyY, control: true):
                    _RedoIntent(),
                SingleActivator(LogicalKeyboardKey.keyY, meta: true):
                    _RedoIntent(),
                SingleActivator(LogicalKeyboardKey.keyS, control: true):
                    _SaveIntent(),
                SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                    _SaveIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _UndoIntent: CallbackAction<_UndoIntent>(
                    onInvoke: (_) {
                      _undo();
                      return null;
                    },
                  ),
                  _RedoIntent: CallbackAction<_RedoIntent>(
                    onInvoke: (_) {
                      _redo();
                      return null;
                    },
                  ),
                  _SaveIntent: CallbackAction<_SaveIntent>(
                    onInvoke: (_) {
                      _saveManually();
                      return null;
                    },
                  ),
                },
                child: Focus(
                  autofocus: true,
                  child: _buildEditorBody(),
                ),
              ),
            ),
    );
  }
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}
