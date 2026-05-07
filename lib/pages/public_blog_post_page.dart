import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/blog_publish_service.dart';
import '../widgets/markdown_preview.dart';

class PublicBlogPostPage extends StatefulWidget {
  const PublicBlogPostPage({super.key});

  @override
  State<PublicBlogPostPage> createState() => _PublicBlogPostPageState();
}

class _PublicBlogPostPageState extends State<PublicBlogPostPage> {
  late Future<Map<String, dynamic>?> _future;
  String? _postId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final id = (args is Map) ? args['id']?.toString() : null;
    if (id != null && id != _postId) {
      _postId = id;
      _future = BlogPublishService.getPostById(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_postId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Blog')),
        body: const Center(child: Text('記事が見つかりません')),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 700;
    final hPad = isWide ? (MediaQuery.of(context).size.width - 680) / 2 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Blog'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172033),
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/blog'),
            icon: const Icon(Icons.list, size: 18),
            label: const Text('一覧'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '記事の読み込みに失敗しました: ${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }
          final post = snap.data;
          if (post == null) {
            return const Center(
              child: Text(
                '記事が見つかりません',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            );
          }
          return _PostBody(post: post, hPad: hPad);
        },
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  final Map<String, dynamic> post;
  final double hPad;

  const _PostBody({required this.post, required this.hPad});

  @override
  Widget build(BuildContext context) {
    final title = post['title']?.toString() ?? '';
    final content = post['content']?.toString() ?? '';
    final postedAt = DateTime.tryParse(post['posted_at']?.toString() ?? '');
    final dateLabel = postedAt != null
        ? DateFormat('yyyy年MM月dd日', 'ja').format(postedAt)
        : '';
    final externalUrl = post['url']?.toString();
    final postId = post['id']?.toString() ?? '';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 4),
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                  height: 1.5,
                ),
              ),
              const SizedBox(width: 16),
              if (post['status'] == 'draft')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '下書き',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD97706),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Edit button (own draft)
          _EditButton(
            postId: postId,
            createdBy: post['created_by']?.toString(),
          ),
          const Divider(height: 32, color: Color(0xFFE5E7EB)),
          // Content
          if (content.trim().isNotEmpty)
            MarkdownPreview(data: content)
          else
            const Text(
              'コンテンツがありません',
              style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
            ),
          // External links
          if (externalUrl != null && externalUrl.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Divider(color: Color(0xFFE5E7EB)),
            const SizedBox(height: 16),
            const Text(
              '外部記事リンク',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final uri = Uri.tryParse(externalUrl);
                if (uri != null) await launchUrl(uri);
              },
              child: Text(
                externalUrl,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1F7AE0),
                  decoration: TextDecoration.underline,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          // Back
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/blog',
              (route) => false,
            ),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('記事一覧へ'),
          ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final String postId;
  final String? createdBy;

  const _EditButton({required this.postId, this.createdBy});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (createdBy == null || userId != createdBy) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      onPressed: () => Navigator.pushNamed(
        context,
        '/blog/compose',
        arguments: {'id': postId},
      ),
      icon: const Icon(Icons.edit, size: 15),
      label: const Text('編集', style: TextStyle(fontSize: 12)),
    );
  }
}
