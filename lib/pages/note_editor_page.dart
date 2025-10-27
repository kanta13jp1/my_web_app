import 'package:flutter/material.dart';
import '../main.dart';
import '../models/note.dart';
import '../models/category.dart';

class NoteEditorPage extends StatefulWidget {
  final Note? note;

  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isSaving = false;
  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _isFavorite = false;
  DateTime? _reminderDate; // 追加

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _selectedCategoryId = widget.note?.categoryId;
    _isFavorite = widget.note?.isFavorite ?? false;
    _reminderDate = widget.note?.reminderDate; // 追加
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('name', ascending: true);

      setState(() {
        _categories = (response as List)
            .map((category) => Category.fromJson(category))
            .toList();
      });
    } catch (error) {
      // エラーは無視（カテゴリなしでも動作可能）
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
                // 日付選択
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
                // 時刻選択
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
        // 新規作成
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
        // 更新
        await supabase.from('notes').update({
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'category_id': _selectedCategoryId,
          'is_favorite': _isFavorite,
          'reminder_date': _reminderDate?.toIso8601String(), // 追加
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.note!.id);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存しました')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.category, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'カテゴリを選択',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('完了'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // 未分類オプション
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.clear, color: Colors.grey),
                ),
                title: const Text('未分類'),
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
              // カテゴリリスト
              if (_categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'カテゴリがありません\nカテゴリ管理画面から作成してください',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                ...(_categories.map((category) {
                  final color = Color(
                    int.parse(category.color.substring(1), radix: 16) +
                        0xFF000000,
                  );
                  final isSelected = _selectedCategoryId == category.id;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          category.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    title: Text(
                      category.name,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = category.id;
                      });
                      Navigator.pop(context);
                    },
                  );
                }).toList()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip() {
    if (_selectedCategoryId == null) {
      return Chip(
        avatar: const Icon(Icons.category_outlined, size: 18),
        label: const Text('カテゴリ未設定'),
        onDeleted: () => _showCategoryPicker(),
        deleteIcon: const Icon(Icons.edit, size: 18),
      );
    }

    final category = _categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => Category(
        id: '',
        userId: '',
        name: '未分類',
        color: '#9E9E9E',
        icon: '📁',
        createdAt: DateTime.now(),
      ),
    );

    final color = Color(
      int.parse(category.color.substring(1), radix: 16) + 0xFF000000,
    );

    return Chip(
      avatar: Text(category.icon, style: const TextStyle(fontSize: 16)),
      label: Text(
        category.name,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color, width: 1),
      onDeleted: () => _showCategoryPicker(),
      deleteIcon: const Icon(Icons.edit, size: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? '新規メモ' : 'メモを編集'),
        actions: [
          // リマインダーボタン（追加）
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
                // カテゴリ選択
                Row(
                  children: [
                    const Icon(Icons.label_outline, color: Colors.grey),
                    const SizedBox(width: 8),
                    _buildCategoryChip(),
                  ],
                ),
                // リマインダー表示
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
          // メモ編集エリア
          Expanded(
            child: Padding(
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
                        hintText: 'メモを入力...',
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
          ),
        ],
      ),
    );
  }
}
