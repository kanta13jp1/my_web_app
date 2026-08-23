import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// サイトマップ・Web分析ページ
/// ページ別アクセス数・直帰率・サイトマップ構造表示。
/// sitemap-analytics Edge Function と連携。
class SitemapAnalyticsPage extends StatefulWidget {
  const SitemapAnalyticsPage({super.key});

  @override
  State<SitemapAnalyticsPage> createState() => _SitemapAnalyticsPageState();
}

class _SitemapAnalyticsPageState extends State<SitemapAnalyticsPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['overview', 'pages'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _pages = [];
  Map<String, dynamic> _overview = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final ovRes = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'sitemap.analyze'},
      );
      setState(() {
        _pages = [];
        final ovData = ovRes.data;
        if (ovData is Map<String, dynamic>) _overview = ovData;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('サイトマップ・Web分析'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: '概要'),
            Tab(icon: Icon(Icons.web), text: 'ページ別'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [_buildOverviewTab(), _buildPagesTab()],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
          const SizedBox(height: 12),
          Text(_errorMessage!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetchData, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final totalViews = _overview['totalPageViews'] as int? ?? 0;
    final uniqueVisitors = _overview['uniqueVisitors'] as int? ?? 0;
    final avgDuration = _overview['avgSessionDuration'] as String? ?? '—';
    final bounceRate = _overview['bounceRate'] as num? ?? 0;
    final totalPages = _overview['totalPages'] as int? ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatRow(
          Icons.visibility,
          'ページビュー',
          '$totalViews',
          const Color(0xFF3D5AFE),
        ),
        _buildStatRow(
          Icons.people,
          'ユニーク訪問者',
          '$uniqueVisitors',
          const Color(0xFF4CAF50),
        ),
        _buildStatRow(
          Icons.timer,
          '平均セッション時間',
          avgDuration,
          const Color(0xFFFF6B35),
        ),
        _buildStatRow(
          Icons.exit_to_app,
          '直帰率',
          '${bounceRate.toStringAsFixed(1)}%',
          const Color(0xFFE53935),
        ),
        _buildStatRow(
          Icons.web,
          '総ページ数',
          '$totalPages',
          const Color(0xFF3D5AFE),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPagesTab() {
    if (_pages.isEmpty) {
      return const Center(
        child: Text(
          'ページデータがありません',
          style: TextStyle(
            color: Color(0xFFB0B0B0),
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pages.length,
      itemBuilder: (ctx, i) {
        final pg = _pages[i];
        final path = pg['path'] as String? ?? '/page-${i + 1}';
        final views = pg['views'] as int? ?? 0;
        final bounce = pg['bounceRate'] as num? ?? 0;
        final maxViews = _pages
            .map((p) => (p['views'] as int? ?? 0))
            .fold(1, (a, b) => a > b ? a : b);
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.link,
                      size: 16,
                      color: Color(0xFF3D5AFE),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        path,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$views PV',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3D5AFE),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: maxViews > 0 ? views / maxViews : 0,
                  minHeight: 4,
                ),
                const SizedBox(height: 4),
                Text(
                  '直帰率: ${bounce.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB0B0B0),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
