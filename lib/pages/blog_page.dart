import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  Map<String, Map<String, dynamic>> _engagement = {};
  bool _loading = true;
  String? _error;
  String _platformFilter = 'all';

  static const _platformColors = {
    'qiita': Color(0xFF55C500),
    'devto': Color(0xFF0A0A0A),
    'zenn': Color(0xFF3EA8FF),
    'hatena': Color(0xFF00A4DE),
    'note': Color(0xFF41C9B4),
  };

  static const _orange = Color(0xFFFF6B35);
  static const _indigo = Color(0xFF4B6EF5);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _supabase
            .from('blog_posts')
            .select(
              'id, title, content, excerpt, url, posted_at, published_at, created_at, target_platforms, tags, notes',
            )
            .eq('status', 'posted')
            .order('posted_at', ascending: false)
            .limit(100),
        _supabase
            .from('blog_engagement')
            .select(
              'platform, article_id, title, likes_count, views_count, comments_count, url',
            )
            .order('likes_count', ascending: false)
            .limit(200),
      ]);
      if (mounted) {
        final posts = List<Map<String, dynamic>>.from(results[0] as List);
        final engagement = Map<String, Map<String, dynamic>>.fromEntries(
          (results[1] as List).map((e) {
            final m = e as Map<String, dynamic>;
            final key = '${m['platform']}_${m['article_id']}';
            return MapEntry(key, m);
          }),
        );
        setState(() {
          _posts = posts;
          _engagement = engagement;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_platformFilter == 'all') return _posts;
    return _posts.where((p) {
      final raw = p['target_platforms'];
      final platforms = (raw is List)
          ? raw.map((x) => x.toString().toLowerCase()).toList()
          : <String>[];
      return platforms.contains(_platformFilter);
    }).toList();
  }

  List<String> get _allPlatforms {
    final set = <String>{};
    for (final p in _posts) {
      final raw = p['target_platforms'];
      if (raw is List) {
        for (final x in raw) {
          set.add(x.toString().toLowerCase());
        }
      }
    }
    return set.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title:
            const Text('技術ブログ', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/blog/compose'),
            icon: const Icon(Icons.edit_note, color: Colors.white70, size: 18),
            label: const Text(
              '記事を書く',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '更新',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _orange.withAlpha(30),
                  border: Border.all(color: _orange.withAlpha(80)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_filtered.length} 記事',
                  style: const TextStyle(
                    color: _orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Flutter × Supabase × AI の実装ログをサイト内で公開。\n管理画面のレビュー後、外部プラットフォームにも自動配信します。',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final platforms = ['all', ..._allPlatforms];
    final labels = {
      'all': 'すべて',
      'qiita': 'Qiita',
      'devto': 'dev.to',
      'zenn': 'Zenn',
      'hatena': 'はてな',
      'note': 'note',
    };
    return Container(
      height: 44,
      color: const Color(0xFF16213E),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: platforms.map((p) {
          final selected = _platformFilter == p;
          final color =
              p == 'all' ? _indigo : (_platformColors[p] ?? Colors.white38);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _platformFilter = p),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? color.withAlpha(50) : Colors.transparent,
                  border: Border.all(
                    color: selected ? color : Colors.white24,
                    width: selected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  labels[p] ?? p,
                  style: TextStyle(
                    color: selected ? color : Colors.white54,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('再試行')),
          ],
        ),
      );
    }
    final posts = _filtered;
    if (posts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text(
              '記事がまだありません',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _orange,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (ctx, i) => _BlogCard(
          post: posts[i],
          likes: _postMetric(posts[i], 'likes_count'),
          views: _postMetric(posts[i], 'views_count'),
          comments: _postMetric(posts[i], 'comments_count'),
        ),
      ),
    );
  }

  int _postMetric(Map<String, dynamic> post, String field) {
    final url = post['url']?.toString() ?? '';
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    final slug = segments.isEmpty ? '' : segments.last;
    for (final entry in _engagement.values) {
      final engagementUrl = entry['url']?.toString() ?? '';
      if (url.isNotEmpty && engagementUrl == url) {
        return _asInt(entry[field]);
      }
      if (slug.isNotEmpty && engagementUrl.contains(slug)) {
        return _asInt(entry[field]);
      }
    }
    return 0;
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _blogPostExcerpt(Map<String, dynamic> post) {
  final explicit = post['excerpt']?.toString().trim() ?? '';
  if (explicit.isNotEmpty) return explicit;
  final content = post['content']?.toString().trim() ?? '';
  if (content.isEmpty) return '';
  final plain = content
      .replaceAll(RegExp(r'^#{1,6}\s.*$', multiLine: true), '')
      .replaceAll(RegExp(r'```[\s\S]*?```'), '')
      .replaceAll(RegExp(r'`([^`]*)`'), r'$1')
      .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1')
      .replaceAll(RegExp(r'[*_~>#-]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return plain.length <= 140 ? plain : '${plain.substring(0, 140)}…';
}

class _BlogCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final int likes;
  final int views;
  final int comments;
  const _BlogCard({
    required this.post,
    required this.likes,
    required this.views,
    required this.comments,
  });

  static const _orange = Color(0xFFFF6B35);
  static const _platformColors = {
    'qiita': Color(0xFF55C500),
    'devto': Color(0xFF0A0A0A),
    'zenn': Color(0xFF3EA8FF),
    'hatena': Color(0xFF00A4DE),
    'note': Color(0xFF41C9B4),
  };

  @override
  Widget build(BuildContext context) {
    final title = post['title']?.toString() ?? '無題';
    final url = post['url']?.toString() ?? '';
    final rawDate =
        post['posted_at'] ?? post['published_at'] ?? post['created_at'];
    final postedAt = rawDate != null
        ? DateFormat('yyyy/MM/dd')
            .format(DateTime.parse(rawDate.toString()).toLocal())
        : '';
    final rawPlatforms = post['target_platforms'];
    final platforms = (rawPlatforms is List)
        ? rawPlatforms.map((p) => p.toString().toLowerCase()).toList()
        : <String>[];
    final rawTags = post['tags'];
    final tags = (rawTags is List)
        ? rawTags.map((t) => t.toString()).toList()
        : <String>[];
    final excerpt = _blogPostExcerpt(post);
    final postId = post['id']?.toString() ?? '';
    final hasMetrics = likes > 0 || views > 0 || comments > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: InkWell(
        onTap: postId.isEmpty
            ? null
            : () => Navigator.pushNamed(
                  context,
                  '/blog/post',
                  arguments: {'id': postId},
                ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (postedAt.isNotEmpty)
                    Text(
                      postedAt,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  const Spacer(),
                  ...platforms.map((p) {
                    final color = _platformColors[p] ?? Colors.white38;
                    return Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        border: Border.all(color: color.withAlpha(80)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        p == 'devto'
                            ? 'dev.to'
                            : p.substring(0, 1).toUpperCase() + p.substring(1),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (excerpt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  excerpt,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.6,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags
                      .take(5)
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _orange.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#$t',
                            style: TextStyle(
                              color: _orange.withAlpha(200),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (hasMetrics || url.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (likes > 0) ...[
                      _metric(Icons.favorite_outline, _formatCount(likes)),
                      const SizedBox(width: 10),
                    ],
                    if (views > 0) ...[
                      _metric(Icons.visibility_outlined, _formatCount(views)),
                      const SizedBox(width: 10),
                    ],
                    if (comments > 0) ...[
                      _metric(Icons.chat_bubble_outline, '$comments'),
                      const SizedBox(width: 10),
                    ],
                    const Spacer(),
                    if (url.isNotEmpty) ...[
                      const Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () async {
                          final uri = Uri.tryParse(url);
                          if (uri != null) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: const Text(
                          '外部で読む',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return '$value';
  }
}
