import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// サポートチケット一覧ページ (管理者用)
/// 未返信のサポートチケットを確認する
class SupportTicketsPage extends StatefulWidget {
  const SupportTicketsPage({super.key});

  @override
  State<SupportTicketsPage> createState() => _SupportTicketsPageState();
}

class _SupportTicketsPageState extends State<SupportTicketsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _faq = [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase.functions.invoke('admin-hub', body: {'action': 'support.list'});

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final tickets = data['tickets'];
        final faq = data['faq'];
        setState(() {
          _tickets = tickets is List
              ? List<Map<String, dynamic>>.from(
                  tickets.map((e) => Map<String, dynamic>.from(e as Map)),
                )
              : [];
          _faq = faq is List
              ? List<Map<String, dynamic>>.from(
                  faq.map((e) => Map<String, dynamic>.from(e as Map)),
                )
              : [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'チケット取得に失敗しました: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('サポートチケット'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTickets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _tickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.teal.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '未返信チケットはありません',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '未返信チケット: ${_tickets.length}件 / FAQ: ${_faq.length}件',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _tickets.length,
                            itemBuilder: (context, index) {
                              final ticket = _tickets[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.support_agent,
                                    color: Colors.teal,
                                  ),
                                  title: Text(
                                    ticket['title']?.toString() ?? '無題',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    ticket['body']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Chip(
                                    label: Text(
                                      ticket['status']?.toString() ?? 'open',
                                    ),
                                    backgroundColor: Colors.teal.shade50,
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
