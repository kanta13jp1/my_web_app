import 'package:flutter/material.dart';
import '../services/note_operations_service.dart';
import '../widgets/note_editor/ai_assistant_menu.dart'; // AI機能

class NoteEditorPage extends StatefulWidget {
  final String? noteId;
  final String? initialTitle; // 追加
  final String? initialContent; // 追加

  const NoteEditorPage({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialContent,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
    if (widget.noteId != null) {
      _loadNote();
    }
  }

  Future<void> _loadNote() async {
    // 既存ノート読み込みロジック (スタブ)
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    // 保存ロジック (スタブ)
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('保存しました')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモ作成'),
        actions: [
          IconButton(onPressed: _saveNote, icon: const Icon(Icons.save)),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'タイトル',
                    border: InputBorder.none,
                    hintStyle:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
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
                    expands: true,
                  ),
                ),
              ],
            ),
          ),
          // AIアシスタントメニュー (右下に配置)
          Positioned(
            bottom: 16,
            right: 16,
            child: AiAssistantMenu(
              contentController: _contentController,
              onApply: (newText) {
                setState(() {
                  _contentController.text = newText;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
