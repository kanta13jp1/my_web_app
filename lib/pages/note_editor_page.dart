import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note_snapshot.dart';
import '../services/ai_service.dart';
import '../services/auto_save_service.dart';
import '../services/undo_redo_service.dart';
import '../widgets/note_editor/ai_assistant_menu.dart';
import '../widgets/note_editor/editor_dialogs.dart';

class NoteEditorPage extends StatefulWidget {
  final String? noteId;
  final String? initialTitle;
  final String? initialContent;
  final SupabaseClient? supabaseClient;
  final AIService? aiService;

  const NoteEditorPage({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialContent,
    this.supabaseClient,
    this.aiService,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _slashCommandController;
  late AutoSaveService _autoSaveService;
  late UndoRedoService _undoRedoService;
  late final SupabaseClient _supabase;
  late final AIService _aiService;

  String? _currentNoteId;
  DateTime? _reminderDate;
  bool _isFavorite = false;
  bool _isLoading = false;
  bool _isRunningSlashCommand = false;
  bool _isApplyingSnapshot = false;
  static const String _draftKeyPrefix = 'note_editor_draft_';
  static const List<String> _slashCommandSuggestions = <String>[
    '/help',
    '/improve',
    '/summarize',
    '/title',
    '/translate en',
    '/favorite',
    '/stamp',
  ];

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _aiService = widget.aiService ?? AIService(_supabase);
    _currentNoteId = widget.noteId;
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
    _slashCommandController = TextEditingController();
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

  bool get _hasPersistableState =>
      _titleController.text.trim().isNotEmpty ||
      _contentController.text.trim().isNotEmpty ||
      _reminderDate != null ||
      _isFavorite;

  bool _boolFromValue(dynamic value) => value == true;

  Future<void> _persistDraftToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final title = _titleController.text;
    final content = _contentController.text;
    if (!_hasPersistableState) {
      await prefs.remove(_currentDraftKey());
      return;
    }
    final payload = <String, dynamic>{
      'title': title,
      'content': content,
      'reminder_date': _reminderDate?.toIso8601String(),
      'is_favorite': _isFavorite,
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
    DateTime? reminderDate;
    bool isFavorite;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      title = (decoded['title'] ?? '').toString();
      content = (decoded['content'] ?? '').toString();
      reminderDate = decoded['reminder_date'] == null
          ? null
          : DateTime.tryParse(decoded['reminder_date'].toString())?.toLocal();
      isFavorite = _boolFromValue(decoded['is_favorite']);
    } catch (_) {
      return;
    }
    if (title.isEmpty &&
        content.isEmpty &&
        reminderDate == null &&
        !isFavorite) {
      return;
    }

    final hasChanges =
        _titleController.text != title ||
        _contentController.text != content ||
        _reminderDate?.toIso8601String() != reminderDate?.toIso8601String() ||
        _isFavorite != isFavorite;
    if (!hasChanges) return;

    _titleController.text = title;
    _contentController.text = content;
    _reminderDate = reminderDate;
    _isFavorite = isFavorite;

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
        _contentController.text.trim().isNotEmpty ||
        _reminderDate != null ||
        _isFavorite;
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

  void _handleReminderChanged(DateTime? reminderDate) {
    setState(() {
      _reminderDate = reminderDate?.toLocal();
    });
    _autoSaveService.markAsModified();
    _autoSaveService.triggerAutoSave(_saveNoteWithoutClosing);
    _persistDraftToLocal();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _setTitleText(String value) {
    _titleController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _setContentText(String value) {
    _contentController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _prefillSlashCommand(String command) {
    _slashCommandController.value = TextEditingValue(
      text: command,
      selection: TextSelection.collapsed(offset: command.length),
    );
  }

  String _formatCommandTimestamp(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  void _appendTimestampBlock() {
    final timestamp = '## ${_formatCommandTimestamp(DateTime.now().toLocal())}';
    final current = _contentController.text.trimRight();
    final nextContent = current.isEmpty ? timestamp : '$current\n\n$timestamp';
    _setContentText(nextContent);
  }

  Future<void> _showSlashCommandHelp() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Slash Commands'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('/help 使えるコマンド一覧を表示'),
            SizedBox(height: 8),
            Text('/improve 本文を読みやすく改善'),
            SizedBox(height: 8),
            Text('/summarize 本文を要約'),
            SizedBox(height: 8),
            Text('/title 本文からタイトル候補を生成'),
            SizedBox(height: 8),
            Text('/translate en 本文を指定言語へ翻訳'),
            SizedBox(height: 8),
            Text('/favorite ノートのお気に入りを切り替え'),
            SizedBox(height: 8),
            Text('/stamp 現在時刻の見出しを本文に追加'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _runSlashCommand() async {
    if (_isRunningSlashCommand) return;

    final rawInput = _slashCommandController.text.trim();
    if (rawInput.isEmpty) {
      _showMessage('スラッシュコマンドを入力してください');
      return;
    }
    if (!rawInput.startsWith('/')) {
      _showMessage('コマンドは / から始めてください');
      return;
    }

    final body = rawInput.substring(1).trim();
    if (body.isEmpty) {
      _showMessage('コマンド名を入力してください');
      return;
    }

    final parts = body.split(RegExp(r'\s+'));
    final command = parts.first.toLowerCase();
    final arguments = parts.skip(1).toList(growable: false);

    switch (command) {
      case 'help':
        await _showSlashCommandHelp();
        _slashCommandController.clear();
        return;
      case 'favorite':
      case 'fav':
      case 'star':
        _toggleFavorite();
        _slashCommandController.clear();
        return;
      case 'stamp':
      case 'date':
        _appendTimestampBlock();
        _slashCommandController.clear();
        _showMessage('タイムスタンプを追加しました');
        return;
      case 'clear':
        _setContentText('');
        _slashCommandController.clear();
        _showMessage('本文をクリアしました');
        return;
    }

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showMessage('本文が空のため、このコマンドは実行できません');
      return;
    }

    setState(() {
      _isRunningSlashCommand = true;
    });

    try {
      switch (command) {
        case 'improve':
          final improved = await _aiService.improveText(content);
          _setContentText(improved);
          _showMessage('本文を改善しました');
          break;
        case 'summarize':
        case 'summary':
          final summary = await _aiService.summarizeText(content);
          _setContentText(summary);
          _showMessage('本文を要約しました');
          break;
        case 'title':
          final suggestions = await _aiService.suggestTitles(content);
          if (suggestions.isEmpty) {
            _showMessage('タイトル候補を生成できませんでした');
            break;
          }
          _setTitleText(suggestions.first);
          _showMessage('タイトル候補を反映しました');
          break;
        case 'translate':
          final targetLanguage = arguments.isEmpty ? 'en' : arguments.join(' ');
          final translated = await _aiService.translateText(
            content,
            targetLanguage: targetLanguage,
          );
          _setContentText(translated);
          _showMessage('本文を $targetLanguage に翻訳しました');
          break;
        default:
          _showMessage('未対応のコマンドです: /$command');
          return;
      }
      _slashCommandController.clear();
    } catch (e) {
      _showMessage('コマンド実行に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRunningSlashCommand = false;
        });
      }
    }
  }

  Future<void> _loadNote(String id) async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('notes')
          .select('title, content, reminder_date, is_favorite')
          .eq('id', id)
          .single();

      if (mounted) {
        setState(() {
          _titleController.text = data['title'] as String? ?? '';
          _contentController.text = data['content'] as String? ?? '';
          _reminderDate = data['reminder_date'] == null
              ? null
              : DateTime.tryParse(
                    data['reminder_date'].toString(),
                  )?.toLocal();
          _isFavorite = _boolFromValue(data['is_favorite']);
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

    if (!_hasPersistableState && _currentNoteId == null) {
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('ログインが必要です');

    if (_currentNoteId != null) {
      await _supabase.from('notes').update({
        'title': title,
        'content': content,
        'reminder_date': _reminderDate?.toUtc().toIso8601String(),
        'is_favorite': _isFavorite,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentNoteId!);
    } else {
      final dynamic inserted = await _supabase
          .from('notes')
          .insert({
            'user_id': user.id,
            'title': title,
            'content': content,
            'reminder_date': _reminderDate?.toUtc().toIso8601String(),
            'is_favorite': _isFavorite,
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
    if (!_hasPersistableState && _currentNoteId == null) {
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

  void _toggleFavorite() {
    final nextValue = !_isFavorite;
    setState(() {
      _isFavorite = nextValue;
    });
    _autoSaveService.markAsModified();
    _persistDraftToLocal();
    if (_currentNoteId != null || _hasPersistableState) {
      _autoSaveService.triggerAutoSave(_saveNoteWithoutClosing);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextValue ? 'お気に入りに追加しました' : 'お気に入りを解除しました',
        ),
      ),
    );
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

  String _formatReminderDate(DateTime dateTime) =>
      '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${_formatTime(dateTime)}';

  Color _reminderColor(BuildContext context) {
    final reminderDate = _reminderDate;
    if (reminderDate == null) {
      return Theme.of(context).colorScheme.primary;
    }
    if (reminderDate.isBefore(DateTime.now())) {
      return Colors.red.shade700;
    }
    if (DateUtils.isSameDay(reminderDate, DateTime.now())) {
      return Colors.orange.shade700;
    }
    return Colors.teal.shade700;
  }

  Widget _buildReminderBanner(BuildContext context) {
    if (_reminderDate == null) {
      return const SizedBox.shrink();
    }

    final color = _reminderColor(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.alarm, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reminder: ${_formatReminderDate(_reminderDate!)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _handleReminderChanged(null),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
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

  Widget _buildSlashCommandChip(String command) {
    return ActionChip(
      label: Text(command),
      onPressed: _isRunningSlashCommand ? null : () => _prefillSlashCommand(command),
    );
  }

  Widget _buildSlashCommandBar(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline.withValues(alpha: 0.16);

    return Container(
      key: const Key('note_editor_slash_command_bar'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.terminal_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Claude Code-style slash commands',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('note_editor_slash_command_field'),
            controller: _slashCommandController,
            enabled: !_isRunningSlashCommand,
            onSubmitted: (_) => _runSlashCommand(),
            decoration: InputDecoration(
              hintText: '例: /summarize  または  /favorite',
              prefixIcon: const Icon(Icons.code_rounded),
              suffixIcon: _isRunningSlashCommand
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      key: const Key('note_editor_slash_command_run_button'),
                      onPressed: _runSlashCommand,
                      icon: const Icon(Icons.play_arrow_rounded),
                      tooltip: 'コマンドを実行',
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter で実行。よく使うコマンドをワンクリックで入力できます。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _slashCommandSuggestions
                .map(_buildSlashCommandChip)
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorBody() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildReminderBanner(context),
              _buildSlashCommandBar(context),
              TextField(
                key: const Key('note_editor_title_field'),
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
                  key: const Key('note_editor_content_field'),
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
    _slashCommandController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _currentNoteId != null;

    return Scaffold(
      key: const Key('note_editor_page_scaffold'),
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
            key: const Key('note_editor_page_favorite_button'),
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
            color: _isFavorite ? Colors.amber.shade700 : null,
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? 'お気に入り解除' : 'お気に入りに追加',
          ),
          IconButton(
            icon: Icon(
              _reminderDate == null
                  ? Icons.alarm_add_outlined
                  : Icons.alarm_on_outlined,
            ),
            onPressed: () => showReminderDialog(
              context: context,
              currentReminder: _reminderDate,
              onReminderSet: _handleReminderChanged,
            ),
            tooltip: 'Reminder',
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
