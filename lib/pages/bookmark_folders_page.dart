import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Xブックマーク・ブラウザブックマークのフォルダ管理ページ。
/// 整理対象フォルダを登録し、整理の進捗を管理する。
class BookmarkFoldersPage extends StatefulWidget {
  const BookmarkFoldersPage({super.key});

  @override
  State<BookmarkFoldersPage> createState() => _BookmarkFoldersPageState();
}

class _BookmarkFoldersPageState extends State<BookmarkFoldersPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _folders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await _supabase
          .from('bookmark_folders')
          .select()
          .eq('user_id', userId)
          .order('created_at');
      if (mounted) {
        setState(() {
          _folders = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('BookmarkFolders load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addFolder() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String platform = 'x';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('ブックマークフォルダを登録'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'x', label: Text('X')),
                    ButtonSegment(value: 'chrome', label: Text('Chrome')),
                    ButtonSegment(value: 'other', label: Text('その他')),
                  ],
                  selected: {platform},
                  onSelectionChanged: (v) => setD(() => platform = v.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'フォルダ名 *',
                    hintText: '例: 技術記事、あとで読む',
                    prefixIcon: Icon(Icons.folder),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL (任意)',
                    hintText: 'https://x.com/i/bookmarks/...',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('登録'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('bookmark_folders').insert({
        'user_id': userId,
        'folder_name': name,
        'platform': platform,
        'url': urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
      });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleOrganized(Map<String, dynamic> folder) async {
    final current = folder['is_organized'] == true;
    try {
      await _supabase.from('bookmark_folders').update({
        'is_organized': !current,
        'last_organized_at':
            current ? null : DateTime.now().toIso8601String(),
      }).eq('id', folder['id']);
      await _load();
    } catch (e) {
      debugPrint('Toggle error: $e');
    }
  }

  Future<void> _deleteFolder(Map<String, dynamic> folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('フォルダを削除'),
        content: Text('「${folder['folder_name']}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase.from('bookmark_folders').delete().eq(
            'id',
            folder['id'],
          );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  IconData _platformIcon(String? platform) {
    switch (platform) {
      case 'x':
        return Icons.bookmark;
      case 'chrome':
        return Icons.language;
      default:
        return Icons.folder;
    }
  }

  Color _platformColor(String? platform) {
    switch (platform) {
      case 'x':
        return const Color(0xFF1DA1F2);
      case 'chrome':
        return const Color(0xFF4285F4);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final organized =
        _folders.where((f) => f['is_organized'] == true).length;
    final total = _folders.length;
    final progress = total > 0 ? organized / total : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ブックマーク整理'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFolder,
        icon: const Icon(Icons.add),
        label: const Text('フォルダ追加'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 進捗カード
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: progress >= 1.0
                          ? [Colors.green.shade600, Colors.green.shade400]
                          : [
                              const Color(0xFF1DA1F2),
                              const Color(0xFF4285F4),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        progress >= 1.0 ? '🎉 全フォルダ整理完了！' : '🔖 ブックマーク整理',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$organized / $total フォルダ整理済み',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_folders.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 48,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '整理対象のブックマークフォルダを登録してください',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._folders.map((f) => _buildFolderCard(f)),
              ],
            ),
    );
  }

  Widget _buildFolderCard(Map<String, dynamic> folder) {
    final name = folder['folder_name']?.toString() ?? '';
    final platform = folder['platform']?.toString();
    final url = folder['url']?.toString();
    final isOrganized = folder['is_organized'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isOrganized ? Colors.green.shade200 : Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
      child: ListTile(
        leading: Icon(
          isOrganized ? Icons.check_circle : _platformIcon(platform),
          color: isOrganized ? Colors.green : _platformColor(platform),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: isOrganized ? TextDecoration.lineThrough : null,
            color: isOrganized ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          '${platform == 'x' ? 'X (Twitter)' : platform == 'chrome' ? 'Chrome' : 'その他'}${url != null && url.isNotEmpty ? ' • $url' : ''}',
          style: const TextStyle(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isOrganized ? Icons.undo : Icons.check,
                size: 20,
              ),
              onPressed: () => _toggleOrganized(folder),
              tooltip: isOrganized ? '未整理に戻す' : '整理済みにする',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _deleteFolder(folder),
              tooltip: '削除',
            ),
          ],
        ),
        onTap: () => _toggleOrganized(folder),
      ),
    );
  }
}
