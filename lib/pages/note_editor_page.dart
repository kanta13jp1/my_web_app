import 'package:flutter/material.dart';
import '../main.dart';
import '../models/note.dart';
import '../models/category.dart';
import '../widgets/markdown_preview.dart';

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
  bool _isSaving = false;
  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _isFavorite = false;
  DateTime? _reminderDate;

  // マークダウン関連
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _selectedCategoryId = widget.note?.categoryId;
    _isFavorite = widget.note?.isFavorite ?? false;
    _reminderDate = widget.note?.reminderDate;
    _loadCategories();

    // タブコントローラーを初期化
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tabController.dispose();
    super.dispose();
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
    if (_titleController.text.isEmpty && _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルまたは内容を入力してください')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;

      if (widget.note == null) {
        await supabase.from('notes').insert({
          'user_id': userId,
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'category_id': _selectedCategoryId,
          'is_favorite': _isFavorite,
          'reminder_date': _reminderDate?.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await supabase.from('notes').update({
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'category_id': _selectedCategoryId,
          'is_favorite': _isFavorite,
          'reminder_date': _reminderDate?.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.note!.id);
      }

      if (!mounted) {
        // ← 追加
        return;
      }

      if (!context.mounted) {
        // ← 追加（114行目付近）
        return;
      }

      Navigator.pop(context);

      if (!context.mounted) {
        // ← 追加
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存しました')),
      );
    } catch (error) {
      if (!mounted) {
        // ← 追加
        return;
      }

      if (!context.mounted) {
        // ← 追加
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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

  // マークダウンヘルプボタン
  void _showMarkdownHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('マークダウン記法'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
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
            onPressed: () => Navigator.pop(context),
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
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
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
