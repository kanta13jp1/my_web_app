import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final _supabase = Supabase.instance.client;
  final _textController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchHealthLogs();
  }

  Future<void> _fetchHealthLogs() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Noteテーブルを使用し、タイトルが '[Health]' で始まるものを健康ログとして扱う
      final data = await _supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .ilike('title', '[Health]%') // 簡易的なフィルタリング
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }

  Future<void> _addHealthLog() async {
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('notes').insert({
        'user_id': userId,
        'title': '[Health] 健康記録', // 固定タイトル識別子
        'content': content,
        'is_archived': false,
        'is_pinned': false,
      });
      _textController.clear();
      _fetchHealthLogs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存エラー: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康管理室'),
        backgroundColor: const Color(0xFF009688),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '例: ランニング 3km, 昼食はサラダチキン',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _addHealthLog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(
                        child: Text(
                          '健康ログはまだありません',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            height: 1.5,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final item = _logs[index];
                          final created = DateTime.parse(item['created_at']);
                          final dateStr =
                              DateFormat('MM/dd HH:mm').format(created);

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(
                                Icons.directions_run,
                                color: Color(0xFF009688),
                              ),
                              title: Text(item['content'] ?? ''),
                              trailing: Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
