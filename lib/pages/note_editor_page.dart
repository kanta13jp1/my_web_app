import 'package:flutter/material.dart';
import '../main.dart';
import '../models/note.dart';
import '../widgets/note_editor/ai_assistant_menu.dart'; // 追加

class NoteEditorPage extends StatefulWidget {
  final Note? note;
  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final now = DateTime.now().toIso8601String();

      if (widget.note == null) {
        // 新規作成
        await supabase.from('notes').insert({
          'user_id': userId,
          'title': title,
          'content': content,
          'is_archived': false,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        // 更新
        await supabase.from('notes').update({
          'title': title,
          'content': content,
          'updated_at': now,
        }).eq('id', widget.note!.id);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('案件が決裁（保存）されました'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('決裁エラー: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ★ AIアシスタントメニューを表示するメソッド
  void _showAiAssistant() {
    final content = _contentController.text;
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AIに依頼するには、本文を入力してください')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // コンテンツ量に応じて高さを調整
      builder: (context) => AIAssistantMenu(
        content: content,
        onUpdateContent: (newText) {
          // テキストの更新処理 (追記か置換かを選べるようにしても良いが、一旦は追記/置換)
          // 既存のコードでは追記形式が多かったので、単純なsetTextで対応
          setState(() {
            _contentController.text = newText;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? '新規事業起案' : '稟議書編集'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A), // Navy
        elevation: 1,
        actions: [
          // ★ AIアシスタントボタン
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.purple),
            onPressed: _showAiAssistant,
            tooltip: 'AIアシスタント (分析・取締役会)',
          ),
          // 保存ボタン
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveNote,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A), // Navy
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              icon: const Icon(Icons.verified, size: 18),
              label: const Text('決裁'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '案件名 (Project Title)',
                border: InputBorder.none,
                hintStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black26),
              ),
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A)),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: '事業計画詳細内容を入力...',
                  border: InputBorder.none,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
