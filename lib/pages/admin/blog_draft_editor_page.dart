// lib/pages/admin/blog_draft_editor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/blog_service.dart';

class BlogDraftEditorPage extends StatefulWidget {
  final String? postId;
  const BlogDraftEditorPage({super.key, this.postId});

  @override
  State<BlogDraftEditorPage> createState() => _BlogDraftEditorPageState();
}

class _BlogDraftEditorPageState extends State<BlogDraftEditorPage> {
  final _service = BlogService();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPublishing = false;
  bool _showPreview = false;
  List<String> _targetPlatforms = ['qiita', 'devto'];

  static const _bg = Color(0xFF0A0A0A);
  static const _card = Color(0xFF1A1A2E);
  static const _orange = Color(0xFFFF6B35);
  static const _green = Color(0xFF4CAF50);
  static const _red = Color(0xFFE53935);

  bool get _isEditMode => widget.postId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) _fetchPost();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPost() async {
    setState(() => _isLoading = true);
    try {
      final post = await _service.fetchPost(widget.postId!);
      if (post != null && mounted) {
        setState(() {
          _titleCtrl.text = post['title'] as String? ?? '';
          _contentCtrl.text = post['content'] as String? ?? '';
          _notesCtrl.text = post['notes'] as String? ?? '';
          final platforms = post['target_platforms'];
          if (platforms is List) {
            _targetPlatforms = List<String>.from(platforms);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 読み込み失敗: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDraft() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してください')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      if (_isEditMode) {
        await _service.updatePost(
          id: widget.postId!,
          title: title,
          content: _contentCtrl.text,
          targetPlatforms: _targetPlatforms,
          notes: _notesCtrl.text.trim(),
        );
      } else {
        await _service.insertPost(
          title: title,
          content: _contentCtrl.text,
          targetPlatforms: _targetPlatforms,
          notes: _notesCtrl.text.trim(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 下書きを保存しました'),
            backgroundColor: _green,
          ),
        );
        if (!_isEditMode) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 保存失敗: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _publishNow() async {
    if (!_isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に下書き保存してください')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          '今すぐ公開',
          style: TextStyle(color: Colors.white, height: 1.5),
        ),
        content: const Text(
          'Qiita / dev.to に投稿します。よろしいですか？',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('投稿', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isPublishing = true);
    try {
      final res = await _service.publishPost(widget.postId!);
      if (!mounted) return;
      final results = res['results'] as Map<String, dynamic>? ?? {};
      final qiitaOk = (results['qiita'] as Map?)?['ok'] == true;
      final devtoOk = (results['devto'] as Map?)?['ok'] == true;
      final platforms = [
        if (qiitaOk) 'Qiita',
        if (devtoOk) 'dev.to',
      ].join(' + ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 投稿完了 $platforms'),
          backgroundColor: _green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 投稿失敗: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isEditMode ? '下書き編集' : '新規下書き',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showPreview = !_showPreview),
            icon: Icon(
              _showPreview ? Icons.edit : Icons.preview,
              color: Colors.white70,
              size: 18,
            ),
            label: Text(
              _showPreview ? '編集' : 'プレビュー',
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ),
          if (_isEditMode)
            _isPublishing
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _orange,
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _publishNow,
                    icon: const Icon(Icons.send, color: _orange, size: 18),
                    label: const Text(
                      '公開',
                      style: TextStyle(color: _orange, height: 1.5),
                    ),
                  ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: _saveDraft,
                  icon: const Icon(Icons.save, color: Colors.white70, size: 18),
                  label: const Text(
                    '保存',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _showPreview
              ? _buildPreview()
              : _buildEditor(),
    );
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
            decoration: _inputDeco('タイトル *'),
          ),
          const SizedBox(height: 12),
          _buildPlatformSelector(),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            style: const TextStyle(color: Colors.white, height: 1.5),
            decoration: _inputDeco('メモ / タグ'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentCtrl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'monospace',
              height: 1.6,
            ),
            decoration: _inputDeco('本文 (Markdown) *'),
            maxLines: null,
            minLines: 20,
            maxLength: 100000,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final content = _contentCtrl.text;
    if (content.isEmpty) {
      return const Center(
        child: Text(
          'プレビューする内容がありません',
          style: TextStyle(color: Colors.white38, height: 1.5),
        ),
      );
    }
    return Markdown(
      data: content,
      padding: const EdgeInsets.all(20),
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: const TextStyle(color: Colors.white70, height: 1.7),
        h1: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
        h2: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
        h3: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
        code: const TextStyle(
          color: Color(0xFFFF6B35),
          fontFamily: 'monospace',
          height: 1.5,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildPlatformSelector() {
    return Row(
      children: [
        const Text(
          '投稿先:',
          style: TextStyle(color: Colors.white54, height: 1.5),
        ),
        const SizedBox(width: 12),
        for (final p in ['qiita', 'devto'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                p == 'devto' ? 'dev.to' : 'Qiita',
                style: const TextStyle(height: 1.5),
              ),
              selected: _targetPlatforms.contains(p),
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _targetPlatforms.add(p);
                  } else {
                    _targetPlatforms.remove(p);
                  }
                });
              },
              selectedColor: _orange,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: _targetPlatforms.contains(p)
                    ? Colors.white
                    : Colors.white54,
              ),
              backgroundColor: Colors.white10,
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, height: 1.5),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _orange),
        ),
        counterStyle: const TextStyle(color: Colors.white38),
      );
}
