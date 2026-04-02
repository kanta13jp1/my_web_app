import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// イベントチケット管理ページ
/// event-ticketing Edge Function と連携してイベントとチケットを管理する
class EventTicketingPage extends StatefulWidget {
  const EventTicketingPage({super.key});

  @override
  State<EventTicketingPage> createState() => _EventTicketingPageState();
}

class _EventTicketingPageState extends State<EventTicketingPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _events = [];

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
        'event-ticketing',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['events'] is List) {
        setState(() => _events = (data['events'] as List).cast<Map<String, dynamic>>());
      } else if (data is List) {
        setState(() => _events = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _events = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'イベント一覧の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('イベントチケット管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEvents,
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
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchEvents, child: const Text('再試行')),
                    ],
                  ),
                )
              : _events.isEmpty
                  ? const Center(child: Text('イベントがありません'))
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(event['title']?.toString() ?? 'イベント ${index + 1}'),
                          subtitle: Text(event['date']?.toString() ?? ''),
                          trailing: Text('残 ${event['tickets_remaining'] ?? 0}枚'),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'イベントを作成',
        child: const Icon(Icons.add),
      ),
    );
  }
}
