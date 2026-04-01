import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 集中タイマーページ
/// focus-timer Edge Function と連携して集中セッションを管理
class FocusTimerPage extends StatefulWidget {
  const FocusTimerPage({super.key});

  @override
  State<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<FocusTimerPage> {
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
        'focus-timer',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['sessions'] is List) {
        setState(() => _sessions = (data['sessions'] as List).cast<Map<String, dynamic>>());
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
        title: const Text('集中タイマー'),
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
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchSessions,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _sessions.isEmpty
                  ? const Center(child: Text('集中セッションはありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final title = session['title']?.toString() ?? 'セッション ${index + 1}';
                        final duration = session['duration_minutes']?.toString() ?? '25';
                        final status = session['status']?.toString() ?? '完了';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.timer, color: Colors.orange),
                            title: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('$duration 分'),
                            trailing: Chip(
                              label: Text(status, style: const TextStyle(fontSize: 12)),
                              backgroundColor: status == 'active'
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('新しい集中セッションを開始します')),
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('開始'),
      ),
    );
  }
}
