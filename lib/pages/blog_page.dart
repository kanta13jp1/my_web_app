// lib/pages/blog_page.dart
// 公式ブログ一覧ページ — blog_posts (status='posted') を公開表示
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'blog_post_page.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _posts = [];
  Map<String, Map<String, dynamic>> _engagement = {};
  bool _isLoading = true;
  String? _error;
  String _platformFilter = 'all';

  static const _bg = Color(0xFF0A0A0A);
  static const _card = Color(0xFF1A1A2E);
  static const _orange = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _supabase
            .from('blog_posts')
            .select(
              'id, title, content, status, target_platforms, notes, posted_at, created_at, url, tags',
            )
            .eq('status', 'posted')
            .order('posted_at', ascending: false)
            .limit(100),
        _supabase
            .from('blog_engagement')
            .select('platform, article_id, title, likes_count, views_count, comments_count, url')
            .order('likes_count', ascending: false)
            .limit(200),
      ]);
      if (mounted) {
        final posts = List<Map<String, dynamic>>.from(results[0] as List);
        final eng = Map<String, Map<String, dynamic>>.fromEntries(
          (results[1] as List).map((e) {
            final m = e as Map<String, dynamic>;
            final key = '${m['platform']}_${m['article_id']}';
            return MapEntry(key, m);
          }),
        );
        setState(() {
          _posts = posts;
          _engagement = eng;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredPosts {
    if (_platformFilter == 'all') return _posts;
    return _posts.where((p) {
      final platforms = p['target_platforms'] as List? ?? [];
      return platforms.contains(_platformFilter);
    }).toList();
  }

  int _postLikes(Map<String, dynamic> post) {
    final url = post['url'] as String? ?? '';
    for (final e in _engagement.values) {
      final engUrl = e['url'] as String? ?? '';
      if (url.isNotEmpty && engUrl.contains(url.split('/').last)) {
        return (e['likes_count'] as int?) ?? 0;
      }
    }
    return 0;
  }

  int _postViews(Map<String, dynamic> post) {
    final url = post['url'] as String? ?? '';
    for (final e in _engagement.values) {
      final engUrl = e['url'] as String? ?? '';
      if (url.isNotEmpty && engUrl.contains(url.split('/').last)) {
        return (e['views_count'] as int?) ?? 0;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '自分株式会社 ブログ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: '再読み込み',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: _orange,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      SliverToBoxAdapter(child: _buildFilterBar()),
                      if (_filteredPosts.isEmpty)
                        const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(48),
                              child: Text(
                                '公開記事がありません\n毎日 21:00 JST に自動公開されます',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white38,
                                  height: 1.7,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildPostCard(_filteredPosts[i]),
                            childCount: _filteredPosts.length,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(
            _error ?? '読み込みエラー',
            style: const TextStyle(color: Colors.white54, height: 1.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(backgroundColor: _orange),
            child: const Text('再試行', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rss_feed, color: _orange, size: 24),
              const SizedBox(width: 8),
              Text(
                '${_posts.length} 件の記事',
                style: const TextStyle(
                  color: _orange,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '技術・ライフマネジメント・AI に関する記事を毎日自動公開。\nQiita・dev.to にも同時配信しています。',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          for (final (id, label) in [
            ('all', '全て'),
            ('qiita', 'Qiita'),
            ('devto', 'dev.to'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _platformFilter = id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _platformFilter == id ? _orange : Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _platformFilter == id ? Colors.white : Colors.white54,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final title = post['title'] as String? ?? '(タイトルなし)';
    final postedAt = post['posted_at'] as String? ?? post['created_at'] as String? ?? '';
    final url = post['url'] as String? ?? '';
    final platforms = (post['target_platforms'] as List? ?? []).cast<String>();
    final tags = (post['tags'] as List? ?? []).cast<String>();
    final content = post['content'] as String? ?? '';
    final preview = _extractPreview(content);
    final likes = _postLikes(post);
    final views = _postViews(post);

    final dateStr = postedAt.isNotEmpty
        ? postedAt.substring(0, 10)
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlogPostPage(post: post),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final p in platforms)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _platformBadge(p),
                    ),
                  const Spacer(),
                  if (dateStr.isNotEmpty)
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: tags.take(4).map((t) => _tagChip(t)).toList(),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (likes > 0) ...[
                    const Icon(Icons.favorite_outline,
                        size: 14, color: Colors.white38),
                    const SizedBox(width: 3),
                    Text(
                      '$likes',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (views > 0) ...[
                    const Icon(Icons.visibility_outlined,
                        size: 14, color: Colors.white38),
                    const SizedBox(width: 3),
                    Text(
                      _formatNum(views),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(width: 10),
                  ],
                  const Spacer(),
                  if (url.isNotEmpty)
                    GestureDetector(
                      onTap: () => _openUrl(url),
                      child: const Row(
                        children: [
                          Text(
                            '外部で読む',
                            style: TextStyle(
                              color: _orange,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.open_in_new, size: 12, color: _orange),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _platformBadge(String platform) {
    final isQiita = platform == 'qiita';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isQiita
            ? const Color(0xFF55C500).withOpacity(0.15)
            : const Color(0xFF3D5AFE).withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isQiita ? 'Qiita' : 'dev.to',
        style: TextStyle(
          color: isQiita ? const Color(0xFF55C500) : const Color(0xFF82B1FF),
          fontSize: 10,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '#$tag',
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }

  String _extractPreview(String content) {
    final stripped = content
        .replaceAll(RegExp(r'^#{1,6}\s.*$', multiLine: true), '')
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'`[^`]*`'), '')
        .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'[*_~]'), '')
        .trim();
    if (stripped.length <= 120) return stripped;
    return '${stripped.substring(0, 120)}…';
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
