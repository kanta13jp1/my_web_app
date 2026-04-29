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
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _showCreateEventDialog() async {
    _titleController.clear();
    _dateController.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('イベントを作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'イベント名'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dateController,
              decoration:
                  const InputDecoration(labelText: '開催日 (例: 2026-05-01)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {
          'action': 'event.create',
          'title': title,
          if (_dateController.text.trim().isNotEmpty)
            'date': _dateController.text.trim(),
        },
      );
      await _fetchEvents();
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = 'イベントの作成に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEvents() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'event.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['events'] is List) {
        setState(
          () => _events = (data['events'] as List).cast<Map<String, dynamic>>(),
        );
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
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchEvents,
                        child: const Text('再試行'),
                      ),
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
                          title: Text(
                            event['title']?.toString() ?? 'イベント ${index + 1}',
                          ),
                          subtitle: Text(event['date']?.toString() ?? ''),
                          trailing:
                              Text('残 ${event['tickets_remaining'] ?? 0}枚'),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _showCreateEventDialog,
        tooltip: 'イベントを作成',
        child: const Icon(Icons.add),
      ),
    );
  }
}
