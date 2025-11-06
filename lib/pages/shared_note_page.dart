import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/note.dart';
import '../models/shared_note.dart';

class SharedNotePage extends StatefulWidget {
  final String shareToken;

  const SharedNotePage({super.key, required this.shareToken});

  @override
  State<SharedNotePage> createState() => _SharedNotePageState();
}

class _SharedNotePageState extends State<SharedNotePage> {
  Note? _note;
  SharedNote? _shareInfo;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _loadSharedNote();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadSharedNote() async {
    try {
      // 共有情報を取得
      final shareResponse = await supabase
          .from('shared_notes')
          .select()
          .eq('share_token', widget.shareToken)
          .single();

      final shareInfo = SharedNote.fromJson(shareResponse);

      // 期限切れチェック
      if (shareInfo.isExpired) {
        setState(() {
          _errorMessage = 'この共有リンクは期限切れです';
          _isLoading = false;
        });
        return;
      }

      // メモを取得
      final noteResponse = await supabase
          .from('notes')
          .select()
          .eq('id', shareInfo.noteId)
          .single();

      final note = Note.fromJson(noteResponse);

      // アクセスカウントを更新
      await supabase.rpc('increment_access_count', params: {
        'token': widget.shareToken,
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _note = note;
        _shareInfo = shareInfo;
        _titleController.text = note.title;
        _contentController.text = note.content;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '共有リンクが見つかりません';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNote() async {
    if (_shareInfo == null || !_shareInfo!.canWrite) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await supabase.from('notes').update({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _note!.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存しました')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  void _copyLink() {
    // 現在のURLから自動的にベースURLを取得
    final currentUrl = Uri.base;

    // ベースURL構築（開発環境と本番環境の自動判定）
    final baseUrl = currentUrl.host == 'localhost'
        ? 'http://localhost:${currentUrl.port}'
        : 'https://my-web-app-b67f4.web.app';

    // 共有リンクを生成（#を含める）
    final link = '$baseUrl/#/shared/${widget.shareToken}';

    Clipboard.setData(ClipboardData(text: link));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('リンクをコピーしました'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('共有されたメモ'),
        actions: [
          if (_shareInfo != null) ...[
            // 共有情報表示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _shareInfo!.canWrite
                        ? Colors.orange.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _shareInfo!.canWrite ? Icons.edit : Icons.visibility,
                        size: 16,
                        color:
                            _shareInfo!.canWrite ? Colors.orange : Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _shareInfo!.canWrite ? '編集可能' : '閲覧のみ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _shareInfo!.canWrite
                              ? Colors.orange
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.link),
              onPressed: _copyLink,
              tooltip: 'リンクをコピー',
            ),
            if (_shareInfo!.canWrite && !_isSaving)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveNote,
                tooltip: '保存',
              ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 共有情報バナー
                    if (_shareInfo != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _shareInfo!.canWrite
                              ? Colors.orange.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.1),
                          border: Border(
                            bottom: BorderSide(
                              color: _shareInfo!.canWrite
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: _shareInfo!.canWrite
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _shareInfo!.canWrite
                                    ? 'このメモは編集可能です。変更は自動的に保存されます。'
                                    : 'このメモは閲覧のみです。編集することはできません。',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _shareInfo!.canWrite
                                      ? Colors.orange.shade900
                                      : Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // メモ内容
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
                              readOnly: !(_shareInfo?.canWrite ?? false),
                            ),
                            const Divider(),
                            Expanded(
                              child: TextField(
                                controller: _contentController,
                                decoration: const InputDecoration(
                                  hintText: 'メモの内容',
                                  border: InputBorder.none,
                                ),
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                readOnly: !(_shareInfo?.canWrite ?? false),
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
