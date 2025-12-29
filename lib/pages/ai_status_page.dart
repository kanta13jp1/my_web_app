import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AiStatusPage extends StatefulWidget {
  const AiStatusPage({super.key});

  @override
  State<AiStatusPage> createState() => _AiStatusPageState();
}

class _AiStatusPageState extends State<AiStatusPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    try {
      final response = await supabase
          .from('ai_request_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(int? status) {
    if (status == 200) return Colors.green.shade100;
    if (status == 429) return Colors.orange.shade100;
    if (status == 402) return Colors.red.shade100; // Payment Required
    return Colors.grey.shade100;
  }

  String _getStatusText(int? status) {
    if (status == 200) return 'OK';
    if (status == 429) return 'Limit (429)';
    if (status == 402) return 'No Credit (402)';
    return 'Err ($status)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI稼働状況モニター'),
        actions: [
          IconButton(onPressed: _fetchLogs, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Cards
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      _buildSummaryCard(
                        '総リクエスト',
                        '${_logs.length}',
                        Icons.analytics,
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        'エラー率',
                        '${(_logs.where((l) => l['status_code'] != 200).length / (_logs.isEmpty ? 1 : _logs.length) * 100).toStringAsFixed(1)}%',
                        Icons.warning_amber,
                        Colors.redAccent,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final date = DateTime.parse(log['created_at']).toLocal();
                      final dateStr = DateFormat('MM/dd HH:mm:ss').format(date);
                      final status = log['status_code'] as int;
                      final provider = log['provider'] ?? 'unknown';
                      final model = log['model'] ?? '';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        color: _getStatusColor(status),
                        child: ListTile(
                          leading: Icon(
                            status == 200 ? Icons.check_circle : Icons.error,
                            color: status == 200 ? Colors.green : Colors.red,
                          ),
                          title: Text('$provider ($model)',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Action: ${log['action']}'),
                              Text(
                                  'Time: $dateStr | Duration: ${log['duration_ms']}ms'),
                              if (status != 200)
                                Text('Error: ${log['error_message']}',
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 12)),
                            ],
                          ),
                          trailing: Text(
                            _getStatusText(status),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: status == 200
                                    ? Colors.green[800]
                                    : Colors.red[800]),
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

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
