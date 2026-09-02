import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// コードプレイグラウンドページ
/// code-playground Edge Function と連携
/// GitHub Gist / CodePen / Claude Code / Codex 競合
class CodePlaygroundPage extends StatefulWidget {
  const CodePlaygroundPage({super.key});

  @override
  State<CodePlaygroundPage> createState() => _CodePlaygroundPageState();
}

class _CodePlaygroundPageState extends State<CodePlaygroundPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['snippets', 'collections', 'stats'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _snippets = [];
  List<Map<String, dynamic>> _collections = [];
  Map<String, dynamic> _stats = {};

  List<String> _languages = [];
  Map<String, dynamic> _templates = {};
  String _selectedLanguage = 'javascript';
  bool _isPublic = false;

  final _titleCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchLanguages();
    _fetchSnippets();
    _fetchStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLanguages() async {
    try {
      final res = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'playground.list'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final langs = data['languages'];
        final tmpl = data['templates'];
        setState(() {
          if (langs is List) {
            _languages = langs.map((l) => l as String).toList();
          }
          if (tmpl is Map) {
            _templates = tmpl.map(
              (k, v) => MapEntry(k as String, v as Map<String, dynamic>),
            );
          }
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _fetchSnippets() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions
          .invoke('enterprise-hub', body: {'action': 'playground.list'});
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final list = data['snippets'];
        if (list is List) {
          setState(() {
            _snippets = list.map((s) => s as Map<String, dynamic>).toList();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCollections() async {
    try {
      final res = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'playground.list'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final list = data['collections'];
        if (list is List) {
          setState(() {
            _collections = list.map((c) => c as Map<String, dynamic>).toList();
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _fetchStats() async {
    try {
      final res = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'playground.list'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final stats = data['stats'];
        if (stats is Map<String, dynamic>) {
          setState(() => _stats = stats);
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _saveSnippet() async {
    final title = _titleCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (title.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルとコードを入力してください')),
      );
      return;
    }
    try {
      final res = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'playground.save',
          'title': title,
          'code': code,
          'language': _selectedLanguage,
          'description': _descCtrl.text.trim(),
          'is_public': _isPublic,
        },
      );
      final data = res.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        if (mounted) {
          Navigator.of(context).pop();
          _titleCtrl.clear();
          _codeCtrl.clear();
          _descCtrl.clear();
          setState(() => _isPublic = false);
          _fetchSnippets();
          _fetchStats();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('スニペット保存完了'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  void _showNewSnippetDialog() {
    // Preload template if available
    if (_templates.containsKey(_selectedLanguage)) {
      final tmpl = _templates[_selectedLanguage] as Map<String, dynamic>;
      _codeCtrl.text = (tmpl['code'] as String?) ?? '';
      _titleCtrl.text = (tmpl['name'] as String?) ?? '';
    }
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('新規スニペット'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'タイトル *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: '言語',
                      border: OutlineInputBorder(),
                    ),
                    items: _languages
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDlg(() => _selectedLanguage = v);
                        if (_templates.containsKey(v)) {
                          final tmpl = _templates[v] as Map<String, dynamic>;
                          _codeCtrl.text = (tmpl['code'] as String?) ?? '';
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeCtrl,
                    maxLines: 10,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'コード *',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '説明 (任意)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('公開スニペット'),
                    subtitle: const Text('他のユーザーと共有'),
                    value: _isPublic,
                    onChanged: (v) => setDlg(() => _isPublic = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(onPressed: _saveSnippet, child: const Text('保存')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('コードプレイグラウンド'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.code), text: 'スニペット'),
            Tab(icon: Icon(Icons.folder_open), text: 'コレクション'),
            Tab(icon: Icon(Icons.bar_chart), text: '統計'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _fetchSnippets,
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewSnippetDialog,
        icon: const Icon(Icons.add),
        label: const Text('新規スニペット'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage!),
                      TextButton(
                        onPressed: _fetchSnippets,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSnippetsTab(),
                    _buildCollectionsTab(),
                    _buildStatsTab(),
                  ],
                ),
    );
  }

  Widget _buildSnippetsTab() {
    if (_snippets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.code_off,
              size: 64,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 12),
            const Text('スニペットがありません'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _showNewSnippetDialog,
              icon: const Icon(Icons.add),
              label: const Text('最初のスニペットを作成'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchSnippets,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _snippets.length,
        itemBuilder: (context, i) {
          final s = _snippets[i];
          final title = s['title'] as String? ?? '無題';
          final lang = s['language'] as String? ?? '';
          final code = s['code'] as String? ?? '';
          final isPublic = s['is_public'] == true;
          final shareCode = s['share_code'] as String?;
          final preview =
              code.length > 80 ? '${code.substring(0, 80)}...' : code;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: _langIcon(lang),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              subtitle: Text(
                lang,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPublic)
                    const Tooltip(
                      message: '公開',
                      child: Icon(
                        Icons.public,
                        size: 16,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  const Icon(Icons.expand_more),
                ],
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).colorScheme.onSurface,
                  child: Text(
                    preview,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF4CAF50),
                      height: 1.5,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('コピーしました')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('コピー'),
                      ),
                      if (shareCode != null) ...[
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: shareCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('共有コード: $shareCode コピー済み'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share, size: 16),
                          label: Text('共有 ($shareCode)'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _langIcon(String lang) {
    final Map<String, Color> langColors = {
      'javascript': const Color(0xFFFFA000),
      'typescript': const Color(0xFF3D5AFE),
      'python': const Color(0xFF4CAF50),
      'dart': const Color(0xFF3D5AFE),
      'rust': const Color(0xFFFF6B35),
      'go': const Color(0xFF00BCD4),
      'java': const Color(0xFFE53935),
      'sql': const Color(0xFF3D5AFE),
      'html': const Color(0xFFFF6B35),
      'css': const Color(0xFF3D5AFE),
    };
    final color = langColors[lang] ?? const Color(0xFF9CA3AF);
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        lang.isEmpty ? '?' : lang.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildCollectionsTab() {
    if (_collections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off,
              size: 64,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 12),
            const Text('コレクションがありません'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _showNewCollectionDialog,
              icon: const Icon(Icons.create_new_folder),
              label: const Text('コレクション作成'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchCollections();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _collections.length,
        itemBuilder: (context, i) {
          final c = _collections[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.folder, color: Color(0xFFFFC107)),
              title: Text(c['name'] as String? ?? ''),
              subtitle: Text(c['description'] as String? ?? ''),
              trailing: Text('${c['snippet_count'] ?? 0}件'),
            ),
          );
        },
      ),
    );
  }

  void _showNewCollectionDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規コレクション'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'コレクション名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: '説明',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await _supabase.functions.invoke(
                'enterprise-hub',
                body: {
                  'action': 'playground.save',
                  'title': name,
                  'code': '// ${descCtrl.text.trim()}',
                  'language': 'markdown',
                },
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              _fetchCollections();
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    final total = _stats['totalSnippets'] as int? ?? 0;
    final publicCount = _stats['publicCount'] as int? ?? 0;
    final langBreakdown = _stats['languageBreakdown'];
    final breakdown = langBreakdown is List
        ? langBreakdown.map((b) => b as Map<String, dynamic>).toList()
        : <Map<String, dynamic>>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '総スニペット',
                  '$total件',
                  Icons.code,
                  const Color(0xFF3D5AFE),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  '公開スニペット',
                  '$publicCount件',
                  Icons.public,
                  const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '言語別内訳',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          if (breakdown.isEmpty)
            const Text(
              'データなし',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            )
          else
            ...breakdown.map((b) {
              final lang = b['language'] as String? ?? '';
              final count = b['count'] as int? ?? 0;
              final fraction = total > 0 ? count / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        lang,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: fraction,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
