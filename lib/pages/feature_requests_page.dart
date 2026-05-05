import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeatureRequestsPage extends StatefulWidget {
  const FeatureRequestsPage({super.key});

  @override
  State<FeatureRequestsPage> createState() => _FeatureRequestsPageState();
}

class _FeatureRequestsPageState extends State<FeatureRequestsPage> {
  final _supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _requests = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  final Set<String> _votedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _supabase
          .from('feature_requests')
          .select('id, title, description, votes, status, created_at, user_id')
          .eq('status', 'open')
          .order('votes', ascending: false)
          .order('created_at', ascending: false)
          .limit(30);
      if (!mounted) return;
      setState(() {
        _requests = List<Map<String, dynamic>>.from(data as List);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '機能要望を読み込めませんでした: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRequestDialog() async {
    _titleController.clear();
    _descriptionController.clear();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('機能要望を送る'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleController,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: '要望タイトル',
                    hintText: '例: ブログ投稿前に自動チェックしてほしい',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: '詳細',
                    hintText: '困っていること、ほしい動作、成功条件を短く書いてください。',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton.icon(
              onPressed: _submitting ? null : _submitRequest,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_submitting ? '送信中' : '送信'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitRequest() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.length < 3 || description.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトル3文字以上、詳細10文字以上で入力してください。')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = _supabase.auth.currentUser;
      await _supabase.from('feature_requests').insert({
        'user_id': user?.id,
        'email': user?.email,
        'title': title,
        'description': description,
        'votes': 1,
        'status': 'open',
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('機能要望を保存しました。')),
      );
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送信に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _upvote(String id, int currentVotes) async {
    if (_votedIds.contains(id)) return;
    setState(() => _votedIds.add(id));
    try {
      await _supabase
          .from('feature_requests')
          .update({'votes': currentVotes + 1}).eq('id', id);
      if (!mounted) return;
      setState(() {
        _requests = _requests.map((request) {
          if (request['id'] == id) {
            return <String, dynamic>{...request, 'votes': currentVotes + 1};
          }
          return request;
        }).toList(growable: false);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _votedIds.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投票に失敗しました: $e')),
        );
      }
    }
  }

  void _openRoute(String route) {
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('シングルページMVP'),
        actions: [
          IconButton(
            tooltip: '更新',
            onPressed: _loadRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '今日使うコア機能',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '複雑な画面遷移を避け、記録・検索・発信の入口を1画面に集約しています。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 720;
                      final actions = [
                        _CoreAction(
                          icon: Icons.note_add_outlined,
                          title: '記録する',
                          subtitle: 'メモや作業ログを残す',
                          onTap: () => _openRoute('/note-editor'),
                        ),
                        _CoreAction(
                          icon: Icons.search_outlined,
                          title: '探す',
                          subtitle: '外部脳と既存メモを検索',
                          onTap: () => _openRoute('/memory-search'),
                        ),
                        _CoreAction(
                          icon: Icons.article_outlined,
                          title: '発信する',
                          subtitle: 'ブログとニュース投稿へ進む',
                          onTap: () => _openRoute('/blog'),
                        ),
                      ];
                      if (compact) {
                        return Column(
                          children: actions
                              .map(
                                (action) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: action,
                                ),
                              )
                              .toList(growable: false),
                        );
                      }
                      return Row(
                        children: actions
                            .map(
                              (action) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: action,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _openRequestDialog,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('機能要望を送る'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '届いている要望',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_error != null)
                    _StatusMessage(
                      icon: Icons.error_outline,
                      color: colorScheme.error,
                      text: _error!,
                    )
                  else if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_requests.isEmpty)
                    _StatusMessage(
                      icon: Icons.inbox_outlined,
                      color: colorScheme.primary,
                      text: 'まだ要望はありません。最初の1件を送ってください。',
                    )
                  else
                    ..._requests.map(_buildRequestTile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestTile(Map<String, dynamic> request) {
    final id = '${request['id'] ?? ''}';
    final votes = (request['votes'] as num?)?.round() ?? 0;
    final title = '${request['title'] ?? ''}';
    final description = '${request['description'] ?? ''}'.trim();
    final createdAt = '${request['created_at'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('受付日時: $createdAt'),
            ],
          ],
        ),
        trailing: SizedBox(
          width: 84,
          child: OutlinedButton.icon(
            onPressed: id.isEmpty ? null : () => _upvote(id, votes),
            icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
            label: Text('$votes'),
          ),
        ),
      ),
    );
  }
}

class _CoreAction extends StatelessWidget {
  const _CoreAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
