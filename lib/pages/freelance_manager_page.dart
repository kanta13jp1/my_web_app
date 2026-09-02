import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// フリーランス管理ページ
/// 案件・請求書・契約・稼働時間・確定申告を一元管理。freee 対抗。
class FreelanceManagerPage extends StatefulWidget {
  const FreelanceManagerPage({super.key});

  @override
  State<FreelanceManagerPage> createState() => _FreelanceManagerPageState();
}

class _FreelanceManagerPageState extends State<FreelanceManagerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['projects', 'invoices'];

  @override
  TabController get tabUrlController => _tabCtrl;

  final _supabase = Supabase.instance.client;
  late final TabController _tabCtrl;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _invoices = [];

  final _titleCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _saving = false;

  static const _statusColors = {
    'active': Color(0xFF4CAF50),
    'completed': Color(0xFF3D5AFE),
    'pending': Color(0xFFFF6B35),
    'cancelled': Color(0xFFE53935),
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _titleCtrl.dispose();
    _clientCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final results = await Future.wait([
        _supabase
            .from('freelance_projects')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(20),
        _supabase
            .from('freelance_invoices')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(20),
      ]);
      setState(() {
        _projects = (results[0] as List).cast<Map<String, dynamic>>();
        _invoices = (results[1] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addProject() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('freelance_projects').insert({
        'user_id': userId,
        'title': _titleCtrl.text.trim(),
        'client_name':
            _clientCtrl.text.trim().isEmpty ? null : _clientCtrl.text.trim(),
        'amount': int.tryParse(_amountCtrl.text.trim()),
        'status': 'active',
      });
      _titleCtrl.clear();
      _clientCtrl.clear();
      _amountCtrl.clear();
      if (mounted) Navigator.pop(context);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('フリーランス管理'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.work), text: '案件'),
            Tab(icon: Icon(Icons.receipt), text: '請求書'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '更新',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildProjectsTab(),
                _buildInvoicesTab(),
              ],
            ),
    );
  }

  void _showAddDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規案件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: '案件名 *'),
            ),
            TextField(
              controller: _clientCtrl,
              decoration: const InputDecoration(labelText: 'クライアント名'),
            ),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: '金額 (円)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: _saving ? null : _addProject,
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsTab() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline,
              color: Color(0xFF3D5AFE),
              size: 48,
            ),
            const SizedBox(height: 8),
            const Text('freelance_projects テーブルを作成すると案件管理が使えます'),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_projects.isEmpty) {
      return const Center(child: Text('案件がありません。+ ボタンから追加してください。'));
    }
    final totalAmount = _projects.fold<int>(
      0,
      (sum, p) => sum + (p['amount'] as int? ?? 0),
    );
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 18),
              const SizedBox(width: 8),
              Text(
                '合計: ¥${totalAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Text('${_projects.length}件'),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _projects.length,
            itemBuilder: (_, i) {
              final p = _projects[i];
              final status = p['status'] as String? ?? 'active';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        (_statusColors[status] ?? const Color(0xFF9CA3AF))
                            .withAlpha(40),
                    child: Icon(
                      Icons.work,
                      color: _statusColors[status] ?? const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                  ),
                  title: Text(p['title'] as String? ?? ''),
                  subtitle: Text(p['client_name'] as String? ?? ''),
                  trailing: p['amount'] != null
                      ? Text(
                          '¥${p['amount']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicesTab() {
    if (_invoices.isEmpty) {
      return const Center(child: Text('請求書がありません。'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _invoices.length,
      itemBuilder: (_, i) {
        final inv = _invoices[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: Color(0xFF3D5AFE)),
            title: Text(inv['title'] as String? ?? '請求書'),
            subtitle: Text(inv['client_name'] as String? ?? ''),
            trailing: Text(
              '¥${inv['amount'] ?? 0}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
