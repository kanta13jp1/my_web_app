import 'package:flutter/material.dart';
import '../main.dart';
import '../models/note.dart';
import '../models/category.dart';
import '../widgets/markdown_preview.dart';
import '../models/attachment.dart'; // 追加
import '../services/attachment_service.dart'; // 追加
import '../widgets/attachment_list_widget.dart'; // 追加
import '../services/gamification_service.dart'; // ゲーミフィケーション追加
import '../services/ai_service.dart'; // AI機能追加
import '../widgets/achievement_notification.dart'; // 実績通知追加
import '../widgets/note_editor/editor_dialogs.dart' as editor_dialogs;
import '../widgets/note_editor/category_chip.dart';
import '../utils/date_formatter.dart';

class NoteEditorPage extends StatefulWidget {
  final Note? note;
  final String? initialTitle;
  final String? initialContent;

  const NoteEditorPage({super.key, this.note, this.initialTitle, this.initialContent});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _isFavorite = false;
  DateTime? _reminderDate;
  bool _isPinned = false;

  // 添付ファイル関連（追加）
  List<Attachment> _attachments = [];
  bool _isLoadingAttachments = false;
  bool _isUploadingFile = false;

  // マークダウン関連
  late TabController _tabController;

  // ゲーミフィケーション用
  late final GamificationService _gamificationService;

  // AI機能用
  late final AIService _aiService;
  bool _isAIProcessing = false;

  @override
  void initState() {
    super.initState();
    _gamificationService = GamificationService();
    _aiService = AIService();
    _titleController = TextEditingController(text: widget.note?.title ?? widget.initialTitle ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? widget.initialContent ?? '');
    _selectedCategoryId = widget.note?.categoryId;
    _isFavorite = widget.note?.isFavorite ?? false;
    _reminderDate = widget.note?.reminderDate;
    _isPinned = widget.note?.isPinned ?? false; // ← ?を追加してnull安全に
    _loadCategories();

    // タブコントローラーを初期化
    _tabController = TabController(length: 2, vsync: this);

    // 添付ファイルを読み込み（追加）
    if (widget.note != null) {
      _loadAttachments();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tabController.dispose();
    super.dispose();
  }

// 添付ファイルを読み込み
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

// ファイルを添付
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

      setState(() {
        _isUploadingFile = true;
      });

      final attachment = await AttachmentService.uploadFile(
        noteId: widget.note!.id,
        file: file,
      );

      if (mounted && attachment != null) {
        setState(() {
          _attachments.add(attachment);
          _isUploadingFile = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ファイルを添付しました')),
        );

        // ゲーミフィケーション: 添付ファイル追加イベント
        final achievements = await _gamificationService.onAttachmentAdded(
          supabase.auth.currentUser!.id,
        );
        if (mounted) {
          _showAchievementNotifications(achievements);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $error')),
        );
      }
    }
  }

// 添付ファイルを削除
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

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = (response as List)
            .map((category) => Category.fromJson(category))
            .toList();
      });
    } catch (error) {
      // カテゴリがなくても動作可能
    }
  }

  // 保存（画面を閉じない）
  Future<void> _saveNoteWithoutClosing() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final isNewNote = widget.note == null;
      final wasNotFavorite = widget.note?.isFavorite == false;
      final hadNoReminder = widget.note?.reminderDate == null;

      if (isNewNote) {
        // 新規作成
        await supabase.from('notes').insert({
          'user_id': userId,
          'title': _titleController.text,
          'content': _contentController.text,
          'category_id': _selectedCategoryId,
          'is_favorite': _isFavorite,
          'reminder_date': _reminderDate?.toIso8601String(),
          'is_pinned': _isPinned,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // ゲーミフィケーション: メモ作成イベント
        final achievements = await _gamificationService.onNoteCreated(userId);
        if (mounted) {
          _showAchievementNotifications(achievements);
        }

        // 初回のお気に入りまたはリマインダー設定
        if (_isFavorite) {
          final favAchievements = await _gamificationService.onNoteFavorited(userId);
          if (mounted) {
            _showAchievementNotifications(favAchievements);
          }
        }
        if (_reminderDate != null) {
          final reminderAchievements = await _gamificationService.onReminderSet(userId);
          if (mounted) {
            _showAchievementNotifications(reminderAchievements);
          }
        }
      } else {
        // 更新
        await supabase.from('notes').update({
          'title': _titleController.text,
          'content': _contentController.text,
          'category_id': _selectedCategoryId,
          'is_favorite': _isFavorite,
          'reminder_date': _reminderDate?.toIso8601String(),
          'is_pinned': _isPinned,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.note!.id);

        // お気に入りが新たに設定された場合
        if (_isFavorite && wasNotFavorite) {
          final achievements = await _gamificationService.onNoteFavorited(userId);
          if (mounted) {
            _showAchievementNotifications(achievements);
          }
        }

        // リマインダーが新たに設定された場合
        if (_reminderDate != null && hadNoReminder) {
          final achievements = await _gamificationService.onReminderSet(userId);
          if (mounted) {
            _showAchievementNotifications(achievements);
          }
        }
      }

      if (!mounted) return;

      // 保存完了メッセージを表示（画面は閉じない）
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

  // 保存して閉じる
  Future<void> _saveNote() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final isNewNote = widget.note == null;
      final wasNotFavorite = widget.note?.isFavorite == false;
      final hadNoReminder = widget.note?.reminderDate == null;

      if (isNewNote) {
        // 新規作成
        await supabase.from('notes').insert({
          'user_id': userId,
          'title': _titleController.text,
          'content': _contentController.text,
          'category_id': _selectedCategoryId,
          'is_favorite': _isFavorite,
          'reminder_date': _reminderDate?.toIso8601String(),
          'is_pinned': _isPinned,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // ゲーミフィケーション: メモ作成イベント
        final achievements = await _gamificationService.onNoteCreated(userId);
        if (mounted) {
          _showAchievementNotifications(achievements);
        }

        // 初回のお気に入りまたはリマインダー設定
        if (_isFavorite) {
          final favAchievements = await _gamificationService.onNoteFavorited(userId);
          if (mounted) {
            _showAchievementNotifications(favAchievements);
          }
        }
        if (_reminderDate != null) {
          final reminderAchievements = await _gamificationService.onReminderSet(userId);
          if (mounted) {
            _showAchievementNotifications(reminderAchievements);
          }
        }
      } else {
        // 更新
        await supabase.from('notes').update({
          'title': _titleController.text,
          'content': _contentController.text,
          'category_id': _selectedCategoryId,
          'is_favorite': _isFavorite,
          'reminder_date': _reminderDate?.toIso8601String(),
          'is_pinned': _isPinned,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.note!.id);

        // お気に入りが新たに設定された場合
        if (_isFavorite && wasNotFavorite) {
          final achievements = await _gamificationService.onNoteFavorited(userId);
          if (mounted) {
            _showAchievementNotifications(achievements);
          }
        }

        // リマインダーが新たに設定された場合
        if (_reminderDate != null && hadNoReminder) {
          final achievements = await _gamificationService.onReminderSet(userId);
          if (mounted) {
            _showAchievementNotifications(achievements);
          }
        }
      }

      if (!mounted) return;

      Navigator.pop(context);
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  // 実績通知を表示
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

  // AI機能メニューを表示
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
              subtitle: const Text('より明確で読みやすい文章に改善します'),
              onTap: () {
                Navigator.pop(context);
                _improveText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize, color: Colors.blue),
              title: const Text('要約を生成'),
              subtitle: const Text('長い文章を簡潔に要約します'),
              onTap: () {
                Navigator.pop(context);
                _summarizeText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.expand, color: Colors.green),
              title: const Text('文章を展開'),
              subtitle: const Text('短い文章を詳しく展開します'),
              onTap: () {
                Navigator.pop(context);
                _expandText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate, color: Colors.orange),
              title: const Text('英語に翻訳'),
              subtitle: const Text('文章を英語に翻訳します'),
              onTap: () {
                Navigator.pop(context);
                _translateText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.title, color: Colors.red),
              title: const Text('タイトルを提案'),
              subtitle: const Text('内容から適切なタイトルを提案します'),
              onTap: () {
                Navigator.pop(context);
                _suggestTitle();
              },
            ),
            ListTile(
              leading: const Icon(Icons.label, color: Colors.teal),
              title: const Text('タグ・カテゴリを提案'),
              subtitle: const Text('自動的にタグとカテゴリを提案します'),
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

  // AIエラーメッセージのフォーマット
  String _formatAIError(dynamic error) {
    if (error is AIServiceException) {
      if (error.isRateLimitError) {
        return 'AI機能の使用制限に達しました。しばらく待ってから再度お試しください。';
      }
      return error.message;
    }
    // その他のエラーは一般的なメッセージ
    return 'AI処理に失敗しました。しばらく待ってから再度お試しください。';
  }

  // AI文章改善
  Future<void> _improveText() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('改善する文章を入力してください')),
      );
      return;
    }

    setState(() => _isAIProcessing = true);
    try {
      final improvedText = await _aiService.improveText(_contentController.text);
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

  // AI要約生成
  Future<void> _summarizeText() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('要約する文章を入力してください')),
      );
      return;
    }

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

  // AI文章展開
  Future<void> _expandText() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('展開する文章を入力してください')),
      );
      return;
    }

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

  // AI翻訳
  Future<void> _translateText() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('翻訳する文章を入力してください')),
      );
      return;
    }

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

  // AIタイトル提案
  Future<void> _suggestTitle() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを提案するための文章を入力してください')),
      );
      return;
    }

    setState(() => _isAIProcessing = true);
    try {
      final titles = await _aiService.suggestTitles(_contentController.text);
      if (mounted) {
        setState(() => _isAIProcessing = false);
        // タイトル選択ダイアログを表示
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
            ],
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

  // AIタグ・カテゴリ提案
  Future<void> _suggestTags() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タグ・カテゴリを提案するための文章を入力してください')),
      );
      return;
    }

    setState(() => _isAIProcessing = true);
    try {
      final suggestion = await _aiService.suggestTags(
        content: _contentController.text,
        title: _titleController.text,
        existingCategories: _categories.map((c) => c.name).toList(),
      );

      if (mounted) {
        setState(() => _isAIProcessing = false);
        // 提案結果を表示
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🏷️ タグ・カテゴリ提案'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '提案理由: ${suggestion.reason}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Text(
                  '推奨カテゴリ: ${suggestion.category}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('推奨タグ:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...suggestion.tags.map((tag) => Chip(label: Text(tag))),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // カテゴリを適用（既存のカテゴリから検索または新規作成を促す）
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('提案を参考にカテゴリとタグを設定してください')),
                  );
                },
                child: const Text('適用'),
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? '新規メモ' : 'メモを編集'),
        actions: [
          // AI機能ボタン
          if (_isAIProcessing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.purple),
              onPressed: _showAIMenu,
              tooltip: 'AI アシスタント',
            ),
          // ピン留めトグルボタン
          if (widget.note != null)
            IconButton(
              icon: Icon(
                _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: _isPinned ? Colors.amber : null,
              ),
              onPressed: () {
                setState(() {
                  _isPinned = !_isPinned;
                });
              },
              tooltip: _isPinned ? 'ピン留めを解除' : 'ピン留め',
            ),
          // 添付ファイルボタン（追加）
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: _isUploadingFile ? null : _attachFile,
                tooltip: '添付ファイル',
              ),
              if (_attachments.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_attachments.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (_isUploadingFile)
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
          // マークダウンヘルプ
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showMarkdownHelp,
            tooltip: 'マークダウン記法ヘルプ',
          ),
          // リマインダーボタン
          IconButton(
            icon: Icon(
              _reminderDate != null ? Icons.alarm : Icons.alarm_add,
              color: _reminderDate != null ? Colors.orange : null,
            ),
            onPressed: _showReminderDialog,
            tooltip: _reminderDate != null ? 'リマインダー設定済み' : 'リマインダーを設定',
          ),
          // お気に入りボタン
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
            tooltip: _isFavorite ? 'お気に入りから削除' : 'お気に入りに追加',
          ),
          // 保存ボタン（画面を閉じない）
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveNoteWithoutClosing,
            tooltip: '保存',
          ),
          // 保存して閉じるボタン
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveNote,
            tooltip: '保存して閉じる',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: '編集'),
            Tab(icon: Icon(Icons.visibility), text: 'プレビュー'),
          ],
        ),
      ),
      body: Column(
        children: [
          // カテゴリとリマインダー情報エリア
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.label_outline, color: Colors.grey),
                    const SizedBox(width: 8),
                    _buildCategoryChip(),
                  ],
                ),
                if (_reminderDate != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _reminderDate!.isBefore(DateTime.now())
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.alarm,
                          color: _reminderDate!.isBefore(DateTime.now())
                              ? Colors.red
                              : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'リマインダー: ${DateFormatter.formatReminder(_reminderDate!)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: _reminderDate!.isBefore(DateTime.now())
                                  ? Colors.red
                                  : Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            setState(() {
                              _reminderDate = null;
                            });
                          },
                          tooltip: 'リマインダーを削除',
                        ),
                      ],
                    ),
                  ),
                ],
                // 添付ファイル一覧（追加）
                if (_attachments.isNotEmpty || _isLoadingAttachments) ...[
                  const SizedBox(height: 12),
                  _isLoadingAttachments
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : AttachmentListWidget(
                          attachments: _attachments,
                          onDelete: _deleteAttachment,
                          isEditing: true,
                        ),
                ],
              ],
            ),
          ),
          // タブビュー
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 編集モード
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
                            hintText: 'メモを入力（マークダウン記法が使えます）',
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
                // プレビューモード
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_titleController.text.isNotEmpty) ...[
                        Text(
                          _titleController.text,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                      ],
                      Expanded(
                        child: _contentController.text.isEmpty
                            ? const Center(
                                child: Text(
                                  'プレビューする内容がありません',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : MarkdownPreview(
                                // ← カスタムウィジェットを使用
                                data: _contentController.text,
                                selectable: true,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
