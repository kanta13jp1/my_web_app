import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/note.dart';
import '../models/category.dart';
import '../widgets/markdown_preview.dart';
import '../models/attachment.dart';
import '../services/attachment_service.dart';
import '../widgets/attachment_list_widget.dart';
import '../services/gamification_service.dart';
import '../services/ai_service.dart';
import '../widgets/achievement_notification.dart';
import '../widgets/note_editor/editor_dialogs.dart' as editor_dialogs;
import '../widgets/note_editor/category_chip.dart';
import '../utils/date_formatter.dart';
import '../widgets/timer_setup_dialog.dart';
import 'package:provider/provider.dart';
import '../services/timer_service.dart';
import '../services/auto_save_service.dart';
import '../services/undo_redo_service.dart';
import '../models/note_snapshot.dart';
// ✅ 追加: デイリーチャレンジサービス
import '../services/daily_challenge_service.dart';

class NoteEditorPage extends StatefulWidget {
  final Note? note;
  final String? initialTitle;
  final String? initialContent;

  const NoteEditorPage({
    super.key,
    this.note,
    this.initialTitle,
    this.initialContent,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _isFavorite = false;
  DateTime? _reminderDate;
  bool _isPinned = false;
  int? _currentNoteId;
  DateTime? _lastSavedTime;

  // 添付ファイル関連
  List<Attachment> _attachments = [];
  bool _isLoadingAttachments = false;

  // 表示モード管理（タブの代わり）
  bool _isPreviewMode = false;

  // ゲーミフィケーション用
  late final GamificationService _gamificationService;
  // ✅ 追加: デイリーチャレンジ用
  late final DailyChallengeService _dailyChallengeService;

  // AI機能用
  late final AIService _aiService;
  bool _isAIProcessing = false;

  // 自動保存・UNDO/REDO用
  late final AutoSaveService _autoSaveService;
  late final UndoRedoService _undoRedoService;
  bool _isUndoRedoOperation = false;

  @override
  void initState() {
    super.initState();
    _gamificationService = GamificationService();
    // ✅ 追加: 初期化 (supabaseはmain.dartのgetter経由)
    _dailyChallengeService = DailyChallengeService(supabase);

    _aiService = AIService();
    _autoSaveService = AutoSaveService();
    _undoRedoService = UndoRedoService();

    _titleController = TextEditingController(
      text: widget.note?.title ?? widget.initialTitle ?? '',
    );
    _contentController = TextEditingController(
      text: widget.note?.content ?? widget.initialContent ?? '',
    );
    _selectedCategoryId = widget.note?.categoryId;
    _isFavorite = widget.note?.isFavorite ?? false;
    _reminderDate = widget.note?.reminderDate;
    _isPinned = widget.note?.isPinned ?? false;
    _currentNoteId = widget.note?.id;
    _lastSavedTime = widget.note?.updatedAt;
    _loadCategories();

    // 初期スナップショットを追加
    _undoRedoService.addSnapshot(
      NoteSnapshot(
        title: _titleController.text,
        content: _contentController.text,
        categoryId: _selectedCategoryId != null
            ? int.tryParse(_selectedCategoryId!)
            : null,
        timestamp: DateTime.now(),
      ),
    );

    // テキストコントローラーにリスナーを追加
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    // 添付ファイルを読み込み
    if (widget.note != null) {
      _loadAttachments();
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
    _titleController.dispose();
    _contentController.dispose();
    _autoSaveService.dispose();
    _undoRedoService.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_isUndoRedoOperation) return;

    _undoRedoService.addSnapshot(
      NoteSnapshot(
        title: _titleController.text,
        content: _contentController.text,
        categoryId: _selectedCategoryId != null
            ? int.tryParse(_selectedCategoryId!)
            : null,
        timestamp: DateTime.now(),
      ),
    );

    _autoSaveService.triggerAutoSave(() => _saveNoteWithoutClosing());
  }

  Future<void> _loadAttachments() async {
    if (widget.note == null) return;

    setState(() {
      _isLoadingAttachments = true;
    });

    try {
      final attachments =
          await AttachmentService.getAttachments(widget.note!.id);
      if (mounted) {
        setState(() {
          _attachments = attachments;
          _isLoadingAttachments = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingAttachments = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添付ファイルの読み込みエラー: $error')),
        );
      }
    }
  }

  Future<void> _attachFile() async {
    if (widget.note == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先にメモを保存してからファイルを添付してください')),
      );
      return;
    }

    try {
      final file = await AttachmentService.pickFile();
      if (file == null) return;

      final attachment = await AttachmentService.uploadFile(
        noteId: widget.note!.id,
        file: file,
      );

      if (mounted && attachment != null) {
        setState(() {
          _attachments.add(attachment);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ファイルを添付しました')),
        );

        final achievements = await _gamificationService.onAttachmentAdded(
          supabase.auth.currentUser!.id,
        );
        if (mounted) {
          _showAchievementNotifications(achievements);
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $error')),
        );
      }
    }
  }

  Future<void> _deleteAttachment(Attachment attachment) async {
    try {
      await AttachmentService.deleteAttachment(attachment);

      if (mounted) {
        setState(() {
          _attachments.removeWhere((a) => a.id == attachment.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('添付ファイルを削除しました')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除エラー: $error')),
        );
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('name', ascending: true);

      if (!mounted) return;

      setState(() {
        _categories = (response as List)
            .map((category) => Category.fromJson(category))
            .toList();
      });
    } catch (error) {
      // カテゴリがなくても動作可能
    }
  }

  void _undo() {
    final snapshot = _undoRedoService.undo();
    if (snapshot != null) {
      _isUndoRedoOperation = true;
      setState(() {
        _titleController.text = snapshot.title;
        _contentController.text = snapshot.content;
        _selectedCategoryId = snapshot.categoryId?.toString();
      });
      _isUndoRedoOperation = false;
    }
  }

  void _redo() {
    final snapshot = _undoRedoService.redo();
    if (snapshot != null) {
      _isUndoRedoOperation = true;
      setState(() {
        _titleController.text = snapshot.title;
        _contentController.text = snapshot.content;
        _selectedCategoryId = snapshot.categoryId?.toString();
      });
      _isUndoRedoOperation = false;
    }
  }

  Future<void> _saveNoteWithoutClosing() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final isNewNote = _currentNoteId == null;
      final wasNotFavorite = widget.note?.isFavorite == false;
      final hadNoReminder = widget.note?.reminderDate == null;

      if (isNewNote) {
        final insertedData = await supabase.from('notes').insert({
          'user_id': userId,
          'title': _titleController.text,
          'content': _contentController.text,
          'category_id': _selectedCategoryId,
          'is_favorite': _isFavorite,
          'reminder_date': _reminderDate?.toIso8601String(),
          'is_pinned': _isPinned,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).select();

        if (insertedData.isNotEmpty) {
          _currentNoteId = insertedData[0]['id'];
        }

        final achievements = await _gamificationService.onNoteCreated(userId);
        if (mounted) {
          _showAchievementNotifications(achievements);
        }

        // 🔥 ✅ 追加: デイリーチャレンジ「メモ作成」の進捗を進める
        try {
          // 'create_notes' はDBの daily_challenges テーブルの challenge_type と一致させる
          await _dailyChallengeService.updateProgress(userId, 'create_notes');
        } catch (e) {
          debugPrint('Error updating daily challenge: $e');
        }

        if (_isFavorite) {
          final favAchievements =
              await _gamificationService.onNoteFavorited(userId);
          if (mounted) {
            _showAchievementNotifications(favAchievements);
          }
        }
        if (_reminderDate != null) {
          final reminderAchievements =
              await _gamificationService.onReminderSet(userId);
          if (mounted) {
            _showAchievementNotifications(reminderAchievements);
          }
        }
      } else {
        await supabase.from('notes').update({
          'title': _titleController.text,
          'content': _contentController.text,
          'category_id': _selectedCategoryId,
          'is_favorite': _isFavorite,
          'reminder_date': _reminderDate?.toIso8601String(),
          'is_pinned': _isPinned,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _currentNoteId!);

        if (_isFavorite && wasNotFavorite) {
          final achievements =
              await _gamificationService.onNoteFavorited(userId);
          if (mounted) {
            _showAchievementNotifications(achievements);
          }
        }

        if (_reminderDate != null && hadNoReminder) {
          final achievements = await _gamificationService.onReminderSet(userId);
          if (mounted) {
            _showAchievementNotifications(achievements);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _lastSavedTime = DateTime.now();
      });

      _autoSaveService.markAsSaved();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 保存しました'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  Future<void> _saveNote() async {
    // 閉じる前の保存処理
    await _saveNoteWithoutClosing();
    if (mounted) Navigator.pop(context);
  }

  void _showAchievementNotifications(List<dynamic> achievements) {
    for (final achievement in achievements) {
      AchievementNotification.show(
        context: context,
        achievement: achievement,
      );
    }
  }

  Future<void> _showReminderDialog() async {
    await editor_dialogs.showReminderDialog(
      context: context,
      currentReminder: _reminderDate,
      onReminderSet: (date) {
        setState(() {
          _reminderDate = date;
        });
      },
    );
  }

  void _showCategoryDialog() {
    editor_dialogs.showCategoryDialog(
      context: context,
      categories: _categories,
      selectedCategoryId: _selectedCategoryId,
      onCategorySelected: (categoryId) {
        setState(() {
          _selectedCategoryId = categoryId;
        });
      },
    );
  }

  Widget _buildCategoryChip() {
    return CategoryChip(
      categories: _categories,
      selectedCategoryId: _selectedCategoryId,
      onTap: _showCategoryDialog,
    );
  }

  void _showMarkdownHelp() {
    editor_dialogs.showMarkdownHelp(context);
  }

  Future<void> _showTimerDialog() async {
    final timerService = Provider.of<TimerService>(context, listen: false);

    if (timerService.hasActiveTimer) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('タイマー実行中'),
          content: const Text('既に実行中のタイマーがあります。新しいタイマーを開始しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('開始'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TimerSetupDialog(
        noteId: _currentNoteId,
      ),
    );

    if (result == null) return;

    try {
      await timerService.startTimer(
        name: result['name'] as String,
        durationSeconds: result['durationSeconds'] as int,
        noteId: _currentNoteId,
        soundNotification: result['soundNotification'] as bool,
        browserNotification: result['browserNotification'] as bool,
        autoSave: result['autoSave'] as bool,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('タイマーを開始しました: ${result['name']}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('タイマーの開始に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAIMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🤖 AI アシスタント',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.auto_fix_high, color: Colors.purple),
              title: const Text('文章を改善'),
              onTap: () {
                Navigator.pop(context);
                _improveText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize, color: Colors.blue),
              title: const Text('要約を生成'),
              onTap: () {
                Navigator.pop(context);
                _summarizeText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.expand, color: Colors.green),
              title: const Text('文章を展開'),
              onTap: () {
                Navigator.pop(context);
                _expandText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate, color: Colors.orange),
              title: const Text('英語に翻訳'),
              onTap: () {
                Navigator.pop(context);
                _translateText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.title, color: Colors.red),
              title: const Text('タイトルを提案'),
              onTap: () {
                Navigator.pop(context);
                _suggestTitle();
              },
            ),
            ListTile(
              leading: const Icon(Icons.label, color: Colors.teal),
              title: const Text('タグ・カテゴリを提案'),
              onTap: () {
                Navigator.pop(context);
                _suggestTags();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatAIError(dynamic error) {
    if (error is AIServiceException) {
      if (error.isRateLimitError) {
        return 'AI機能の使用制限に達しました。';
      }
      return error.message;
    }
    return 'AI処理に失敗しました。';
  }

  Future<void> _improveText() async {
    if (_contentController.text.isEmpty) return;
    setState(() => _isAIProcessing = true);
    try {
      final improvedText =
          await _aiService.improveText(_contentController.text);
      if (mounted) {
        setState(() {
          _contentController.text = improvedText;
          _isAIProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ 文章を改善しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAIProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatAIError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _summarizeText() async {
    if (_contentController.text.isEmpty) return;
    setState(() => _isAIProcessing = true);
    try {
      final summary = await _aiService.summarizeText(_contentController.text);
      if (mounted) {
        setState(() {
          _contentController.text = summary;
          _isAIProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📝 要約を生成しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAIProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatAIError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _expandText() async {
    if (_contentController.text.isEmpty) return;
    setState(() => _isAIProcessing = true);
    try {
      final expandedText = await _aiService.expandText(_contentController.text);
      if (mounted) {
        setState(() {
          _contentController.text = expandedText;
          _isAIProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📝 文章を展開しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAIProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatAIError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _translateText() async {
    if (_contentController.text.isEmpty) return;
    setState(() => _isAIProcessing = true);
    try {
      final translatedText = await _aiService.translateText(
        _contentController.text,
        targetLanguage: 'en',
      );
      if (mounted) {
        setState(() {
          _contentController.text = translatedText;
          _isAIProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🌐 英語に翻訳しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAIProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatAIError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _suggestTitle() async {
    if (_contentController.text.isEmpty) return;
    setState(() => _isAIProcessing = true);
    try {
      final titles = await _aiService.suggestTitles(_contentController.text);
      if (mounted) {
        setState(() => _isAIProcessing = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('💡 タイトル提案'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: titles.map((title) {
                return ListTile(
                  title: Text(title),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _titleController.text = title;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAIProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatAIError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _suggestTags() async {
    if (_contentController.text.isEmpty) return;
    setState(() => _isAIProcessing = true);
    try {
      final suggestion = await _aiService.suggestTags(
        content: _contentController.text,
        title: _titleController.text,
        existingCategories: _categories.map((c) => c.name).toList(),
      );
      if (mounted) {
        setState(() => _isAIProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('推奨カテゴリ: ${suggestion.category}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAIProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatAIError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNoteInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'メモ情報',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('カテゴリ', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildCategoryChip(),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('変更'),
                  onPressed: _showCategoryDialog,
                ),
              ],
            ),
            const Divider(),
            if (_lastSavedTime != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '最終保存: ${DateFormatter.formatDateTime(_lastSavedTime!)}',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text('リマインダー', style: TextStyle(color: Colors.grey)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _reminderDate != null ? Icons.alarm : Icons.alarm_add,
                color: _reminderDate != null ? Colors.orange : null,
              ),
              title: Text(
                _reminderDate != null
                    ? DateFormatter.formatReminder(_reminderDate!)
                    : '未設定',
              ),
              trailing: _reminderDate != null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _reminderDate = null;
                        });
                        Navigator.pop(context);
                      },
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                _showReminderDialog();
              },
            ),
            const Divider(),
            const Text('添付ファイル', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            if (_isLoadingAttachments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_attachments.isEmpty)
              const Text('なし', style: TextStyle(color: Colors.grey))
            else
              AttachmentListWidget(
                attachments: _attachments,
                onDelete: _deleteAttachment,
                isEditing: true,
              ),
            TextButton.icon(
              icon: const Icon(Icons.attach_file),
              label: const Text('ファイルを追加'),
              onPressed: () {
                Navigator.pop(context);
                _attachFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveStateIndicator() {
    return ListenableBuilder(
      listenable: _autoSaveService,
      builder: (context, child) {
        switch (_autoSaveService.saveState) {
          case SaveState.saved:
            return const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 16,
            );
          case SaveState.saving:
            return const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          case SaveState.modified:
            return const Icon(Icons.edit, color: Colors.orange, size: 16);
          case SaveState.error:
            return const Icon(Icons.error, color: Colors.red, size: 16);
        }
      },
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: _isPinned ? Colors.amber : null,
              ),
              title: Text(_isPinned ? 'ピン留めを解除' : 'ピン留め'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isPinned = !_isPinned;
                });
              },
            ),
            ListTile(
              leading: Icon(
                Icons.timer,
                color: Provider.of<TimerService>(context, listen: true)
                        .hasActiveTimer
                    ? Colors.blue
                    : Colors.green,
              ),
              title: const Text('タイマー（ポモドーロ）'),
              subtitle: Provider.of<TimerService>(context, listen: true)
                      .hasActiveTimer
                  ? const Text('実行中')
                  : null,
              onTap: () {
                Navigator.pop(context);
                _showTimerDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('マークダウン記法ヘルプ'),
              onTap: () {
                Navigator.pop(context);
                _showMarkdownHelp();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('メモの詳細情報'),
              onTap: () {
                Navigator.pop(context);
                _showNoteInfo();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if ((event.logicalKey == LogicalKeyboardKey.keyZ) &&
              (HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed) &&
              !HardwareKeyboard.instance.isShiftPressed) {
            _undo();
          } else if (((event.logicalKey == LogicalKeyboardKey.keyY) &&
                  (HardwareKeyboard.instance.isControlPressed ||
                      HardwareKeyboard.instance.isMetaPressed)) ||
              ((event.logicalKey == LogicalKeyboardKey.keyZ) &&
                  (HardwareKeyboard.instance.isControlPressed ||
                      HardwareKeyboard.instance.isMetaPressed) &&
                  HardwareKeyboard.instance.isShiftPressed)) {
            _redo();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.note == null ? '新規メモ' : '編集',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (_lastSavedTime != null)
                      Text(
                        DateFormatter.formatDateTime(_lastSavedTime!),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              _buildSaveStateIndicator(),
              const SizedBox(width: 8),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isPreviewMode
                    ? Icons.edit_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() {
                  _isPreviewMode = !_isPreviewMode;
                });
              },
              tooltip: _isPreviewMode ? '編集モード' : 'プレビュー',
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showNoteInfo,
              tooltip: 'メモ情報',
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showMoreMenu,
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveNote,
              tooltip: '保存して閉じる',
            ),
          ],
        ),
        body: _isPreviewMode
            ? MarkdownPreview(
                data: '${_titleController.text}\n\n${_contentController.text}',
                selectable: true,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'タイトル',
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: TextField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          hintText: 'メモを入力...',
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: BottomAppBar(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ListenableBuilder(
                listenable: _undoRedoService,
                builder: (context, child) => IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: _undoRedoService.canUndo ? _undo : null,
                  tooltip: 'Undo',
                ),
              ),
              ListenableBuilder(
                listenable: _undoRedoService,
                builder: (context, child) => IconButton(
                  icon: const Icon(Icons.redo),
                  onPressed: _undoRedoService.canRedo ? _redo : null,
                  tooltip: 'Redo',
                ),
              ),
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  color: _isFavorite ? Colors.amber : null,
                ),
                onPressed: () {
                  setState(() {
                    _isFavorite = !_isFavorite;
                  });
                },
              ),
              if (_isAIProcessing)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: Colors.purple),
                  onPressed: _showAIMenu,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
