import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/external_diff_alert/external_diff_alert_container.dart';

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
  List<Map<String, Object?>> _notifications = <Map<String, Object?>>[];
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
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'admin-hub',
        body: {
          'action': 'admin.notifications.list',
          if (_filterSeverity != 'all') 'severity': _filterSeverity,
        },
      );
      final data = res.data;
      if (data is Map<Object?, Object?> &&
          data['notifications'] is List<Object?>) {
        final rawList = data['notifications'] as List<Object?>;
        final mapped = <Map<String, Object?>>[];
        for (final item in rawList) {
          if (item is Map<Object?, Object?>) {
            final row = <String, Object?>{};
            for (final entry in item.entries) {
              if (entry.key != null) {
                row[entry.key.toString()] = entry.value;
              }
            }
            mapped.add(row);
          }
        }
        setState(() {
          _notifications = mapped;
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
        'admin-hub',
        body: {'action': 'admin.notifications.mark_read', 'id': notificationId},
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
                backgroundColor: const Color(0xFFE53935).withAlpha(30),
                labelStyle: const TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 11,
                  height: 1.5,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            key: const Key('open_external_diff_alerts_btn'),
            tooltip: '外部連携 差分検知・リアルタイムアラート',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.radar_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(
                    name: '/admin-notifications?view=external-diff-alert',
                  ),
                  builder: (_) => const ExternalDiffAlertContainer(),
                ),
              );
            },
          ),
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
                          style: const TextStyle(
                            color: Color(0xFFE53935),
                            height: 1.5,
                          ),
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
                              final color = _severityColors[severity] ??
                                  const Color(0xFF3D5AFE);
                              final isRead = n['is_read'] as bool? ?? false;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                color: isRead ? null : color.withAlpha(10),
                                child: ListTile(
                                  leading: Icon(
                                    _severityIcon(severity),
                                    color: color,
                                  ),
                                  title: Text(
                                    n['title'] as String? ?? '',
                                    style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      height: 1.5,
                                    ),
                                  ),
                                  subtitle: Text(n['message'] as String? ?? ''),
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
