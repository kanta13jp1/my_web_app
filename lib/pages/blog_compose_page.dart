import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/blog_publish_service.dart';
import '../widgets/markdown_preview.dart';

/// 認証ユーザーが blog 記事を作成・編集するページ。
/// status='draft' で保存 → admin レビュー後に公開。
class BlogComposePage extends StatefulWidget {
  const BlogComposePage({super.key});

  @override
  State<BlogComposePage> createState() => _BlogComposePageState();
}

class _BlogComposePageState extends State<BlogComposePage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  bool _showPreview = false;
  bool _saving = false;
  String? _editId;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    final id = (args is Map) ? args['id']?.toString() : null;
    if (id != null) {
      _editId = id;
      _loadExisting(id);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _notesCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  List<String> _parseTags() => _tagsCtrl.text
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .take(5)
      .toList();

  Future<void> _loadExisting(String id) async {
    try {
      final post = await BlogPublishService.getPostById(id);
      if (post == null || !mounted) return;
      setState(() {
        _titleCtrl.text = post['title']?.toString() ?? '';
        _contentCtrl.text = post['content']?.toString() ?? '';
        _notesCtrl.text = post['notes']?.toString() ?? '';
        final rawTags = post['tags'];
        _tagsCtrl.text = rawTags is List ? rawTags.join(', ') : '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('記事の読み込みに失敗: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('タイトルを入力してください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_editId != null) {
        await BlogPublishService.updatePost(
          _editId!,
          title: title,
          content: _contentCtrl.text,
          notes: _notesCtrl.text,
          tags: _parseTags(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('下書きを更新しました'),
            backgroundColor: Color(0xFF26A69A),
          ),
        );
      } else {
        final result = await BlogPublishService.insertPost(
          title: title,
          content: _contentCtrl.text,
          notes: _notesCtrl.text,
          tags: _parseTags(),
        );
        _editId = result['id']?.toString();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('下書きを保存しました — 管理者のレビュー後に公開されます'),
            backgroundColor: Color(0xFF26A69A),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('_save error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('記事を書く')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ログインが必要です',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '記事を投稿するにはログインしてください',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('ログイン'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_editId != null ? '記事を編集' : '記事を書く'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172033),
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showPreview = !_showPreview),
            icon: Icon(
              _showPreview ? Icons.edit_outlined : Icons.preview_outlined,
              size: 18,
            ),
            label: Text(_showPreview ? '編集' : 'プレビュー'),
          ),
          const SizedBox(width: 8),
          _saving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('保存'),
                ),
          const SizedBox(width: 12),
        ],
      ),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(child: _buildEditorPanel()),
        const VerticalDivider(width: 1),
        Expanded(
          child: _buildPreviewPanel(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return _showPreview ? _buildPreviewPanel() : _buildEditorPanel();
  }

  Widget _buildEditorPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'タイトル',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              hintText: '記事のタイトルを入力',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          const Text(
            'コンテンツ (Markdown)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _contentCtrl,
            maxLines: 28,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              height: 1.6,
            ),
            decoration: const InputDecoration(
              hintText: '# 見出し\n\n本文を Markdown で書きます...',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          const Text(
            'タグ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _tagsCtrl,
            decoration: const InputDecoration(
              hintText: 'Flutter, Supabase, AI のようにカンマ区切りで入力',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'メモ (任意)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '投稿に関するメモ（内部用）',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF059669)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '保存された下書きは管理者のレビュー後に公開されます。公開後は /blog で閲覧できます。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF065F46),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel() {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE5E7EB)),
            const SizedBox(height: 16),
          ],
          if (content.trim().isNotEmpty)
            MarkdownPreview(data: content)
          else
            const Text(
              'コンテンツを入力するとここにプレビューが表示されます',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }
}
