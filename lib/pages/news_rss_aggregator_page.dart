import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/blog_service.dart';

class NewsRssAggregatorPage extends StatefulWidget {
  const NewsRssAggregatorPage({super.key});

  @override
  State<NewsRssAggregatorPage> createState() => _NewsRssAggregatorPageState();
}

class _NewsRssAggregatorPageState extends State<NewsRssAggregatorPage> {
  final _supabase = Supabase.instance.client;
  final _blogService = BlogService();
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isAdding = false;
  bool _isDrafting = false;
  String? _errorMessage;
  String _selectedCategory = '総合';
  DateTime? _lastFetchedAt;
  List<_NewsFeedSource> _personalFeeds = [];
  List<_NewsItem> _items = [];
  List<_NewsItem> _signals = [];

  static const _accent = Color(0xFFE53935);
  static const _ink = Color(0xFF172033);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  static const _defaultFeeds = <_NewsFeedSource>[
    _NewsFeedSource(
      title: 'NHK NEWS WEB',
      url: 'https://www3.nhk.or.jp/rss/news/cat0.xml',
      category: '総合',
    ),
    _NewsFeedSource(
      title: 'ITmedia NEWS',
      url: 'https://rss.itmedia.co.jp/rss/2.0/news_bursts.xml',
      category: 'IT',
    ),
    _NewsFeedSource(
      title: 'ITmedia AI+',
      url: 'https://rss.itmedia.co.jp/rss/2.0/aiplus.xml',
      category: 'AI',
    ),
    _NewsFeedSource(
      title: 'CNET Japan',
      url: 'http://feed.japan.cnet.com/rss/index.rdf',
      category: 'IT',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _loadPersonalFeeds();
      final feeds = [..._defaultFeeds, ..._personalFeeds];
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'rss.fetch_latest',
          'feeds': feeds.map((feed) => feed.toJson()).toList(),
          'per_feed_limit': 10,
          'limit': 80,
          'signal_limit': 24,
        },
      );
      if (response.status != 200) {
        throw Exception('HTTP ${response.status}: ${response.data}');
      }
      final data = response.data as Map<String, dynamic>? ?? {};
      final rawItems = data['items'] as List? ?? [];
      final rawSignals = data['signals'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _items = rawItems
            .whereType<Map>()
            .map((item) => _NewsItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _signals = rawSignals
            .whereType<Map>()
            .map((item) => _NewsItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _lastFetchedAt = DateTime.tryParse(
          data['fetched_at']?.toString() ?? '',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'ニュース取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPersonalFeeds() async {
    if (_supabase.auth.currentUser == null) {
      _personalFeeds = [];
      return;
    }
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'rss.list_feeds'},
      );
      final feeds = (response.data as Map<String, dynamic>?)?['feeds'] as List?;
      if (feeds == null) return;
      _personalFeeds = feeds
          .whereType<Map>()
          .map((row) {
            final metadata = row['metadata'];
            final meta = metadata is Map ? metadata : row;
            return _NewsFeedSource(
              title: meta['title']?.toString() ?? 'RSS',
              url: meta['url']?.toString() ?? '',
              category: meta['category']?.toString() ?? '購読',
            );
          })
          .where((feed) => feed.url.startsWith('http'))
          .toList();
    } catch (_) {
      _personalFeeds = [];
    }
  }

  Future<void> _addFeed() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || _isAdding) return;
    setState(() => _isAdding = true);
    try {
      final title =
          _titleCtrl.text.trim().isEmpty ? url : _titleCtrl.text.trim();
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'rss.add_feed',
          'url': url,
          'title': title,
          'category': '購読',
        },
      );
      if (response.status != 200) {
        throw Exception('HTTP ${response.status}: ${response.data}');
      }
      _urlCtrl.clear();
      _titleCtrl.clear();
      await _loadNews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('フィード追加に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _createBlogDraftFromSignals() async {
    if (_signals.isEmpty || _isDrafting) return;
    if (_supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ブログ下書き化にはログインが必要です')));
      return;
    }
    setState(() => _isDrafting = true);
    try {
      final signals = _signals.take(5).toList();
      final lead = signals.first;
      final response = await _blogService.insertPost(
        title: _shortenTitle('ニュースシグナル: ${lead.title}', 80),
        content: _buildBlogDraftMarkdown(signals),
        targetPlatforms: const ['note', 'qiita', 'devto'],
        tags: const ['AI', 'ニュース', '自動化', '外部脳'],
        notes:
            'Generated from news.signal_rank at ${DateTime.now().toIso8601String()}',
      );
      if (!mounted) return;
      final post = response['post'] is Map ? response['post'] as Map : null;
      final postId = post?['id']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            postId == null ? 'ブログ下書きを作成しました' : 'ブログ下書きを作成しました: $postId',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ブログ下書き化に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _isDrafting = false);
    }
  }

  String _buildBlogDraftMarkdown(List<_NewsItem> signals) {
    final fetched = _lastFetchedAt == null
        ? DateTime.now().toIso8601String()
        : _lastFetchedAt!.toIso8601String();
    final lead = signals.first;
    final buffer = StringBuffer()
      ..writeln('# ${lead.title}')
      ..writeln()
      ..writeln('> RSSニュースをAI外部脳の素材として取り込み、重要シグナルを抽出した下書きです。')
      ..writeln()
      ..writeln('- 取得時刻: $fetched')
      ..writeln('- 主要カテゴリ: ${lead.category}')
      ..writeln('- 初期信頼度: ${lead.confidence ?? 'unknown'}')
      ..writeln()
      ..writeln('## 要点')
      ..writeln()
      ..writeln(lead.summary.isEmpty ? '- 本文要約は公開前に追記する。' : '- ${lead.summary}')
      ..writeln()
      ..writeln('## 注目シグナル')
      ..writeln();
    for (final item in signals) {
      buffer
        ..writeln('### ${item.title}')
        ..writeln()
        ..writeln('- スコア: ${item.signalScore ?? 0}')
        ..writeln('- 出典: ${item.source}')
        ..writeln('- URL: ${item.url}')
        ..writeln('- なぜ重要か: ${item.whyItMatters ?? '要確認'}')
        ..writeln('- 検証メモ: ${item.verificationWarning ?? '一次情報を確認'}')
        ..writeln();
    }
    buffer
      ..writeln('## 公開前チェック')
      ..writeln()
      ..writeln('- 一次情報と公開日時を確認する')
      ..writeln('- 固有名詞、金額、引用元を確認する')
      ..writeln('- 投資・医療・法律など高リスク領域は断定表現を避ける')
      ..writeln('- 関連する既存メモやブログ記事へリンクする')
      ..writeln()
      ..writeln('## 次の自動化')
      ..writeln()
      ..writeln('- raw/news に原文を保存')
      ..writeln('- wiki/sources に要約を保存')
      ..writeln('- blog_posts の draft を人間レビュー後に公開');
    return buffer.toString();
  }

  String _shortenTitle(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 3)}...';
  }

  List<String> get _categories {
    final values = {'総合', ..._items.map((item) => item.category)};
    return values.toList();
  }

  List<_NewsItem> get _filteredItems {
    if (_selectedCategory == '総合') return _items;
    return _items.where((item) => item.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final items = _filteredItems;
    final lead = items.isNotEmpty ? items.first : null;
    final rest = lead == null ? <_NewsItem>[] : items.skip(1).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'ニュース',
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
            onPressed: _isLoading ? null : _loadNews,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNews,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildCategoryTabs()),
            if (_errorMessage != null)
              SliverToBoxAdapter(child: _buildError())
            else if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (lead == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    '配信できるニュースがありません',
                    style: TextStyle(color: _muted),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _LeadStory(item: lead)),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _SignalPanel(
                                items: _signals,
                                isDrafting: _isDrafting,
                                onCreateDraft: _createBlogDraftFromSignals,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _LeadStory(item: lead),
                            const SizedBox(height: 12),
                            _SignalPanel(
                              items: _signals,
                              isDrafting: _isDrafting,
                              onCreateDraft: _createBlogDraftFromSignals,
                            ),
                          ],
                        ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: rest.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _border),
                  itemBuilder: (context, index) => _NewsRow(item: rest[index]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final fetched = _lastFetchedAt == null
        ? ''
        : DateFormat('MM/dd HH:mm').format(_lastFetchedAt!.toLocal());
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 28, color: _accent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'トップニュース',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
              if (fetched.isNotEmpty)
                Text(
                  '$fetched 更新',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFeedInput(),
        ],
      ),
    );
  }

  Widget _buildFeedInput() {
    final signedIn = _supabase.auth.currentUser != null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            controller: _titleCtrl,
            enabled: signedIn,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'フィード名',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 360,
          child: TextField(
            controller: _urlCtrl,
            enabled: signedIn,
            decoration: InputDecoration(
              isDense: true,
              labelText: signedIn ? 'RSS URL' : 'ログインでRSS購読を追加できます',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => signedIn ? _addFeed() : null,
          ),
        ),
        FilledButton.icon(
          onPressed: signedIn && !_isAdding ? _addFeed : null,
          icon: _isAdding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: const Text('追加'),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _categories.map((category) {
          final selected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: selected,
              selectedColor: _accent,
              labelStyle: TextStyle(
                color: selected ? Colors.white : _ink,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              onSelected: (_) => setState(() => _selectedCategory = category),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          border: Border.all(color: const Color(0xFFFDA4AF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Color(0xFF9F1239), height: 1.5),
          ),
        ),
      ),
    );
  }
}

class _LeadStory extends StatelessWidget {
  const _LeadStory({required this.item});

  final _NewsItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openUrl(item.url),
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _NewsRssAggregatorPageState._border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SourceLine(item: item),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: const TextStyle(
                  color: _NewsRssAggregatorPageState._ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              if (item.summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  item.summary,
                  style: const TextStyle(
                    color: _NewsRssAggregatorPageState._muted,
                    fontSize: 14,
                    height: 1.65,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              const Row(
                children: [
                  Text(
                    '記事を開く',
                    style: TextStyle(
                      color: _NewsRssAggregatorPageState._accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new,
                    color: _NewsRssAggregatorPageState._accent,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalPanel extends StatelessWidget {
  const _SignalPanel({
    required this.items,
    required this.isDrafting,
    required this.onCreateDraft,
  });

  final List<_NewsItem> items;
  final bool isDrafting;
  final VoidCallback onCreateDraft;

  @override
  Widget build(BuildContext context) {
    final signals = items.take(5).toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NewsRssAggregatorPageState._border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: _NewsRssAggregatorPageState._accent,
                ),
                const SizedBox(width: 6),
                Text(
                  '注目シグナル',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (signals.isEmpty)
              const Text(
                'ランキング対象がありません',
                style: TextStyle(color: _NewsRssAggregatorPageState._muted),
              )
            else
              ...signals.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => _openUrl(item.url),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${item.signalScore ?? 0}',
                            style: const TextStyle(
                              color: _NewsRssAggregatorPageState._accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  height: 1.35,
                                ),
                              ),
                              Text(
                                item.whyItMatters ?? item.source,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _NewsRssAggregatorPageState._muted,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Divider(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: signals.isEmpty || isDrafting ? null : onCreateDraft,
                icon: isDrafting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.edit_note),
                label: const Text('ブログ下書き化'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.item});

  final _NewsItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openUrl(item.url),
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _NewsRssAggregatorPageState._border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SourceLine(item: item),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: _NewsRssAggregatorPageState._ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                if (item.summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.summary,
                    style: const TextStyle(
                      color: _NewsRssAggregatorPageState._muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.item});

  final _NewsItem item;

  @override
  Widget build(BuildContext context) {
    final time = item.publishedAt == null
        ? ''
        : DateFormat('MM/dd HH:mm').format(item.publishedAt!.toLocal());
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            item.category,
            style: const TextStyle(
              color: _NewsRssAggregatorPageState._accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            item.source,
            style: const TextStyle(
              color: _NewsRssAggregatorPageState._muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (time.isNotEmpty)
          Text(
            time,
            style: const TextStyle(
              color: _NewsRssAggregatorPageState._muted,
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}

class _NewsFeedSource {
  const _NewsFeedSource({
    required this.title,
    required this.url,
    required this.category,
  });

  final String title;
  final String url;
  final String category;

  Map<String, String> toJson() => {
        'title': title,
        'url': url,
        'category': category,
      };
}

class _NewsItem {
  const _NewsItem({
    required this.id,
    required this.title,
    required this.url,
    required this.source,
    required this.category,
    required this.summary,
    this.publishedAt,
    this.signalScore,
    this.confidence,
    this.verificationWarning,
    this.whyItMatters,
  });

  final String id;
  final String title;
  final String url;
  final String source;
  final String category;
  final String summary;
  final DateTime? publishedAt;
  final int? signalScore;
  final String? confidence;
  final String? verificationWarning;
  final String? whyItMatters;

  factory _NewsItem.fromJson(Map<String, dynamic> json) {
    return _NewsItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '(無題)',
      url: json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? 'RSS',
      category: json['category']?.toString() ?? '総合',
      summary: json['summary']?.toString() ?? '',
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      signalScore: _intOrNull(json['signal_score']),
      confidence: json['confidence']?.toString(),
      verificationWarning: json['verification_warning']?.toString(),
      whyItMatters: json['why_it_matters']?.toString(),
    );
  }
}

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString());
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
