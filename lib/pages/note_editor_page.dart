import 'package:flutter/material.dart';
import '../widgets/note_editor/ai_assistant_menu.dart';

class NoteEditorPage extends StatefulWidget {
  final String? noteId;
  final String? initialTitle;
  final String? initialContent;

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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メモ作成')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(hintText: 'タイトル'),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                        hintText: '内容を入力...', border: InputBorder.none),
                    maxLines: null,
                    expands: true,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: AiAssistantMenu(
              contentController: _contentController,
              onApply: (text) => setState(() => _contentController.text = text),
            ),
          ),
        ],
      ),
    );
  }
}
