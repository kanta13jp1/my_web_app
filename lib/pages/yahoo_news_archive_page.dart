import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Yahoo!ニュース アーカイブ
///
/// 著作権保護のため記事本文はこのサイトには一切保存しない。
/// 保存するのは見出し・リンク・配信日時等のメタデータのみで、
/// 元記事の公開終了後の本文閲覧は Internet Archive (Wayback Machine) の
/// スナップショットに委ねる設計。
class YahooNewsArchivePage extends StatefulWidget {
  const YahooNewsArchivePage({super.key});

  @override
  State<YahooNewsArchivePage> createState() => _YahooNewsArchivePageState();
}

class _YahooNewsArchivePageState extends State<YahooNewsArchivePage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoadingNews = true;
  bool _isLoadingArchive = true;
  String? _newsError;
  String? _archiveError;
  String _selectedCategory = '主要';
  DateTime? _lastFetchedAt;
  List<_YahooNewsItem> _items = [];
  List<_ArchivedItem> _archivedItems = [];
  final Set<String> _savingUrls = {};
  final Set<String> _busyArchiveIds = {};

  static const _accent = Color(0xFF7B1FA2);
  static const _ink = Color(0xFF172033);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  // Yahoo!ニュースが公式に配信しているトピックス RSS のみを利用する。
  static const _yahooFeeds = <Map<String, String>>[
    {
      'title': 'Yahoo!ニュース・トピックス',
      'url': 'https://news.yahoo.co.jp/rss/topics/top-picks.xml',
      'category': '主要',
    },
    {
      'title': 'Yahoo!ニュース・トピックス',
      'url': 'https://news.yahoo.co.jp/rss/topics/domestic.xml',
      'category': '国内',
    },
    {
      'title': 'Yahoo!ニュース・トピックス',
      'url': 'https://news.yahoo.co.jp/rss/topics/world.xml',
      'category': '国際',
    },
    {
      'title': 'Yahoo!ニュース・トピックス',
      'url': 'https://news.yahoo.co.jp/rss/topics/business.xml',
      'category': '経済',
    },
    {
      'title': 'Yahoo!ニュース・トピックス',
      'url': 'https://news.yahoo.co.jp/rss/topics/entertainment.xml',
      'category': 'エンタメ',
    },
    {
      'title': 'Yahoo!ニュース・トピックス',
      'url': 'https://news.yahoo.co.jp/rss/topics/sports.xml',
      'category': 'スポーツ',
    },
    {
      'title': 'Yahoo!ニュース・トピックス',
      'url': 'https://news.yahoo.co.jp/rss/topics/it.xml',
      'category': 'IT',
    },
    {
      'title': 'Yahoo!ニュース・トピックス',
      'url': 'https://news.yahoo.co.jp/rss/topics/science.xml',
      'category': '科学',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNews();
    _loadArchive();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoadingNews = true;
      _newsError = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'rss.fetch_latest',
          'feeds': _yahooFeeds,
          'per_feed_limit': 12,
          'limit': 96,
          'signal_limit': 1,
        },
      );
      if (response.status != 200) {
        throw Exception('HTTP ${response.status}: ${response.data}');
      }
      final data = response.data as Map<String, dynamic>? ?? {};
      final rawItems = data['items'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _items = rawItems
            .whereType<Map>()
            .map(
              (item) =>
                  _YahooNewsItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((item) => item.url.startsWith('http'))
            .toList();
        _lastFetchedAt = DateTime.tryParse(
          data['fetched_at']?.toString() ?? '',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _newsError = 'ニュース取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoadingNews = false);
    }
  }

  Future<void> _loadArchive() async {
    if (_supabase.auth.currentUser == null) {
      setState(() {
        _archivedItems = [];
        _isLoadingArchive = false;
      });
      return;
    }
    setState(() {
      _isLoadingArchive = true;
      _archiveError = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'news_archive.list'},
      );
      if (response.status != 200) {
        throw Exception('HTTP ${response.status}: ${response.data}');
      }
      final data = response.data as Map<String, dynamic>? ?? {};
      final rawItems = data['items'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _archivedItems = rawItems
            .whereType<Map>()
            .map(
              (row) => _ArchivedItem.fromRow(Map<String, dynamic>.from(row)),
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _archiveError = 'アーカイブ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoadingArchive = false);
    }
  }

  Future<void> _saveToArchive(_YahooNewsItem item) async {
    if (_supabase.auth.currentUser == null) {
      _showSnack('アーカイブ保存にはログインが必要です');
      return;
    }
    if (_savingUrls.contains(item.url)) return;
    setState(() => _savingUrls.add(item.url));
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'news_archive.save',
          'url': item.url,
          'title': item.title,
          'source': item.source,
          'category': item.category,
          'published_at': item.publishedAt?.toIso8601String(),
        },
      );
      if (response.status != 200) {
        throw Exception('HTTP ${response.status}: ${response.data}');
      }
      final data = response.data as Map<String, dynamic>? ?? {};
      final duplicated = data['duplicated'] == true;
      _showSnack(
        duplicated
            ? 'すでにアーカイブ済みです'
            : 'アーカイブに保存し、Wayback Machine へスナップショットを依頼しました',
      );
      await _loadArchive();
    } catch (e) {
      _showSnack('アーカイブ保存に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _savingUrls.remove(item.url));
    }
  }

  Future<void> _refreshWayback(_ArchivedItem item) async {
    if (_busyArchiveIds.contains(item.id)) return;
    setState(() => _busyArchiveIds.add(item.id));
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'news_archive.refresh_wayback', 'id': item.id},
      );
      if (response.status != 200) {
        throw Exception('HTTP ${response.status}: ${response.data}');
      }
      await _loadArchive();
      final refreshed =
          _archivedItems.where((row) => row.id == item.id).toList();
      final saved = refreshed.isNotEmpty && refreshed.first.waybackUrl != null;
      _showSnack(
        saved ? 'スナップショットを確認しました' : 'スナップショットはまだ生成中です。時間をおいて再確認してください',
      );
    } catch (e) {
      _showSnack('スナップショット確認に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _busyArchiveIds.remove(item.id));
    }
  }

  Future<void> _deleteArchived(_ArchivedItem item) async {
    if (_busyArchiveIds.contains(item.id)) return;
    setState(() => _busyArchiveIds.add(item.id));
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'news_archive.delete', 'id': item.id},
      );
      if (response.status != 200) {
        throw Exception('HTTP ${response.status}: ${response.data}');
      }
      await _loadArchive();
    } catch (e) {
      _showSnack('削除に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _busyArchiveIds.remove(item.id));
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> get _categories {
    final values = {'主要', ..._items.map((item) => item.category)};
    return values.toList();
  }

  List<_YahooNewsItem> get _filteredItems {
    if (_selectedCategory == '主要') return _items;
    return _items.where((item) => item.category == _selectedCategory).toList();
  }

  Set<String> get _archivedUrls =>
      _archivedItems.map((item) => item.url).toSet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Yahoo!ニュース アーカイブ',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: () {
              _loadNews();
              _loadArchive();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _accent,
          unselectedLabelColor: _muted,
          indicatorColor: _accent,
          tabs: const [
            Tab(text: '最新トピックス'),
            Tab(text: 'アーカイブ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNewsTab(), _buildArchiveTab()],
      ),
    );
  }

  Widget _buildNewsTab() {
    return RefreshIndicator(
      onRefresh: _loadNews,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildNoticeCard()),
          SliverToBoxAdapter(child: _buildCategoryTabs()),
          if (_newsError != null)
            SliverToBoxAdapter(child: _buildError(_newsError!, _loadNews))
          else if (_isLoadingNews)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredItems.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  '配信できるトピックスがありません',
                  style: TextStyle(color: _muted),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList.separated(
                itemCount: _filteredItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _buildNewsCard(_filteredItems[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1BEE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: _accent),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '本文はこのサイトに保存されません',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '著作権保護のため、保存されるのは見出し・リンク・配信日時のみです。'
            '保存時に Internet Archive (Wayback Machine) へスナップショット作成を依頼し、'
            '元記事の公開終了後は archive.org 上のスナップショットで閲覧します。',
            style: const TextStyle(fontSize: 12, color: _muted, height: 1.5),
          ),
          if (_lastFetchedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '最終取得: ${DateFormat('MM/dd HH:mm').format(_lastFetchedAt!.toLocal())}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category == _selectedCategory;
          return ChoiceChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) => setState(() => _selectedCategory = category),
            selectedColor: _accent,
            labelStyle: TextStyle(
              color: selected ? Colors.white : _muted,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            backgroundColor: Colors.white,
            side: const BorderSide(color: _border),
          );
        },
      ),
    );
  }

  Widget _buildNewsCard(_YahooNewsItem item) {
    final archived = _archivedUrls.contains(item.url);
    final saving = _savingUrls.contains(item.url);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _CategoryBadge(label: item.category),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.publishedAt == null
                      ? item.source
                      : '${item.source} · ${DateFormat('MM/dd HH:mm').format(item.publishedAt!.toLocal())}',
                  style: const TextStyle(fontSize: 11, color: _muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _openUrl(item.url),
                icon: const Icon(Icons.open_in_new, size: 15),
                label: const Text('元記事'),
                style: TextButton.styleFrom(
                  foregroundColor: _muted,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const Spacer(),
              if (archived)
                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 15, color: _accent),
                    SizedBox(width: 4),
                    Text(
                      'アーカイブ済み',
                      style: TextStyle(
                        fontSize: 12,
                        color: _accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: saving ? null : () => _saveToArchive(item),
                  icon: saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.archive_outlined, size: 15),
                  label: Text(saving ? '保存中...' : 'アーカイブ保存'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveTab() {
    if (_supabase.auth.currentUser == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'アーカイブの利用にはログインが必要です',
            style: TextStyle(color: _muted),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadArchive,
      child: CustomScrollView(
        slivers: [
          if (_archiveError != null)
            SliverToBoxAdapter(
              child: _buildError(_archiveError!, _loadArchive),
            )
          else if (_isLoadingArchive)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_archivedItems.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'アーカイブはまだありません。\n「最新トピックス」タブから保存できます。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, height: 1.6),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList.separated(
                itemCount: _archivedItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _buildArchivedCard(_archivedItems[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArchivedCard(_ArchivedItem item) {
    final busy = _busyArchiveIds.contains(item.id);
    final hasSnapshot = item.waybackUrl != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title.isEmpty ? item.url : item.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _CategoryBadge(label: item.category),
              const SizedBox(width: 8),
              _WaybackStatusBadge(status: item.waybackStatus),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.archivedAt == null
                      ? item.source
                      : '保存: ${DateFormat('yyyy/MM/dd HH:mm').format(item.archivedAt!.toLocal())}',
                  style: const TextStyle(fontSize: 11, color: _muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => _openUrl(item.url),
                icon: const Icon(Icons.open_in_new, size: 15),
                label: const Text('元記事'),
                style: TextButton.styleFrom(
                  foregroundColor: _muted,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              if (hasSnapshot)
                TextButton.icon(
                  onPressed: () => _openUrl(item.waybackUrl!),
                  icon: const Icon(Icons.history, size: 15),
                  label: const Text('Waybackで開く'),
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: busy ? null : () => _refreshWayback(item),
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 15),
                  label: const Text('スナップショット再確認'),
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              TextButton.icon(
                onPressed: busy ? null : () => _deleteArchived(item),
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text('削除'),
                style: TextButton.styleFrom(
                  foregroundColor: _muted,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message, Future<void> Function() onRetry) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9F1239)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WaybackStatusBadge extends StatelessWidget {
  const _WaybackStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      'saved' => (
          'スナップショット済',
          const Color(0xFF166534),
          const Color(0xFFDCFCE7)
        ),
      'requested' => (
          'スナップショット生成中',
          const Color(0xFF92400E),
          const Color(0xFFFEF3C7),
        ),
      _ => ('未確認', const Color(0xFF64748B), const Color(0xFFF1F5F9)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _YahooNewsItem {
  const _YahooNewsItem({
    required this.title,
    required this.url,
    required this.source,
    required this.category,
    this.publishedAt,
  });

  final String title;
  final String url;
  final String source;
  final String category;
  final DateTime? publishedAt;

  factory _YahooNewsItem.fromJson(Map<String, dynamic> json) {
    return _YahooNewsItem(
      title: json['title']?.toString() ?? '(無題)',
      url: json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? 'Yahoo!ニュース',
      category: json['category']?.toString() ?? '主要',
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
    );
  }
}

class _ArchivedItem {
  const _ArchivedItem({
    required this.id,
    required this.title,
    required this.url,
    required this.source,
    required this.category,
    required this.waybackStatus,
    this.waybackUrl,
    this.publishedAt,
    this.archivedAt,
  });

  final String id;
  final String title;
  final String url;
  final String source;
  final String category;
  final String waybackStatus;
  final String? waybackUrl;
  final DateTime? publishedAt;
  final DateTime? archivedAt;

  factory _ArchivedItem.fromRow(Map<String, dynamic> row) {
    final metadata = row['metadata'];
    final meta = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : <String, dynamic>{};
    final waybackUrl = meta['wayback_url']?.toString();
    return _ArchivedItem(
      id: row['id']?.toString() ?? '',
      title: meta['title']?.toString() ?? '',
      url: meta['url']?.toString() ?? '',
      source: meta['source']?.toString() ?? 'Yahoo!ニュース',
      category: meta['category']?.toString() ?? '総合',
      waybackStatus: meta['wayback_status']?.toString() ?? 'pending',
      waybackUrl: (waybackUrl != null && waybackUrl.startsWith('http'))
          ? waybackUrl
          : null,
      publishedAt: DateTime.tryParse(meta['published_at']?.toString() ?? ''),
      archivedAt: DateTime.tryParse(
        meta['archived_at']?.toString() ?? row['created_at']?.toString() ?? '',
      ),
    );
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
