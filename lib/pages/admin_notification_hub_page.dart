import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminNotificationHubPage extends StatefulWidget {
  const AdminNotificationHubPage({super.key});

  @override
  State<AdminNotificationHubPage> createState() =>
      _AdminNotificationHubPageState();
}

class _AdminNotificationHubPageState extends State<AdminNotificationHubPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _notifications = [];
  String _filterSeverity = 'all';

  static const _severityColors = {
    'critical': Color(0xFFDC2626),
    'warning': Color(0xFFF59E0B),
    'info': Color(0xFF3B82F6),
    'success': Color(0xFF10B981),
  };

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'admin-notification-hub',
        queryParameters: {
          'action': 'list',
          if (_filterSeverity != 'all') 'severity': _filterSeverity,
        },
      );
      final data = res.data;
      if (data is Map && data['notifications'] is List) {
        setState(() {
          _notifications =
              (data['notifications'] as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '通知の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _supabase.functions.invoke(
        'admin-notification-hub',
        body: {'action': 'mark_read', 'id': notificationId},
      );
      setState(() {
        _notifications = _notifications.map((n) {
          if (n['id'] == notificationId) {
            return {...n, 'is_read': true};
          }
          return n;
        }).toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n['is_read'] != true).length;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('管理通知ハブ'),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text('$unread 未読'),
                backgroundColor: Colors.red.withAlpha(30),
                labelStyle: const TextStyle(color: Colors.red, fontSize: 11),
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: Column(
        children: [
          _SeverityFilter(
            selected: _filterSeverity,
            onChanged: (v) {
              setState(() => _filterSeverity = v);
              _fetchNotifications();
            },
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _notifications.isEmpty
                        ? const Center(child: Text('通知はありません'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _notifications.length,
                            itemBuilder: (context, i) {
                              final n = _notifications[i];
                              final severity =
                                  n['severity'] as String? ?? 'info';
                              final color =
                                  _severityColors[severity] ?? Colors.blue;
                              final isRead = n['is_read'] as bool? ?? false;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                color: isRead ? null : color.withAlpha(10),
                                child: ListTile(
                                  leading:
                                      Icon(_severityIcon(severity), color: color),
                                  title: Text(
                                    n['title'] as String? ?? '',
                                    style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                  subtitle:
                                      Text(n['message'] as String? ?? ''),
                                  trailing: isRead
                                      ? null
                                      : TextButton(
                                          onPressed: () => _markAsRead(
                                            n['id'] as String? ?? '',
                                          ),
                                          child: const Text('既読'),
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

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning_amber;
      case 'success':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }
}

class _SeverityFilter extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _SeverityFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = ['all', 'critical', 'warning', 'info', 'success'];
    const labels = {
      'all': '全て',
      'critical': '緊急',
      'warning': '警告',
      'info': '情報',
      'success': '成功',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: options
            .map(
              (opt) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(labels[opt] ?? opt),
                  selected: selected == opt,
                  onSelected: (_) => onChanged(opt),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
