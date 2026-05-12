import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// インフラ健全性チェックページ
/// health-check Edge Function と連携。DB接続・テーブルアクセス・EFランタイム状態を表示。
class HealthCheckPage extends StatefulWidget {
  const HealthCheckPage({super.key});

  @override
  State<HealthCheckPage> createState() => _HealthCheckPageState();
}

class _HealthCheckPageState extends State<HealthCheckPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _fetchHealth();
  }

  Future<void> _fetchHealth() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'admin-hub',
        body: {'action': 'health.check'},
      );
      setState(() => _result = res.data as Map<String, dynamic>?);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'healthy':
        return Colors.green;
      case 'degraded':
        return Colors.orange;
      case 'unhealthy':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'healthy':
        return Icons.check_circle;
      case 'degraded':
        return Icons.warning_amber_rounded;
      case 'unhealthy':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _result?['status'] as String?;
    final checks = _result?['checks'] as Map<String, dynamic>?;
    final timestamp = _result?['timestamp'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('インフラ健全性チェック'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchHealth,
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
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('再試行'),
                        onPressed: _fetchHealth,
                      ),
                    ],
                  ),
                )
              : _result == null
                  ? const Center(child: Text('データなし'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ステータスサマリーカード
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Icon(
                                  _statusIcon(status),
                                  color: _statusColor(status),
                                  size: 40,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        status?.toUpperCase() ?? 'UNKNOWN',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: _statusColor(status),
                                          height: 1.5,
                                        ),
                                      ),
                                      if (timestamp != null)
                                        Text(
                                          timestamp,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                            height: 1.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // チェック詳細
                        if (checks != null && checks.isNotEmpty) ...[
                          const Text(
                            'チェック詳細',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...checks.entries.map((entry) {
                            final check = entry.value as Map<String, dynamic>?;
                            final ok = check?['ok'] as bool? ?? false;
                            final latency = check?['latencyMs'];
                            final detail = check?['detail'] as String?;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  ok ? Icons.check_circle : Icons.cancel,
                                  color: ok ? Colors.green : Colors.red,
                                ),
                                title: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (latency != null)
                                      Text(
                                        'レイテンシ: ${latency}ms',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                    if (detail != null)
                                      Text(
                                        detail,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: ok
                                    ? const Chip(
                                        label: Text(
                                          'OK',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            height: 1.5,
                                          ),
                                        ),
                                        backgroundColor: Colors.green,
                                        padding: EdgeInsets.zero,
                                      )
                                    : const Chip(
                                        label: Text(
                                          'NG',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            height: 1.5,
                                          ),
                                        ),
                                        backgroundColor: Colors.red,
                                        padding: EdgeInsets.zero,
                                      ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
    );
  }
}
