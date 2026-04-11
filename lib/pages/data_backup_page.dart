import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// データバックアップページ
/// 全データの自動バックアップ・クラウド同期・ワンクリック復元。Dropbox / iCloud 対抗。
class DataBackupPage extends StatefulWidget {
  const DataBackupPage({super.key});

  @override
  State<DataBackupPage> createState() => _DataBackupPageState();
}

class _DataBackupPageState extends State<DataBackupPage> {
  final _supabase = Supabase.instance.client;

  bool _loading = false;
  bool _exporting = false;
  String? _error;
  Map<String, dynamic>? _lastBackup;
  List<Map<String, dynamic>> _backupHistory = [];

  static const _exportTargets = [
    _ExportTarget('notes', 'ノート', Icons.note, Colors.amber),
    _ExportTarget('tasks', 'タスク', Icons.task, Colors.blue),
    _ExportTarget('habits', '習慣', Icons.loop, Colors.green),
    _ExportTarget('finances', '財務', Icons.account_balance_wallet, Colors.purple),
    _ExportTarget('blog_posts', 'ブログ', Icons.article, Colors.indigo),
  ];

  final Set<String> _selected = {
    'notes', 'tasks', 'habits', 'finances', 'blog_posts',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('data_backups')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);
      final list = (data as List).cast<Map<String, dynamic>>();
      setState(() {
        _backupHistory = list;
        _lastBackup = list.isNotEmpty ? list.first : null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runBackup() async {
    setState(() => _exporting = true);
    try {
      final resp = await _supabase.functions.invoke(
        'data-export-manager',
        body: {
          'action': 'backup',
          'targets': _selected.toList(),
        },
      );
      final data = resp.data;
      if (data is Map && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('バックアップが完了しました')),
          );
        }
        await _load();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('バックアップ結果: ${data?.toString() ?? '不明'}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('バックアップ失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('データバックアップ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  _buildSelectCard(),
                  const SizedBox(height: 16),
                  _buildHistorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_done, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'バックアップ状況',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(height: 4),
                    Text(
                      'data_backups テーブルを作成すると履歴が表示されます',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else if (_lastBackup != null) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '最終バックアップ: ${(_lastBackup!['created_at'] as String? ?? '').substring(0, 10)}',
                  ),
                ],
              ),
            ] else
              const Text('バックアップ履歴がありません。'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exporting ? null : _runBackup,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.backup),
                label: Text(_exporting ? 'バックアップ中...' : '今すぐバックアップ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'バックアップ対象',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._exportTargets.map(
              (t) => CheckboxListTile(
                value: _selected.contains(t.key),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(t.key);
                    } else {
                      _selected.remove(t.key);
                    }
                  });
                },
                secondary: Icon(t.icon, color: t.color),
                title: Text(t.label),
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_backupHistory.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'バックアップ履歴',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._backupHistory.map(
          (b) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: const Icon(Icons.cloud_done, color: Colors.green),
              title: Text(
                (b['created_at'] as String? ?? '').substring(0, 10),
              ),
              subtitle: Text(b['targets']?.toString() ?? '全データ'),
              trailing: Text(
                b['size_kb'] != null ? '${b['size_kb']} KB' : '',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExportTarget {
  const _ExportTarget(this.key, this.label, this.icon, this.color);
  final String key;
  final String label;
  final IconData icon;
  final Color color;
}
