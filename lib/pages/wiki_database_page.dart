import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// Wiki・データベースページ
/// wiki-database Edge Function と連携して階層型Wikiを管理
/// Notion競合 — ページ階層・テーブルビュー・リンク参照
class WikiDatabasePage extends StatefulWidget {
  const WikiDatabasePage({super.key});

  @override
  State<WikiDatabasePage> createState() => _WikiDatabasePageState();
}

class _WikiDatabasePageState extends State<WikiDatabasePage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['pages', 'detail'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _pages = [];
  String? _selectedPageId;
  Map<String, dynamic>? _selectedPage;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _tableRows = [];
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPages() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions
          .invoke('enterprise-hub', body: {'action': 'wiki.list'});
      final data = response.data;
      if (data is Map<String, dynamic> && data['pages'] is List) {
        setState(
          () => _pages = (data['pages'] as List).cast<Map<String, dynamic>>(),
        );
      } else {
        setState(() => _pages = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Wiki ページの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPageDetail(String pageId) async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'wiki.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['pages'] is List) {
        final allPages = (data['pages'] as List).cast<Map<String, dynamic>>();
        final page = allPages.where((p) {
          final meta = p['metadata'] as Map<String, dynamic>? ?? p;
          return (meta['id'] ?? p['id'])?.toString() == pageId;
        }).firstOrNull;
        setState(() {
          _selectedPage = page;
          _children = [];
          _tableRows = [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'ページ詳細の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createPage({String? parentId}) async {
    _titleCtrl.clear();
    _contentCtrl.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新しいページを作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'タイトル'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(labelText: '内容 (Markdown)'),
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (confirmed != true || _titleCtrl.text.trim().isEmpty) return;
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'wiki.create',
          'title': _titleCtrl.text.trim(),
          'content': _contentCtrl.text.trim(),
          if (parentId != null) 'category': parentId,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ページを作成しました')),
        );
      }
      await _fetchPages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _addTableRow(String pageId) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('行を追加'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '内容 (JSON またはテキスト)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (confirmed != true) return;
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'sheet.add_row',
          'sheet_id': pageId,
          'data': {'content': ctrl.text.trim()},
        },
      );
      await _fetchPageDetail(pageId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('行の追加に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Wiki・データベース'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.article_outlined), text: 'ページ一覧'),
            Tab(icon: Icon(Icons.table_chart_outlined), text: 'ページ詳細'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _fetchPages,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新規ページ作成',
            onPressed: () => _createPage(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetchPages,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPageList(),
                    _buildPageDetail(),
                  ],
                ),
    );
  }

  Widget _buildPageList() {
    if (_pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.article_outlined,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            const Text(
              'Wikiページがありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _createPage(),
              icon: const Icon(Icons.add),
              label: const Text('最初のページを作成'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchPages,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pages.length,
        itemBuilder: (context, index) {
          final page = _pages[index];
          final title = page['title']?.toString() ?? '無題';
          final pageId =
              page['page_id']?.toString() ?? page['id']?.toString() ?? '';
          final createdAt = page['createdAt']?.toString() ?? '';
          final isSelected = _selectedPageId == pageId;
          return Card(
            elevation: isSelected ? 4 : 1,
            color: isSelected
                ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
                : null,
            shadowColor: isSelected ? null : const Color(0xFF1E1E1E),
            child: ListTile(
              leading:
                  const Icon(Icons.article_outlined, color: Color(0xFF4F46E5)),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              subtitle: createdAt.isNotEmpty
                  ? Text(
                      createdAt.length > 10
                          ? createdAt.substring(0, 10)
                          : createdAt,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                      ),
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    tooltip: 'サブページを追加',
                    onPressed: () => _createPage(parentId: pageId),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () {
                setState(() {
                  _selectedPageId = pageId;
                  _selectedPage = null;
                  _children = [];
                  _tableRows = [];
                });
                _fetchPageDetail(pageId);
                _tabController.animateTo(1);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageDetail() {
    if (_selectedPage == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text(
              '左のタブからページを選択してください',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    final title = _selectedPage!['title']?.toString() ?? '無題';
    final content = _selectedPage!['content']?.toString() ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const Divider(height: 24),
          if (content.isNotEmpty) ...[
            const Text(
              '内容',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(content),
            ),
            const SizedBox(height: 16),
          ],
          if (_children.isNotEmpty) ...[
            const Text(
              'サブページ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ..._children.map(
              (child) => ListTile(
                leading: const Icon(
                  Icons.subdirectory_arrow_right,
                  color: Color(0xFF4F46E5),
                ),
                title: Text(child['title']?.toString() ?? '無題'),
                dense: true,
                onTap: () {
                  final id = child['page_id']?.toString() ??
                      child['id']?.toString() ??
                      '';
                  if (id.isNotEmpty) {
                    setState(() => _selectedPageId = id);
                    _fetchPageDetail(id);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              const Text(
                'テーブルデータ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addTableRow(_selectedPageId!),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('行を追加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_tableRows.isEmpty)
            const Text(
              'テーブルデータなし',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            )
          else
            ..._tableRows.map((row) {
              final content2 =
                  row['content']?.toString() ?? row['data']?.toString() ?? '';
              final createdAt = row['createdAt']?.toString() ?? '';
              return Card(
                color: const Color(0xFF1E1E1E),
                child: ListTile(
                  leading:
                      const Icon(Icons.data_array, color: Color(0xFF4F46E5)),
                  title: Text(
                    content2.length > 60
                        ? '${content2.substring(0, 60)}...'
                        : content2,
                  ),
                  subtitle: createdAt.isNotEmpty
                      ? Text(
                          createdAt.length > 10
                              ? createdAt.substring(0, 10)
                              : createdAt,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                          ),
                        )
                      : null,
                  dense: true,
                ),
              );
            }),
        ],
      ),
    );
  }
}
