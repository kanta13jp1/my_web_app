import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SNS投稿スケジュール管理ページ
/// social-media-scheduler Edge Function と連携
class SocialMediaSchedulerPage extends StatefulWidget {
  const SocialMediaSchedulerPage({super.key});

  @override
  State<SocialMediaSchedulerPage> createState() =>
      _SocialMediaSchedulerPageState();
}

class _SocialMediaSchedulerPageState extends State<SocialMediaSchedulerPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _scheduled = [];
  List<dynamic> _published = [];
  List<dynamic> _drafts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'social-media-scheduler',
        body: {'action': 'list'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          _scheduled = (data['scheduled'] as List?) ?? [];
          _published = (data['published'] as List?) ?? [];
          _drafts = (data['drafts'] as List?) ?? [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final contentCtrl = TextEditingController();
    String selectedPlatform = 'x';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規投稿を作成'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedPlatform,
                  decoration: const InputDecoration(labelText: 'プラットフォーム'),
                  items: const [
                    DropdownMenuItem(value: 'x', child: Text('X (Twitter)')),
                    DropdownMenuItem(
                      value: 'linkedin',
                      child: Text('LinkedIn'),
                    ),
                    DropdownMenuItem(
                      value: 'instagram',
                      child: Text('Instagram'),
                    ),
                    DropdownMenuItem(
                      value: 'facebook',
                      child: Text('Facebook'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => selectedPlatform = v ?? 'x'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  decoration: const InputDecoration(
                    labelText: '投稿内容',
                    hintText: '140字以内',
                  ),
                  maxLines: 3,
                  maxLength: 280,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (contentCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _supabase.functions.invoke(
                  'social-media-scheduler',
                  body: {
                    'action': 'create',
                    'platform': selectedPlatform,
                    'content': contentCtrl.text.trim(),
                    'status': 'draft',
                  },
                );
                await _fetchPosts();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('下書きを保存しました')),
                  );
                  _tabController.animateTo(2);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('保存に失敗しました: $e')),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Color _platformColor(String? platform) {
    switch (platform) {
      case 'x':
        return Colors.black;
      case 'linkedin':
        return const Color(0xFF0077B5);
      case 'instagram':
        return const Color(0xFFE1306C);
      case 'facebook':
        return const Color(0xFF1877F2);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData _platformIcon(String? platform) {
    switch (platform) {
      case 'x':
        return Icons.close; // X logo approximation
      case 'linkedin':
        return Icons.business;
      case 'instagram':
        return Icons.camera_alt;
      case 'facebook':
        return Icons.facebook;
      default:
        return Icons.public;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('SNS投稿スケジューラー'),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _isLoading ? null : _fetchPosts,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: '予定 (${_scheduled.length})'),
            Tab(text: '投稿済 (${_published.length})'),
            Tab(text: '下書き (${_drafts.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFFFF6B35),
        tooltip: '新規投稿',
        child: const Icon(Icons.add),
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
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchPosts,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostList(_scheduled, '予定された投稿がありません'),
                    _buildPostList(_published, '投稿済みの投稿がありません'),
                    _buildPostList(_drafts, '下書きがありません'),
                  ],
                ),
    );
  }

  Widget _buildPostList(List<dynamic> posts, String emptyMessage) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_send, size: 48, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 8),
            Text(
              emptyMessage,
              style: const TextStyle(color: const Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final post = posts[i] as Map<String, dynamic>;
        final platform = post['platform']?.toString();
        return Card(
          color: const Color(0xFF1E1E1E),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _platformColor(platform).withAlpha(20),
              child: Icon(
                _platformIcon(platform),
                color: _platformColor(platform),
                size: 20,
              ),
            ),
            title: Text(
              post['content']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${platform?.toUpperCase() ?? '-'}  |  '
              '${post['scheduled_at'] ?? post['published_at'] ?? post['created_at'] ?? '-'}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        );
      },
    );
  }
}
