import 'package:flutter/material.dart';
import '../main.dart';
import '../models/note.dart';
import '../models/category.dart';
import '../utils/app_logger.dart';
import '../services/note_operations_service.dart';

class NoteEditorPage extends StatefulWidget {
  final Note? note;

  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _selectedCategoryId;
  List<Category> _categories = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _selectedCategoryId = widget.note!.categoryId;
    }
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

      if (mounted) {
        setState(() {
          _categories = (response as List)
              .map((category) => Category.fromJson(category))
              .toList();
        });
      }
    } catch (e) {
      // カテゴリロード失敗時は無視
    }
  }

  Future<void> _saveNote() async {
    if (_titleController.text.isEmpty && _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルまたは内容を入力してください')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final noteData = {
        'user_id': userId,
        'title': _titleController.text,
        'content': _contentController.text,
        'category_id': _selectedCategoryId,
        'updated_at': DateTime.now().toIso8601String(),
        'is_archived': false,
        'is_pinned': widget.note?.isPinned ?? false,
        'is_favorite': widget.note?.isFavorite ?? false,
      };

      if (widget.note == null) {
        // 新規作成
        noteData['created_at'] = DateTime.now().toIso8601String();
        await supabase.from('notes').insert(noteData);
      } else {
        // 更新
        await supabase.from('notes').update(noteData).eq('id', widget.note!.id);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存しました')),
        );
      }
    } catch (e) {
      AppLogger.error('Error saving note', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? '新規メモ' : 'メモを編集'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveNote,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // カテゴリ選択（簡易版）
                  if (_categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'カテゴリ',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('なし')),
                        ..._categories.map((category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            )),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedCategoryId = value),
                    ),
                  const SizedBox(height: 16),

                  // タイトル入力
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'タイトル',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // 本文入力
                  Expanded(
                    child: TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: '内容',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
