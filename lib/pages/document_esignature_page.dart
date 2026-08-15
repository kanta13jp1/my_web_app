import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// ドキュメント電子署名ページ
/// 文書のアップロード・署名依頼・署名状況確認。
/// document-esignature Edge Function と連携。
class DocumentEsignaturePage extends StatefulWidget {
  const DocumentEsignaturePage({super.key});

  @override
  State<DocumentEsignaturePage> createState() => _DocumentEsignaturePageState();
}

class _DocumentEsignaturePageState extends State<DocumentEsignaturePage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['pending', 'completed'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _completed = [];

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
      final pendingRes = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'esign.list'},
      );
      final completedRes = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'esign.list'},
      );
      setState(() {
        _pending = _toList(pendingRes.data, 'requests');
        _completed = _toList(completedRes.data, 'requests');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _toList(dynamic data, String key) {
    if (data is Map<String, dynamic>) {
      final list = data[key];
      if (list is List) {
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('電子署名'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.pending_actions),
              text: '署名待ち (${_pending.length})',
            ),
            Tab(
              icon: const Icon(Icons.check_circle),
              text: '完了 (${_completed.length})',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRequestDialog,
        icon: const Icon(Icons.upload_file),
        label: const Text('署名依頼'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDocList(_pending, pending: true),
                    _buildDocList(_completed, pending: false),
                  ],
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

  Widget _buildDocList(
    List<Map<String, dynamic>> docs, {
    required bool pending,
  }) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              pending ? Icons.pending_actions : Icons.check_circle,
              size: 64,
              color: const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              pending ? '署名待ちの文書がありません' : '完了した文書がありません',
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final doc = docs[i];
        final title = doc['title'] as String? ?? '文書 ${i + 1}';
        final sender = doc['senderName'] as String? ?? '';
        final date = doc['createdAt'] as String? ?? '';
        final signers = doc['signers'] as List<dynamic>? ?? [];
        final signedCount =
            signers.where((s) => (s as Map)['signed'] == true).length;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              Icons.description,
              color:
                  pending ? const Color(0xFFFF6B35) : const Color(0xFF4CAF50),
              size: 32,
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sender.isNotEmpty) Text('依頼者: $sender'),
                if (signers.isNotEmpty)
                  Text('署名: $signedCount / ${signers.length} 人'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (date.length >= 10)
                  Text(
                    date.substring(0, 10),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                if (pending)
                  FilledButton.tonal(
                    onPressed: () async {
                      try {
                        await _supabase.functions.invoke(
                          'media-hub',
                          body: {
                            'action': 'esign.sign',
                            'documentId': doc['id'],
                          },
                        );
                        await _fetchData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('署名しました')),
                          );
                        }
                      } catch (_) {}
                    },
                    child: const Text(
                      '署名',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
            isThreeLine: signers.isNotEmpty,
          ),
        );
      },
    );
  }

  void _showRequestDialog() {
    final titleCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('署名依頼を作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: '文書タイトル',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: '署名者のメールアドレス',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final email = emailCtrl.text.trim();
              Navigator.pop(ctx);
              if (title.isEmpty || email.isEmpty) return;
              try {
                await _supabase.functions.invoke(
                  'media-hub',
                  body: {
                    'action': 'esign.create_request',
                    'title': title,
                    'signerEmail': email,
                  },
                );
                await _fetchData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('署名依頼を送信しました')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: $e')),
                  );
                }
              }
            },
            child: const Text('送信'),
          ),
        ],
      ),
    );
  }
}
