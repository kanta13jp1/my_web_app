// lib/pages/admin/blog_management_page.dart
// ブログ管理ページ: 投稿済み記事一覧・エンゲージメント・コメント確認
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlogManagementPage extends StatefulWidget {
  const BlogManagementPage({super.key});

  @override
  State<BlogManagementPage> createState() => _BlogManagementPageState();
}

class _BlogManagementPageState extends State<BlogManagementPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _engagement = [];
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  String _tab = 'articles'; // 'articles' | 'comments' | 'likers'

  static const _bg = Color(0xFF0A0A0A);
  static const _card = Color(0xFF1A1A2E);
  static const _orange = Color(0xFFFF6B35);
  static const _green = Color(0xFF4CAF50);
  static const _red = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final engRes = await _supabase
          .from('blog_engagement')
          .select()
          .order('likes_count', ascending: false)
          .limit(100);
      final cmtRes = await _supabase
          .from('blog_comments')
          .select()
          .order('fetched_at', ascending: false)
          .limit(200);

      if (mounted) {
        setState(() {
          _engagement = List<Map<String, dynamic>>.from(engRes as List);
          _comments = List<Map<String, dynamic>>.from(cmtRes as List);
        });
      }
    } catch (e) {
      debugPrint('blog management load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _unrepliedCount =>
      _comments.where((c) => c['replied'] != true).length;

  int get _totalLikes =>
      _engagement.fold(0, (sum, e) => sum + ((e['likes_count'] as int?) ?? 0));

  int get _totalViews =>
      _engagement.fold(0, (sum, e) => sum + ((e['views_count'] as int?) ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        title: const Text(
          'ブログ管理',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _orange,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildSummaryCards()),
                  SliverToBoxAdapter(child: _buildTabBar()),
                  if (_tab == 'articles') ..._buildArticleSliver(),
                  if (_tab == 'comments') ..._buildCommentSliver(),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }

  // ── サマリーカード ───────────────────────────────────────────
  Widget _buildSummaryCards() {
    final unreplied = _unrepliedCount;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _statCard('記事数', '${_engagement.length}', Icons.article_outlined),
          const SizedBox(width: 8),
          _statCard('いいね合計', '$_totalLikes', Icons.favorite_outline,
              color: Colors.pinkAccent,),
          const SizedBox(width: 8),
          _statCard('閲覧数', _formatNum(_totalViews), Icons.visibility_outlined,
              color: Colors.blueAccent,),
          const SizedBox(width: 8),
          _statCard(
            '未返信',
            '$unreplied',
            Icons.comment_outlined,
            color: unreplied > 0 ? _red : _green,
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon,
      {Color color = _orange,}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ── タブバー ────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _tabBtn('articles', '記事一覧'),
          const SizedBox(width: 8),
          _tabBtn('comments', 'コメント${_unrepliedCount > 0 ? ' ($_unrepliedCount)' : ''}'),
        ],
      ),
    );
  }

  Widget _tabBtn(String id, String label) {
    final selected = _tab == id;
    return GestureDetector(
      onTap: () => setState(() => _tab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _orange : Colors.white12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── 記事一覧 ────────────────────────────────────────────────
  List<Widget> _buildArticleSliver() {
    if (_engagement.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'blog-engagement.yml を実行すると\nデータが表示されます',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _buildArticleCard(_engagement[i]),
            childCount: _engagement.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildArticleCard(Map<String, dynamic> e) {
    final platform = e['platform'] as String? ?? '';
    final title = e['title'] as String? ?? '(no title)';
    final url = e['url'] as String? ?? '';
    final likes = e['likes_count'] as int? ?? 0;
    final comments = e['comments_count'] as int? ?? 0;
    final views = e['views_count'] as int? ?? 0;

    final platformColor = platform == 'qiita'
        ? const Color(0xFF55C500)
        : const Color(0xFF08090A);
    final platformBg = platform == 'qiita'
        ? const Color(0xFF55C500).withAlpha(20)
        : const Color(0xFFFFFFFF).withAlpha(10);

    return Card(
      color: _card,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: platformBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: platformColor.withAlpha(100)),
                  ),
                  child: Text(
                    platform.toUpperCase(),
                    style: TextStyle(
                      color: platformColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _engStat(Icons.favorite, '$likes', Colors.pinkAccent),
                const SizedBox(width: 16),
                _engStat(Icons.comment, '$comments', Colors.blueAccent),
                const SizedBox(width: 16),
                _engStat(Icons.visibility, _formatNum(views), Colors.white38),
                const Spacer(),
                if (url.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _openUrl(url),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('開く', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: _orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4,),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _engStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }

  // ── コメント一覧 ─────────────────────────────────────────────
  List<Widget> _buildCommentSliver() {
    final sorted = [..._comments]
      ..sort((a, b) {
        final ra = (a['replied'] as bool?) == true ? 1 : 0;
        final rb = (b['replied'] as bool?) == true ? 1 : 0;
        return ra.compareTo(rb); // 未返信を先頭に
      });

    if (sorted.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'コメントなし',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _buildCommentCard(sorted[i]),
            childCount: sorted.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildCommentCard(Map<String, dynamic> c) {
    final platform = c['platform'] as String? ?? '';
    final author = c['author'] as String? ?? '';
    final body = c['body'] as String? ?? '';
    final replied = (c['replied'] as bool?) == true;
    final replyText = c['reply_text'] as String? ?? '';

    return Card(
      color: _card,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: replied ? Colors.white12 : _red.withAlpha(80),
          width: replied ? 0.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text(
                  '@$author',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,),
                ),
                const SizedBox(width: 8),
                Text(
                  platform.toUpperCase(),
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: replied
                        ? _green.withAlpha(30)
                        : _red.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    replied ? '返信済み' : '未返信',
                    style: TextStyle(
                      color: replied ? _green : _red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (replied && replyText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _green.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _green.withAlpha(50)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '自分の返信:',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      replyText,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11,),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openUrl(String url) {
    // URLはブラウザで開く (dart:html or url_launcher)
    // Web環境: window.open(url, '_blank')
    debugPrint('Open: $url');
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}
