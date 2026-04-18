import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MedicalNotesPage extends StatefulWidget {
  const MedicalNotesPage({super.key});

  @override
  State<MedicalNotesPage> createState() => _MedicalNotesPageState();
}

class _MedicalNotesPageState extends State<MedicalNotesPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notes = [];

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _category = '通院記録';
  bool _saving = false;

  static const _categories = ['通院記録', '処方薬', '健康診断', '手術・処置', 'その他'];

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotes() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .ilike('title', '[Medical]%')
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _notes = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNote() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) return;

    setState(() => _saving = true);
    try {
      await _supabase.from('notes').insert({
        'user_id': userId,
        'title':
            '[Medical] [$_category] ${title.isNotEmpty ? title : DateFormat('MM/dd').format(DateTime.now())}',
        'content': content,
        'is_archived': false,
        'is_pinned': false,
      });

      _titleController.clear();
      _contentController.clear();
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('医療メモを保存しました')),
        );
        _fetchNotes();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存エラー: $e')));
      }
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case '通院記録':
        return Colors.blue;
      case '処方薬':
        return Colors.green;
      case '健康診断':
        return Colors.orange;
      case '手術・処置':
        return Colors.red;
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _extractCategory(String title) {
    final match = RegExp(r'\[Medical\] \[(.+?)\]').firstMatch(title);
    return match?.group(1) ?? 'その他';
  }

  String _extractTitle(String title) {
    return title.replaceFirst(RegExp(r'\[Medical\] \[.+?\] ?'), '');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('医療・健康ノート'),
        backgroundColor: const Color(0xFF009688)[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '新規メモを追加',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'カテゴリ',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'タイトル（任意）: 例: 内科受診 2026/03/28',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        hintText: '詳細: 症状・診断・処方薬・次回予約日など',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      maxLines: 4,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _saveNote,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF009688),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '記録一覧',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_notes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '医療・健康ノートはまだありません',
                    style: TextStyle(color: const Color(0xFF9CA3AF)),
                  ),
                ),
              )
            else
              ...(_notes.map((note) {
                final created = DateTime.tryParse(
                  note['created_at']?.toString() ?? '',
                );
                final dateStr = created != null
                    ? DateFormat('MM/dd HH:mm').format(created)
                    : '';
                final rawTitle = note['title']?.toString() ?? '';
                final category = _extractCategory(rawTitle);
                final title = _extractTitle(rawTitle);
                final color = _categoryColor(category);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withAlpha(30),
                      child:
                          Icon(Icons.medical_services, color: color, size: 20),
                    ),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (title.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: note['content']?.toString().isNotEmpty == true
                        ? Text(
                            note['content']?.toString() ?? '',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11, color: const Color(0xFF9CA3AF)),
                    ),
                  ),
                );
              })),
          ],
        ),
      ),
    );
  }
}
