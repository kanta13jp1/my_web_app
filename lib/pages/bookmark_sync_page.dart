import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ブックマーク同期ページ
/// tools-hub:bookmark.* actions でブックマークを管理
/// Pocket / Instapaper 競合 — URL保存・タグ管理・既読管理・クロスデバイス同期
class BookmarkSyncPage extends StatefulWidget {
  const BookmarkSyncPage({super.key});

  @override
  State<BookmarkSyncPage> createState() => _BookmarkSyncPageState();
}

class _BookmarkSyncPageState extends State<BookmarkSyncPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _bookmarks = [];
  List<String> _allTags = [];
  Map<String, dynamic> _stats = {};
  String? _selectedTag;
  bool _unreadOnly = false;

  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final List<String> _newTags = [];

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBookmarks() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final params = <String, String>{'action': 'list'};
      if (_selectedTag != null) params['tag'] = _selectedTag!;
      if (_unreadOnly) params['unread'] = 'true';

      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'bookmark.list'},
      );
      final data = response.data;
      if (data is Map) {
        setState(() {
          _bookmarks = data['bookmarks'] is List
              ? (data['bookmarks'] as List).cast<Map<String, dynamic>>()
              : [];
          _allTags = [];
          _stats = {};
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'ブックマークの取得に失敗: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addBookmark() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'bookmark.add',
          'url': url,
          'title':
              _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : url,
          'description': _descCtrl.text.trim(),
          'tags': List<String>.from(_newTags),
        },
      );
      navigator.pop();
      _urlCtrl.clear();
      _titleCtrl.clear();
      _descCtrl.clear();
      _tagCtrl.clear();
      if (mounted) setState(() => _newTags.clear());
      await _fetchBookmarks();
      messenger.showSnackBar(const SnackBar(content: Text('ブックマークを追加しました')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('追加に失敗: $e')));
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'bookmark.mark_read', 'id': id},
      );
      await _fetchBookmarks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新に失敗: $e')));
      }
    }
  }

  Future<void> _deleteBookmark(String id) async {
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'bookmark.delete', 'id': id},
      );
      await _fetchBookmarks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('削除に失敗: $e')));
      }
    }
  }

  void _showAddDialog() {
    _urlCtrl.clear();
    _titleCtrl.clear();
    _descCtrl.clear();
    _tagCtrl.clear();
    setState(() => _newTags.clear());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('ブックマークを追加'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'URL *',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'タイトル (任意)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'メモ・説明 (任意)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagCtrl,
                          decoration: const InputDecoration(
                            hintText: 'タグを追加...',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag, size: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: '追加',
                        onPressed: () {
                          final tag = _tagCtrl.text.trim();
                          if (tag.isNotEmpty && !_newTags.contains(tag)) {
                            setDialogState(() {
                              _newTags.add(tag);
                              _tagCtrl.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (_newTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: _newTags
                          .map(
                            (t) => Chip(
                              label: Text(
                                t,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              onDeleted: () =>
                                  setDialogState(() => _newTags.remove(t)),
                              deleteIconColor: const Color(0xFF9CA3AF),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: _addBookmark,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final total = (_stats['total'] as num?)?.toInt() ?? 0;
    final unread = (_stats['unread'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _buildStatChip(Icons.bookmarks, '$total件', const Color(0xFF3D5AFE)),
          const SizedBox(width: 8),
          _buildStatChip(
            Icons.mark_email_unread,
            '$unread 未読',
            const Color(0xFFFF6B35),
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            Icons.local_offer,
            '${_allTags.length} タグ',
            const Color(0xFF009688),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('全て'),
                    selected: _selectedTag == null && !_unreadOnly,
                    onSelected: (_) {
                      setState(() {
                        _selectedTag = null;
                        _unreadOnly = false;
                      });
                      _fetchBookmarks();
                    },
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('未読'),
                    selected: _unreadOnly,
                    onSelected: (v) {
                      setState(() {
                        _unreadOnly = v;
                        if (v) _selectedTag = null;
                      });
                      _fetchBookmarks();
                    },
                  ),
                  ..._allTags.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: FilterChip(
                        label: Text(t),
                        selected: _selectedTag == t,
                        onSelected: (_) {
                          setState(() {
                            _selectedTag = _selectedTag == t ? null : t;
                            _unreadOnly = false;
                          });
                          _fetchBookmarks();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkCard(Map<String, dynamic> bm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final id = bm['id']?.toString() ?? '';
    final url = bm['url'] as String? ?? '';
    final title = bm['title'] as String? ?? url;
    final description = bm['description'] as String? ?? '';
    final tags = (bm['tags'] as List?)?.cast<String>() ?? [];
    final isRead = bm['is_read'] as bool? ?? false;
    final createdAt = bm['created_at'] as String? ?? '';

    String displayDate = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        displayDate = '${dt.year}/${dt.month}/${dt.day}';
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isRead
          ? null
          : (isDark ? const Color(0xFF0C1A2A) : const Color(0xFFE3F2FD)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isRead
              ? const Color(0xFF9CA3AF).withValues(alpha: 0.15)
              : const Color(0xFF3D5AFE).withValues(alpha: 0.15),
          child: Icon(
            isRead ? Icons.bookmark : Icons.bookmark_add,
            color: isRead ? const Color(0xFF9CA3AF) : const Color(0xFF3D5AFE),
            size: 20,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            height: 1.5,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF3D5AFE),
                height: 1.5,
              ),
            ),
            if (description.isNotEmpty)
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: tags
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF009688).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$t',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF009688),
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (displayDate.isNotEmpty)
              Text(
                displayDate,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          tooltip: 'メニュー',
          itemBuilder: (_) => [
            if (!isRead)
              const PopupMenuItem(
                value: 'read',
                child: Row(
                  children: [
                    Icon(Icons.check, size: 16),
                    SizedBox(width: 8),
                    Text('既読にする'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    '削除',
                    style: TextStyle(
                      color: Colors.red,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (v) {
            if (v == 'read') _markRead(id);
            if (v == 'delete') _deleteBookmark(id);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ブックマーク同期'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _fetchBookmarks,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('URL を保存'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchBookmarks,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(),
                    _buildFilterRow(),
                    const Divider(height: 1),
                    Expanded(
                      child: _bookmarks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bookmarks_outlined,
                                    size: 64,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'ブックマークがありません',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('最初のURLを保存'),
                                    onPressed: _showAddDialog,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchBookmarks,
                              child: ListView(
                                padding: const EdgeInsets.all(12),
                                children:
                                    _bookmarks.map(_buildBookmarkCard).toList(),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
