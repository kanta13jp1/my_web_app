import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 駐車場予約ページ
/// parking-reservation Edge Function と連携して駐車場の予約を管理
class ParkingReservationPage extends StatefulWidget {
  const ParkingReservationPage({super.key});

  @override
  State<ParkingReservationPage> createState() => _ParkingReservationPageState();
}

class _ParkingReservationPageState extends State<ParkingReservationPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _reservations = [];

  @override
  void initState() {
    super.initState();
    _fetchReservations();
  }

  Future<void> _fetchReservations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'parking-reservation',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['reservations'] is List) {
        setState(() => _reservations = data['reservations'] as List);
      } else if (data is List) {
        setState(() => _reservations = data);
      } else {
        setState(() => _reservations = []);
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
      appBar: AppBar(
        title: const Text('駐車場予約'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReservations,
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
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchReservations,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _reservations.isEmpty
                  ? const Center(child: Text('予約はありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reservations.length,
                      itemBuilder: (context, index) {
                        final res = _reservations[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.local_parking,
                                color: Colors.blue),
                            title: Text(
                              res['spot_name']?.toString() ??
                                  'スポット ${index + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              res['reserved_at']?.toString() ??
                                  res['status']?.toString() ?? '',
                            ),
                            trailing: Chip(
                              label: Text(
                                res['status']?.toString() ?? '予約済み',
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor:
                                  res['status'] == 'active'
                                      ? Colors.green.shade100
                                      : Colors.grey.shade200,
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('新規予約機能は準備中です')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('新規予約'),
      ),
    );
  }
}
