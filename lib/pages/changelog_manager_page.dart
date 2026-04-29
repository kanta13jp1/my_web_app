import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 変更履歴管理ページ
/// changelog-manager Edge Function と連携して変更履歴を管理
class ChangelogManagerPage extends StatefulWidget {
  const ChangelogManagerPage({super.key});

  @override
  State<ChangelogManagerPage> createState() => _ChangelogManagerPageState();
}

class _ChangelogManagerPageState extends State<ChangelogManagerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _fetchChangelog();
  }

  Future<void> _fetchChangelog() async {
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
          .invoke('app-hub', body: {'action': 'changelog.list'});
      if (res.data != null) {
        final data = res.data as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _entries = List<Map<String, dynamic>>.from(
            data['entries'] as List? ?? [],
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'feature':
        return Colors.green;
      case 'fix':
        return Colors.red;
      case 'improvement':
        return const Color(0xFF3D5AFE);
      default:
        return const Color(0xFFB0B0B0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('変更履歴 (Changelog)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchChangelog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchChangelog,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _entries.isEmpty
                  ? const Center(child: Text('変更履歴がありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        final type = entry['type']?.toString();
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _typeColor(type),
                              child: Text(
                                (entry['version']?.toString() ?? 'v?')
                                    .replaceAll('v', ''),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            title: Text(
                              entry['title']?.toString() ?? '変更 ${index + 1}',
                            ),
                            subtitle: Text(
                              [
                                if (type != null) type,
                                if (entry['date'] != null)
                                  entry['date'].toString(),
                              ].join(' · '),
                            ),
                            isThreeLine: entry['description'] != null,
                            trailing: entry['description'] != null
                                ? const Icon(Icons.chevron_right)
                                : null,
                          ),
                        );
                      },
                    ),
    );
  }
}
