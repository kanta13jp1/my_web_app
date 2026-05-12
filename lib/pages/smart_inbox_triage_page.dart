import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// スマート受信トレイ トリアージページ
/// smart-inbox-triage Edge Function と連携して受信メッセージのAI仕分けを提供
class SmartInboxTriagePage extends StatefulWidget {
  const SmartInboxTriagePage({super.key});

  @override
  State<SmartInboxTriagePage> createState() => _SmartInboxTriagePageState();
}

class _SmartInboxTriagePageState extends State<SmartInboxTriagePage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchInbox();
  }

  Future<void> _fetchInbox() async {
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
        'lifestyle-hub',
        body: {'action': 'inbox.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['items'] is List) {
        setState(() => _items = data['items'] as List);
      } else if (data is Map<String, dynamic> && data['messages'] is List) {
        setState(() => _items = data['messages'] as List);
      } else if (data is List) {
        setState(() => _items = data);
      } else {
        setState(() => _items = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'データ取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _priorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
      case '高':
        return const Color(0xFFE53935);
      case 'medium':
      case '中':
        return const Color(0xFFFF6B35);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('スマート受信トレイ'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchInbox,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchInbox,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox, size: 48, color: Color(0xFFB0B0B0)),
                          SizedBox(height: 8),
                          Text(
                            '受信メッセージはありません',
                            style: TextStyle(
                              color: Color(0xFFB0B0B0),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = _items[i] as Map<String, dynamic>;
                        final priority = item['priority']?.toString();
                        return Card(
                          color: const Color(0xFF1E1E1E),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  _priorityColor(priority).withAlpha(30),
                              child: Icon(
                                Icons.mail_outline,
                                color: _priorityColor(priority),
                              ),
                            ),
                            title: Text(
                              item['subject']?.toString() ??
                                  item['title']?.toString() ??
                                  '(件名なし)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                            subtitle: Text(
                              item['summary']?.toString() ??
                                  item['body']?.toString() ??
                                  '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: priority != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _priorityColor(priority)
                                          .withAlpha(30),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      priority,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _priorityColor(priority),
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
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
