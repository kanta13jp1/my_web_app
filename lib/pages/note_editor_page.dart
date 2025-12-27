import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/note.dart';

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
  bool _isAiLoading = false;

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
          'is_archived': false, // デフォルトでアーカイブなし
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //  AI機能: 文章校正要約など
  Future<void> _callAiAssistant(String action) async {
    final content = _contentController.text;
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AIに依頼するテキストを入力してください')),
      );
      return;
    }

    setState(() => _isAiLoading = true);

    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': action,
          'content': content,
          'language': 'ja', // 日本語指定
        },
      );

      if (response.status != 200)
        throw Exception('AI Server Error: ${response.status}');

      final data = response.data;
      if (data['success'] != true)
        throw Exception(data['error'] ?? 'Unknown Error');

      final result = data['result'] as String;

      if (mounted) {
        // 結果をダイアログで表示し、採用するか選ばせる
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.auto_awesome, color: Colors.indigo),
              SizedBox(width: 8),
              Text('AIの提案')
            ]),
            content: SingleChildScrollView(child: Text(result)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル')),
              ElevatedButton.icon(
                onPressed: () {
                  // 提案を採用（上書きまたは追記）
                  if (action == 'improve') {
                    _contentController.text = result; // 校正なら置き換え
                  } else {
                    _contentController.text =
                        '$content\n\n--- AIによる追記 ---\n$result'; // その他は追記
                  }
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                label: const Text('採用する'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AIエラー: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  void _showAiMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text('文章を校正改善する'),
              onTap: () {
                Navigator.pop(context);
                _callAiAssistant('improve');
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize),
              title: const Text('要約する'),
              onTap: () {
                Navigator.pop(context);
                _callAiAssistant('summarize');
              },
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb),
              title: const Text('アイデアを広げる'),
              onTap: () {
                Navigator.pop(context);
                _callAiAssistant('expand');
              },
            ),
            ListTile(
              leading: const Icon(Icons.title),
              title: const Text('タイトル案を出す'),
              onTap: () {
                Navigator.pop(context);
                _callAiAssistant('suggest_title');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? '新しいメモ' : 'メモの編集'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // AIボタン
          IconButton(
            icon: _isAiLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome, color: Colors.indigo),
            onPressed: _isAiLoading ? null : _showAiMenu,
            tooltip: 'AIアシスタント',
          ),
          // 保存ボタン
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveNote,
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
                hintText: 'タイトル',
                border: InputBorder.none,
                hintStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black26),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
