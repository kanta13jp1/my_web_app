// lib/pages/blog_post_page.dart
// 個別ブログ記事ページ — Markdown レンダリング + 外部リンク
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class BlogPostPage extends StatelessWidget {
  final Map<String, dynamic> post;
  const BlogPostPage({super.key, required this.post});

  static const _bg = Color(0xFF0A0A0A);
  static const _card = Color(0xFF1A1A2E);
  static const _orange = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context) {
    final title = post['title'] as String? ?? '';
    final content = post['content'] as String? ?? '';
    final url = post['url'] as String? ?? '';
    final postedAt =
        post['posted_at'] as String? ?? post['created_at'] as String? ?? '';
    final platforms = (post['target_platforms'] as List? ?? []).cast<String>();
    final tags = (post['tags'] as List? ?? []).cast<String>();
    final dateStr = postedAt.length >= 10 ? postedAt.substring(0, 10) : '';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'ブログ記事',
          style: TextStyle(color: Colors.white, height: 1.5),
        ),
        actions: [
          if (url.isNotEmpty)
            TextButton.icon(
              onPressed: () => _openUrl(url),
              icon: const Icon(Icons.open_in_new, size: 16, color: _orange),
              label: const Text(
                '外部で読む',
                style: TextStyle(color: _orange, height: 1.5),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Markdown(
        data: _buildMarkdown(title, dateStr, platforms, tags, url, content),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
        onTapLink: (text, href, title2) {
          if (href != null) _openUrl(href);
        },
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: const TextStyle(
            color: Colors.white70,
            height: 1.8,
            fontSize: 15,
          ),
          h1: const TextStyle(
            color: Colors.white,
            fontSize: 26,
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
            fontSize: 17,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
          h4: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
          code: const TextStyle(
            color: Color(0xFFFF6B35),
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.5,
          ),
          codeblockDecoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(8),
          ),
          blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          listBullet: const TextStyle(color: _orange),
          a: const TextStyle(
            color: Color(0xFF82B1FF),
            decoration: TextDecoration.underline,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  String _buildMarkdown(
    String title,
    String dateStr,
    List<String> platforms,
    List<String> tags,
    String url,
    String content,
  ) {
    final buf = StringBuffer();
    buf.writeln('# $title');
    buf.writeln();
    if (dateStr.isNotEmpty) {
      buf.write('*$dateStr*');
      if (platforms.isNotEmpty) {
        final platformNames =
            platforms.map((p) => p == 'qiita' ? 'Qiita' : 'dev.to').join(' · ');
        buf.write(' · $platformNames');
      }
      buf.writeln();
      buf.writeln();
    }
    if (tags.isNotEmpty) {
      buf.writeln(tags.map((t) => '`#$t`').join(' '));
      buf.writeln();
    }
    buf.writeln('---');
    buf.writeln();
    buf.writeln(
      content.isEmpty ? '*この記事は外部プラットフォームに投稿されています。*' : content,
    );
    if (url.isNotEmpty) {
      buf.writeln();
      buf.writeln('---');
      buf.writeln();
      buf.writeln('[外部プラットフォームで読む →]($url)');
    }
    return buf.toString();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
