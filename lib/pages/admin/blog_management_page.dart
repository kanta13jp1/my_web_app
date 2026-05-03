// lib/pages/admin/blog_management_page.dart
// ブログ管理ページ: 投稿済み記事一覧・エンゲージメント・コメント確認
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  List<Map<String, dynamic>> _drafts = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  final Set<String> _publishingIds = {};
  final Set<String> _togglingIds = {};
  String _tab = 'articles'; // 'articles' | 'comments' | 'drafts'
  String _platformFilter = 'all'; // 'all' | 'qiita' | 'devto'

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
      final results = await Future.wait([
        _supabase
            .from('blog_engagement')
            .select()
            .order('likes_count', ascending: false)
            .limit(200),
        _supabase
            .from('blog_comments')
            .select()
            .order('fetched_at', ascending: false)
            .limit(300),
        _supabase
            .from('blog_posts')
            .select('id, title, status, target_platforms, draft_path, posted_at, url, created_at')
            .inFilter('status', ['draft', 'ready'])
            .order('created_at', ascending: false)
            .limit(50),
      ]);

      if (mounted) {
        setState(() {
          _engagement = List<Map<String, dynamic>>.from(results[0] as List);
          _comments = List<Map<String, dynamic>>.from(results[1] as List);
          _drafts = List<Map<String, dynamic>>.from(results[2] as List);
        });
      }
    } catch (e) {
      debugPrint('blog management load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final res = await _supabase.functions.invoke(
        'schedule-hub',
        body: {'action': 'blog.sync_engagement'},
      );
      if (mounted) {
        final success = res.status == 200;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✅ 同期完了' : '⚠️ 同期エラー (${res.status})'),
            backgroundColor: success ? _green : _red,
            duration: const Duration(seconds: 3),
          ),
        );
        if (success) await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 同期失敗: $e'),
            backgroundColor: _red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _publishDraft(Map<String, dynamic> d) async {
    final id = d['id']?.toString() ?? '';
    if (id.isEmpty || _publishingIds.contains(id)) return;
    setState(() => _publishingIds.add(id));
    try {
      final res = await _supabase.functions.invoke(
        'schedule-hub',
        body: {'action': 'blog.publish_post', 'id': id},
      );
      if (!mounted) return;
      final ok = res.status == 200;
      final data = res.data as Map<String, dynamic>?;
      final results = data?['results'] as Map<String, dynamic>? ?? {};
      final qiitaOk = (results['qiita'] as Map?)?['ok'] == true;
      final devtoOk = (results['devto'] as Map?)?['ok'] == true;
      final msg = ok
          ? '✅ 投稿完了 ${[if (qiitaOk) 'Qiita', if (devtoOk) 'dev.to'].join(' + ')}'
          : '⚠️ 投稿エラー (${res.status}): ${data?['error'] ?? ''}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? _green : _red,
          duration: const Duration(seconds: 4),
        ),
      );
      if (ok) await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 投稿失敗: $e'),
            backgroundColor: _red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _publishingIds.remove(id));
    }
  }

  Future<void> _toggleDraftStatus(Map<String, dynamic> d) async {
    final id = d['id']?.toString() ?? '';
    if (id.isEmpty || _togglingIds.contains(id)) return;
    final current = d['status'] as String? ?? 'draft';
    final next = current == 'ready' ? 'draft' : 'ready';
    setState(() => _togglingIds.add(id));
    try {
      await _supabase
          .from('blog_posts')
          .update({'status': next})
          .eq('id', id);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ステータス更新失敗: $e'),
            backgroundColor: _red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingIds.remove(id));
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.white70),
              tooltip: 'Qiita/dev.to から同期',
              onPressed: _syncNow,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'DB 再読み込み',
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
                  if (_tab == 'drafts') ..._buildDraftSliver(),
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
          _statCard(
            'いいね合計',
            '$_totalLikes',
            Icons.favorite_outline,
            color: const Color(0xFFFF6B35),
          ),
          const SizedBox(width: 8),
          _statCard(
            '閲覧数',
            _formatNum(_totalViews),
            Icons.visibility_outlined,
            color: const Color(0xFF3D5AFE),
          ),
          const SizedBox(width: 8),
          _statCard(
            '未返信',
            '$unreplied',
            Icons.comment_outlined,
            color: unreplied > 0 ? _red : _green,
          ),
          const SizedBox(width: 8),
          _statCard(
            '下書き',
            '${_drafts.length}',
            Icons.drafts_outlined,
            color: _drafts.isNotEmpty ? _orange : Colors.white38,
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon, {
    Color color = _orange,
  }) {
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
                height: 1.5,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── タブバー ────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tabBtn('articles', '記事一覧 (${_filteredEngagement.length})'),
              const SizedBox(width: 8),
              _tabBtn(
                'comments',
                'コメント${_unrepliedCount > 0 ? ' ($_unrepliedCount)' : ''}',
              ),
              const SizedBox(width: 8),
              _tabBtn('drafts', '下書き (${_drafts.length})'),
            ],
          ),
          if (_tab == 'articles') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _filterBtn('all', '全て'),
                const SizedBox(width: 6),
                _filterBtn('qiita', 'Qiita'),
                const SizedBox(width: 6),
                _filterBtn('devto', 'dev.to'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabBtn(String id, String label) {
    final selected = _tab == id;
    return GestureDetector(
      onTap: () => setState(() => _tab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _orange : Colors.white12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _filterBtn(String id, String label) {
    final selected = _platformFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _platformFilter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.white38 : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white70 : Colors.white38,
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredEngagement {
    if (_platformFilter == 'all') return _engagement;
    return _engagement.where((e) => e['platform'] == _platformFilter).toList();
  }

  // ── 記事一覧 ────────────────────────────────────────────────
  List<Widget> _buildArticleSliver() {
    final items = _filteredEngagement;
    if (items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.article_outlined, color: Colors.white24, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'データなし\nSync ボタンで Qiita / dev.to から取得できます',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, height: 1.6),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _syncNow,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync),
                  label: Text(_isSyncing ? '同期中...' : '今すぐ同期'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
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
            (ctx, i) => _buildArticleCard(items[i]),
            childCount: items.length,
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

    final platformColor = switch (platform) {
      'qiita' => const Color(0xFF55C500),
      'devto' => const Color(0xFF3D5AFE),
      _ => Colors.white38,
    };
    final platformBg = platformColor.withAlpha(25);

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
                      height: 1.5,
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
                      height: 1.5,
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
                _engStat(Icons.favorite, '$likes', const Color(0xFFFF6B35)),
                const SizedBox(width: 16),
                _engStat(Icons.comment, '$comments', const Color(0xFF3D5AFE)),
                const SizedBox(width: 16),
                _engStat(Icons.visibility, _formatNum(views), Colors.white38),
                const Spacer(),
                if (url.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _openUrl(url),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text(
                      '開く',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
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
          style: TextStyle(
            color: color,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── コメント一覧 ─────────────────────────────────────────────
  List<Widget> _buildCommentSliver() {
    final sorted = [..._comments]..sort((a, b) {
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
                style: TextStyle(
                  color: Colors.white38,
                  height: 1.5,
                ),
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
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  platform.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: replied ? _green.withAlpha(30) : _red.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    replied ? '返信済み' : '未返信',
                    style: TextStyle(
                      color: replied ? _green : _red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.5,
              ),
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
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      replyText,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        height: 1.5,
                      ),
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

  // ── 下書き一覧 ──────────────────────────────────────────────
  List<Widget> _buildDraftSliver() {
    if (_drafts.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                '下書きなし',
                style: TextStyle(color: Colors.white38, height: 1.5),
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
            (ctx, i) => _buildDraftCard(_drafts[i]),
            childCount: _drafts.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildDraftCard(Map<String, dynamic> d) {
    final id = d['id']?.toString() ?? '';
    final title = d['title'] as String? ?? '(no title)';
    final status = d['status'] as String? ?? 'draft';
    final rawPlatforms = d['target_platforms'];
    final platforms = (rawPlatforms is List)
        ? rawPlatforms.map((p) => p.toString()).join(', ')
        : rawPlatforms?.toString() ?? '';
    final url = d['url'] as String? ?? '';
    final draftPath = d['draft_path'] as String? ?? '';

    final isPublishing = _publishingIds.contains(id);
    final isToggling = _togglingIds.contains(id);
    final statusColor = status == 'ready' ? _orange : Colors.white38;
    final isReady = status == 'ready';

    return Card(
      color: _card,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isReady
            ? BorderSide(color: _orange.withAlpha(80), width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
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
                      height: 1.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (url.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    color: _orange,
                    tooltip: '記事を開く',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () => _openUrl(url),
                  ),
              ],
            ),
            if (platforms.isNotEmpty || draftPath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    if (platforms.isNotEmpty) '📍 $platforms',
                    if (draftPath.isNotEmpty) '📄 $draftPath',
                  ].join('  '),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    height: 1.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                // ready/draft toggle
                SizedBox(
                  height: 28,
                  child: OutlinedButton.icon(
                    onPressed: isToggling ? null : () => _toggleDraftStatus(d),
                    icon: isToggling
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white54,
                            ),
                          )
                        : Icon(
                            isReady ? Icons.undo : Icons.check_circle_outline,
                            size: 14,
                          ),
                    label: Text(
                      isReady ? '下書きに戻す' : '公開準備完了',
                      style: const TextStyle(fontSize: 11, height: 1.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isReady ? Colors.white38 : _orange,
                      side: BorderSide(
                        color: isReady
                            ? Colors.white24
                            : _orange.withAlpha(120),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // publish button — only active when ready
                SizedBox(
                  height: 28,
                  child: ElevatedButton.icon(
                    onPressed: (isReady && !isPublishing)
                        ? () => _publishDraft(d)
                        : null,
                    icon: isPublishing
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 14),
                    label: Text(
                      isPublishing ? '投稿中...' : '今すぐ投稿',
                      style: const TextStyle(fontSize: 11, height: 1.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isReady ? _orange : Colors.white12,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}
