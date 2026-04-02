import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 音楽コラボレーションページ
/// music-collaboration Edge Function と連携してセッション一覧を取得
class MusicCollaborationPage extends StatefulWidget {
  const MusicCollaborationPage({super.key});

  @override
  State<MusicCollaborationPage> createState() => _MusicCollaborationPageState();
}

class _MusicCollaborationPageState extends State<MusicCollaborationPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'music-collaboration',
        body: {'action': 'feed'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['sessions'] is List) {
        setState(
          () => _sessions =
              (data['sessions'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _sessions = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _sessions = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'セッション一覧の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音楽コラボレーション'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSessions,
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
                      const SizedBox(height: 12),
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchSessions,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _sessions.isEmpty
                  ? const Center(child: Text('セッションがありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.people),
                            title: Text(
                              session['title']?.toString() ?? 'セッション',
                            ),
                            subtitle: Text(
                              session['type']?.toString() ?? '',
                            ),
                            trailing: session['collaborators'] != null
                                ? Chip(
                                    label: Text(
                                      '${session['collaborators']} 人',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
    );
  }
}
