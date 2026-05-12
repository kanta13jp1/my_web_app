import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// パスワード管理ページ
/// 保存されたパスワード一覧・強度表示・クリップボードコピー。
/// password-vault Edge Function と連携。
class PasswordVaultPage extends StatefulWidget {
  const PasswordVaultPage({super.key});

  @override
  State<PasswordVaultPage> createState() => _PasswordVaultPageState();
}

class _PasswordVaultPageState extends State<PasswordVaultPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _entries = [];
  final Set<String> _revealed = {};

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  Future<void> _fetchEntries() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'vault.list'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final list = data['entries'];
        if (list is List) {
          setState(() {
            _entries = list.map((e) => e as Map<String, dynamic>).toList();
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

  Color _strengthColor(String? strength) {
    switch (strength) {
      case 'strong':
        return const Color(0xFF4CAF50);
      case 'medium':
        return const Color(0xFFFF6B35);
      default:
        return const Color(0xFFE53935);
    }
  }

  IconData _strengthIcon(String? strength) {
    switch (strength) {
      case 'strong':
        return Icons.shield;
      case 'medium':
        return Icons.shield_outlined;
      default:
        return Icons.warning_amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('パスワード管理'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchEntries),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _buildList(),
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
          ElevatedButton(onPressed: _fetchEntries, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Color(0xFFB0B0B0)),
            SizedBox(height: 12),
            Text(
              '保存されたパスワードがありません',
              style: TextStyle(
                color: Color(0xFFB0B0B0),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _entries.length,
      itemBuilder: (ctx, i) {
        final e = _entries[i];
        final id = e['id'] as String? ?? '$i';
        final site = e['site'] as String? ?? 'サイト ${i + 1}';
        final username = e['username'] as String? ?? '';
        final password = e['password'] as String? ?? '••••••••';
        final strength = e['strength'] as String?;
        final isRevealed = _revealed.contains(id);
        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              _strengthIcon(strength),
              color: _strengthColor(strength),
            ),
            title: Text(
              site,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Text(username.isNotEmpty ? username : '—'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isRevealed ? password : '••••••••',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isRevealed ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () => setState(() {
                    if (isRevealed) {
                      _revealed.remove(id);
                    } else {
                      _revealed.add(id);
                    }
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: password));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('コピーしました')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddDialog() {
    final siteCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('パスワードを追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: siteCtrl,
              decoration: const InputDecoration(
                labelText: 'サイト名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(
                labelText: 'ユーザー名',
                border: OutlineInputBorder(),
              ),
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
              final site = siteCtrl.text.trim();
              Navigator.pop(ctx);
              if (site.isEmpty) return;
              try {
                await _supabase.functions.invoke(
                  'tools-hub',
                  body: {
                    'action': 'vault.add',
                    'site': site,
                    'username': userCtrl.text.trim(),
                  },
                );
                await _fetchEntries();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: $e')),
                  );
                }
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }
}
