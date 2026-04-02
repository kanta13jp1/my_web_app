import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// カレンダーイベントページ
/// calendar-events Edge Function と連携してイベントを管理
class CalendarEventsPage extends StatefulWidget {
  const CalendarEventsPage({super.key});

  @override
  State<CalendarEventsPage> createState() => _CalendarEventsPageState();
}

class _CalendarEventsPageState extends State<CalendarEventsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'calendar-events',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['events'] is List) {
        setState(() => _events = data['events'] as List);
      } else if (data is List) {
        setState(() => _events = data);
      } else {
        setState(() => _events = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'イベントの取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダーイベント'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEvents,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _events.isEmpty
                      ? const Center(child: Text('イベントはありません'))
                      : ListView.builder(
                          itemCount: _events.length,
                          itemBuilder: (context, index) {
                            final item = _events[index];
                            final title = item is Map
                                ? (item['title'] ?? item['name'] ?? 'タイトルなし')
                                : item.toString();
                            final start = item is Map
                                ? (item['start_at'] ?? item['start'] ?? '')
                                : '';
                            final description = item is Map
                                ? (item['description'] ?? '')
                                : '';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.event),
                                title: Text(title.toString()),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (start.toString().isNotEmpty)
                                      Text(start.toString()),
                                    if (description.toString().isNotEmpty)
                                      Text(description.toString()),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEventDialog(BuildContext context) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('イベントを追加'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'タイトル'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabase.functions.invoke(
                  'calendar-events',
                  body: {
                    'action': 'add',
                    'title': titleController.text.trim(),
                  },
                );
                await _fetchEvents();
              } catch (e) {
                if (mounted) {
                  setState(() => _errorMessage = 'イベントの追加に失敗しました: $e');
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
