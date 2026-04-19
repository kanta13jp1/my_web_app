import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 予約スケジューラーページ
/// appointment-scheduler Edge Function と連携して予約を管理
class AppointmentSchedulerPage extends StatefulWidget {
  const AppointmentSchedulerPage({super.key});

  @override
  State<AppointmentSchedulerPage> createState() =>
      _AppointmentSchedulerPageState();
}

class _AppointmentSchedulerPageState extends State<AppointmentSchedulerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _appointments = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'appointment-scheduler',
        body: {'action': 'list'},
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
      if (mounted) {
        setState(() => _errorMessage = '予約一覧の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('予約スケジューラー'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAppointments,
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
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchAppointments,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _appointments.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 64,
                            color: Color(0xFFB0B0B0),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '予約はありません',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFFB0B0B0),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _appointments.length,
                      itemBuilder: (context, index) {
                        final item =
                            _appointments[index] as Map<String, dynamic>;
                        final title = item['title']?.toString() ??
                            item['name']?.toString() ??
                            '予約 ${index + 1}';
                        final subtitle = item['date']?.toString() ??
                            item['scheduled_at']?.toString() ??
                            '';
                        return Card(
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.event,
                              color: Color(0xFF6366F1),
                            ),
                            title: Text(title),
                            subtitle:
                                subtitle.isNotEmpty ? Text(subtitle) : null,
                          ),
                        );
                      },
                    ),
    );
  }
}
