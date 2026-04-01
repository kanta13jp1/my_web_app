import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 予約スケジューラーページ
/// appointment-scheduler Edge Function と連携して予約管理を提供
class AppointmentSchedulerPage extends StatefulWidget {
  const AppointmentSchedulerPage({super.key});

  @override
  State<AppointmentSchedulerPage> createState() => _AppointmentSchedulerPageState();
}

class _AppointmentSchedulerPageState extends State<AppointmentSchedulerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _appointments = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'appointment-scheduler',
        queryParameters: {'view': 'upcoming'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['appointments'] is List) {
        setState(() => _appointments = data['appointments'] as List);
      } else if (data is List) {
        setState(() => _appointments = data);
      } else {
        setState(() => _appointments = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      case 'no_show':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'confirmed':
        return '確定';
      case 'pending':
        return '保留中';
      case 'cancelled':
        return 'キャンセル';
      case 'completed':
        return '完了';
      case 'no_show':
        return '無断欠席';
      default:
        return status ?? '不明';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('予約スケジューラー'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetch,
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
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetch,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _appointments.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            '予定はありません',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _appointments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = _appointments[i] as Map<String, dynamic>;
                        final status = item['status']?.toString();
                        final title = item['title']?.toString() ?? item['type']?.toString() ?? '予約';
                        final date = item['date']?.toString();
                        final time = item['time']?.toString();
                        final location = item['location']?.toString();
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(status).withAlpha(30),
                              child: Icon(Icons.event, color: _statusColor(status)),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              [
                                if (date != null) date,
                                if (time != null) time,
                                if (location != null) location,
                              ].join(' · '),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
