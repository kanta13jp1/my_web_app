import 'package:flutter/material.dart';
import '../main.dart';
import '../models/note.dart';
import '../models/category.dart';
import '../widgets/markdown_preview.dart';
import '../models/attachment.dart'; // 追加
import '../services/attachment_service.dart'; // 追加
import '../widgets/attachment_list_widget.dart'; // 追加
import '../services/gamification_service.dart'; // ゲーミフィケーション追加
import '../widgets/achievement_notification.dart'; // 実績通知追加

class NoteEditorPage extends StatefulWidget {
  final Note? note;

  const NoteEditorPage({super.key, this.note});

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

  @override
  void initState() {
    super.initState();
    _gamificationService = GamificationService();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
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
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('リマインダーを設定'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('日付'),
                  subtitle: Text(
                    selectedDate != null
                        ? '${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}'
                        : '日付を選択',
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() {
                        selectedDate = date;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: const Text('時刻'),
                  subtitle: Text(
                    selectedTime != null
                        ? '${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                        : '時刻を選択',
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setDialogState(() {
                        selectedTime = time;
                      });
                    }
                  },
                ),
                if (_reminderDate != null) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '現在の設定: ${_formatReminderDate(_reminderDate!)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (_reminderDate != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _reminderDate = null;
                    });
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('削除'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: selectedDate != null && selectedTime != null
                    ? () {
                        setState(() {
                          _reminderDate = DateTime(
                            selectedDate!.year,
                            selectedDate!.month,
                            selectedDate!.day,
                            selectedTime!.hour,
                            selectedTime!.minute,
                          );
                        });
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text('設定'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatReminderDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDay = DateTime(date.year, date.month, date.day);

    String dateStr;
    if (targetDay == today) {
      dateStr = '今日';
    } else if (targetDay == tomorrow) {
      dateStr = '明日';
    } else {
      dateStr = '${date.month}/${date.day}';
    }

    return '$dateStr ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('カテゴリを選択'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('カテゴリなし'),
                trailing: _selectedCategoryId == null
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCategoryId = null;
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ..._categories.map((category) {
                final color = Color(
                    int.parse(category.color.substring(1), radix: 16) +
                        0xFF000000);
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(category.icon,
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  title: Text(category.name),
                  trailing: _selectedCategoryId == category.id
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = category.id;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip() {
    final category = _categories.cast<Category?>().firstWhere(
          (c) => c?.id == _selectedCategoryId,
          orElse: () => null,
        );

    if (category == null) {
      return TextButton.icon(
        icon: const Icon(Icons.add, size: 16),
        label: const Text('カテゴリを選択'),
        onPressed: _showCategoryDialog,
      );
    }

    final color =
        Color(int.parse(category.color.substring(1), radix: 16) + 0xFF000000);

    return InkWell(
      onTap: _showCategoryDialog,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              category.name,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  void _showMarkdownHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('マークダウン記法'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('# 見出し1', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('## 見出し2', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('**太字**'),
              Text('*斜体*'),
              Text('~~取り消し線~~'),
              SizedBox(height: 8),
              Text('- リスト項目'),
              Text('1. 番号付きリスト'),
              SizedBox(height: 8),
              Text('[リンク](https://example.com)'),
              SizedBox(height: 8),
              Text('```dart\nコードブロック\n```'),
              Text('`インラインコード`'),
              SizedBox(height: 8),
              Text('> 引用'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? '新規メモ' : 'メモを編集'),
        actions: [
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
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveNote,
            tooltip: '保存',
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
                            'リマインダー: ${_formatReminderDate(_reminderDate!)}',
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
