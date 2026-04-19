import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// アプリハブページ
/// app-hub Edge Function と連携してサブスクリプション・カレンダー・タスク等を統合管理
class AppHubPage extends StatefulWidget {
  const AppHubPage({super.key});

  @override
  State<AppHubPage> createState() => _AppHubPageState();
}

class _AppHubPageState extends State<AppHubPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _billingStatus;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final billingRes = await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'billing.status'},
      );
      final eventsRes = await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'calendar.list'},
      );
      final tasksRes = await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'task.list'},
      );

      final billing = billingRes.data;
      final eventsData = eventsRes.data;
      final tasksData = tasksRes.data;

      setState(() {
        if (billing is Map<String, dynamic>) _billingStatus = billing;
        if (eventsData is Map<String, dynamic> &&
            eventsData['events'] is List) {
          _events = (eventsData['events'] as List).cast<Map<String, dynamic>>();
        }
        if (tasksData is Map<String, dynamic> && tasksData['tasks'] is List) {
          _tasks = (tasksData['tasks'] as List).cast<Map<String, dynamic>>();
        }
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'データの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _billingStatus?['plan'] as String? ?? 'free';
    return Scaffold(
      appBar: AppBar(
        title: const Text('アプリハブ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: '再読み込み',
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
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchData,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // サブスクリプション状態
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.star_outline),
                        title: const Text('プラン'),
                        subtitle: Text(plan == 'free' ? '無料プラン' : '$plan プラン'),
                        trailing: TextButton(
                          onPressed: () {},
                          child: const Text('アップグレード'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // カレンダーイベント
                    Text(
                      '直近のイベント',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_events.isEmpty)
                      const Card(child: ListTile(title: Text('イベントなし')))
                    else
                      ..._events.take(5).map(
                            (e) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.event),
                                title: Text(
                                  (e['metadata'] as Map<String, dynamic>?)?[
                                          'title'] as String? ??
                                      'イベント',
                                ),
                                subtitle:
                                    Text(e['created_at']?.toString() ?? ''),
                              ),
                            ),
                          ),
                    const SizedBox(height: 16),
                    // タスク
                    Text('タスク', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_tasks.isEmpty)
                      const Card(child: ListTile(title: Text('タスクなし')))
                    else
                      ..._tasks.take(5).map(
                            (t) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.task_alt),
                                title: Text(
                                  (t['metadata'] as Map<String, dynamic>?)?[
                                          'title'] as String? ??
                                      'タスク',
                                ),
                                subtitle:
                                    Text(t['created_at']?.toString() ?? ''),
                              ),
                            ),
                          ),
                  ],
                ),
    );
  }
}
